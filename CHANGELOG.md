# Changelog

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
