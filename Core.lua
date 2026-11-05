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
  -- Keep any profession snapshot from the live recipe scanner. A missing
  -- profession API should not erase previously observed account data.
  char.professions=char.professions or {}
  local observed={}
  if GetProfessions and GetProfessionInfo then
    -- Profession slots may contain nil holes (especially secondary skills).
    -- ipairs stops at the first hole and silently loses every later skill.
    local ids={GetProfessions()}
    for i=1,6 do
      local index=ids[i]
      if index then
        local ok,name,_,rank,maxRank,_,_,skillLine=pcall(GetProfessionInfo,index)
        if ok and name then
          observed[name]={rank=rank or 0,maxRank=maxRank or 0,skillLine=skillLine}
        end
      end
    end
  end
  if next(observed) then char.professions=observed end
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
      -- Prefer nearby observed high-yield nodes without inventing respawn timers.
      local lootTotal=0
      for _,v in pairs(n.loot or {}) do lootTotal=lootTotal+(v.count or 0) end
      local avgYield=lootTotal/math.max(1,n.visits or 1)
      local weight=1+math.min(n.visits or 1,10)*0.06+math.min(avgYield,4)*0.08
      local score=distance(current,n)/weight
      if score<bestScore then best,bestScore=i,score end
    end
    local nextNode=table.remove(remaining,best)
    route[#route+1]=nextNode;current=nextNode
  end
  -- Improve the initial greedy order with bounded 2-opt passes. Include the
  -- return leg so the displayed route is a useful repeatable gathering loop.
  -- Coordinates are zone-relative, so this is geometric optimization only;
  -- it does not claim to account for terrain or inaccessible paths.
  local function leg(a,b)
    return math.sqrt(distance(a,b))
  end
  if #route >= 3 and #route <= 100 then
    local function loopLength()
      local total=leg({x=x,y=y},route[1])
      for i=1,#route-1 do total=total+leg(route[i],route[i+1]) end
      return total+leg(route[#route],route[1])
    end
    -- Keep the first stop nearest the player; optimize the remaining circuit.
    -- Limit work on densely observed zones to keep map refresh responsive.
    local bestLength=loopLength()
    local passes=0
    local improved=true
    while improved and passes<4 do
      passes=passes+1
      improved=false
      for i=2,#route-1 do
        for j=i+1,#route do
          local left,right=i,j
          while left<right do
            route[left],route[right]=route[right],route[left]
            left=left+1;right=right-1
          end
          local candidate=loopLength()
          if candidate+0.000001<bestLength then
            bestLength=candidate
            improved=true
          else
            left,right=i,j
            while left<right do
              route[left],route[right]=route[right],route[left]
              left=left+1;right=right-1
            end
          end
        end
      end
    end
  end
  return route,map
end
function FP:SelectResource(name)
  if not name or name=='' then self:Say('Usage: /fp resource Mining'); return end
  self.db.selectedResource=name
  self.db.manualResourceSelection=true
  self:Say('Tracking '..name..'. Routes use observed locations in the current zone.')
  self:RefreshUI()
end
function FP:RefreshUI() end
for _,event in ipairs({'ADDON_LOADED','PLAYER_LOGIN','SKILL_LINES_CHANGED','PLAYER_LEVEL_UP'}) do
  pcall(frame.RegisterEvent,frame,event)
end
frame:SetScript('OnEvent',function(_,event,arg)
  if event=='ADDON_LOADED' and arg==addonName then
    ForeverProfessionsDB=ForeverProfessionsDB or {}
    FP.db=ForeverProfessionsDB
    FP.db.nodes=FP.db.nodes or {}
    FP.db.characters=FP.db.characters or {}
    FP.db.settings=FP.db.settings or {}
    FP.db.settings.advisorPriority=FP.db.settings.advisorPriority or 'balanced'
    FP.db.materialGoals=FP.db.materialGoals or {}
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
  elseif cmd=='advisor' then FP:ShowAdvisor(rest)
  elseif cmd=='level' then FP:ShowLeveling(rest)
  elseif cmd=='mats' then FP:ShowMaterials(rest)
  elseif cmd=='track' then FP:TrackMaterial(rest)
  elseif cmd=='untrack' then FP:UntrackMaterial(rest)
  elseif cmd=='detect' and (rest or ''):lower()=='debug' then FP:ToggleDetectionDebug()
  elseif cmd=='help' then FP:Say('/fp show | level [profession] | mats [profession] | track <item> <qty> | untrack <item> | resource <name> | mark | route | advisor [balanced|gold|utility|account] | detect debug')
  else FP:Say('Unknown command. Try /fp help') end
end
