-- Offline 1-300 routes + account-local material goals.
-- The live skill-up and reagent reader is in Leveling.lua; its results override
-- guide estimates when the profession window supplies valid data.
local _, FP = ...
local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end
local function playerKey()
  return (UnitName("player") or "Unknown").."-"..(GetRealmName() or "Realm")
end
local function safe(fn,...)
  if type(fn)~="function" then return nil end
  local ok,v=pcall(fn,...)
  if ok then return v end
end
function FP:ResolveProfession(request)
  local chars=self.character and self.character.professions or {}
  local query=trim(request):lower():gsub("%s+","")
  if query~="" then
    for name in pairs(chars) do
      if name:lower():gsub("%s+","")==query then return name end
    end
    return nil
  end
  if self.db and self.db.selectedProfession and chars[self.db.selectedProfession] then
    return self.db.selectedProfession
  end
  local names={}
  for name in pairs(chars) do names[#names+1]=name end
  table.sort(names)
  for _,name in ipairs(names) do
    if self.ProfessionData.primary[name]=="crafting" then return name end
  end
  return names[1]
end
function FP:SaveRecipeState(state)
  if not state or not state.name or state.name=="Profession" or state.loading or not self.db then return end
  self.db.characters=self.db.characters or {}
  local char=self.db.characters[playerKey()] or {professions={}}
  char.professions=char.professions or {}
  char.recipes=char.recipes or {}
  local cached={}
  for _,opt in ipairs(state.options or {}) do
    local slots={}
    for _,slot in ipairs(opt.reagents or {}) do
      local alternatives={}
      for _,m in ipairs(slot) do
        alternatives[#alternatives+1]={name=m.name,id=m.id,amount=m.amount}
      end
      slots[#slots+1]=alternatives
    end
    cached[opt.name]={name=opt.name,difficulty=opt.difficulty,slots=slots}
  end
  char.recipes[state.name]=cached
  if type(state.skill)=="number" then
    char.professions[state.name]={rank=state.skill,maxRank=tonumber(state.maxSkill) or 0}
  end
  char.lastRecipeScan=time()
  self.db.characters[playerKey()]=char
  self.character=char
  self.db.selectedProfession=state.name
end
local function pickMaterials(recipe)
  local materials={}
  for _,slot in ipairs(recipe and recipe.slots or {}) do
    local first
    for _,m in ipairs(slot) do
      if not first then first=m end
      local have=safe(GetItemCount,m.id or m.name,true)
      if type(have)=="number" and have>=m.amount then first=m;break end
    end
    if first then materials[#materials+1]=first end
  end
  return materials
end
function FP:GetLevelingSuggestion(request)
  if not self.db then return end
  local profession=self:ResolveProfession(request)
  if not profession then return end
  local info=self.character.professions[profession] or {}
  local rank,cap=tonumber(info.rank) or 0,tonumber(info.maxRank) or 0
  local s={profession=profession,rank=rank,cap=cap}
  if rank>=300 then s.done=true;return s end
  if cap>0 and rank>=cap then s.trainer=true;return s end
  local stage
  for _,p in ipairs(self.LevelingData and self.LevelingData[profession] or {}) do
    if rank<p[2] then stage=p;break end
  end
  if not stage then s.missing=true;return s end
  local cached=self.character.recipes and self.character.recipes[profession] or {}
  local preferred=cached[stage[3]]
  local gather=self.ProfessionData.primary[profession]=="gathering" or profession=="Fishing"
  local actual=preferred
  if not actual and not gather then
    local best,score=nil,-1
    for _,r in pairs(cached) do
      local n=({orange=3,optimal=3,medium=2,yellow=2,easy=1,green=1})[r.difficulty] or 0
      if n>score then best,score=r,n end
    end
    if score>0 then actual=best end
  end
  s.name=actual and actual.name or stage[3]
  s.target=stage[2]
  s.known=actual~=nil
  s.gather=gather
  s.materials=pickMaterials(actual)
  s.quantity=math.max(1,math.ceil((stage[4] or (stage[2]-stage[1]))*
    (stage[2]-rank)/math.max(1,stage[2]-stage[1])))
  s.alternative=actual and actual.name~=stage[3] or false
  return s
end
function FP:LevelingLabel(s)
  if not s then return "No learned professions found." end
  if s.done then return s.profession..": maxed at 300." end
  if s.trainer then return s.profession.." "..s.rank.."/"..s.cap..": train the next rank." end
  if s.missing then return s.profession..": no leveling route available." end
  if s.gather then return s.profession.." "..s.rank.." -> "..s.target..": gather "..s.name end
  local verb=s.known and (s.alternative and "Learned alternative: " or "Make: ") or "Target recipe: "
  return s.profession.." "..s.rank.." -> "..s.target..": "..verb..s.name..
    " (~"..s.quantity.." crafts, estimate)"
end
function FP:GetMaterialNeeds(s)
  local list={}
  for _,m in ipairs(s and s.materials or {}) do
    local need=(tonumber(m.amount) or 0)*(s.quantity or 1)
    local value=safe(GetItemCount,m.id or m.name,true)
    local have=type(value)=="number" and value or nil
    list[#list+1]={name=m.name,required=need,have=have,
      missing=have and math.max(0,need-have) or nil}
  end
  table.sort(list,function(a,b) return a.name<b.name end)
  return list
end
function FP:ShowMaterials(request)
  if not self.db then return end
  local s=self:GetLevelingSuggestion(request)
  self:Say(self:LevelingLabel(s))
  if s and not (s.done or s.gather or s.trainer) then
    local materials=self:GetMaterialNeeds(s)
    if #materials==0 then
      self:Say("Open your profession recipes to cache their exact materials.")
    end
    for _,m in ipairs(materials) do
      self:Say(m.name..": "..m.required.." estimated, "..
        tostring(m.have or "?").." owned"..
        (m.missing and (", "..m.missing.." missing") or ""))
    end
  end
  for _,goal in pairs(self.db.materialGoals or {}) do
    local have=safe(GetItemCount,goal.id or goal.name,true)
    self:Say("Tracked "..goal.name..": "..tostring(have or "?").."/"..goal.count)
  end
end
function FP:TrackMaterial(args)
  if not self.db then return end
  local name,qty=trim(args):match("^(.-)%s+(%d+)$")
  local number=tonumber(qty)
  if not name or not number or number<1 or number>999999 then
    self:Say("Use /fp track <item name or ID> <quantity>");return
  end
  self.db.materialGoals=self.db.materialGoals or {}
  self.db.materialGoals[name:lower()]={name=name,id=tonumber(name),count=number}
  self:Say("Tracking "..name.." x"..number)
end
function FP:UntrackMaterial(args)
  if not self.db then return end
  self.db.materialGoals=self.db.materialGoals or {}
  self.db.materialGoals[trim(args):lower()]=nil
  self:Say("Material tracking updated.")
end
