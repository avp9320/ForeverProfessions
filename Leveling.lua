-- Profession leveling coach. Forever's modern profession API exposes
-- canSkillUp and relativeDifficulty; the UI's arrow art is presentation only.
local _, FP = ...
local function recipeKey(value) return tostring(value or ''):lower():gsub('[^%a%d]','') end

local window = CreateFrame('Frame', 'ForeverProfessionsLevelingWindow', UIParent, 'BackdropTemplate')
window:SetSize(360, 330)
window:SetPoint('CENTER')
window:SetFrameStrata('DIALOG')
window:SetMovable(true)
window:EnableMouse(true)
window:RegisterForDrag('LeftButton')
window:SetScript('OnDragStart', window.StartMoving)
window:SetScript('OnDragStop', window.StopMovingOrSizing)
window:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=14,insets={left=3,right=3,top=3,bottom=3}})
window:Hide()

local title = window:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
title:SetPoint('TOPLEFT', 15, -16)
title:SetText('Profession Leveling')

local close = CreateFrame('Button', nil, window, 'UIPanelCloseButton')
close:SetPoint('TOPRIGHT', 0, 0)

local content = window:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
content:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -18)
content:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -18, -48)
content:SetHeight(245)
content:SetJustifyH('LEFT')
content:SetJustifyV('TOP')

local refresh = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
refresh:SetSize(110, 24)
refresh:SetPoint('BOTTOMLEFT', 15, 15)
refresh:SetText('Refresh')
refresh:SetScript('OnClick', function() FP:RefreshLeveling() end)

local function difficultyRank(value)
  local difficulty = Enum and Enum.TradeskillRelativeDifficulty
  if type(value) == 'number' then
    local optimal = difficulty and difficulty.Optimal or 0
    local medium = difficulty and difficulty.Medium or 1
    local easy = difficulty and difficulty.Easy or 2
    if value == optimal then return 1 end
    if value == medium then return 2 end
    if value == easy then return 3 end
    return 4
  end
  if value == 'optimal' or value == 'difficult' then return 1 end
  if value == 'medium' then return 2 end
  if value == 'easy' then return 3 end
  return 4
end

local function difficultyLabel(value)
  local rank = difficultyRank(value)
  if rank == 1 then return 'Guaranteed skill-up' end
  if rank == 2 then return 'Likely skill-up' end
  if rank == 3 then return 'Possible skill-up' end
  return 'Skill-up chance unknown'
end

local function itemName(itemID)
  if itemID and GetItemInfo then
    local name = GetItemInfo(itemID)
    if name then return name end
  end
  return 'Item ' .. tostring(itemID or '?')
end

local function itemCount(itemID)
  if itemID and GetItemCount then
    local count = GetItemCount(itemID, false)
    if count ~= nil then return count end
  end
end

