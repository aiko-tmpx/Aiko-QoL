local addonName, ns = ...

local TooltipService = {}
ns.Core.TooltipService = TooltipService

local function IsSafe(v)
    if v == nil then
        return false
    end
    if issecretvalue and issecretvalue(v) then
        return false
    end
    if canaccessvalue and not canaccessvalue(v) then
        return false
    end
    return true
end

local function GetTooltipUnit(tooltip)
    if tooltip and tooltip.GetUnit then
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if ok and IsSafe(unit) and UnitExists(unit) then
            return unit
        end
    end

    local owner = tooltip and tooltip:GetOwner()
    if owner and not owner:IsForbidden() and owner.unit and IsSafe(owner.unit) and UnitExists(owner.unit) then
        return owner.unit
    end

    if UnitExists("mouseover") then
        return "mouseover"
    end

    return nil
end

local function GetParentZoneName(unit)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
        return nil
    end

    local okMap, mapID = pcall(C_Map.GetBestMapForUnit, unit)
    if not okMap or not IsSafe(mapID) or not mapID or mapID <= 0 then
        return nil
    end

    local okInit, initialInfo = pcall(C_Map.GetMapInfo, mapID)
    if not okInit or not initialInfo or not IsSafe(initialInfo.name) then
        return nil
    end

    local currentID = mapID
    while currentID and currentID > 0 do
        local okInfo, info = pcall(C_Map.GetMapInfo, currentID)
        if not okInfo or not info then
            break
        end

        if info.mapType == Enum.UIMapType.Zone and IsSafe(info.name) then
            return info.name
        end

        if info.mapType == Enum.UIMapType.Continent or info.mapType == Enum.UIMapType.World then
            break
        end

        currentID = info.parentMapID
    end

    return initialInfo.name
end

local function GetUnitDistanceText(unit)
    -- 1. Try modern UnitDistanceSquared API
    if UnitDistanceSquared then
        local ok, distSq = pcall(UnitDistanceSquared, unit)
        if ok and IsSafe(distSq) and type(distSq) == "number" and distSq >= 0 then
            local dist = math.floor(math.sqrt(distSq) + 0.5)
            return dist .. " yds"
        end
    end

    -- 2. Try UnitPosition coordinates comparison
    if UnitPosition then
        local okP, py, px, _, pInst = pcall(UnitPosition, "player")
        local okU, uy, ux, _, uInst = pcall(UnitPosition, unit)
        if okP and okU and IsSafe(px) and IsSafe(py) and IsSafe(ux) and IsSafe(uy) and IsSafe(pInst) and IsSafe(uInst) then
            if pInst == uInst and type(px) == "number" and type(ux) == "number" then
                local dx = px - ux
                local dy = py - uy
                local dist = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
                return dist .. " yds"
            end
        end
    end

    return "Unknown"
end

function TooltipService:OnTooltipSetUnit(tooltip)
    if not tooltip or tooltip:IsForbidden() then
        return
    end

    local profile = ns.Core.Repository:GetProfile()
    if not profile or not profile.modules or not profile.modules.tooltip or not profile.modules.tooltip.enabled then
        return
    end

    -- Enable only in the open world
    if IsInInstance and IsInInstance() then
        return
    end

    local unit = GetTooltipUnit(tooltip)
    if not unit or not UnitExists(unit) then
        return
    end

    -- Skip self
    if UnitIsUnit(unit, "player") then
        return
    end

    -- Only friendly players in party or raid
    if not UnitIsPlayer(unit) then
        return
    end

    if not UnitIsFriend("player", unit) then
        return
    end

    if not (UnitInParty(unit) or UnitInRaid(unit)) then
        return
    end

    local showZone = profile.modules.tooltip.showZone ~= false
    local showDistance = profile.modules.tooltip.showDistance ~= false

    if showZone then
        local zone = GetParentZoneName(unit) or "Unknown"
        tooltip:AddDoubleLine(ns.L["TOOLTIP_ZONE_LABEL"] or "Zone:", zone, 1, 0.82, 0, 1, 1, 1)
    end

    if showDistance then
        local distance = GetUnitDistanceText(unit)
        tooltip:AddDoubleLine(ns.L["TOOLTIP_DISTANCE_LABEL"] or "Distance:", distance, 1, 0.82, 0, 1, 1, 1)
    end
end

function TooltipService:Init()
    if self.initialized then return end
    self.initialized = true

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            pcall(self.OnTooltipSetUnit, self, tooltip)
        end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", function(tip)
            pcall(self.OnTooltipSetUnit, self, tip)
            tip:Show()
        end)
    end
end
