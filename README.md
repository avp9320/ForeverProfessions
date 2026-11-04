# ForeverProfessions — v0.2.0

A minimal, account-aware professions and gathering companion for WoW: Forever.

## Working features

- Account-wide SavedVariables database shared by characters on the same installation/account.
- Automatic node-location recording when a player mining, herbalism, or fishing cast is followed by a loot item.
- Nodes are stored as **observed locations**, not guaranteed spawns. Nearby gathers update the visit count and item-yield observations.
- Manual location recording remains available as a fallback.
- Resource-specific nearest-neighbor gathering loop with a modest preference for frequently visited locations; the route recomputes from your current position.
- Compact, movable window hidden until requested.
- Character-specific profession skill snapshots and a provisional pairing advisor. Recommendations are utility heuristics, not verified Forever meta rankings.

## Commands

- \`/fp\` — open or close the window
- \`/fp resource Mining\` — choose the route to view (Mining, Herbalism, or Fishing)
- \`/fp mark\` — manually record a location for the selected route
- \`/fp route\` — list the suggested loop
- \`/fp advisor\` — show two provisional profession pairings
- \`/fp detect debug\` — toggle gather-event diagnostics in chat
- \`/fp help\` — command summary

Automatic detection pairs a player gathering cast with a nearby \`CHAT_MSG_LOOT\` event. It uses the player position sampled at the cast and the item link from the loot event. When enabled, debug output helps identify casts the current client reports. The reliable fallback is \`/fp mark\`.

## Current limits

- Forever's modern API uses secret values in some contexts. The detector skips secret spell names, IDs, coordinates, and loot messages rather than trying to inspect them.
- Live-client verification is still needed for the exact spell names and event order emitted by each gathering profession. If a successful gather is missed, enable \`/fp detect debug\` and use \`/fp mark\` for that spot.
- Fishing and some gather events may not expose a cast/loot pair in every situation. The detector accepts a loot event for up to 12 seconds after a recognized gathering cast.
- World map route overlay, profession leveling plans/material totals, and trainer reminders are not implemented yet.
- Profession pairing scores are illustrative utility estimates, not live class/meta rankings.
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