local function readSchematic(recipeID)
  local api = C_TradeSkillUI
  if not api or not api.GetRecipeSchematic then return {}, 0 end
  local ok, schematic = pcall(api.GetRecipeSchematic, recipeID, false)
  if not ok or not schematic then return {}, 0 end

  local reagents, units = {}, 0
  for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
    if slot.required ~= false and slot.quantityRequired and slot.quantityRequired > 0 then
      local choices = {}
      for _, reagent in ipairs(slot.reagents or {}) do
        if reagent.itemID then
          local count = itemCount(reagent.itemID)
          choices[#choices + 1] = {
            name = itemName(reagent.itemID),
            id = reagent.itemID,
            amount = slot.quantityRequired,
            inBags = count,
          }
        end
      end
      if #choices > 0 then
        units = units + slot.quantityRequired
        table.sort(choices, function(a, b)
          local aEnough = a.inBags and a.inBags >= a.amount
          local bEnough = b.inBags and b.inBags >= b.amount
          if aEnough ~= bEnough then return aEnough end
          return a.name < b.name
        end)
        reagents[#reagents + 1] = choices
      end
    end
  end
  return reagents, units
end

local function readModernProfession()
  local api = C_TradeSkillUI
  if not api or not api.GetAllRecipeIDs or not api.GetRecipeInfo then return nil end
  if api.IsDataSourceChanging then
    local ok, changing = pcall(api.IsDataSourceChanging)
    if ok and changing then return {loading=true} end
  end

  local ok, recipeIDs = pcall(api.GetAllRecipeIDs)
  if not ok or type(recipeIDs) ~= 'table' then return nil end

  local baseInfo
  if api.GetBaseProfessionInfo then
    local infoOK, info = pcall(api.GetBaseProfessionInfo)
    if infoOK then baseInfo = info end
  end

  local options, recipes = {}, {}
  local routeNames = {}
  local profession = baseInfo and FP.ResolveProfession and FP:ResolveProfession(baseInfo.professionName)
  for _, step in ipairs(FP.LevelingData and FP.LevelingData[profession] or {}) do
    routeNames[recipeKey(step[3])] = true
  end
  for _, recipeID in ipairs(recipeIDs) do
    local infoOK, info = pcall(api.GetRecipeInfo, recipeID)
    if infoOK and type(info) == 'table' and info.name and info.learned then
      local canSkillUp = info.canSkillUp == true
      local recipe = {
        id=recipeID,name=info.name,learned=true,canSkillUp=canSkillUp,
        difficulty=info.relativeDifficulty,materials={},
      }
      if canSkillUp or routeNames[recipeKey(info.name)] then
        recipe.materials = readSchematic(recipeID)
      end
      recipes[recipeKey(info.name)] = recipe
      if canSkillUp then
        local reagents, reagentUnits = readSchematic(recipeID)
        local available
        if api.GetCraftableCount then
          local countOK, count = pcall(api.GetCraftableCount, recipeID)
          if countOK then available = count end
        end
        options[#options + 1] = {
          id=recipeID,name=info.name,difficulty=info.relativeDifficulty,
          available=available,enough=available and available > 0 or false,
          reagents=reagents,reagentUnits=reagentUnits,
        }
      end
    end
  end

  table.sort(options, function(a, b)
    local ar, br = difficultyRank(a.difficulty), difficultyRank(b.difficulty)
    if ar ~= br then return ar < br end
    if a.enough ~= b.enough then return a.enough end
    if a.reagentUnits ~= b.reagentUnits then return a.reagentUnits < b.reagentUnits end
    return a.name < b.name
  end)

  return {
    name=baseInfo and baseInfo.professionName or 'Profession',
    skill=baseInfo and baseInfo.skillLevel,
    maxSkill=baseInfo and baseInfo.maxSkillLevel,
    options=options,
    recipes=recipes,
    modern=true,
  }
end

-- Older clients expose the same skill-up category through the legacy
-- tradeskill API. This fallback never inspects rendered text or pixel colors.
local function readLegacyProfession()
  if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillInfo then return nil end
  local profession, skill, maxSkill = GetTradeSkillLine()
  if not profession or profession == '' or profession == 'UNKNOWN' then return nil end

  local options = {}
  for index = 1, (GetNumTradeSkills() or 0) do
    local name, difficulty, available = GetTradeSkillInfo(index)
    local rank = difficultyRank(difficulty)
    if name and rank <= 3 then
      local reagents = {}
      local reagentUnits = 0
      local count = GetTradeSkillNumReagents and GetTradeSkillReagentInfo and GetTradeSkillNumReagents(index) or 0
      for reagentIndex = 1, (count or 0) do
        local reagentName, _, amount, inBags = GetTradeSkillReagentInfo(index, reagentIndex)
        if reagentName then
          reagents[#reagents + 1] = {{
            name=reagentName,
            amount=amount or 0,
            inBags=inBags,
          }}
          reagentUnits = reagentUnits + (amount or 0)
        end
      end
      options[#options + 1] = {
        name=name,
        difficulty=difficulty,
        available=available or 0,
        enough=available and available > 0 or false,
        reagents=reagents,
        reagentUnits=reagentUnits,
      }
    end
  end

  table.sort(options, function(a, b)
    local ar, br = difficultyRank(a.difficulty), difficultyRank(b.difficulty)
    if ar ~= br then return ar < br end
    if a.enough ~= b.enough then return a.enough end
    if a.reagentUnits ~= b.reagentUnits then return a.reagentUnits < b.reagentUnits end
    return a.name < b.name
  end)
  return {name=profession, skill=skill, maxSkill=maxSkill, options=options}
