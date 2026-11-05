local _, FP = ...

-- Draw the account's observed gathering loop on the selected world-map canvas.
-- Coordinates are normalized map positions, so pins move with map zoom and pan.
local mapFrame = CreateFrame("Frame", "ForeverProfessionsMapRoute", UIParent)
mapFrame:Hide()

local pins, lines = {}, {}
local currentMap

local function mapID()
  local world = WorldMapFrame
  if not world then return nil end
  if world.GetMapID then
    local ok, id = pcall(world.GetMapID, world)
    if ok and id then return id end
  end
  return world.mapID
end

local function canvasFor(world)
  local scroll = world and world.ScrollContainer
  if not scroll then return nil end
  if scroll.GetScrollChild then
    local child = scroll:GetScrollChild()
    if child then return child end
  end
  return scroll.Child
end

local function routeFor(map, resource)
  local nodes = FP.db and FP.db.nodes and FP.db.nodes[map] and FP.db.nodes[map][resource]
  if not nodes or #nodes == 0 then return {} end

  local remaining, route = {}, {}
  for _, node in ipairs(nodes) do
    if tonumber(node.x) and tonumber(node.y) then remaining[#remaining + 1] = node end
  end

  local playerMap, px, py
  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
    playerMap = C_Map.GetBestMapForUnit("player")
    if playerMap == map then
      local pos = C_Map.GetPlayerMapPosition(map, "player")
      if pos then px, py = pos:GetXY() end
    end
  end

  local x, y = px, py
  while #remaining > 0 do
    local best, bestScore = 1, math.huge
    for i, node in ipairs(remaining) do
      local score
      if x and y then
        local dx, dy = node.x - x, node.y - y
        local visits = math.min(tonumber(node.visits) or 1, 10)
        score = (dx * dx + dy * dy) / (1 + visits * 0.06)
      else
        score = -(tonumber(node.visits) or 1)
      end
      if score < bestScore then best, bestScore = i, score end
    end
    local nextNode = table.remove(remaining, best)
    route[#route + 1] = nextNode
    x, y = nextNode.x, nextNode.y
  end
  return route
end

local function pinAt(index)
  local pin = pins[index]
  if pin then return pin end
  pin = CreateFrame("Frame", nil, mapFrame, "BackdropTemplate")
  pin:SetSize(22, 22)
  pin:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8, insets={left=1,right=1,top=1,bottom=1}})
  pin:SetBackdropColor(0.12, 0.08, 0.02, 0.94)
  pin:SetBackdropBorderColor(1, 0.72, 0.12, 1)
  local label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER")
  label:SetTextColor(1, 1, 1)
  pin.label = label
  pin:EnableMouse(true)
  pin:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Gathering stop " .. self.routeIndex)
    GameTooltip:AddLine(self.resourceName, 1, 0.82, 0.2)
    GameTooltip:AddLine((self.visits or 1) .. " observed gathers", 0.85, 0.85, 0.85)
    GameTooltip:Show()
  end)
  pin:SetScript("OnLeave", GameTooltip_Hide)
  pins[index] = pin
  return pin
end

local function lineAt(index)
  local line = lines[index]
  if line then return line end
  line = mapFrame:CreateTexture(nil, "ARTWORK")
  line:SetTexture("Interface\\Buttons\\WHITE8X8")
  line:SetVertexColor(1, 0.68, 0.1, 0.78)
  lines[index] = line
  return line
end

local function hideUnused(list, firstUnused)
  for i = firstUnused, #list do list[i]:Hide() end
end

function FP:RefreshRouteMap()
  if not WorldMapFrame or not WorldMapFrame:IsShown() or not self.db then
    mapFrame:Hide()
    return
  end

  local map = mapID()
  local canvas = canvasFor(WorldMapFrame)
  local resource = self.db.selectedResource
  if not map or not canvas or not resource then
    mapFrame:Hide()
    return
  end

  local width, height = canvas:GetSize()
  if width <= 0 or height <= 0 then
    mapFrame:Hide()
    return
  end

  mapFrame:SetParent(canvas)
  mapFrame:ClearAllPoints()
  mapFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT")
  mapFrame:SetSize(width, height)
  mapFrame:SetFrameLevel(canvas:GetFrameLevel() + 8)
  mapFrame:Show()

  local route = routeFor(map, resource)
  for i, node in ipairs(route) do
    local px, py = node.x * width, node.y * height
    local pin = pinAt(i)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", mapFrame, "TOPLEFT", px, -py)
    pin.label:SetText(tostring(i))
    pin.routeIndex = i
    pin.resourceName = resource
    pin.visits = node.visits
    pin:Show()

    if i > 1 then
      local previous = route[i - 1]
      local x1, y1 = previous.x * width, previous.y * height
      local dx, dy = px - x1, py - y1
      local length = math.sqrt(dx * dx + dy * dy)
      local line = lineAt(i - 1)
      line:ClearAllPoints()
      line:SetSize(length, 3)
      line:SetPoint("CENTER", mapFrame, "TOPLEFT", (px + x1) / 2, -(py + y1) / 2)
      line:SetRotation(math.atan2(-dy, dx))
      line:Show()
    end
  end
  hideUnused(pins, #route + 1)
  hideUnused(lines, math.max(1, #route))
  currentMap = map
end

local events = CreateFrame("Frame")
events:RegisterEvent("WORLD_MAP_UPDATE")
events:RegisterEvent("WORLD_MAP_OPEN")
events:RegisterEvent("WORLD_MAP_CLOSE")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent", function(_, event)
  if event == "WORLD_MAP_CLOSE" then
    mapFrame:Hide()
  else
    FP:RefreshRouteMap()
  end
end)

if WorldMapFrame and WorldMapFrame.HookScript then
  WorldMapFrame:HookScript("OnShow", function() FP:RefreshRouteMap() end)
  WorldMapFrame:HookScript("OnHide", function() mapFrame:Hide() end)
  WorldMapFrame:HookScript("OnSizeChanged", function() FP:RefreshRouteMap() end)
end
