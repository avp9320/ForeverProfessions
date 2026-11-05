-- Context-sensitive leveling coach built from the recipes the game says this
-- character has learned. It deliberately does not ship a guessed recipe route.
local _, FP = ...

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

local function isCandidate(difficulty)
  return difficulty == 'optimal' or difficulty == 'difficult' or difficulty == 'medium'
end

local function difficultyLabel(difficulty)
  if difficulty == 'optimal' or difficulty == 'difficult' then return 'Orange' end
  if difficulty == 'medium' then return 'Yellow' end
  return tostring(difficulty or 'unknown')
end

local function scanOpenProfession()
  if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillInfo then return nil end
  local profession, skill, maxSkill = GetTradeSkillLine()
  if not profession or profession == '' or profession == 'UNKNOWN' then return nil end

  local options = {}
  for index = 1, (GetNumTradeSkills() or 0) do
    local name, difficulty, available = GetTradeSkillInfo(index)
    if name and isCandidate(difficulty) then
      local reagents = {}
      local reagentCount = GetTradeSkillNumReagents and GetTradeSkillReagentInfo and GetTradeSkillNumReagents(index) or 0
      for reagentIndex = 1, (reagentCount or 0) do
        local reagentName, _, amount, inBags = GetTradeSkillReagentInfo(index, reagentIndex)
        if reagentName then
          reagents[#reagents + 1] = {
            name = reagentName,
            amount = amount or 0,
            inBags = inBags,
          }
        end
      end
      local enough = available and available > 0
      options[#options + 1] = {
        name = name,
        difficulty = difficulty,
        available = available or 0,
        enough = enough,
        reagents = reagents,
        reagentUnits = (function()
          local total = 0
          for _, reagent in ipairs(reagents) do total = total + (reagent.amount or 0) end
          return total
        end)(),
      }
    end
  end

  table.sort(options, function(a, b)
    local rank = {optimal=1, difficult=1, medium=2}
    local ar, br = rank[a.difficulty] or 9, rank[b.difficulty] or 9
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

function FP:RefreshLeveling()
  if not self.db then return end
  local state = scanOpenProfession()
  if not state then
    content:SetText('Open a profession window first, then press Refresh.\n\nThe coach reads the recipes your character has learned and their live orange/yellow skill-up colors.')
    return
  end

  local lines = {state.name .. '  |  Skill ' .. tostring(state.skill or '?') .. ' / ' .. tostring(state.maxSkill or '?')}
  local reminder = trainerReminder(state.name)
  if reminder then
    lines[#lines + 1] = ''
    lines[#lines + 1] = reminder
  end
  lines[#lines + 1] = ''
  if #state.options == 0 then
    lines[#lines + 1] = 'No learned orange or yellow recipes are available right now.'
    lines[#lines + 1] = 'Learn another recipe or train the next rank, then refresh.'
  else
    local best = state.options[1]
    lines[#lines + 1] = 'RECOMMENDED NEXT CRAFT'
    lines[#lines + 1] = best.name .. '  (' .. difficultyLabel(best.difficulty) .. ')'
    lines[#lines + 1] = best.enough and ('You can make ' .. best.available .. ' with current reagents.') or 'Not enough reagents in your bags for one craft.'
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Materials for 1 craft:'
    if #best.reagents == 0 then
      lines[#lines + 1] = 'The game did not report reagent details.'
    else
      for _, reagent in ipairs(best.reagents) do
        local bagText = reagent.inBags ~= nil and ('  (bags: ' .. reagent.inBags .. ')') or ''
        lines[#lines + 1] = string.format('%d x %s%s', reagent.amount, reagent.name, bagText)
      end
    end
    if #state.options > 1 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = 'Other skill-up recipes:'
      for i = 2, math.min(3, #state.options) do
        local option = state.options[i]
        lines[#lines + 1] = option.name .. '  (' .. difficultyLabel(option.difficulty) .. ')'
      end
    end
  end
  content:SetText(table.concat(lines, '\n'))
end

function FP:ShowLeveling()
  self:RefreshLeveling()
  window:Show()
end

local events = CreateFrame('Frame')
events:RegisterEvent('TRADE_SKILL_SHOW')
events:RegisterEvent('TRADE_SKILL_LIST_UPDATE')
events:RegisterEvent('TRADE_SKILL_CLOSE')
events:SetScript('OnEvent', function()
  if window:IsShown() then FP:RefreshLeveling() end
end)
