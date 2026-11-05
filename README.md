# ForeverProfessions — v0.3.4

A minimal, account-aware professions and gathering companion for WoW: Forever.

## Working features

- Account-wide SavedVariables database shared by characters on the same installation/account.
- Skill-aware 1–300 leveling recommendations for the nine primary and three secondary professions.
- Scans known recipes, difficulty colors, and exact reagents from the profession book (legacy or modern APIs); stores them per character.
- Automatically recommends a craft based on skill, estimates crafts to the next bracket, and suggests learned orange/yellow alternatives.
- Tracks needed recipe materials against visible inventory and personal material goals using /fp mats, /fp track and /fp untrack.
- Account-aware profession advisor supports balanced, gold, utility and account-coverage priorities.
- Skinning gather detection in addition to mining, herbalism and fishing.
- Automatic node-location recording when a player mining, herbalism, or fishing cast is followed by a loot item.
- Nodes are stored as **observed locations**, not guaranteed spawns. Nearby gathers update the visit count and item-yield observations.
- The first detected gather selects its profession route automatically, including when an older manual resource selection was saved.
- Manual location recording remains available as a fallback.
- Resource-specific nearest-neighbor gathering loop with a modest preference for frequently visited locations; the route recomputes from your current position.
- Compact, movable window hidden until requested.
- Character-specific profession skill snapshots and a provisional pairing advisor. Recommendations combine confirmed Forever profession availability/benefits with labeled Classic supply synergies, not unverified class meta.
- A character-specific leveling coach: open a profession window and use **Leveling** or `/fp level` to get the next learned recipe that the game reports can still grant a skill-up, materials for one craft, bag counts, and up to two alternatives.
- Rank trainer reminders when the saved profession skill reaches or nears its current rank cap.

## Commands

- `/fp level [profession]` — next recommended skill-up recipe or gathering target
- `/fp mats [profession]` — material requirements and tracked goals
- `/fp track <item ID or name> <quantity>` — track material goal
- `/fp untrack <item ID or name>` — stop tracking a material
- `/fp advisor balanced|gold|utility|account` — choose recommendation priority

- \`/fp\` — open or close the window
- \`/fp resource Mining\` — choose the route to view (Mining, Herbalism, or Fishing)
- \`/fp mark\` — manually record a location for the selected route
- \`/fp route\` — list the suggested loop
- \`/fp advisor\` — show two provisional profession pairings
- \`/fp level\` — show the next-craft coach (open the profession window first)
- \`/fp detect debug\` — toggle gather-event diagnostics in chat
- \`/fp help\` — command summary

Automatic detection pairs a player gathering cast with a \`CHAT_MSG_LOOT\` event and uses the player position sampled at the cast. Mining and herbalism loot is paired for up to 12 seconds; fishing loot is paired for up to 45 seconds. A node is recorded only after a successful cast and an item link. When enabled, debug output shows casts that were not classified. The reliable fallback is \`/fp mark\`.

## Current limits

- Forever's modern API uses secret values in some contexts. The detector skips secret spell names, IDs, coordinates, and loot messages rather than trying to inspect them.
- Live-client verification is still needed for the exact spell names and event order emitted by each gathering profession and for the leveling coach's profession API behavior. If a successful gather is missed, enable \`/fp detect debug\` and use \`/fp mark\` for that spot.
- Fishing loot may not expose a cast/loot pair in every situation. The detector accepts a loot event for up to 45 seconds after a recognized fishing cast.
- The leveling coach uses the game's recipe skill-up API (including its skill-up flag and difficulty value); it does not inspect recipe text color or arrow art. It does not yet provide a fixed 1–300 route, total materials for an entire rank, auction-house prices, or an account-wide inventory forecast.
- Profession pairing scores are illustrative estimates, not live class/meta rankings. The separate ProfessionData.lua source defines the nine actual primary professions, three secondary professions, and provisional Classic material pairings. Confirmed Forever data takes priority; no fabricated node maps or recipe data are shipped.
- Routes are a greedy nearest-neighbor ordering, not terrain-aware pathfinding or spawn timers.

## Install

Install with WoWUp using this repository URL:
https://github.com/avp9320/ForeverProfessions

Or unzip the release into the client's \`Interface/AddOns\` directory, keeping the \`ForeverProfessions\` folder intact.

Interface target: \`16001\`.

## Publishing

GitHub Actions publishes a versioned release ZIP for WoWUp when a push advances the addon's \`## Version:\` in \`ForeverProfessions.toc\`.

## Design

No automatic profession purchases, no chat spam by default, and no permanent overlay. Future additions should remain optional and context-sensitive.
