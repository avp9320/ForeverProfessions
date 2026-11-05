# Changelog

## 0.3.11

- Improved the leveling coach’s contrast, spacing, and section labels.
- Separated the 1–300 route target from live skill-up recipe choices and aligned material details with the selected recipe.


## 0.3.8

- Improved the leveling coach’s contrast, spacing, and section labels.
- Separated the 1–300 route target from live skill-up recipe choices and aligned material details with the selected recipe.

## 0.3.7

- Fixed automatic route selection so detected gathers switch away from a legacy saved selection.
- Explicit `/fp resource` choices now remain in control of the route.


## 0.3.6

- Added numbered observed gathering stops and connecting loop lines to the matching World Map zone.
- The route overlay refreshes when a gather is detected and uses account-wide saved nodes.


## 0.3.5

- Connected the 1–300 leveling routes to live profession scans and the Leveling UI/commands.
- Uses Forever's live recipe skill-up state and learned recipes to choose each next step.
- Added remaining-route reagent totals for learned recipes, bag/bank counts, and last-seen per-character material snapshots.
- Added rank-cap reminders and persistent material goals through `/fp track`, `/fp untrack`, and `/fp mats`.


## 0.3.2

- Read Forever's recipe `canSkillUp` and relative-difficulty data instead of assuming the recipe list uses colored text.
- Added recipe material reading through the modern profession schematic API, including alternative reagents and bag counts.


## 0.3.1

- Repackaged the complete profession leveling coach, UI button, and `/fp level` command in the WoWUp release.


## 0.3.0

- Added a profession leveling coach that recommends learned orange/yellow recipes from the live profession window.
- Shows reagents required for one craft, current bag counts when available, and up to two alternate skill-up recipes.
- Added rank-cap trainer reminders, a Leveling button, and `/fp level`.


## 0.2.2

- Automatically switch to the detected profession route on first gather, including when the account has a legacy manual selection saved.

## 0.2.1

- Require a successful player gathering cast before recording a loot-correlated location.
- Handle loot arriving before the cast-success event.
- Allow up to 45 seconds to pair fishing casts with catches.
- Show unclassified player cast names with \`/fp detect debug\`.

## 0.2.0

- Added automatic gather recording by pairing player gathering casts with loot events.
- Recorded known locations by gathering profession with observed item-yield counts.
- Added \`/fp detect debug\` diagnostics and kept manual \`/fp mark\` as a fallback.
- Updated the window and README to explain observed locations and live-client verification limits.

## 0.1.0

- Initial WoW: Forever test release.
- Added account-wide manual node recording, route suggestions, character profession snapshots, and a provisional account-aware advisor.