end

local function trainerReminder(profession)
  local data = FP.character and FP.character.professions and FP.character.professions[profession]
  if not data then return nil end
  local rank, cap = tonumber(data.rank), tonumber(data.maxRank)
  if not rank or not cap or cap <= 0 then return nil end
  if rank >= cap then
    return string.format('Trainer reminder: current rank cap reached (%d). Train the next rank before continuing.', cap)
  end
  if cap - rank <= 5 then
    return string.format('Trainer reminder: %d skill point%s left in this rank (%d cap).', cap - rank, cap - rank == 1 and '' or 's', cap)
  end
end

function FP:GetLiveRecipeState()
  local state = readModernProfession()
  if not state then state = readLegacyProfession() end
  return state
end

function FP:RefreshLeveling(requested)
  if not self.db then return end
  local state = self:GetLiveRecipeState()
  if state and not state.loading and self.SaveRecipeState then
    self:SaveRecipeState(state)
  end
  if not state or state.loading then
    local suggestion = self.GetLevelingSuggestion and self:GetLevelingSuggestion(requested)
    local guide = suggestion and self:LevelingLabel(suggestion) .. '\n\n' or ''
    content:SetText(guide .. 'Open a profession window to scan learned recipes and exact reagents.')
    return
  end

  local lines = {state.name .. '  |  Skill ' .. tostring(state.skill or '?') .. ' / ' .. tostring(state.maxSkill or '?')}
  local planned = self.GetLevelingSuggestion and self:GetLevelingSuggestion(requested or state.name)
  if planned then
    lines[#lines + 1] = self:LevelingLabel(planned)
  end
  lines[#lines + 1] = ''
  if #state.options == 0 then
    lines[#lines + 1] = 'No learned recipes can raise this profession right now.'
    lines[#lines + 1] = 'Learn another recipe or train the next rank, then refresh.'
  else
    local best = state.options[1]
    lines[#lines + 1] = 'RECOMMENDED NEXT CRAFT'
    lines[#lines + 1] = best.name .. '  (' .. difficultyLabel(best.difficulty) .. ')'
    if best.available ~= nil then
      lines[#lines + 1] = best.available > 0 and ('You can make ' .. best.available .. ' with current reagents.') or 'Not enough reagents in your bags for one craft.'
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Materials for 1 craft:'
    if #best.reagents == 0 then
      lines[#lines + 1] = 'The game did not report reagent details.'
    else
      for _, slot in ipairs(best.reagents) do
        local parts = {}
        for _, reagent in ipairs(slot) do
          local bagText = reagent.inBags ~= nil and (' (bags: ' .. reagent.inBags .. ')') or ''
          parts[#parts + 1] = string.format('%d x %s%s', reagent.amount, reagent.name, bagText)
        end
        lines[#lines + 1] = table.concat(parts, ' OR ')
      end
    end
    if #state.options > 1 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = 'Other recipes that can skill up:'
      for i = 2, math.min(3, #state.options) do
        local option = state.options[i]
        lines[#lines + 1] = option.name .. '  (' .. difficultyLabel(option.difficulty) .. ')'
      end
    end
  end
  content:SetText(table.concat(lines, '\n'))
end

function FP:ShowLeveling(request)
  local chosen
  if self.db and request and request ~= '' and self.ResolveProfession then
    chosen = self:ResolveProfession(request)
    if chosen then self.db.selectedProfession = chosen end
  end
  self:RefreshLeveling(chosen)
  window:Show()
end

local events = CreateFrame('Frame')
for _, event in ipairs({'TRADE_SKILL_SHOW', 'TRADE_SKILL_LIST_UPDATE',
  'TRADE_SKILL_CLOSE', 'TRADE_SKILL_UPDATE', 'CRAFT_SHOW', 'CRAFT_UPDATE'}) do
  pcall(events.RegisterEvent, events, event)
end
events:SetScript('OnEvent', function()
  if window:IsShown() then FP:RefreshLeveling() end
end)
