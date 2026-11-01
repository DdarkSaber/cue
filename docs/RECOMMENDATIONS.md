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

Missing genre/tag metadata stays neutral. No imported title receives an
invented 4/5 rating. Try now adds no stronger durable taste signal.

## Confidence and ranking

Novels and music entries are excluded from recommendations, including cached
titles and Revisit. Manga, manhwa and manhua refer to comics, not prose novels.

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
| Under-rated-format novelty | 0.10 |

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
with a total cap of 12 requests. Enabled-kind order rotates. Missing kinds
are refilled even if another kind fills the cache; unavailable formats are
reported. A refill checks up to four rounds while fewer than 20 eligible
candidates are cached. Swiping refills again as the deck runs low.

AniList pages contain up to 50 titles. Cinemeta offsets advance by 50.
TVmaze discovery samples four index pages with variable result counts.
App page cursors stop at 50 per kind/mood and refresh after seven days.

Hard filters and saved-history exclusions apply to every exact-match route and
exploration slot. A bounded batch or network failure is not proof of exhaustion:
Cue keeps the constraints and offers Retry, not a Review filters dead-end.

Short anime means at most 13 total episodes. When the broad anime catalog has
reported its final page and no eligible short anime remain, Cue can deal nearby
unwatched anime, shortest known episode count first. Each such card is labelled
"Longer than requested" with its episode count; the original filter stays visible.
Other constraints and saved-history exclusions still apply. New exact matches
take precedence when available again. Unknown lengths are not called short.
No titles are fabricated, and an unavailable catalog cannot guarantee a card.

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
