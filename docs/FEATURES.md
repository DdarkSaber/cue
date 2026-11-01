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
Library exposes those queues, which survive reopening. Resolving a title changes
that library, not an active neighbour.

Comic matching checks official, romanized and alternate names using AniList,
MangaDex and MangaUpdates, asking before uncertain links.

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
