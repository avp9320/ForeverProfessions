# v1.0 acceptance checklist

This is a release gate, not a claim of implementation. README claims and static code inspection do not substitute for live-client evidence. Check a box only after its behavior is verified; record test date/client and evidence in this file.

- [ ] Live-verify mining/herbalism/skinning/fishing automatic gather detection and saved node coordinates
- [ ] Verify adaptive account-wide routes and map compatibility
- [ ] Live-verify 1–300 next-craft coach and material accounting against real recipes
- [ ] Improve profession advisor with verified Forever-specific class and account data, not trope-based guesses
- [ ] Verify release packaging and SavedVariables migration

## Phase 1 feature implementation\n\n- [x] Adaptive observed-node route ordering now combines yield-weighted greedy selection with a bounded 2-opt circuit improvement, including the loop's return leg (Core.lua; commit 09bd01f). This is a geometric route only, not terrain-aware navigation.\n- [ ] Confirm in-game that map lines and stop numbering reflect the improved order; measure performance in dense zones.\n\n- [x] Phase 1: Advisor now filters candidate pairings against the current character's existing primary professions and open slots, avoiding impossible recommendations that require unlearning (Advisor.lua; commit 743a93e). Static inspection only; live profession snapshots and UI behavior remain unverified.\n\n## Evidence

- Code review: 2026-11-05 — inspected Gather.lua and corrected two event-order defects (commit 2679a41): SUCCEEDED without START now marks a gather successful; unrelated failed casts no longer clear a completed gather waiting for loot. Static inspection only; exact live event ordering and loot matching remain unverified.
- Automated/static tests: pending
- Live WoW: Forever client verification: pending
- Release ZIP and WoWUp installation: pending

## Status

Pre-1.0. Features described in README may be implemented but are not accepted as verified here until tested. Avoid declaring v1.0 solely on version metadata.
