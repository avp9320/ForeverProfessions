-- Account-aware leveling plans and material goals for ForeverProfessions.
-- Routes are estimated; live client recipe skill-up and reagent data take priority.
local _, FP = ...

local function norm(s) return tostring(s or ''):lower():gsub('[^%a%d]','') end
local function itemName(id)
  if id and GetItemInfo then
    local name=GetItemInfo(id)
    if name then return name end
  end
  return 'Item '..tostring(id or '?')
end
local function liveCount(id)
  if not id or not GetItemCount then return nil end
  local ok,n=pcall(GetItemCount,id,true)
  if ok then return tonumber(n) end
end
local function currentChar()
  for _,char in pairs(FP.db and FP.db.characters or {}) do
    if char==FP.character then return char end
  end
end
local function currentProfile(profession)
  local char=currentChar()
  for name,data in pairs(char and char.professions or {}) do
    if FP:ResolveProfession(name)==profession then return data end
  end
end
local function observed(id)
  local total,cur=0,currentChar()
  local n=liveCount(id)
  if n~=nil then total=n
  else total=tonumber(cur and cur.materials and cur.materials[tostring(id)]) or 0 end
  for _,char in pairs(FP.db and FP.db.characters or {}) do
    if char~=cur then total=total+(tonumber(char.materials and char.materials[tostring(id)]) or 0) end
  end
  return total
end

function FP:ResolveProfession(name)
  local wanted=norm(name)
  if wanted=='' then return nil end
  for profession in pairs(self.LevelingData or {}) do
    if norm(profession)==wanted then return profession end
  end
end

function FP:SaveRecipeState(state)
  if not self.db or not self.character or not state or not state.name then return end
  local profession=self:ResolveProfession(state.name)
  if not profession then return end
  local char=currentChar()
  if not char then return end
  char.professions=char.professions or {}
  local profile=char.professions[profession] or {}
  profile.rank=tonumber(state.skill) or profile.rank or 0
  profile.maxRank=tonumber(state.maxSkill) or profile.maxRank or 300
  profile.recipeScanAt=time()
  if state.recipes then
    profile.recipes={}
    for recipeKey,recipe in pairs(state.recipes) do
      profile.recipes[recipeKey]={
        name=recipe.name,learned=recipe.learned~=false,
        canSkillUp=recipe.canSkillUp==true,difficulty=recipe.difficulty,
        materials=recipe.materials or {},
      }
      for _,slot in ipairs(recipe.materials or {}) do
        for _,item in ipairs(slot) do
          local id=item.itemID or item.id
          if id then
            self.db.trackedMaterialIDs=self.db.trackedMaterialIDs or {}
            self.db.trackedMaterialIDs[id]=true
            char.materials=char.materials or {}
            local count=liveCount(id)
            if count~=nil then char.materials[tostring(id)]=count end
          end
        end
      end
    end
  end
  char.professions[profession]=profile
  self.liveRecipeState=state
end

