# Recommendations

[Back to Cue](../README.md) · [Flow diagram](ARCHITECTURE.md#recommendation-flow)

## Evidence is not an invented rating

Long-term evidence is counted once per canonical title, not once per import.
Explicit ratings replace weaker shortlist or imported-history signals.

| Evidence | Weight |
|---|---:|
| Favourite / Rewatched | +3 |
| Would rewatch / Enjoyed | +2 |
| One-time | +1.5 |
| Okay | +0.5 |
| Disliked | -1 |
| Dropped rating | -1.5 |
| Unrated shortlist | +1 |
| Unrated imported watching / reading | +0.20 |
| Unrated imported completed | +0.15 |
| Imported planned / on-hold / dropped / unknown | 0 |
| Active Not interested | -0.3 |

Imported history is weighted by how recent it is, from the date the source
gives (MAL's finish or last-update date, Mihon's last read, the Excel date):

| Last activity | Multiplier |
|---|---:|
| Within 6 months | ×1.6 |
| Within 1 year | ×1.35 |
| Within 2 years | ×1.1 |
| Within 4 years | ×0.9 |
| Older | ×0.7 |
| Unknown date | ×1.0 |

Titles still in progress (watching or reading) get a further ×1.25.
Explicit ratings are not discounted by age.

Watching and reading keep separate taste: once a medium has 10 titles with
evidence, its own tag weights are used for picks in that medium, so anime
taste does not decide manhwa picks or the other way round. Interest clusters
are built per medium too. A watched anime never hides its manga (and vice
versa) from new picks.

Missing genre/tag metadata stays neutral. No imported title receives an
invented 4/5 rating. Try now adds no stronger durable taste signal.

## Confidence and ranking

Novels and music entries are excluded from recommendations, including cached
titles and Revisit. Manga, manhwa and manhua refer to comics, not prose novels.

Stalled works are not dealt as new picks (Revisit and your library are not
affected): anything cancelled; comics marked finished with fewer than 40
chapters, which are usually axed; and comics on hiatus with fewer than 50
chapters. Hiatus series with a solid run behind them are still dealt.

Confidence grows as `min(1, evidenceStrength / 20)`, summing
`min(1, abs(signal))` over distinct metadata-bearing titles.
Taste blends from neutral 0.5 towards 70% tag-cosine and 30% best-cluster
affinity. Weaker clusters are scaled relative to the strongest.
Clusters use at most the strongest 64 positive titles, four groups and eight
features per group.

Default score weights:

| Component | Weight |
|---|---:|
| Taste | 0.40 |
| Mood | 0.20 |
| Quality | 0.15 |
| Freshness | 0.15 |
| Format affinity | 0.10 |

Freshness is era fit: once 20 dated titles are known, release years near the
years you actually watch or read (within four years, against your busiest
stretch) score highest, and anything newer counts as a fit. Before that,
newer releases score higher. Format affinity favours the formats you rate
most (0.3 to 1, unrated formats 0.3), while exploration and variety slots
still mix other formats in.

Negative-feature penalty is capped at 0.30. A confident learned mood sets mood
weight to `0.10 + 0.25 * confidence` and taste weight to
`max(0.25, 0.40 - (moodWeight - 0.20))`.
Session and temporary lean each contribute up to 0.08; recent exposure
subtracts 0.04.

After Too long, known shorter episodic/reading lengths can receive a temporary
+0.04 preference versus -0.08 for known longer lengths. Unknown lengths and
movie runtime are not guessed.

## Bounded retrieval, not a full-catalog download

Cue ranks a growing cached sample. Each round includes one unfiltered broad
route per enabled kind plus at most three supported related-mood routes,
with a total cap of 12 route slots. Enabled-kind order rotates. The first
related ("taste") route goes to the kind you rate most, the others to the
kinds you rate least. Missing kinds are refilled even if another kind fills
the cache (at most once every two minutes); unavailable formats are reported.

Retrieval is demand driven. A refill runs only when fewer than 30 unseen,
eligible titles are cached for the current filters; with more than that,
swiping makes no catalog request at all, however many cards are swiped.
A refill checks up to four rounds until 30 are cached. Refills are
single-flight: a cycle in progress is never started again, and a re-rank
that is requested meanwhile waits for it.

AniList discovery pages through five orders, each with its own cursor:
popularity, trending, score, favourites and newest (newest skips announced
and cancelled titles). Orders take turns, least-advanced first, so a big
watched library that covers the popular pages does not exhaust supply.
Screen sources have one order each.

A route slot can make up to three requests: when a page is mostly titles
already cached (your library, earlier swipes), it digs on until ten new
titles arrive. A page that is short but new does not trigger more requests.

### Request budget

Worst case without a cap is 12 route slots x 3 requests, plus background
continuations, all queued behind a 30-a-minute limit. A single `RequestBudget`
bounds each cycle, and one token bucket bounds the device:

- **12 provider requests per refill cycle** (all rounds, every route, and the
  taste-seeded call, which counts as one request).
- **12 more for each filter set's background continuations** (up to three
  continuations share them). The share resets when exact matches fill the deck
  or the filters change.
