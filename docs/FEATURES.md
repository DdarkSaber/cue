# Feature guide

[Back to Cue](../README.md)

## Deck and saved picks

Default directions are right = Will try, left = Not interested,
up = Watched / Read it, down = Not now (14 days). Remap them in Settings.
Buttons, arrow keys and screen-reader actions are available.

Double-tap is the only additional gesture: Try now saves a priority marker,
not a rating, consumption record or playback action. Single-tap opens details.
Try now also appears in Filters > Session picks and Why; keyboard: Shift+Enter.
Undo restores the prior state unless a newer edit makes that unsafe.
There is no triple-tap or gesture combination.

Cards explain their reasons without fake match percentages.
Tonight's picks filters the existing shortlist's Try now markers—it is not a
second list. Saved options includes a card picker and a two-title factual
comparison. Unknown metadata stays unknown; Cue does not invent a winner.
Saved titles remain excluded from ordinary discovery.

Optional Rate your library cards offer Loved, Enjoyed, One-time and Dropped.
They are explicit answers, not automatic ratings for imported history.
Skip, dismissal and Haven't started do not assume consumption or liking.
Optional follow-up prompts concern older unrated saved picks and respect
dismissal. Rating Undo checks for newer edits.

## Imports and separate libraries

Supported inputs include MyAnimeList XML, Netflix viewing activity,
Mihon/Tachiyomi backups, CSV or Excel with a Title column, and Cue backups.
You can also sign in to MyAnimeList or use a public AniList username.
Preview matches before confirmation; every import can be undone.

Matching resumes from local checkpoints for the active library. Ready previews
and inclusion choices remain on this device until confirmation or cancellation;
they are never automatically committed or synced. Interrupted requests may be
repeated, but completed matching chunks are kept.

Imports merge by matched catalog identity into the selected library, preserving
stronger statuses and manual edits. Separate local libraries remain independent.
Unmatched or uncertain rows require review before becoming known history.
An entirely unresolved import can be explicitly saved for Library review
without linking any titles or treating them as watched.
Library exposes those queues, which survive reopening. Resolving a title changes
that library, not an active neighbour.

Matching uses known provider IDs first, then official, romanized, native and
alternate names. Anime and comics use AniList; MangaDex and MangaUpdates can
provide additional comic names and verified catalog links. Import labels do not
restrict comic searches to one country. Discovery filters are unchanged.

Unique verified matches are selected automatically in the import preview.
Multiple aliases of one canonical title are not treated as separate matches.
Unresolved, ambiguous or merely similar works stay for review; anime seasons,
movie parts and adaptations are not silently collapsed to a base title.
Manual review and Add a title also search titles already cached from the deck,
including offline. Provider failures produce an incomplete-results warning,
not a false "no matches" result.

The deck checks further catalog pages when the first batch is mostly saved,
watched or outside the requested filters, and prefetches in the background once
fewer than eight cards remain. Each refill is bounded. An empty non-final page
is not treated as the end of the catalog.

The deck never dead-ends while an eligible title is cached. Opening the app
shows cached cards immediately while the catalog refreshes. When exact matches
run out, Cue deals the nearest honest alternatives, each labelled: "Longer than
requested" for Short season (nearest known lengths first; short means at most 13
episodes, not short runtime), then "Outside your filter: <name>" with a one-tap
Keep filter / Clear filter chip. Titles set aside with Not now stay hidden for
their 14 days. Saved, watched, Not interested, novels, music and excluded franchises never return. See
[Recommendations](RECOMMENDATIONS.md#never-an-empty-deck).

Only offline with an empty cache (or with every cached title used) does Cue show
a message instead of a card; it retries automatically when the connection
returns, and Try again or Choose from saved are always available.

New unresolved rows retain their original normalized rating and progress fields
locally until reviewed, including across restart. Older review rows retain only
the fields that the earlier app stored; missing metadata cannot be reconstructed
from those rows alone. Review never bulk-confirms ambiguous matches.

## Browse and correct

In Settings > This library, open a library to browse titles grouped by type
and sorted by name. Search, filter by format or remove an incorrect title with
confirmation. Browsing does not switch libraries; use Use this library.
Delete libraries independently; deleting the last creates a fresh empty one.

Details offers local correction/review shortcuts and known-trait direction.
Rating or review correction cannot repair provider artwork, synopsis or genres,
and uploads no correction report.

## Scope

Working platforms are Android and web, with deck, local mood, imports/Undo,
MAL sign-in/renewal, public AniList lists, libraries and encrypted sync of titles,
lists, settings and mood.

iOS, Trakt, MyDramaList and Prime Video sign-in are not currently planned.
Their title lists can still be imported through a supported CSV.
See [Recommendations](RECOMMENDATIONS.md) for session tools and filtering rules.
