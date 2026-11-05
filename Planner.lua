-- Account-aware profession leveling routes and material tracking.
-- LevelingData craft counts are route estimates; live recipe skill-up data wins.
local _, FP = ...

local function norm(s) return tostring(s or ''):lower():gsub('[^%a%d]','') end
local function playerKey()
  return (UnitName('player') or 'Unknown')..'-'..(GetRealmName() or 'Realm')
end
local function trim(s) return (tostring(s or ''):match('^%s*(.-)%s*$')) end
local function liveName(id)
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
  local key=playerKey()
  local char=FP.db and FP.db.characters and FP.db.characters[key]
  if char then FP.character=char end
  return char
end
local function profileFor(profession)
  local char=currentChar()
  for name,info in pairs(char and char.professions or {}) do
    if FP:ResolveProfession(name)==profession then return info,name end
  end
end
local function accountCount(id)
  local total,char=0,currentChar()
  local current=liveCount(id)
  if current~=nil then total=current
  else total=tonumber(char and char.materials and char.materials[tostring(id)]) or 0 end
  for _,other in pairs(FP.db and FP.db.characters or {}) do
    if other~=char then total=total+(tonumber(other.materials and other.materials[tostring(id)]) or 0) end
  end
  return total
end

function FP:ResolveProfession(request)
  local query=norm(request)
  if query=='' then return nil end
  for name in pairs(self.LevelingData or {}) do
    if norm(name)==query then return name end
  end
  for name in pairs(self.character and self.character.professions or {}) do
    if norm(name)==query then return name end
  end
end

local function saveMaterialSnapshot(itemID)
  if not itemID then return end
  local char=currentChar()
  if not char then return end
  char.materials=char.materials or {}
  local count=liveCount(itemID)
  if count~=nil then char.materials[tostring(itemID)]=count end
  char.materialsObservedAt=time()
end

local function copyMaterials(materials)
  local saved={}
  for _,slot in ipairs(materials or {}) do
    local choices={}
    for _,item in ipairs(slot or {}) do
      local id=item.itemID or item.id
      choices[#choices+1]={
        name=item.name or liveName(id),id=id,itemID=id,
        amount=tonumber(item.amount or item.perCraft) or 0,
      }
      if id then
        FP.db.trackedMaterialIDs=FP.db.trackedMaterialIDs or {}
        FP.db.trackedMaterialIDs[id]=true
        saveMaterialSnapshot(id)
      end
    end
    if #choices>0 then saved[#saved+1]=choices end
  end
  return saved
end

function FP:SaveRecipeState(state)
  if not state or not state.name or state.name=='Profession' or state.loading or not self.db then return end
  local profession=self:ResolveProfession(state.name)
  if not profession then return end
  local char=currentChar()
  if not char then return end
  char.professions=char.professions or {}
  char.recipes=char.recipes or {}
  char.routeRecipes=char.routeRecipes or {}
  local old=char.professions[profession] or {}
  old.rank=tonumber(state.skill) or old.rank or 0
  old.maxRank=tonumber(state.maxSkill) or old.maxRank or 300
  old.skillLine=state.skillLine or old.skillLine
  old.recipeScanAt=time()
  char.professions[profession]=old

  local current={}
  for _,option in ipairs(state.options or {}) do
    current[option.name]={
      name=option.name,difficulty=option.difficulty,canSkillUp=true,
      slots=copyMaterials(option.reagents),
    }
  end
  char.recipes[profession]=current

  if state.recipes then
    local route={}
    for recipeKey,recipe in pairs(state.recipes) do
      route[recipeKey]={
        name=recipe.name,learned=recipe.learned~=false,
        canSkillUp=recipe.canSkillUp==true,difficulty=recipe.difficulty,
        slots=copyMaterials(recipe.materials or {}),
      }
    end
    char.routeRecipes[profession]=route
  end
  char.lastRecipeScan=time()
  self.db.characters[playerKey()]=char
  self.character=char
  self.liveRecipeState=state
  self.db.selectedProfession=profession
end

local function chooseSlot(slot)
  local best,bestHave
  for _,material in ipairs(slot or {}) do
    local id=material.itemID or material.id
    local have=id and accountCount(id) or tonumber(material.have) or 0
    if not best or have>(bestHave or -1) then best,bestHave=material,have end
  end
  if not best then return end
  local id=best.itemID or best.id
  return {itemID=id,id=id,name=best.name or liveName(id),
    amount=tonumber(best.amount or best.perCraft) or 0,have=bestHave or 0}
end