local function recipeMaterials(recipe,crafts)
  local totals={}
  for _,slot in ipairs(recipe and recipe.materials or {}) do
    local pick,bestHave
    for _,item in ipairs(slot) do
      local id=item.itemID or item.id
      local have=id and observed(id) or tonumber(item.have) or 0
      if not pick or have>(bestHave or -1) then pick,bestHave=item,have end
    end
    if pick then
      local id=pick.itemID or pick.id
      local k=id and tostring(id) or ('name:'..tostring(pick.name))
      local row=totals[k] or {itemID=id,name=pick.name or itemName(id),required=0}
      row.required=row.required+(tonumber(pick.amount) or tonumber(pick.perCraft) or 0)*crafts
      row.have=id and observed(id) or tonumber(pick.have) or 0
      totals[k]=row
    end
  end
  local rows={}
  for _,row in pairs(totals) do
    row.shortage=math.max(0,row.required-(row.have or 0))
    rows[#rows+1]=row
  end
  table.sort(rows,function(a,b)
    if a.shortage~=b.shortage then return a.shortage>b.shortage end
    return tostring(a.name)<tostring(b.name)
  end)
  return rows
end

local function stepAt(route,skill)
  for _,step in ipairs(route or {}) do
    if skill<(tonumber(step[2]) or 0) then return step end
  end
end
local function craftEstimate(step,skill,target)
  local start,finish=tonumber(step[1]) or skill,tonumber(step[2]) or skill+1
  local guide=tonumber(step[4]) or math.max(1,finish-start)
  return math.max(1,math.ceil(guide*math.max(0,target-skill)/math.max(1,finish-start)))
end

function FP:GetLevelingSuggestion(requested)
  if not self.db then return nil end
  local state=self.liveRecipeState
  local active=state and self:ResolveProfession(state.name)
  local profession=self:ResolveProfession(requested) or active
    or self:ResolveProfession(self.db.settings and self.db.settings.selectedProfession)
  if not profession then
    for name in pairs(self.character and self.character.professions or {}) do
      profession=self:ResolveProfession(name)
      if profession then break end
    end
  end
  if not profession then return nil end
  self.db.settings=self.db.settings or {}
  self.db.settings.selectedProfession=profession
  local profile=currentProfile(profession) or {}
  local same=active==profession
  local skill=tonumber(same and state.skill) or tonumber(profile.rank) or 0
  local cap=tonumber(same and state.maxSkill) or tonumber(profile.maxRank) or 300
  local suggestion={profession=profession,skill=skill,cap=cap,recipes=profile.recipes,
    materialList={},materials=false,skillRange={skill,skill}}
  if cap<300 and skill>=cap then
    suggestion.trainer=true
    suggestion.nextCap=math.min(300,cap+75)
    return suggestion
  end
  if cap<300 and skill>=cap-5 then
    suggestion.trainerSoon=true
    suggestion.pointsToCap=cap-skill
  end
  if skill>=300 then suggestion.done=true;return suggestion end

  local step=stepAt(self.LevelingData and self.LevelingData[profession],skill)
  if not step then suggestion.done=true;return suggestion end
  local start,finish=tonumber(step[1]) or skill,tonumber(step[2]) or skill+1
  local target=math.min(finish,cap)
  suggestion.skillRange={math.max(skill,start),target}
  suggestion.guideName=step[3]
  suggestion.crafts=craftEstimate(step,skill,target)

  if profession=='Mining' or profession=='Herbalism' or profession=='Skinning' or profession=='Fishing' then
    suggestion.gather=true
    suggestion.recipe=step[3]
    return suggestion
  end

  local recipe=profile.recipes and profile.recipes[norm(step[3])]
  if recipe and recipe.learned and recipe.canSkillUp then
    suggestion.recipe=recipe.name or step[3]
    suggestion.recipeData=recipe
    suggestion.materialList=recipeMaterials(recipe,suggestion.crafts)
    suggestion.materials=#suggestion.materialList>0
    suggestion.source='Live recipe + Forever skill-up data'
    return suggestion
  end
  if same and state.options and state.options[1] then
    local option=state.options[1]
    local adHoc={name=option.name,materials=option.reagents or {}}
    suggestion.recipe=option.name
    suggestion.recipeData=adHoc
    suggestion.crafts=1
    suggestion.skillRange={skill,math.min(skill+1,cap)}
    suggestion.liveOnly=true
    suggestion.materialList=recipeMaterials(adHoc,1)
    suggestion.materials=#suggestion.materialList>0
    suggestion.source='Live skill-up recommendation'
    return suggestion
  end
  suggestion.recipe=step[3]
  suggestion.unverified=true
  suggestion.source='Route estimate; recipe not confirmed in this character’s scan'
  return suggestion
end

function FP:LevelingLabel(s)
  if not s then return 'Open a profession or use /fp level <profession>.' end
  if s.trainer then return string.format('Train %s before continuing (rank cap %d; next cap %d).',s.profession,s.cap,s.nextCap) end
  if s.done then return s.profession..' is at the listed skill cap.' end
  local from,to=s.skillRange[1],s.skillRange[2]
  local label
  if s.gather then
    label=string.format('Gather %s to move from skill %d toward %d.',s.recipe,from,to)
  elseif s.recipe then
    label=string.format('Make %s for skill %d–%d (~%d crafts).',s.recipe,from,to,s.crafts or 1)
    if s.liveOnly then label=label..' Live skill-up pick.' end
    if s.unverified then label=label..' Guide route; confirm in profession book.' end
  else
    label='No leveling step is available for '..s.profession..'.'
  end
  if s.trainerSoon then
    label=label..string.format(' Trainer soon: %d point%s to cap.',s.pointsToCap,s.pointsToCap==1 and '' or 's')
  end
  return label
end

function FP:GetMaterialNeeds(s)
  if not s then return {} end
  local rows=s.materialList or recipeMaterials(s.recipeData,s.crafts or 1)
  for _,row in ipairs(rows) do
    if row.itemID then row.have=observed(row.itemID);row.shortage=math.max(0,row.required-row.have) end
  end
  return rows
end

function FP:GetLevelingPlanMaterials(s)
  if not s or not s.recipes then return {},0 end
  local totals,missing={},0
  for _,step in ipairs(self.LevelingData[s.profession] or {}) do
    local finish,start=tonumber(step[2]) or 0,tonumber(step[1]) or 0
    if finish>s.skill then
      local recipe=s.recipes[norm(step[3])]
      if recipe and recipe.learned then
        local crafts=craftEstimate(step,math.max(s.skill,start),finish)
        for _,row in ipairs(recipeMaterials(recipe,crafts)) do
          local id=row.itemID and tostring(row.itemID) or ('name:'..row.name)
          local total=totals[id] or {itemID=row.itemID,name=row.name,required=0,have=row.have or 0}
          total.required=total.required+row.required
          if row.itemID then total.have=observed(row.itemID) end
          totals[id]=total
        end
      elseif step[4] then missing=missing+1 end
    end
  end
  local rows={}
  for _,row in pairs(totals) do
    row.shortage=math.max(0,row.required-(row.have or 0))
    rows[#rows+1]=row
  end
  table.sort(rows,function(a,b)
    if a.shortage~=b.shortage then return a.shortage>b.shortage end
    return tostring(a.name)<tostring(b.name)
  end)
  return rows,missing
end

function FP:ShowMaterials(requested)
  local state=self.GetLiveRecipeState and self:GetLiveRecipeState()
  if state and not state.loading then self:SaveRecipeState(state) end
  local s=self:GetLevelingSuggestion(requested)
  if s then
    self:Say(self:LevelingLabel(s))
    local rows,missing=self:GetLevelingPlanMaterials(s)
    if #rows>0 then
      self:Say('Estimated materials for learned route recipes through 300 (account-observed totals):')
      for i=1,math.min(20,#rows) do
        local r=rows[i]
        self:Say(string.format('%d needed, %d owned: %s%s',r.required,r.have or 0,r.name,
          r.shortage>0 and (' — short '..r.shortage) or ''))
      end
      if #rows>20 then self:Say('...plus '..(#rows-20)..' more materials.') end
    elseif not s.gather and not s.trainer and not s.done then
      self:Say('Open the profession book to scan learned recipes and exact reagents.')
    end
    if missing>0 then self:Say(missing..' route step(s) use recipes not learned by this character; totals exclude them.') end
  end
  for _,goal in pairs(self.db.materialGoals or {}) do
    local have=observed(goal.itemID)
    self:Say(string.format('Goal: %s %d/%d owned (short %d).',goal.name,have,goal.target,math.max(0,goal.target-have)))
  end
end

local function resolveItem(value)
  local id=tonumber(value)
  if id then return id,itemName(id) end
  if GetItemInfoInstant then
    local found=GetItemInfoInstant(value)
    if found then return found,itemName(found) end
  end
  if GetItemInfo then
    local name,link=GetItemInfo(value)
    local found=link and link:match('item:(%d+)')
    if found then return tonumber(found),name end
  end
end

function FP:TrackMaterial(input)
  local item,qty=(input or ''):match('^(.-)%s+(%d+)%s*$')
  local id,name=resolveItem(item or '')
  if not id or not qty then self:Say('Usage: /fp track <item ID or cached name> <quantity>');return end
  self.db.materialGoals=self.db.materialGoals or {}
  self.db.materialGoals[tostring(id)]={itemID=id,name=name,target=tonumber(qty)}
  self.db.trackedMaterialIDs=self.db.trackedMaterialIDs or {}
  self.db.trackedMaterialIDs[id]=true
  self:Say('Tracking '..name..': goal '..qty..'.')
  self:ShowMaterials()
end

function FP:UntrackMaterial(input)
  local id,name=resolveItem((input or ''):match('^%s*(.-)%s*$'))
  if not id then self:Say('Usage: /fp untrack <item ID or cached name>');return end
  if self.db.materialGoals then self.db.materialGoals[tostring(id)]=nil end
  if self.db.trackedMaterialIDs then self.db.trackedMaterialIDs[id]=nil end
  self:Say('Stopped tracking '..(name or ('item '..id))..'.')
end

local function refreshInventory()
  if not FP.db or not FP.character then return end
  FP.character.materials=FP.character.materials or {}
  for id in pairs(FP.db.trackedMaterialIDs or {}) do
    local n=liveCount(tonumber(id) or id)
    if n~=nil then FP.character.materials[tostring(id)]=n end
  end
  FP.character.materialsObservedAt=time()
end

local inventoryEvents=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','BAG_UPDATE_DELAYED','BANKFRAME_OPENED','BANKFRAME_CLOSED'}) do
  pcall(inventoryEvents.RegisterEvent,inventoryEvents,event)
end
inventoryEvents:SetScript('OnEvent',refreshInventory)
