-- ForeverProfessions data policy, November 4, 2026.
-- This file separates documented Forever profession facts from provisional
-- Classic material-supply pairings. Live Forever evidence takes priority.
-- Source: Blizzard profession starter guide and October 21 Camping article.
-- https://worldofwarcraft.blizzard.com/en-us/news/24315280/
-- https://worldofwarcraft.blizzard.com/en-us/news/24301516/
-- Legacy tradeskill milestone source:
-- https://worldofwarcraft.blizzard.com/en-gb/news/24307383
--
-- DO NOT add Classic-only professions or fabricate node positions, skill-ups,
-- trainer locations, recipe availability, yield or price predictions.
-- This is not a complete recipe database. Actual gathering nodes are recorded
-- from player observations by Gather.lua and shared account-wide.
local _, FP = ...

FP.ProfessionData = {
    verifiedBuild = nil, -- no in-game launch build verified yet
    primaryLimit = 2,
    primary = {
        Alchemy = "crafting",
        Blacksmithing = "crafting",
        Enchanting = "crafting",
        Engineering = "crafting",
        Herbalism = "gathering",
        Leatherworking = "crafting",
        Mining = "gathering",
        Skinning = "gathering",
        Tailoring = "crafting",
    },
    secondary = { Cooking = true, FirstAid = true, ["First Aid"] = true, Fishing = true },
    -- These are advisory candidate pairings, not claimed class meta rankings.
    -- Classic supply relationships remain relevant, while Forever gives
    -- crafting professions additional Camping and Legacy value.
    pairings = {
        {a="Herbalism", b="Alchemy", utility=9, effort=4,
         reason="Consumables for the account; Herbalism supplies Alchemy.",
         provenance="classic-supply-plus-forever"},
        {a="Mining", b="Engineering", utility=9, effort=5,
         reason="Engineering tools and camp utility; Mining supplies materials.",
         provenance="classic-supply-plus-forever"},
        {a="Tailoring", b="Enchanting", utility=8, effort=5,
         reason="Crafted gear can supply disenchanting materials.",
         provenance="classic-supply-plus-forever"},
        {a="Mining", b="Blacksmithing", utility=7, effort=6,
         reason="Metal supply for equipment crafting and camp features.",
         provenance="classic-supply-plus-forever"},
        {a="Skinning", b="Leatherworking", utility=7, effort=5,
         reason="Leather and hides for gear and camp crafting.",
         provenance="classic-supply-plus-forever"},
        {a="Herbalism", b="Mining", utility=7, effort=2,
         reason="Two gathering professions to sell or support other characters.",
         provenance="classic-supply"},
        {a="Skinning", b="Mining", utility=6, effort=2,
         reason="Easy gathering while questing; supplies account crafting.",
         provenance="classic-supply"},
        {a="Skinning", b="Herbalism", utility=6, effort=2,
         reason="Flexible gathering without having to level a crafting skill.",
         provenance="classic-supply"},
    },
}

-- Verified Forever overrides can be added here later, with source/build notes.
FP.ProfessionData.foreverOverrides = {}