local function recipeMaterials(recipe,crafts)
  local totals={}
  for _,slot in ipairs(recipe and recipe.slots or {}) do
    local material=chooseSlot(slot)
    if material then
      local id=material.itemID
      local k=id and tostring(id) or ('name:'..material.name)
      local row=totals[k] or {itemID=id,name=material.name,required=0,have=material.have}
      row.required=row.required+material.amount*crafts
      if id then row.have=accountCount(id) end
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

local function findStep(route,rank)
  for _,step in ipairs(route or {}) do
    if rank<(tonumber(step[2]) or 0) then return step end
  end
end
local function craftCount(step,rank,target)
  local from,to=tonumber(step[1]) or rank,tonumber(step[2]) or rank+1
  local estimate=tonumber(step[4]) or math.max(1,to-from)
  return math.max(1,math.ceil(estimate*math.max(0,target-rank)/math.max(1,to-from)))
end

function FP:GetLevelingSuggestion(request)
  if not self.db then return nil end
  local state=self.liveRecipeState
  local active=state and self:ResolveProfession(state.name)
  local profession=self:ResolveProfession(request) or active
    or self:ResolveProfession(self.db.selectedProfession)
  if not profession then
    local names={}
    for name in pairs(self.character and self.character.professions or {}) do names[#names+1]=name end
    table.sort(names)
    for _,name in ipairs(names) do
      profession=self:ResolveProfession(name)
      if profession then break end
    end
  end
  if not profession then return nil end
  self.db.selectedProfession=profession
  local profile=profileFor(profession) or {}
  local char=currentChar() or {}
  local rank=tonumber(active==profession and state.skill) or tonumber(profile.rank) or 0
  local cap=tonumber(active==profession and state.maxSkill) or tonumber(profile.maxRank) or 300
  local suggestion={profession=profession,rank=rank,cap=cap,recipeMap=char.routeRecipes and char.routeRecipes[profession]}
  if rank>=300 then suggestion.done=true;return suggestion end
  if cap>0 and rank>=cap then
    suggestion.trainer=true
    suggestion.nextCap=math.min(300,cap+75)
    return suggestion
  end
  if cap>0 and rank>=cap-5 then
    suggestion.trainerSoon=true
    suggestion.pointsToCap=math.max(0,cap-rank)
  end

  local step=findStep(self.LevelingData and self.LevelingData[profession],rank)
  if not step then suggestion.missing=true;return suggestion end
  local from,to=tonumber(step[1]) or rank,tonumber(step[2]) or rank+1
  local target=math.min(to,cap>0 and cap or to)
  suggestion.target=target
  suggestion.rangeStart=math.max(rank,from)
  suggestion.quantity=craftCount(step,rank,target)
  suggestion.routeRecipe=step[3]

  local gather=self.ProfessionData.primary[profession]=='gathering' or profession=='Fishing'
  if gather then
    suggestion.gather=true
    suggestion.name=step[3]
    return suggestion
  end

  local routeMap=char.routeRecipes and char.routeRecipes[profession] or {}
  local routeRecipe=routeMap[norm(step[3])]
  local liveOptions=char.recipes and char.recipes[profession] or {}
  local chosen
  if routeRecipe and routeRecipe.learned and routeRecipe.canSkillUp then
    chosen=routeRecipe
  end
  if not chosen and active==profession and state and state.options and state.options[1] then
    local option=state.options[1]
    chosen={name=option.name,canSkillUp=true,slots=copyMaterials(option.reagents)}
    suggestion.liveOnly=true
    suggestion.quantity=1
    suggestion.rangeStart=rank
    target=math.min(rank+1,cap)
    suggestion.target=target
  end
  if not chosen then
    local best,bestRank
    for _,recipe in pairs(liveOptions) do
      if recipe.canSkillUp then
        local r=({optimal=1,difficult=1,medium=2,easy=3})[recipe.difficulty] or 4
        if not best or r<bestRank then best,bestRank=recipe,r end
      end
    end
    chosen=best
    if chosen then
      suggestion.liveOnly=true
      suggestion.quantity=1
      suggestion.rangeStart=rank
      suggestion.target=math.min(rank+1,cap)
    end
  end
  if chosen then
    suggestion.name=chosen.name
    suggestion.recipe=chosen
    suggestion.materials=recipeMaterials(chosen,suggestion.quantity)
    suggestion.known=true
    suggestion.alternative=norm(chosen.name)~=norm(step[3])
  else
    suggestion.name=step[3]
    suggestion.known=false
    suggestion.unverified=true
    suggestion.materials={}
  end
  return suggestion
end

function FP:LevelingLabel(s)
  if not s then return 'Open a profession or use /fp level <profession>.' end
  if s.done then return s.profession..': maxed at skill 300.' end
  if s.trainer then return string.format('%s %d/%d: train the next rank before leveling.',s.profession,s.rank,s.cap) end
  if s.missing then return s.profession..': no leveling route available.' end
  local label
  if s.gather then
    label=string.format('%s %d -> %d: gather %s',s.profession,s.rank,s.target,s.name)
  else
    local verb=s.known and (s.alternative and 'Learned alternative: ' or 'Make: ') or 'Target recipe: '
    label=string.format('%s %d -> %d: %s%s (~%d crafts, estimate)',s.profession,s.rank,s.target,verb,s.name,s.quantity or 1)
    if s.liveOnly then label=label..' Live skill-up pick.' end
    if s.unverified then label=label..' Route estimate; open the profession book to confirm.' end
  end
  if s.trainerSoon then
    label=label..string.format(' Trainer soon: %d point%s to cap.',s.pointsToCap,s.pointsToCap==1 and '' or 's')
  end
  return label
end

function FP:GetMaterialNeeds(s)
  if not s then return {} end
  local rows=s.materials or {}
  for _,row in ipairs(rows) do
    if row.itemID then
      row.have=accountCount(row.itemID)
      row.shortage=math.max(0,row.required-row.have)
    end
  end
  return rows
end

function FP:GetLevelingPlanMaterials(s)
  if not s then return {},0 end
  local routeMap=s.recipeMap or {}
  local totals,missing={},0
  for _,step in ipairs(self.LevelingData[s.profession] or {}) do
    local finish,start=tonumber(step[2]) or 0,tonumber(step[1]) or 0
    if finish>s.rank then
      local recipe=routeMap[norm(step[3])]
      if recipe and recipe.learned then
        local crafts=craftCount(step,math.max(s.rank,start),finish)
        for _,row in ipairs(recipeMaterials(recipe,crafts)) do
          local id=row.itemID and tostring(row.itemID) or ('name:'..row.name)
          local total=totals[id] or {itemID=row.itemID,name=row.name,required=0,have=row.have or 0}
          total.required=total.required+row.required
          if row.itemID then total.have=accountCount(row.itemID) end
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

function FP:ShowMaterials(request)
  if not self.db then return end
  local state=self.GetLiveRecipeState and self:GetLiveRecipeState()
  if state and not state.loading then self:SaveRecipeState(state) end
  local s=self:GetLevelingSuggestion(request)
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
    local id=goal.id
    local have=id and accountCount(id) or nil
    self:Say(string.format('Goal: %s %s/%s owned.',goal.name,tostring(have or '?'),tostring(goal.count)))
  end
end

local function resolveItem(name)
  local id=tonumber(name)
  if id then return id,liveName(id) end
  if GetItemInfoInstant then
    local found=GetItemInfoInstant(name)
    if found then return found,liveName(found) end
  end
  if GetItemInfo then
    local label,link=GetItemInfo(name)
    local found=link and link:match('item:(%d+)')
    if found then return tonumber(found),label end
  end
end
function FP:TrackMaterial(args)
  if not self.db then return end
  local name,qty=trim(args):match('^(.-)%s+(%d+)$')
  local id,label=resolveItem(name or '')
  if not name or not tonumber(qty) or tonumber(qty)<1 then
    self:Say('Use /fp track <item ID or cached item name> <quantity>');return
  end
  label=label or name
  self.db.materialGoals=self.db.materialGoals or {}
  self.db.materialGoals[tostring(id or norm(name))]={name=label,id=id,count=tonumber(qty)}
  if id then
    self.db.trackedMaterialIDs=self.db.trackedMaterialIDs or {}
    self.db.trackedMaterialIDs[id]=true
  end
  self:Say('Tracking '..label..' x'..qty)
end
function FP:UntrackMaterial(args)
  if not self.db then return end
  local id,name=resolveItem(trim(args))
  local key=id and tostring(id) or norm(args)
  self.db.materialGoals=self.db.materialGoals or {}
  self.db.materialGoals[key]=nil
  self:Say('Material tracking updated.')
end

local inventory=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','BAG_UPDATE_DELAYED','BANKFRAME_OPENED','BANKFRAME_CLOSED'}) do
  pcall(inventory.RegisterEvent,inventory,event)
end
inventory:SetScript('OnEvent',function()
  local char=currentChar()
  if not char then return end
  char.materials=char.materials or {}
  for id in pairs(FP.db.trackedMaterialIDs or {}) do
    local n=liveCount(tonumber(id) or id)
    if n then char.materials[tostring(id)]=n end
  end
  char.materialsObservedAt=time()
end)