- Every route's first request is claimed before any route digs deeper, so
  routes that have not been tried come before extra pages from overlapping
  ones.
- The budget closes early once 100 unseen titles have arrived.

All AniList traffic shares one bucket of **25 requests in any 60 seconds**
(the limit is 30; the margin leaves room for 429 retries). When it is empty,
the waiting request with the highest priority goes first: a deck refill, then
taste seeds, then AI-pick name lookups. Imports, search and details count as
deck priority.

AI picks sit outside the per-cycle budget but are bounded on their own: a refresh runs
at most once every four hours (or after five new ratings), looks up at most 30
suggested names, in batches of 12 (about three AniList requests), through the
same paced client.

At the paced rate 12 requests is about 24 seconds of AniList time, which is
why a refill happens only when the cache runs thin, not on a swipe count.

There is no page ceiling. A route is exhausted only when every order has
reported its final page; cursors refresh after seven days. AniList pages
contain up to 50 titles. Cinemeta offsets advance by 50. TVmaze discovery
samples four index pages with variable result counts. The Worker accepts
pages up to 500 (TMDB's own limit).

AniList calls are paced by the rate limit AniList reports. Calls made at
once queue one gap apart rather than bursting. After a 429, Cue waits as
long as Retry-After asks and never goes faster than 30 calls a minute again.
Three refused retries are reported as busy, never as exhaustion.

## Taste-seeded retrieval

Seeds are your strongest liked titles, at most 24: Favourite and Rewatched,
then Would rewatch and Enjoyed, then Once was enough, most recently finished
first. Imported completed or watching history fills in without ratings.
Okay, negative, planned and dropped titles never seed.

On each refill, and once after launch or a taste change even when the cache is
deep (in the background, one request), Cue asks about at most four seeds not
asked in the last seven days:

- AniList `Media.recommendations`, sorted `RATING_DESC`, 15 per seed, four
  seeds per request. Entries with a non-positive community rating, adult
  entries, novels and music are dropped.
- TMDB `/recommendations` through the Worker, first page, for TMDB-backed
  titles. Without a TMDB key the Worker answers an empty list and Cue skips
  the route. Animation, reality, talk and news TV is left out.

Only the seed's provider ID leaves the device. The returned titles join the
public cache with a public edge (seed, title, rank). The edges hold no
personal data; Cue joins them with the active library's seeds in memory.

Hard filters and library exclusions still apply. A candidate recommended by
one seed scores +0.04, plus 0.04 per further liked seed, capped at +0.12. Its
reason reads "Because you liked [seed title]." The card's `becauseOf` field lists
the seed catalog IDs, strongest first, for other surfaces. When a seeded fetch
or an AI-picks refresh finishes and adds candidates, the cards not yet shown are
re-ranked at once, with the card on screen kept, so the picks appear without a
swipe.

Recommendation edges are pruned at most once a day: rows are kept for the
current top 24 seeds and for 90 days after they were fetched; older edges of
seeds that are no longer top seeds are deleted.

Hard filters and saved-history exclusions apply to every exact-match route and
exploration slot. A bounded batch or network failure is not proof of exhaustion.
Swiping prefetches once fewer than eight cards remain, so the deck refills
before it runs out.

## Never an empty deck

Cue deals a card whenever any eligible real title is cached. Exact matches always
come first; later steps are reached only when earlier ones cannot fill the deck,
and every card they add carries a short label saying why it is there:

1. **Exact matches** for every filter, ranked as above.
2. **Soft preferences relaxed.** Mood, session lean and the exploration mix only
   affect ranking, never eligibility. Short season (at most 13 episodes or 60
   chapters) pads the deck with nearby known lengths, shortest first, labelled
   "Longer than requested" with the actual length. Unknown lengths are not
   called short.
3. **Wider search.** While relaxed cards are shown and more catalog pages remain,
   Cue keeps fetching in the background (up to three more bounded batches per
   filter set). New exact matches take precedence when they arrive.
4. **Nearest matches outside your filters.** If explicit filters (format, genre,
   era, status, country, Tell me exclusions) exclude every cached title, Cue
   deals the titles that miss the fewest filters, ranked by taste and quality,
   labelled "Outside your filter: Comedy". An inline chip offers Keep filter or
   Clear filter in one tap. While any exact match exists, format and genre
   filters stay strict.

Never relaxed: titles set aside with Not now (they stay hidden for their
full 14 days), titles in the library (including saved, watching and planned),
Not interested, novels and music, explicit franchise exclusions, adult titles
when hidden, and formats disabled in Settings. No titles are fabricated.

Only when no eligible title is reachable at all (for example offline with an
empty cache) does Cue show a non-card state: a friendly message with Try again
and Choose from saved. Offline refills retry automatically (5 s doubling to a
minute) and immediately when the app returns to the foreground. A deck of
fewer than eight cards after a refused catalog (429 or a 5xx) retries on its
own the same way, waiting at least as long as the provider's Retry-After (up to
ten minutes). The retry stops when the screen closes or the filters change.

