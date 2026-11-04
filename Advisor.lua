local _, FP = ...

-- Advice is account-aware and uses Classic supply synergies as provisional
-- heuristics, but only professions confirmed to exist in Forever.
-- Never add points merely because a class stereotypically uses an armor type.
local function existingCoverage(db)
    local found = {}
    for _, char in pairs((db and db.characters) or {}) do
        for name in pairs(char.professions or {}) do found[name] = true end
    end
    return found
end

function FP:GetRecommendations()
    local data = self.ProfessionData
    if not data then return nil, nil end
    local existing = existingCoverage(self.db)
    local scored = {}
    for _, p in ipairs(data.pairings or {}) do
        if data.primary[p.a] and data.primary[p.b] then
            local missing = (existing[p.a] and 0 or 1) + (existing[p.b] and 0 or 1)
            -- Forever: crafting professions can also progress Legacy and offer
            -- campsite items; keep this a modest, explicitly estimated bonus.
            local craftingCount = (data.primary[p.a] == "crafting" and 1 or 0)
                + (data.primary[p.b] == "crafting" and 1 or 0)
            local score = p.utility * 2 - p.effort * 0.5
                + missing * 0.6 + craftingCount * 0.35
            scored[#scored + 1] = { pair=p, score=score, missing=missing }
        end
    end
    table.sort(scored, function(a,b) return a.score > b.score end)
    return scored[1], scored[2]
end

function FP:ShowAdvisor()
    local first, second = self:GetRecommendations()
    self:Say("Advisor (provisional Classic supply + verified Forever systems, not a class-meta ranking):")
    for i, entry in ipairs({first, second}) do
        if entry then
            local pair = entry.pair
            self:Say(i .. ". " .. pair.a .. " + " .. pair.b .. " — " .. pair.reason)
        end
    end
    self:Say("Includes account profession coverage. Live Forever popularity will replace estimated rankings when verified.")
end
