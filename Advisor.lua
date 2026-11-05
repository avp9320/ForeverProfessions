local _, FP = ...
-- Account coverage first. Do not grant "warrior -> blacksmithing" or
-- "hunter -> leatherworking" bonuses purely for class stereotypes.
local weights = {
  balanced = {coverage=1.5, effort=0.6, utility=1.0, gold=0.8, craft=0.7},
  gold = {coverage=0.7, effort=1.1, utility=0.55, gold=3.0, craft=0},
  utility = {coverage=1.0, effort=0.35, utility=1.55, gold=0.2, craft=1.2},
  account = {coverage=3.2, effort=0.6, utility=0.7, gold=0.3, craft=0.6},
}
local function coverage(db)
  local result={}
  for _,char in pairs(db and db.characters or {}) do
    for name,info in pairs(char.professions or {}) do
      result[name]=(result[name] or 0)+1
    end
  end
  return result
end
-- Keep a character's existing primary professions. Recommendations must be
-- attainable without silently asking the player to unlearn a profession.
local function currentPrimaries(self)
  local owned={}
  for name in pairs(self.character and self.character.professions or {}) do
    if self.ProfessionData.primary[name] then owned[name]=true end
  end
  return owned
end
function FP:GetRecommendations()
  if not self.ProfessionData or not self.db then return nil,nil end
  local existing=coverage(self.db)
  local owned=currentPrimaries(self)
  local ownedCount=0
  for _ in pairs(owned) do ownedCount=ownedCount+1 end
  local slots=math.max(0,(self.ProfessionData.primaryLimit or 2)-ownedCount)
  local mode=self.db.settings.advisorPriority or "balanced"
  local w=weights[mode] or weights.balanced
  local scored={}
  if slots==0 then return nil,nil,slots end
  for _,p in ipairs(self.ProfessionData.pairings or {}) do
    if self.ProfessionData.primary[p.a] and self.ProfessionData.primary[p.b] then
      local requires=(owned[p.a] and 0 or 1)+(owned[p.b] and 0 or 1)
      -- With one profession already learned, only offer combinations
      -- containing it; with zero learned, offer complete pairings.
      if requires>0 and requires<=slots and (ownedCount==0 or owned[p.a] or owned[p.b]) then
        local a,b=existing[p.a] or 0,existing[p.b] or 0
        local missing=(a==0 and 1 or 0)+(b==0 and 1 or 0)
        local craft=(self.ProfessionData.primary[p.a]=="crafting" and 1 or 0)
                  +(self.ProfessionData.primary[p.b]=="crafting" and 1 or 0)
        local dualGather=(craft==0) and 1 or 0
        local complement=((a>0 and b==0) or (b>0 and a==0)) and 1 or 0
        local score=p.utility*w.utility-p.effort*w.effort
                   +missing*w.coverage+craft*w.craft+dualGather*w.gold
                   +complement*w.coverage*0.5
                   -math.max(0,a-1)*0.2-math.max(0,b-1)*0.2
        scored[#scored+1]={pair=p,score=score,missing=missing,
          accountCounts={a=a,b=b},complement=complement,
          newProfessions=requires}
      end
    end
  end
  table.sort(scored,function(a,b)
    if a.score==b.score then
      return (a.pair.a.."+"..a.pair.b)<(b.pair.a.."+"..b.pair.b)
    end
    return a.score>b.score
  end)
  return scored[1],scored[2],slots
end
function FP:ShowAdvisor(mode)
  if not self.db then return end
  mode=(mode or ""):lower():match("^%s*(.-)%s*$")
  if mode~="" then
    if not weights[mode] then self:Say("Advisor modes: balanced, gold, utility, account");return end
    self.db.settings.advisorPriority=mode
  end
  local first,second,slots=self:GetRecommendations()
  self:Say("Account-aware profession pairings ("..
    (self.db.settings.advisorPriority or "balanced").." priority):")
  if slots==0 then\n    self:Say("Both primary profession slots are filled. No new pairing is available without unlearning one.")\n    return\n  end\n  if not first then\n    self:Say("No verified candidate pairing fits your open slots and current professions. No unlearning is recommended.")\n    return\n  end\n  for i,entry in ipairs({first,second}) do
    if entry then
      local p=entry.pair
      local a,b=entry.accountCounts.a,entry.accountCounts.b
      self:Say(i..". "..p.a.." + "..p.b.." — "..p.reason..
        " (current account: "..p.a.." x"..a..", "..p.b.." x"..b..").")
    end
  end
  self:Say("Estimated utility / account coverage, not a verified popularity ranking.")
end