On launch, the deck is ranked from the local cache with current taste and shown
at once while the network refill runs; the card on screen is kept when the
refill finishes.

## Deal time with a large cache

Hard exclusions run in the cache query, not after loading it: library,
shortlist, Not now, Not interested, franchise exclusions, disabled formats,
novels, music and hidden adult titles never leave the database. With no
filters, at most 8,000 candidates load: 5,000 by best score and 3,000 most
recently cached, in storage order when the cache is smaller. A filtered deck
loads every match, so a narrow filter is never cut short. A cache of 20,000
titles deals in the same time as one of 8,000.

## Familiar, adjacent and exploring picks

For N cards, familiar share is:

```text
clamp(0.55 + 0.20 * tasteConfidence - 0.35 * explorationPreference, 0.25, 0.60)
```

Adjacent slots are rounded `0.20 * N`; the remainder explores.
Default exploration preference 0.35 generally yields 4/2/4 cold-start or
6/2/2 warm ten-card decks. Interleaving starts early rather than hiding every
other format at the end.

Known quality below 40 is avoided for variety when stronger eligible options
exist; missing scores are not assumed bad. Franchise/near-duplicate deck
grouping is a presentation safeguard, not sufficient evidence for a permanent
franchise exclusion.

## Temporary direction

More/Less uses signals +/-0.6; supported traits +0.6; Try now immediate
interest +0.9. Per-event decay is 0.85 and per-feature cap is +/-1.5.
The reversible in-memory journal holds at most 40 events, 32 features per
action and 256 retained bias features.

These signals expire after 45 minutes away, a new local day, library switch,
process restart or Reset session. They never become ratings, permanent
exclusions, learned moods or synced taste. Public metadata fetched along
those routes can remain cached.

Surprise me changes the next five choices within hard filters, then restores
the exploration preference. Different direction is an optional dismissible
suggestion after repeated Not now; it clears temporary direction and shifts
the mix. Too long / Wrong mood / Saving for later are session-only context.
Not now's delay persists, but does not train a lasting negative mood.

## Tell me and live mood

Cue learns modes from choices and notices mood changes within a few swipes.
It learns personal word meanings from choices made after typing them.
Recognized format and genre keywords work immediately; other meanings need
evidence. The Cue read chip shows the current interpretation and lets you
correct it; mood naming and management are available in the existing UI.

Recognized formats and positive genres are strict filters. For example,
"fast paced comedy kdrama" requires K-drama and Comedy, not Action.
Mood and pacing remain soft preferences because pace metadata is incomplete.
Local rules handle bounded synonyms and reliable negation, not general
natural-language understanding.

The sheet shows understood constraints and unmapped text. Clearing Tell me
removes its derived constraints, not unrelated manual filters. Unknown genres
cannot prove "without horror". Smarter mood text is optional and off by
default; it sends the typed sentence to Groq with Gemini as a fallback for
allowlisted hints, not title recommendations. Real Gemini key validity remains
unverified; see [Testing](TESTING.md).

## Deliberate exclusions

Ordinary discovery excludes saved library titles, including watching, reading
and planned titles. The old default-rewatch preference does not bring history
back into ordinary discovery. Revisit explicitly includes Rewatched / Would
rewatch ratings or an actual watch date more than three years ago.

Persistent franchise exclusion requires a verified TMDB movie collection ID.
It covers cached members with the same ID, not unknown members or
cross-provider adaptations. Cue never guesses identity from title strings.
Restore it in Settings > Recommendation preferences; Reset swipes preserves
this deliberate preference.
