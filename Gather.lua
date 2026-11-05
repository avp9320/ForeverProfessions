local _, FP = ...
-- Detect a player gathering cast paired with its resulting loot item.
-- Saved coordinates are observed locations, not guaranteed spawns.
local detector = CreateFrame("Frame")
local pending

local function isSecret(value)
  return issecretvalue and issecretvalue(value)
end

local function position()
  if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID or isSecret(mapID) then return end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return end
  local x, y = pos:GetXY()
  if isSecret(x) or isSecret(y) then return end
  return mapID, x, y
end

local function gatherKind(spellID)
  if not spellID or isSecret(spellID) or not C_Spell or not C_Spell.GetSpellInfo then return end
  local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
  local name = ok and info and info.name
  if not name or isSecret(name) then return end
  local lower = name:lower()
  if lower:find("fish", 1, true) then return "Fishing", name end
  if lower:find("skin", 1, true) then return "Skinning", name end
  if lower:find("mining", 1, true) or lower == "mine" then return "Mining", name end
  if lower:find("herb", 1, true) or lower:find("gather", 1, true) then return "Herbalism", name end
  return nil, name
end

local function itemFromLoot(message)
  if not message or isSecret(message) then return end
  local link = message:match("(|Hitem:[^|]+|h%[[^%]]+%]|h)")
  if not link then return end
  local itemID = tonumber(link:match("|Hitem:(%d+)"))
  local itemName = link:match("|h%[(.-)%]|h")
  if itemID and C_Item and C_Item.GetItemInfo then
    local ok, cachedName = pcall(C_Item.GetItemInfo, itemID)
    if ok and cachedName and not isSecret(cachedName) then itemName = cachedName end
  end
  if itemName and not isSecret(itemName) then return itemName, itemID end
end

local selectAutoRoute

local function recordGather(candidate, itemName, itemID)
  local db = FP.db
  if not db or not candidate or not candidate.map or not candidate.x or not candidate.y then return end
  db.nodes = db.nodes or {}
  local zone = db.nodes[candidate.map] or {}
  db.nodes[candidate.map] = zone
  local nodes = zone[candidate.kind] or {}
  zone[candidate.kind] = nodes

  for _, node in ipairs(nodes) do
    local dx, dy = node.x - candidate.x, node.y - candidate.y
    if dx * dx + dy * dy < 0.000025 then
      node.visits = (node.visits or 1) + 1
      node.lastSeen = time()
      node.knownSpawn = true
      node.loot = node.loot or {}
      local lootKey = itemID and tostring(itemID) or itemName
      local loot = node.loot[lootKey] or {name = itemName, itemID = itemID, count = 0}
      loot.name, loot.itemID = itemName, itemID
      loot.count = (loot.count or 0) + 1
      node.loot[lootKey] = loot
      if db.settings.detectionDebug then
        FP:Say("Gather detected: " .. candidate.kind .. " → " .. itemName .. " (known spot, " .. node.visits .. " visits).")
      end
      selectAutoRoute(candidate.kind)
      FP:RefreshUI()
      if FP.RefreshRouteMap then FP:RefreshRouteMap() end
      return
    end
  end

  local lootKey = itemID and tostring(itemID) or itemName
  nodes[#nodes + 1] = {
    x = candidate.x, y = candidate.y, visits = 1, lastSeen = time(), knownSpawn = true,
    loot = {[lootKey] = {name = itemName, itemID = itemID, count = 1}},
  }
  if db.settings.detectionDebug then
    FP:Say(string.format("Gather detected: %s → %s at %.1f, %.1f.", candidate.kind, itemName, candidate.x * 100, candidate.y * 100))
  end
  if not db.selectedResource then db.selectedResource = candidate.kind end
  FP:RefreshUI()
  if FP.RefreshRouteMap then FP:RefreshRouteMap() end
end

selectAutoRoute = function(kind)
  local selected = FP.db and FP.db.selectedResource
  if not selected or (selected ~= "Mining" and selected ~= "Herbalism" and selected ~= "Fishing" and selected ~= "Skinning") then
    FP.db.selectedResource = kind
  end
end

local function clearPending()
  pending = nil
end

local function timeoutFor(kind)
  return kind == "Fishing" and 45 or 12
end

local function onEvent(_, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "ForeverProfessions" then
      detector:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
      detector:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
      detector:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
      detector:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
      detector:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
      detector:RegisterEvent("CHAT_MSG_LOOT")
      detector:RegisterEvent("PLAYER_REGEN_DISABLED")
      detector:RegisterEvent("ZONE_CHANGED_NEW_AREA")
      detector:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    return
  end

  if event == "PLAYER_REGEN_DISABLED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
    clearPending()
    return
  end

  if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
    local unit = ...
    if unit == "player" then clearPending() end
    return
  end

  if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
    local unit, _, spellID = ...
    if unit ~= "player" then return end
    local kind, spellName = gatherKind(spellID)
    if not kind then
      if FP.db and FP.db.settings.detectionDebug and spellName then FP:Say("Cast seen, not classified: " .. spellName) end
      return
    end
    local mapID, x, y = position()
    if mapID then
      pending = {kind = kind, spell = spellName, started = GetTime(), map = mapID, x = x, y = y, timeout = timeoutFor(kind)}
    end
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit ~= "player" then return end
    local kind, spellName = gatherKind(spellID)
    if not kind then
      if FP.db and FP.db.settings.detectionDebug and spellName then FP:Say("Successful cast not classified: " .. spellName) end
      return
    end
    local now = GetTime()
    if not pending or pending.kind ~= kind or now - pending.started > pending.timeout then
      local mapID, x, y = position()
      if mapID then pending = {kind = kind, spell = spellName, started = now, map = mapID, x = x, y = y, timeout = timeoutFor(kind)} end
    else
      pending.succeeded = now
    end
    if pending and pending.kind == kind and pending.loot then
      local candidate, itemName, itemID = pending, pending.loot.name, pending.loot.itemID
      clearPending()
      recordGather(candidate, itemName, itemID)
    end
    return
  end

  if event == "CHAT_MSG_LOOT" then
    if not pending or GetTime() - pending.started > pending.timeout then clearPending(); return end
    local message = ...
    local itemName, itemID = itemFromLoot(message)
    if itemName then
      if pending.succeeded then
        local candidate = pending
        clearPending()
        recordGather(candidate, itemName, itemID)
      else
        pending.loot = {name = itemName, itemID = itemID}
      end
    end
  end
end

detector:RegisterEvent("ADDON_LOADED")
detector:SetScript("OnEvent", onEvent)

function FP:ToggleDetectionDebug()
  if not self.db then return end
  self.db.settings.detectionDebug = not self.db.settings.detectionDebug
  self:Say("Gather detection debug " .. (self.db.settings.detectionDebug and "on." or "off."))
end
