# ForeverProfessions — v0.3.10

A minimal, account-aware professions and gathering companion for WoW: Forever.

## Working features

- Account-wide SavedVariables database shared by characters on the same installation/account.
- Skill-aware 1–300 leveling recommendations for the nine primary and three secondary professions.
- Reads the game's direct skill-up status and relative difficulty for learned recipes; caches learned route recipes and exact reagents per character.
- Recommends the next recipe or gathering step from a 1–300 profession route; craft counts are estimates and live skill-up recipes take priority.
- Totals reagents across the remaining route for recipes the character has learned, compares them with current bags/bank plus last-seen character snapshots, and supports personal material goals through `/fp mats`, `/fp track`, and `/fp untrack`.
- Account-aware profession advisor supports balanced, gold, utility and account-coverage priorities. It respects the current character's occupied primary profession slots and will not recommend dropping an existing profession to fit a proposed pair.
- Skinning gather detection in addition to mining, herbalism and fishing.
- Automatic node-location recording when a player mining, herbalism, fishing, or skinning action is followed by a loot item.
- Nodes are stored as **observed locations**, not guaranteed spawns. Nearby gathers update the visit count and item-yield observations.
- Detected gathers switch the active route to the profession being gathered unless the player has explicitly chosen a manual route with `/fp resource`.
- Manual location recording remains available as a fallback.
- Resource-specific nearest-neighbor gathering loop with a modest preference for frequently visited locations; the route recomputes from your current position.
- Numbered gathering stops and connecting route lines on the matching World Map zone, shared across characters on the same installation; uses a Lua 5.1-compatible angle calculation and ignores map events unsupported by the client.
- Compact, movable window hidden until requested.
- Character-specific profession skill snapshots (including noncontiguous profession slots) and a provisional pairing advisor. Recommendations combine confirmed Forever profession availability/benefits with labeled Classic supply synergies, not unverified class meta.
- The character-specific leveling coach uses the **Leveling** button or `/fp level [profession]` to show a clearly separated route target, available skill-up recipe, and craft materials. The route recipe is preferred when it can currently raise skill.
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

Automatic detection pairs a player gathering cast with a \`CHAT_MSG_LOOT\` event and uses the player position sampled at the cast. Mining, herbalism, and skinning loot is paired for up to 12 seconds; fishing loot is paired for up to 45 seconds. A node is recorded only after a successful cast and an item link. When enabled, debug output shows casts that were not classified. The reliable fallback is \`/fp mark\`.

## Current limits

- Forever's modern API uses secret values in some contexts. The detector skips secret spell names, IDs, coordinates, and loot messages rather than trying to inspect them.
- Live-client verification is still needed for the exact spell names and event order emitted by each gathering profession and for the leveling coach's profession API behavior. If a successful gather is missed, enable \`/fp detect debug\` and use \`/fp mark\` for that spot.
- Fishing loot may not expose a cast/loot pair in every situation. The detector accepts a loot event for up to 45 seconds after a recognized fishing cast.
- Route quantities are guide estimates, and material totals exclude recipes the character has not learned or whose reagents the client has not supplied. Other-character inventory is last-seen while that character was logged in. Auction-house prices and trainer map pins are not included.
- Profession pairing scores are illustrative estimates, not live class/meta rankings. The separate ProfessionData.lua source defines the nine actual primary professions, three secondary professions, and provisional Classic material pairings. Confirmed Forever data takes priority; no fabricated node maps or recipe data are shipped.
- Map markers appear when the World Map shows the same zone as the saved gathering locations. Routes are a greedy nearest-neighbor ordering, not terrain-aware pathfinding or spawn timers.

## Install

Install with WoWUp using this repository URL:
https://github.com/avp9320/ForeverProfessions

Or unzip the release into the client's \`Interface/AddOns\` directory, keeping the \`ForeverProfessions\` folder intact.

Interface target: \`16001\`.

## Publishing

GitHub Actions publishes a versioned release ZIP for WoWUp when a push advances the addon's \`## Version:\` in \`ForeverProfessions.toc\`.

## Design

No automatic profession purchases and no chat spam by default. The gathering route overlay appears only on the World Map. Future additions should remain optional and context-sensitive.
