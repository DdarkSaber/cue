import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/catalog_gateway.dart';
import '../../imports/adapters/list_api.dart';
import '../../imports/oauth.dart';
import '../../imports/records.dart';
import '../../data/profile_repository.dart' show randomId;

enum SignInProvider {
  mal('mal', 'MyAnimeList', byUsername: true),
  anilist('anilist', 'AniList', byUsername: true);

  const SignInProvider(this.id, this.label, {required this.byUsername});
  final String id;
  final String label;

  /// Public lists can be read by username without signing in.
  final bool byUsername;
}

/// A source row with Sign in (provider page, read-only, one time) and, where
/// the service allows it, "Use my username" for public lists.
class SignInSourceRow extends ConsumerStatefulWidget {
  const SignInSourceRow({
    super.key,
    required this.provider,
    required this.onRecords,
  });

  final SignInProvider provider;
  final Future<void> Function(ParsedImport) onRecords;

  @override
  ConsumerState<SignInSourceRow> createState() => _SignInSourceRowState();
}

class _SignInSourceRowState extends ConsumerState<SignInSourceRow> {
  bool _open = false;
  bool _busy = false;
  String? _message;
  final _name = TextEditingController();
  OAuthConfigDto? _config;
  String? _token;
  String? _account;

  @override
  void initState() {
    super.initState();
    _loadSignIn();
    _loadConfig();
  }

  Future<void> _loadSignIn() async {
    final store = ref.read(tokenStoreProvider);
    final id = widget.provider.id;
    final token = await store.read(id);
    if (!mounted || token == null) return;
    setState(() => _token = token);
    final name = await store.readName(id) ?? await _lookUpName(token);
    if (mounted && name != null) setState(() => _account = name);
  }

