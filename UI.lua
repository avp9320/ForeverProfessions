local _,FP=...
local window=CreateFrame('Frame','ForeverProfessionsWindow',UIParent,'BackdropTemplate')
window:SetSize(330,285)
window:SetPoint('CENTER')
window:SetFrameStrata('DIALOG')
window:SetMovable(true)
window:EnableMouse(true)
window:RegisterForDrag('LeftButton')
window:SetScript('OnDragStart',window.StartMoving)
window:SetScript('OnDragStop',window.StopMovingOrSizing)
window:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=14,insets={left=3,right=3,top=3,bottom=3}})
window:Hide()
local title=window:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
title:SetPoint('TOPLEFT',15,-16);title:SetText('ForeverProfessions')
local close=CreateFrame('Button',nil,window,'UIPanelCloseButton')
close:SetPoint('TOPRIGHT',0,0)
local sub=window:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
sub:SetPoint('TOPLEFT',title,'BOTTOMLEFT',0,-10)
sub:SetWidth(300);sub:SetJustifyH('LEFT')
local content=window:CreateFontString(nil,'OVERLAY','GameFontHighlight')
content:SetPoint('TOPLEFT',sub,'BOTTOMLEFT',0,-15)
content:SetWidth(295);content:SetHeight(160)
content:SetJustifyH('LEFT');content:SetJustifyV('TOP')
local mark=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
mark:SetSize(105,24);mark:SetPoint('BOTTOMLEFT',15,15);mark:SetText('Mark location')
mark:SetScript('OnClick',function() FP:Record() end)
local leveling=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
leveling:SetSize(85,24);leveling:SetPoint('BOTTOM',window,'BOTTOM',0,15);leveling:SetText('Leveling')
leveling:SetScript('OnClick',function() FP:ShowLeveling() end)
local advisor=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
advisor:SetSize(85,24);advisor:SetPoint('BOTTOMRIGHT',-15,15);advisor:SetText('Advisor')
advisor:SetScript('OnClick',function() FP:ShowAdvisor() end)
function FP:RefreshUI()
  if not self.db then return end
  local resource=self.db.selectedResource or '(auto-selects after first gather)'
  sub:SetText('Route: '..resource)
  local route=self:GetRoute()
  local lines={'Auto-records successful mining, herbalism, and fishing gathers.'}
  if #route==0 then
    lines[#lines+1]='No observed locations in this zone yet.'
    lines[#lines+1]='Gather with a node or use /fp mark.'
    lines[#lines+1]='Use /fp detect debug if detection misses.'
  else
    lines[#lines+1]='Known locations in this zone:'
    for i=1,math.min(6,#route) do
      local n=route[i]
      lines[#lines+1]=string.format('%d. %.1f, %.1f  (%d visits)',i,n.x*100,n.y*100,n.visits or 1)
    end
    if #route>6 then lines[#lines+1]='...and '..(#route-6)..' more locations' end
  end
  content:SetText(table.concat(lines,'\n'))
end
function FP:ToggleUI()
  if window:IsShown() then window:Hide() else self:RefreshUI();window:Show() end
end
function FP:PrintRoute()
  local route=self:GetRoute()
  if #route==0 then self:Say('No observed locations in this zone for selected route.');return end
  self:Say('Suggested loop ('..#route..' stops):')
  for i=1,math.min(#route,10) do
    self:Say(string.format('%d: %.1f, %.1f',i,route[i].x*100,route[i].y*100))
  end
end
