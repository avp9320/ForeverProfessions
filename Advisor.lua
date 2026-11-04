local _,FP=...
-- These are broad utility heuristics, NOT live Forever meta rankings.
-- Never give points for class-themed armor stereotypes.
local pairings={
  {a='Mining',b='Engineering',utility=9,effort=5,roles={TANK=2,DAMAGER=2,HEALER=1},reason='Engineering utility, with Mining supplying materials.'},
  {a='Herbalism',b='Alchemy',utility=9,effort=4,roles={TANK=2,DAMAGER=2,HEALER=2},reason='Consumables useful across characters and roles.'},
  {a='Tailoring',b='Enchanting',utility=8,effort=5,roles={TANK=0,DAMAGER=1,HEALER=1},reason='Crafting and disenchanting support each other.'},
  {a='Mining',b='Blacksmithing',utility=7,effort=6,roles={TANK=1,DAMAGER=1,HEALER=0},reason='Crafted equipment and shared metal supply.'},
  {a='Skinning',b='Leatherworking',utility=7,effort=5,roles={TANK=0,DAMAGER=1,HEALER=0},reason='Leather supply supports useful crafted equipment.'},
  {a='Herbalism',b='Inscription',utility=6,effort=5,roles={TANK=0,DAMAGER=0,HEALER=0},reason='Herbalism supports inscription materials.'},
  {a='Mining',b='Jewelcrafting',utility=7,effort=6,roles={TANK=1,DAMAGER=1,HEALER=1},reason='Ore supply supports gem crafting.'},
  {a='Skinning',b='Mining',utility=6,effort=2,roles={TANK=0,DAMAGER=0,HEALER=0},reason='Simple gathering pair for trade or alts.'},
}
local function coverage(db)
  local found={}
  for _,char in pairs(db.characters or {}) do
    for name in pairs(char.professions or {}) do found[name]=true end
  end
  return found
end
function FP:GetRecommendations()
  local existing=coverage(self.db)
  local scored={}
  for _,p in ipairs(pairings) do
    local missing=(existing[p.a] and 0 or 1)+(existing[p.b] and 0 or 1)
    local score=p.utility*2-p.effort*.5+missing*.6
    scored[#scored+1]={pair=p,score=score,missing=missing}
  end
  table.sort(scored,function(a,b) return a.score>b.score end)
  return scored[1],scored[2]
end
function FP:ShowAdvisor()
  local first,second=self:GetRecommendations()
  self:Say('Advisor (provisional utility estimates, not verified class meta):')
  for i,entry in ipairs({first,second}) do
    if entry then
      local p=entry.pair
      self:Say(i..'. '..p.a..' + '..p.b..' — '..p.reason)
    end
  end
  self:Say('Existing profession coverage influences close choices; class-meta guidance requires verified live data.')
end
