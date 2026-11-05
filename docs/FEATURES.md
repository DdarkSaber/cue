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

Optional Rate your library is a full-screen deck of your own titles' story
cards: swipe up Loved, right Enjoyed, down One-time, left Dropped (or use the
buttons or arrow keys), with Skip, Undo, a progress count and an exit button
at the top. Shortlist follow-ups use the same deck: up Loved, right Enjoyed,
left Not for me, down Haven't started.
They are explicit answers, not automatic ratings for imported history.
Skip, dismissal and Haven't started do not assume consumption or liking.
Optional follow-up prompts concern older unrated saved picks and respect
dismissal. Rating Undo checks for newer edits.

## First-run taste quickstart

With fewer than five liked titles (Favourite, Enjoyed, Would rewatch, Rewatched
or Will try), Cue offers a skippable "Pick a few you loved" screen once, and the
deck keeps a quiet "Teach Cue your taste" hint until you have enough. It shows
popular titles across your enabled formats (offline it falls back to the cached
catalog) with a search box. Picks are saved as explicit Favourite ratings, so
picks and "Because you liked X" work without an import. Skipping uploads and
saves nothing.

## Deck help

Each decision shows a confirmation with a tappable Undo for a few seconds; Undo
also sits in the header (phone) or under the actions (desktop). Keys on desktop:
arrows decide, Shift+Enter Try now, U (or Ctrl/Cmd+Z) Undo. Choices give a short
haptic tick on Android. Details lead with why the title was suggested, then the
story, genres, facts and watch options, and scroll at 2x text on small screens.

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

## Library, Will try and Settings usability

Library opens with a Your taste card: how many titles you rated, the genres
and formats you rate well, and a Rate more titles button. It states what
drives recommendations: ratings first, unrated imports only as weak hints.
Below it, search, Sort and filter (Recent, Rating, Title A-Z; format; In
progress, Finished, Planned, Not rated) and a one-tap star on each row to
rate in place. Select several rates or removes many titles at once (Remove
asks first). An empty library or an empty filter result points to Import or
the deck.

Will try offers Pick for tonight (from Try now titles when any exist, else
all saved titles). Marking Watched or Read it asks how it was; skipping
changes nothing, answering stores a rating that feeds taste. The page
scrolls at large text sizes instead of clipping controls. Order is the
saved order with Try now titles first; there is no manual drag reordering.

Import shows "Step 1 of 3" with plain names (Pick your list, Matching your
titles, Check and confirm), says progress is saved and resumes, explains that
unmatched titles go to Library under Needs review and are not counted as
watched, and gives actionable file errors.

Settings groups rows as Recommendations, Appearance, Library and sync,
Privacy and About. All AI features (AI picks, Smarter mood text) sit under
one opt-in section with a privacy explainer; both are off by default.

## Scope

Working platforms are Android and web, with deck, local mood, imports/Undo,
MAL sign-in/renewal, public AniList lists, libraries and encrypted sync of titles,
lists, settings and mood.

iOS, Trakt, MyDramaList and Prime Video sign-in are not currently planned.
Their title lists can still be imported through a supported CSV.
See [Recommendations](RECOMMENDATIONS.md) for session tools and filtering rules.
