import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/icons.dart';
import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/franchise_exclusion_repository.dart';
import '../../domain/franchise_identity.dart';
import '../../domain/models/title.dart';

class _ExcludedCollection {
  const _ExcludedCollection(this.scope, this.members);
  final String scope;
  final List<String> members;

  String get label => 'TMDB collection ${scope.substring('tmdb:c'.length)}';
}

final _excludedCollectionsProvider = FutureProvider.autoDispose
    .family<List<_ExcludedCollection>, String>((ref, profileId) async {
      ref.watch(libraryVersionProvider);
      final db = ref.watch(databaseProvider);
      final scopes = await FranchiseExclusionRepository(db)
          .activeScopes(profileId);
      final sorted = scopes.toList()..sort();
      if (sorted.isEmpty) return const [];
      final rows = await (db.select(
        db.catalogTitles,
      )..where((t) => t.franchiseId.isIn(sorted))).get();
      final members = <String, Set<String>>{};
      for (final row in rows) {
        final title = Title.fromRow(row);
        final scope = reliableFranchiseId(title);
        if (scope != null &&
            title.displayTitle.trim().isNotEmpty &&
            title.displayTitle != 'Untitled') {
          (members[scope] ??= {}).add(title.displayTitle);
        }
      }
      return [
        for (final scope in sorted)
          _ExcludedCollection(scope, ((members[scope] ?? {}).toList()..sort())),
      ];
    });

/// Deliberate library preferences, separate from swipe history and session mood.
class FranchiseExclusionsSection extends ConsumerStatefulWidget {
  const FranchiseExclusionsSection({super.key, this.profileId});

  /// Omit for the active library; supply for a profile-scoped management page.
  final String? profileId;

  @override
  ConsumerState<FranchiseExclusionsSection> createState() =>
      _FranchiseExclusionsSectionState();
}

class _FranchiseExclusionsSectionState
    extends ConsumerState<FranchiseExclusionsSection> {
  bool _expanded = false;
  bool _busy = false;
  String? _message;
  FranchiseExclusionChange? _undo;

  String? get _profileId =>
      widget.profileId ?? ref.read(profileIdProvider).value;

  FranchiseExclusionRepository get _repo => FranchiseExclusionRepository(
    ref.read(databaseProvider),
    clock: ref.read(clockProvider),
  );

  void _clearResult() {
    _message = null;
    _undo = null;
  }

  @override
  void didUpdateWidget(FranchiseExclusionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) _clearResult();
  }

  Future<void> _restore(
    String profileId,
    _ExcludedCollection collection,
  ) async {
    final confirmed = await showCueSheet<bool>(
      context,
      kicker: 'Library preference',
      title: 'Restore ${collection.label}?',
      body: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CueSpace.md,
        children: [
          const Text(
            'Allow verified members of this collection in this library\'s '
            'picks again. Individual title exclusions, saved entries and '
            'other libraries stay unchanged. You can Undo this restoration.',
          ),
          CueSecondaryButton(
            label: 'Cancel',
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CuePrimaryButton(
            label: 'Restore collection',
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _profileId != profileId) return;
    setState(() => _busy = true);
    try {
      final change = await _repo.restore(profileId, collection.scope);
      ref.read(libraryVersionProvider.notifier).bump();
      if (mounted && _profileId == profileId) {
        setState(() {
          _undo = change;
          _message = '${collection.label} restored.';
        });
      }
    } on Object {
      if (mounted && _profileId == profileId) {
        setState(
          () => _message = 'Could not restore this collection. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undoRestore() async {
    final change = _undo;
    if (change == null || change.profileId != _profileId) return;
    setState(() => _busy = true);
    try {
      final restored = await _repo.undo(change);
      if (restored) ref.read(libraryVersionProvider.notifier).bump();
      if (mounted && _profileId == change.profileId) {
        setState(() {
          _undo = null;
          _message = restored
              ? 'Restoration undone. This collection is excluded again.'
              : 'A newer preference was kept. Nothing was overwritten.';
        });
      }
    } on Object {
      if (mounted && _profileId == change.profileId) {
        setState(() => _message = 'Could not undo. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _button(String label, CueIcons icon, VoidCallback? callback) =>
      TextButton(
        onPressed: callback,
        style: TextButton.styleFrom(
          foregroundColor: CueColors.text,
          alignment: Alignment.centerLeft,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        child: Row(
          children: [
            CueIcon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    ref.listen(profileIdProvider, (previous, next) {
      if (widget.profileId == null && previous?.value != next.value) {
        setState(_clearResult);
      }
    });
    final profileId = widget.profileId ?? ref.watch(profileIdProvider).value;
    final collections = profileId == null
        ? null
        : ref.watch(_excludedCollectionsProvider(profileId));
    final count = collections?.value?.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          child: _button(
            'Excluded franchises${count == null ? '' : ' ($count)'}',
            CueIcons.shield,
            () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded) ...[
          const Text(
            'Saved for this library. Resetting swipe history keeps these '
            'deliberate franchise preferences. Restore them here separately.',
            style: TextStyle(color: CueColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: CueSpace.md),
          if (collections == null || collections.isLoading)
            const Text('Loading excluded collections…')
          else if (collections.hasError) ...[
            const Text('Could not load excluded collections.'),
            _button(
              'Retry loading collections',
              CueIcons.repeat,
              () => ref.invalidate(_excludedCollectionsProvider(profileId!)),
            ),
          ] else if (collections.value!.isEmpty)
            const Text('No excluded franchises in this library.')
          else
            for (final collection in collections.value!) ...[
              const SizedBox(height: CueSpace.md),
              Text(
                collection.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                collection.members.isEmpty
                    ? 'No verified member names cached on this device.'
                    : 'Cached members: ${collection.members.join(', ')}',
                style: const TextStyle(color: CueColors.textMuted, height: 1.5),
              ),
              _button(
                'Restore ${collection.label}',
                CueIcons.undo,
                _busy ? null : () => _restore(profileId!, collection),
              ),
            ],
          if (_message != null)
            Semantics(liveRegion: true, child: Text(_message!)),
          if (_undo != null && _undo!.profileId == profileId)
            _button(
              'Undo collection restoration',
              CueIcons.undo,
              _busy ? null : _undoRestore,
            ),
        ],
      ],
    );
  }
}
