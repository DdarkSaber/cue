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
  anilist('anilist', 'AniList', byUsername: true),
  trakt('trakt', 'Trakt', byUsername: false);

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

  @override
  void initState() {
    super.initState();
    ref.read(tokenStoreProvider).read(widget.provider.id).then((t) {
      if (mounted && t != null) setState(() => _token = t);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _clientId => switch (widget.provider) {
    SignInProvider.mal => _config?.mal,
    SignInProvider.anilist => _config?.anilist,
    SignInProvider.trakt => _config?.trakt,
  };

  Future<void> _toggle() async {
    setState(() => _open = !_open);
    if (_open && _config == null) {
      try {
        final c = await ref.read(catalogGatewayProvider).oauthConfig();
        if (mounted) setState(() => _config = c);
      } on CatalogUnavailable {
        if (mounted) {
          setState(() => _message = 'Offline. Sign-in needs a connection.');
        }
      }
    }
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
      final code = await authorize(url, widget.provider.id, state: state);
      if (code == null) throw const CatalogUnavailable('cancelled');
      final gateway = ref.read(catalogGatewayProvider);
      final token = await gateway.exchangeCode(
        widget.provider.id,
        code: code,
        redirectUri: redirect,
        codeVerifier: widget.provider == SignInProvider.anilist
            ? null
            : verifier,
      );
      await ref.read(tokenStoreProvider).write(widget.provider.id, token);
      if (mounted) setState(() => _token = token);
      return gateway.listSignedIn(widget.provider.id, token);
    });
  }

  /// Reads the list again with the token kept on this device. A token the
  /// provider no longer accepts is dropped so the person can sign in again.
  Future<void> _importAgain() async {
    final token = _token;
    if (token == null) return;
    await _run(() async {
      try {
        return await ref
            .read(catalogGatewayProvider)
            .listSignedIn(widget.provider.id, token);
      } on CatalogUnavailable catch (e) {
        if (e.code == 'offline') rethrow;
        await _signOut();
        throw const CatalogUnavailable('expired');
      }
    });
  }

  Future<void> _signOut() async {
    await ref.read(tokenStoreProvider).delete(widget.provider.id);
    if (mounted) setState(() => _token = null);
  }

  Future<void> _run(Future<List<Map<String, dynamic>>> Function() load) async {
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
    final configured = _clientId != null;
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
                      Text(
                        p.byUsername ? 'Sign in or username' : 'Sign in',
                        style: const TextStyle(
                          fontSize: 13,
                          color: CueColors.textMuted,
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
                    'Signs in on ${p.label}\'s own page, is read only. Cue keeps the sign-in on this device, so you can import again without signing in. Sign out removes it.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: CueColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: CueSpace.md),
                  if (_config != null && !configured)
                    Text(
                      'Sign-in for ${p.label} is not set up on this Cue yet.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CueColors.notNow,
                      ),
                    ),
                  if (_token != null) ...[
                    Text(
                      'Signed in to ${p.label} on this device.',
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
