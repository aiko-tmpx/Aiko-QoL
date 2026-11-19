local addonName, ns = ...

-- Gate strictly to WoW Forever (TOC 16001). Leave all other clients untouched.
local _, _, _, tocversion = GetBuildInfo()
if tocversion ~= 16001 and not ns.IsDev then
    return
end

ns.Core = ns.Core or {}
local LootService = {}
ns.Core.LootService = LootService

local QUALITY_HEX_MAP = {
    ["1eff00"] = 2, -- Uncommon
    ["0070dd"] = 3, -- Rare
    ["a335ee"] = 4, -- Epic
    ["ff8000"] = 5, -- Legendary
}

local function CanAccess(val)
    if not val then return false end
    if canaccessvalue and not canaccessvalue(val) then return false end
    if issecretvalue and issecretvalue(val) then return false end
    return true
end

-- =========================================================================
-- CONFIG & STATE
-- =========================================================================
function LootService:GetProfile()
    local profile = ns.Core.Repository and ns.Core.Repository:GetProfile()
    return profile and profile.modules and profile.modules.loot
end

function LootService:IsEnabled()
    local p = self:GetProfile()
    return p and p.enabled and true or false
end

function LootService:GetMinQuality()
    local p = self:GetProfile()
    return p and tonumber(p.minQuality) or 3 -- 2: Uncommon, 3: Rare, 4: Epic
end

function LootService:GetDirection()
    local p = self:GetProfile()
    return (p and p.direction == "DOWN") and "DOWN" or "UP"
end

function LootService:GetAnchorCoords()
    local p = self:GetProfile()
    local x = p and tonumber(p.anchorX) or 350
    local y = p and tonumber(p.anchorY) or 0
    return x, y
end

-- =========================================================================
-- ANCHOR INTERFACE (Delegated to LootToastView)
-- =========================================================================
function LootService:ToggleAnchor()
    if ns.UI.LootToastView then
        return ns.UI.LootToastView:ToggleAnchor()
    end
    return false
end

function LootService:LockAnchor()
    if ns.UI.LootToastView then
        return ns.UI.LootToastView:LockAnchor()
    end
    return false
end

function LootService:IsAnchorUnlocked()
    if ns.UI.LootToastView then
        return ns.UI.LootToastView:IsAnchorUnlocked()
    end
    return false
end

-- =========================================================================
-- TOAST SPAWN & DEDUPLICATION
-- =========================================================================
local recentDedupe = {}

function LootService:SpawnToast(winnerName, playerClass, itemLink, rollType, rollNumber)
    if not self:IsEnabled() then return end
    if not CanAccess(winnerName) or not CanAccess(itemLink) then return end
    if type(itemLink) ~= "string" or type(winnerName) ~= "string" then return end

    local _, _, quality = C_Item.GetItemInfo(itemLink)
    if not quality then
        local rawQuality = itemLink:match("|cff(%x%x%x%x%x%x)")
        if rawQuality then
            quality = QUALITY_HEX_MAP[rawQuality:lower()] or 1
        end
    end
    quality = tonumber(quality) or 1

    if quality < self:GetMinQuality() then
        return
    end

    -- Deduplicate identical wins within 2.5s
    local key = tostring(itemLink) .. ":" .. tostring(winnerName)
    local now = GetTime()
    if recentDedupe[key] and (now - recentDedupe[key] < 2.5) then
        return
    end
    recentDedupe[key] = now

    if ns.UI.LootToastView then
        ns.UI.LootToastView:Spawn(winnerName, playerClass, itemLink, quality, rollType, rollNumber)
    end
end

-- =========================================================================
-- LOOT ROLL LISTENERS (CHAT_MSG_LOOT & PLAYER_REGEN_DISABLED)
-- =========================================================================
function LootService:InitListeners()
    if self.listenersInitialized then return end
    self.listenersInitialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")

    frame:SetScript("OnEvent", function(_, event, msg)
        if event == "PLAYER_REGEN_DISABLED" then
            LootService:LockAnchor()
            return
        end

        if not LootService:IsEnabled() then return end

        if event == "CHAT_MSG_LOOT" and msg and CanAccess(msg) then
            local wonStr = LOOT_ITEM_ROLL_WON or "%s won: %s."
            local pattern = wonStr:gsub("%%s", "(.+)"):gsub("%.", "%%.")
            local winner, item = msg:match(pattern)

            if not winner or not item then
                winner, item = msg:match("^(.-)%s+won:%s+(|c%x+|Hitem:.-|h%[.-%]|h|r)")
                if not winner or not item then
                    winner, item = msg:match("^(.-)%s+побеждает в розыгрыше:%s+(|c%x+|Hitem:.-|h%[.-%]|h|r)")
                end
            end

            if winner and item and CanAccess(winner) and CanAccess(item) then
                winner = winner:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.$", "")
                local rollType = 0
                local rollNum = msg:match("%((%d+)%)") or msg:match("%-%s*(%d+)%)")
                if msg:find("Need") or msg:find("Нужно") then
                    rollType = 1
                elseif msg:find("Greed") or msg:find("Не откажусь") then
                    rollType = 2
                elseif msg:find("Disenchant") or msg:find("Распыление") then
                    rollType = 3
                end

                local playerClass = select(2, UnitClass(winner))
                LootService:SpawnToast(winner, playerClass, item, rollType, rollNum)
            end
        end
    end)
end

-- =========================================================================
-- TEST GENERATOR
-- =========================================================================
local testItems = {
    { id = 19019, name = "Thunderfury, Blessed Blade of the Windseeker", q = 5 },
    { id = 16832, name = "Bloodfang Hood", q = 4 },
    { id = 13386, name = "Archivist Cape", q = 3 },
    { id = 14562, name = "Warmonger's Belt", q = 2 },
}

local testPlayers = {
    { name = "Aiko", class = "ROGUE" },
    { name = "Khadgar", class = "MAGE" },
    { name = "Varian", class = "WARRIOR" },
    { name = "Thrall", class = "SHAMAN" },
    { name = "Anduin", class = "PRIEST" },
    { name = "Malfurion", class = "DRUID" },
}

function LootService:SpawnTestToast()
    local item = testItems[math.random(1, #testItems)]
    local player = testPlayers[math.random(1, #testPlayers)]
    local rType = math.random(1, 2)
    local rNum = math.random(40, 100)

    local hexColors = { [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000" }
    local fakeLink = string.format("|cff%s|Hitem:%d:0:0:0:0:0:0:0:80:0:0:0:0|h[%s]|h|r",
        hexColors[item.q] or "ffffff", item.id, item.name)

    self:SpawnToast(player.name, player.class, fakeLink, rType, rNum)
end

-- =========================================================================
-- LIFECYCLE
-- =========================================================================
function LootService:Init()
    if ns.UI.LootToastView then
        ns.UI.LootToastView:Init()
    end
    self:InitListeners()
end

function LootService:Update()
    if ns.UI.LootToastView then
        ns.UI.LootToastView:Update()
    end
end
