local addonName, FP = ...
_G.ForeverProfessions = FP
local frame = CreateFrame('Frame')
local function playerKey()
  return (UnitName('player') or 'Unknown') .. '-' .. (GetRealmName() or 'Realm')
end
local function mapPosition()
  if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
  local mapID = C_Map.GetBestMapForUnit('player')
  if not mapID then return end
  local pos = C_Map.GetPlayerMapPosition(mapID, 'player')
  if pos then
    local x, y = pos:GetXY()
    return mapID, x, y
  end
end
local function distance(a,b)
  local dx,dy=a.x-b.x,a.y-b.y
  return dx*dx+dy*dy
end
function FP:Say(msg) print('|cffd8b56aForeverProfessions:|r '..tostring(msg)) end
function FP:RefreshCharacter()
  local key=playerKey()
  local char=self.db.characters[key] or {professions={}}
  local _,class=UnitClass('player')
  char.class=class
  char.level=UnitLevel('player')
  char.professions={}
  if GetProfessions and GetProfessionInfo then
    for _,index in ipairs({GetProfessions()}) do
      if index then
        local name,_,rank,maxRank,_,_,skillLine=GetProfessionInfo(index)
        if name then char.professions[name]={rank=rank or 0,maxRank=maxRank or 0,skillLine=skillLine} end
      end
    end
  end
  self.db.characters[key]=char
  self.character=char
end
function FP:Record(resource)
  resource=(resource or self.db.selectedResource or ''):match('^%s*(.-)%s*$')
  if resource=='' then self:Say('Choose a resource first: /fp resource Copper Vein'); return end
  local map,x,y=mapPosition()
  if not map then self:Say('Location unavailable here. Try outdoors in a zone.'); return end
  local bucket=self.db.nodes[map] or {}; self.db.nodes[map]=bucket
  local nodes=bucket[resource] or {}; bucket[resource]=nodes
  for _,n in ipairs(nodes) do
    if distance(n,{x=x,y=y}) < 0.000025 then
      n.visits=(n.visits or 1)+1; n.lastSeen=time()
      self:Say('Updated known '..resource..' location.'); self:RefreshUI(); return
    end
  end
  nodes[#nodes+1]={x=x,y=y,visits=1,lastSeen=time(),knownSpawn=true}
  self:Say('Saved '..resource..' at '..math.floor(x*100)..', '..math.floor(y*100)..'.')
  self:RefreshUI()
end
function FP:GetRoute()
  local map,x,y=mapPosition()
  local resource=self.db.selectedResource
  if not map or not resource then return {},map end
  local source=((self.db.nodes[map] or {})[resource] or {})
  local remaining={}
  for _,node in ipairs(source) do remaining[#remaining+1]=node end
  local route={}; local current={x=x,y=y}
  while #remaining>0 do
    local best,bestScore=1,math.huge
    for i,n in ipairs(remaining) do
      local score=distance(current,n)/(1+math.min(n.visits or 1,8)*0.08)
      if score<bestScore then best,bestScore=i,score end
    end
    local nextNode=table.remove(remaining,best)
    route[#route+1]=nextNode;current=nextNode
  end
  return route,map
end
function FP:SelectResource(name)
  if not name or name=='' then self:Say('Usage: /fp resource Mining'); return end
  self.db.selectedResource=name
  self:Say('Tracking '..name..'. Routes use observed locations in the current zone.')
  self:RefreshUI()
end
function FP:RefreshUI() end
frame:RegisterEvent('ADDON_LOADED')
frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('SKILL_LINES_CHANGED')
frame:RegisterEvent('PLAYER_LEVEL_UP')
frame:SetScript('OnEvent',function(_,event,arg)
  if event=='ADDON_LOADED' and arg==addonName then
    ForeverProfessionsDB=ForeverProfessionsDB or {}
    FP.db=ForeverProfessionsDB
    FP.db.nodes=FP.db.nodes or {}
    FP.db.characters=FP.db.characters or {}
    FP.db.settings=FP.db.settings or {}
    FP.db.settings.advisorPriority=FP.db.settings.advisorPriority or 'balanced'
  elseif FP.db and (event=='PLAYER_LOGIN' or event=='SKILL_LINES_CHANGED' or event=='PLAYER_LEVEL_UP') then
    FP:RefreshCharacter()
    FP:RefreshUI()
  end
end)
SLASH_FOREVERPROFESSIONS1='/fp'
SLASH_FOREVERPROFESSIONS2='/foreverprofessions'
SlashCmdList.FOREVERPROFESSIONS=function(input)
  input=(input or ''):match('^%s*(.-)%s*$')
  local cmd,rest=input:match('^(%S+)%s*(.*)$')
  cmd=(cmd or 'show'):lower()
  if cmd=='show' then FP:ToggleUI()
  elseif cmd=='resource' then FP:SelectResource(rest)
  elseif cmd=='mark' then FP:Record(rest~='' and rest or nil)
  elseif cmd=='route' then FP:PrintRoute()
  elseif cmd=='advisor' then FP:ShowAdvisor()
  elseif cmd=='detect' and (rest or ''):lower()=='debug' then FP:ToggleDetectionDebug()
  elseif cmd=='help' then FP:Say('/fp show | resource <name> | mark | route | advisor | detect debug')
  else FP:Say('Unknown command. Try /fp help') end
end