  /// Best effort: the list import never depends on knowing the name.
  Future<String?> _lookUpName(String token) async {
    try {
      final name = await ref
          .read(catalogGatewayProvider)
          .signedInName(widget.provider.id, token);
      if (name != null && name.isNotEmpty) {
        await ref.read(tokenStoreProvider).writeName(widget.provider.id, name);
      }
      return name;
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _clientId => switch (widget.provider) {
    SignInProvider.mal => _config?.mal,
    SignInProvider.anilist => null,
  };

  /// Loaded up front so a row can say "Not set up" before it is opened.
  Future<void> _loadConfig() async {
    if (_config != null) return;
    try {
      final c = await ref.read(catalogGatewayProvider).oauthConfig();
      if (mounted) setState(() => _config = c);
    } on CatalogUnavailable {
      if (mounted && _open) {
        setState(() => _message = 'Offline. Sign-in needs a connection.');
      }
    }
  }

  Future<void> _toggle() async {
    setState(() => _open = !_open);
    if (_open) await _loadConfig();
  }

  Future<void> _byUsername() async {
    final name = _name.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{2,32}$').hasMatch(name)) {
      setState(
        () => _message = 'Enter a username with letters, digits, _ or -.',
      );
      return;
    }
    await _run(
      () =>
          ref.read(catalogGatewayProvider).listByUser(widget.provider.id, name),
    );
  }

  Future<void> _signIn() async {
    final clientId = _clientId;
    if (clientId == null) return;
    final verifier = pkceVerifier();
    final redirect = redirectUriFor(widget.provider.id);
    final state = randomId(8);
    final url = authorizeUrl(
      widget.provider.id,
      clientId: clientId,
      redirectUri: redirect,
      verifier: verifier,
      state: state,
    );
    await _run(() async {
      final result = await authorize(url, widget.provider.id, state: state);
      if (result == null) throw const CatalogUnavailable('cancelled');
      final gateway = ref.read(catalogGatewayProvider);
      final tokens = await gateway.exchangeCode(
        widget.provider.id,
        code: result,
        redirectUri: redirect,
        codeVerifier: verifier,
      );
      final token = tokens.access;
      await _keep(tokens);
      final name = await _lookUpName(token);
      if (mounted && name != null) setState(() => _account = name);
      return gateway.listSignedIn(widget.provider.id, token);
    });
  }

  /// Reads the list again with the token kept on this device. A token the
  /// provider no longer accepts is dropped so the person can sign in again.
  Future<void> _keep(OAuthTokens t) async {
    final store = ref.read(tokenStoreProvider);
    final id = widget.provider.id;
    await store.write(id, t.access);
    // Keep the old refresh token if the provider did not send a new one.
    if (t.refresh != null) await store.writeRefresh(id, t.refresh);
    await store.writeExpiry(id, t.expiresAt);
    if (mounted) setState(() => _token = t.access);
  }

  /// Whether [e] says the provider refused the sign-in itself, as opposed
  /// to an outage, a rate limit or a broken answer. Only then is the kept
  /// sign-in dropped. The Worker answers 401 `token_expired`; for the
  /// renewal call only, a bare 401 from an older Worker counts too.
  static bool _refused(CatalogUnavailable e, {bool renewal = false}) =>
      e.code == 'token_expired' || (renewal && e.code == 'http_401');

  /// Renews the access token with the kept refresh token. Null when that is
  /// not possible: no refresh token, or the provider refused it. Any other
  /// failure (offline, outage, rate limit) is rethrown so the caller keeps
  /// the sign-in.
  Future<String?> _renew() async {
    final id = widget.provider.id;
    final rt = await ref.read(tokenStoreProvider).readRefresh(id);
    if (rt == null) return null;
    try {
      final t = await ref.read(catalogGatewayProvider).refreshTokens(id, rt);
      await _keep(t);
      return t.access;
    } on CatalogUnavailable catch (e) {
      if (_refused(e, renewal: true)) return null;
      rethrow;
    }
  }

  /// Reads the list again with the kept sign-in, renewing it first when it
  /// has expired (or is about to) and once more if the provider refuses it.
  /// The person is asked to sign in again only when the provider says the
  /// sign-in itself is no longer valid; an outage keeps it.
  Future<void> _importAgain() async {
    var token = _token;
    if (token == null) return;
    await _run(keepsSignIn: true, () async {
      final gateway = ref.read(catalogGatewayProvider);
      final id = widget.provider.id;
      final expiry = await ref.read(tokenStoreProvider).readExpiry(id);
      final soon = DateTime.now().add(const Duration(hours: 1));
      if (expiry != null && expiry.isBefore(soon)) {
        try {
          token = await _renew() ?? token;
        } on CatalogUnavailable catch (e) {
          // The renewal service is down: the kept token may still work.
          if (e.code == 'offline') rethrow;
        }
      }
      try {
        return await gateway.listSignedIn(id, token!);
      } on CatalogUnavailable catch (e) {
        if (!_refused(e)) rethrow;
        final renewed = await _renew();
        if (renewed != null) {
          try {
            return await gateway.listSignedIn(id, renewed);
          } on CatalogUnavailable catch (e2) {
            if (!_refused(e2)) rethrow;
          }
        }
        await _signOut();
        throw const CatalogUnavailable('expired');
      }
    });
  }

  Future<void> _signOut() async {
    await ref.read(tokenStoreProvider).delete(widget.provider.id);
    if (mounted) {
      setState(() {
        _token = null;
        _account = null;
      });
    }
  }

  /// [keepsSignIn]: the call used the kept sign-in, so a failure says that
  /// sign-in is still there to try again with.
  Future<void> _run(
    Future<List<Map<String, dynamic>>> Function() load, {
    bool keepsSignIn = false,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final entries = await load();
      if (!mounted) return;
      if (entries.isEmpty) {
        setState(
          () => _message = 'No titles found. The list may be private or empty.',
        );
        return;
      }
      await widget.onRecords(parseListEntries(widget.provider.id, entries));
    } on CatalogUnavailable catch (e) {
      if (!mounted) return;
      setState(
        () => _message = switch (e.code) {
          'cancelled' => 'Sign-in was cancelled. Nothing was imported.',
          'not_configured' =>
            '${widget.provider.label} is not set up on this Cue yet.',
          'offline' => 'Offline. Try again when connected.',
          'expired' =>
            'Your ${widget.provider.label} sign-in expired. Sign in again.',
          _ when keepsSignIn && _token != null =>
            '${widget.provider.label} is not answering right now. Your '
                'sign-in is kept; try again in a minute.',
          _ => '${widget.provider.label} did not answer. Try again later.',
        },
      );
    } on Object {
      if (mounted) {
        setState(
          () => _message = 'Sign-in did not finish. Nothing was imported.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    // AniList refuses the Worker and its implicit grant is not available to
    // Cue, so AniList is public-username only.
    final signInAvailable = p != SignInProvider.anilist;
    final configured = signInAvailable && _clientId != null;
    final usernameWorks =
        p == SignInProvider.anilist || (p == SignInProvider.mal && configured);
    return Container(
      margin: const EdgeInsets.only(bottom: CueSpace.sm),
      decoration: BoxDecoration(
        color: CueColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CueColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: CueSize.minTarget + 8,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: CueSpace.sm),
                      Flexible(
                        child: Text(
                          _token != null
                              ? (_account != null
                                    ? 'Signed in as $_account'
                                    : 'Signed in')
                              : _config != null && !configured
                              ? (usernameWorks ? 'Username' : 'Not set up yet')
                              : p.byUsername
                              ? (signInAvailable
                                    ? 'Sign in or username'
                                    : 'Username')
                              : 'Sign in',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CueColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signInAvailable
                        ? 'Signs in on ${p.label}\'s own page and is read only. Cue keeps the sign-in on this device, so you can import again without signing in. Sign out removes it.'
                        : 'Reads your public ${p.label} list by username. No login. A private list needs to be made public first.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: CueColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: CueSpace.md),
                  if (_config != null && !configured && signInAvailable)
                    Text(
                      'Sign-in for ${p.label} is not set up on this Cue yet.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CueColors.notNow,
                      ),
                    ),
                  if (_token != null) ...[
                    Text(
                      _account != null
                          ? 'Signed in to ${p.label} as $_account, on this device.'
                          : 'Signed in to ${p.label} on this device.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CueColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: CueSpace.sm),
                    Row(
                      spacing: CueSpace.sm,
                      children: [
                        CueSecondaryButton(
                          label: 'Import again',
                          onPressed: _busy ? null : _importAgain,
                        ),
                        TextButton(
                          onPressed: _busy ? null : _signOut,
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ] else if (configured)
                    CueSecondaryButton(
                      label: 'Sign in with ${p.label}',
                      onPressed: _busy ? null : _signIn,
                    ),
                  if (usernameWorks) ...[
                    const SizedBox(height: CueSpace.md),
                    Row(
                      spacing: CueSpace.sm,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _name,
                            maxLength: 32,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              hintText: '${p.label} username',
                              counterText: '',
                            ),
                            onSubmitted: (_) => _byUsername(),
                          ),
                        ),
                        CueSecondaryButton(
                          label: 'Use username',
                          onPressed: _busy ? null : _byUsername,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Public lists only. No password, ever.',
                      style: TextStyle(
                        fontSize: 12,
                        color: CueColors.textMuted,
                      ),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: CueSpace.md),
                    const LinearProgressIndicator(color: CueColors.accent),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: CueSpace.sm),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: CueColors.notInterested,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
