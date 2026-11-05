-- Profession leveling and reagent reader. Built-in route recommendations are
-- available even when no profession window is open. Live recipe data wins.
local _, FP = ...
local f = CreateFrame("Frame")
local function safe(fn,...)
  if type(fn)~="function" then return nil end
  local ok,a,b,c,d = pcall(fn,...)
  if ok then return a,b,c,d end
end
local function plain(v)
  return v~=nil and (not issecretvalue or not issecretvalue(v))
end
local function playerKey()
  return (UnitName("player") or "Unknown").."-"..(GetRealmName() or "Realm")
end
local function linkID(link)
  if type(link)=="string" then return tonumber(link:match("item:(%d+)")) end
end
local function diff(v)
  if not plain(v) then return "unknown" end
  if type(v)=="number" then return ({[1]="orange",[2]="yellow",[3]="green",[4]="gray"})[v] or "unknown" end
  local s=tostring(v):lower()
  return ({optimal="orange",difficult="orange",medium="yellow",easy="green",trivial="gray",grey="gray"})[s] or s
end
local function classic(craft)
  local name,rank,cap,count,info,num,reg,link
  if craft then
    name,rank,cap=safe(GetCraftDisplaySkillLine)
    count=safe(GetNumCrafts)
    info,num,reg,link=GetCraftInfo,GetCraftNumReagents,GetCraftReagentInfo,GetCraftReagentItemLink
  else
    name,rank,cap=safe(GetTradeSkillLine)
    count=safe(GetNumTradeSkills)
    info,num,reg,link=GetTradeSkillInfo,GetTradeSkillNumReagents,GetTradeSkillReagentInfo,GetTradeSkillReagentItemLink
  end
  if not plain(name) or type(name)~="string" or name=="" or name=="UNKNOWN"
    or type(count)~="number" or count<1 then return end
  local recipes={}
  for i=1,math.min(count,1500) do
    local title,kind
    if craft then title,_,kind=safe(info,i) else title,kind=safe(info,i) end
    if plain(title) and type(title)=="string" and kind~="header" and kind~="subheader" then
      local mats={}
      for j=1,math.min(tonumber(safe(num,i)) or 0,20) do
        local r,_,amount=safe(reg,i,j)
        local id=linkID(safe(link,i,j))
        if plain(r) and plain(amount) and type(amount)=="number" then
          mats[#mats+1]={name=r,id=id,count=amount}
        end
      end
      recipes[title]={name=title,difficulty=diff(kind),materials=mats}
    end
  end
  return name,recipes,tonumber(rank),tonumber(cap)
end
local function modern()
  local api=C_TradeSkillUI
  if not api or type(api.GetAllRecipeIDs)~="function" then return end
  local base=safe(api.GetBaseProfessionInfo)
  local name=type(base)=="table" and (base.professionName or base.name)
  local ids=safe(api.GetAllRecipeIDs)
  if not plain(name) or type(name)~="string" or type(ids)~="table" then return end
  local recipes={}
  for _,id in ipairs(ids) do
    if type(id)=="number" then
      local ri=safe(api.GetRecipeInfo,id)
      if type(ri)=="table" and plain(ri.name) and ri.learned then
        local mats={}
        local sch=safe(api.GetRecipeSchematic,id,false)
        if type(sch)=="table" and type(sch.reagentSlotSchematics)=="table" then
          for _,slot in ipairs(sch.reagentSlotSchematics) do
            local choices=slot.reagents
            local opt=type(choices)=="table" and #choices==1 and choices[1] or nil
            local reagent=opt and (opt.itemID or opt.reagentItemID)
            local qty=slot.quantityRequired or slot.requiredQuantity
            if type(reagent)=="number" and type(qty)=="number" and qty>0 then
              mats[#mats+1]={name=safe(GetItemInfo,reagent) or ("Item "..reagent),id=reagent,count=qty}
            end
          end
        elseif type(api.GetRecipeNumReagents)=="function" then
          for j=1,math.min(tonumber(safe(api.GetRecipeNumReagents,id)) or 0,20) do
            local r,_,qty=safe(api.GetRecipeReagentInfo,id,j)
            if plain(r) and type(qty)=="number" then mats[#mats+1]={name=r,count=qty} end
          end
        end
        recipes[ri.name]={name=ri.name,difficulty=diff(ri.difficulty or ri.recipeDifficulty),materials=mats}
      end
    end
  end
  return name,recipes
end
function FP:ScanProfessionBook()
  if not self.db then return end
  local name,recipes,rank,cap=classic(false)
  if not name then name,recipes,rank,cap=classic(true) end
  if not name then name,recipes,rank,cap=modern() end
  if not name or not recipes then return end
  local char=self.db.characters[playerKey()] or {professions={}}
  char.professions=char.professions or {}
  char.recipes=char.recipes or {}
  char.recipes[name]=recipes
  if rank then char.professions[name]={rank=rank,maxRank=cap or 0}
  elseif not char.professions[name] then char.professions[name]={rank=0,maxRank=0} end
  char.lastRecipeScan=time()
  self.db.characters[playerKey()]=char
  self.character=char
  self.db.selectedProfession=name
  self:RefreshUI()
end
function FP:ProfessionNames()
  local result={}
  for name in pairs(self.character and self.character.professions or {}) do
    if self.ProfessionData.primary[name] or self.ProfessionData.secondary[name] then
      result[#result+1]=name
    end
  end
  table.sort(result)
  return result
end
function FP:ResolveProfession(input)
  local names=self:ProfessionNames()
  if input and input~="" then
    local query=input:lower():gsub("%s+","")
    for _,name in ipairs(names) do
      if name:lower():gsub("%s+","")==query then return name end
    end
    return nil
  end
  if self.db.selectedProfession and self.character.professions[self.db.selectedProfession] then
    return self.db.selectedProfession
  end
  for _,name in ipairs(names) do
    if self.ProfessionData.primary[name]=="crafting" then return name end
  end
  return names[1]
end
local function bestKnown(recipes)
  local best,bestWeight
  for _,r in pairs(recipes or {}) do
    local weight=({orange=3,yellow=2,green=1})[r.difficulty]
    if weight and (not bestWeight or weight>bestWeight or
      (weight==bestWeight and r.name<best.name)) then best,bestWeight=r,weight end
  end
  return best
end
function FP:GetLevelingSuggestion(input)
  local profession=self:ResolveProfession(input)
  if not profession then return nil end
  local info=self.character.professions[profession]
  local rank,cap=tonumber(info.rank) or 0,tonumber(info.maxRank) or 0
  local output={profession=profession,rank=rank,cap=cap}
  if rank>=300 then output.done=true;return output end
  if cap>0 and rank>=cap then output.trainer=true;return output end
  local stages=self.LevelingData and self.LevelingData[profession]
  local step
  for _,s in ipairs(stages or {}) do
    if rank<s[2] then step=s;break end
  end
  if not step then output.missing=true;return output end
  local recipes=self.character.recipes and self.character.recipes[profession] or {}
  local actual=recipes[step[3]]
  local gather=(self.ProfessionData.primary[profession]=="gathering") or profession=="Fishing"
  local chosen=actual and actual.difficulty~="gray" and actual or nil
  local alternative=not chosen and not gather and bestKnown(recipes) or nil
  local recipe=chosen or alternative
  output.name=recipe and recipe.name or step[3]
  output.target=step[2]
  output.known=recipe~=nil
  output.alternative=alternative~=nil
  output.gather=gather
  output.materials=recipe and recipe.materials or {}
  output.difficulty=recipe and recipe.difficulty
  output.quantity=math.max(1,math.ceil((step[4] or (step[2]-step[1]))*
    (step[2]-rank)/math.max(1,step[2]-step[1])))
  return output
end
local function owned(reagent)
  if not GetItemCount then return nil end
  local value=safe(GetItemCount,reagent.id or reagent.name,true)
  if type(value)=="number" and plain(value) then return value end
end
function FP:GetMaterialNeeds(s)
  local result={}
  for _,m in ipairs(s and s.materials or {}) do
    local required=(tonumber(m.count) or 0)*math.max(1,s.quantity or 1)
    local have=owned(m)
    result[#result+1]={name=m.name or ("Item "..tostring(m.id or "?")),
      id=m.id,required=required,have=have,missing=have and math.max(0,required-have) or nil}
  end
  table.sort(result,function(a,b) return a.name<b.name end)
  return result
end
function FP:LevelingLabel(s)
  if not s then return "No learned professions found." end
  if s.done then return s.profession.." is maxed (300)." end
  if s.trainer then return s.profession.." "..s.rank.."/"..s.cap..": train the next profession rank." end
  if s.missing then return s.profession..": no leveling route found." end
  if s.gather then return s.profession.." "..s.rank..": gather "..s.name.." until ~"..s.target.."." end
  local label=s.known and (s.alternative and "Available: " or "Make: ") or "Learn/make: "
  return s.profession.." "..s.rank.." -> "..s.target..": "..label..s.name..
    " (~"..s.quantity.." crafts)"..(s.difficulty and " ["..s.difficulty.."]" or "")
end
function FP:ShowLeveling(input)
  if not self.db then return end
  if input and input~="" then
    local profession=self:ResolveProfession(input)
    if not profession then self:Say("No learned profession named "..input);return end
    self.db.selectedProfession=profession
  end
  local s=self:GetLevelingSuggestion()
  self:Say(self:LevelingLabel(s))
  if s and not s.gather and not s.done and not s.trainer then
    self:ShowMaterials(nil,true)
    if not s.known then self:Say("Open the profession window to read known recipes/reagents. Plans may need a trainer or pattern.") end
  end
  self:RefreshUI()
end
function FP:ShowMaterials(input,calledByLevel)
  if not self.db then return end
  local s=self:GetLevelingSuggestion(input)
  if not s then self:Say("Open Professions (K) or learn a profession.");return end
  if not calledByLevel then self:Say("For "..self:LevelingLabel(s)) end
  local needs=self:GetMaterialNeeds(s)
  if #needs==0 and not (s.done or s.gather or s.trainer) then
    self:Say("Open "..s.profession.." recipes to cache their exact material requirements.")
  end
  for _,m in ipairs(needs) do
    self:Say(m.name..": "..m.required.." needed; "..(m.have and m.have or "?")..
      " owned"..(m.missing and ("; "..m.missing.." missing") or ""))
  end
  for _,goal in pairs(self.db.materialGoals or {}) do
    local have=owned(goal)
    self:Say("Goal "..goal.name..": "..tostring(have or "?").."/"..goal.count)
  end
end
function FP:TrackMaterial(input)
  if not self.db then return end
  local name,number=(input or ""):match("^%s*(.-)%s+(%d+)%s*$")
  local quantity=tonumber(number)
  if not name or not quantity or quantity<1 or quantity>999999 then
    self:Say("Usage: /fp track <item ID or name> <quantity>");return
  end
  self.db.materialGoals=self.db.materialGoals or {}
  self.db.materialGoals[name:lower()]={name=name,id=tonumber(name),count=quantity}
  self:Say("Tracking "..name.." x"..quantity)
  self:RefreshUI()
end
function FP:UntrackMaterial(input)
  if not self.db then return end
  self.db.materialGoals=self.db.materialGoals or {}
  self.db.materialGoals[(input or ""):lower()]=nil
  self:RefreshUI()
end
for _,event in ipairs({"TRADE_SKILL_SHOW","TRADE_SKILL_UPDATE","TRADE_SKILL_LIST_UPDATE",
   "CRAFT_SHOW","CRAFT_UPDATE","BAG_UPDATE_DELAYED","SKILL_LINES_CHANGED"}) do
  f:RegisterEvent(event)
end
f:SetScript("OnEvent",function(_,event)
  if not FP.db then return end
  if event=="BAG_UPDATE_DELAYED" then FP:RefreshUI();return end
  if event=="SKILL_LINES_CHANGED" then FP:RefreshCharacter();FP:RefreshUI();return end
  FP:ScanProfessionBook()
end)
