# ForeverProfessions — v0.1.0 foundation

Minimal, account-aware gathering and professions companion for WoW: Forever.

## Working in this foundation

- Account-wide SavedVariables database of known resource locations, shared by characters on the same installation/account.
- Manual location recording with nearby-node deduplication and repeat-visit counts.
- Resource-specific nearest-neighbor gathering loop with modest preference for frequently visited nodes; route recomputes from your current position.
- Compact, movable window that is hidden until requested.
- Character-specific profession skill snapshots for characters logged in with the addon.
- Provisional profession-pairing advisor considering utility, effort and account coverage; one recommendation and one alternative.

## Commands

- `/fp` — open or close the window
- `/fp resource Copper Vein` — select resource to track (exact text used as database key)
- `/fp mark` — record a gathering location (do this after successful gathering)
- `/fp route` — list the suggested loop
- `/fp advisor` — show two provisional profession pairings
- `/fp help` — command summary

## Not yet implemented / requires live-client verification

- **Automatic gathering detection:** Manual marking is the reliable fallback. Verify spellcast/loot events and coordinate timing in Forever before adding automatic recording.
- **World map route overlay:** Not implemented yet. Need to inspect the live WorldMapFrame and map-canvas pin APIs before drawing clean, optional routes.
- **Real profession leveling plans and materials:** Require verified Forever recipes, profession tiers, and character inventory/bank APIs. No fabricated crafting guidance is shown.
- **Trainer reminders:** Need verified profession skill thresholds and trainer availability.
- **Meta-informed class recommendations:** The included pairing scores are *illustrative utility heuristics*, not live Icy Veins meta rankings. Do not treat them as optimized recommendations.
- **Route learning:** Repeated *manual* records increase visit counts. Visit count is not a proven spawn-rate estimate. Routes currently use a greedy nearest-neighbor heuristic, not obstacle-aware pathfinding.

## Install

Install with WoWUp by using this repository URL:
https://github.com/avp9320/ForeverProfessions

Or unzip the release into your client's `Interface/AddOns` directory, keeping the `ForeverProfessions` folder intact.

Interface target is `16001` and needs launch-client verification.

## Publishing

A GitHub Actions workflow publishes a versioned release ZIP for WoWUp when the addon's `## Version:` in `ForeverProfessions.toc` advances. It keeps the single top-level `ForeverProfessions/` folder in the archive.

## Design

No automatic profession purchases, no chat spam, no permanent overlay. Future additions should remain optional and context-sensitive.
