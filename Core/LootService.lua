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

function LootService:GetWidth()
    local p = self:GetProfile()
    local w = p and tonumber(p.width)
    return (w and w >= 180 and w <= 360) and w or 240
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

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    local quality = tonumber(itemLink:match("|cnIQ(%d):"))
    if not quality and C_Item and C_Item.GetItemQualityByID and itemID then
        local q = C_Item.GetItemQualityByID(itemID)
        if q and q > 0 then quality = q end
    end
    if not quality then
        local _, _, q = C_Item.GetItemInfo(itemLink)
        if q and q > 0 then quality = q end
    end
    if not quality then
        local rawHex = itemLink:match("|c[fF][fF](%x%x%x%x%x%x)")
        if rawHex then
            quality = QUALITY_HEX_MAP[rawHex:lower()]
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
local function Invert(fmt)
    if not fmt or type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%%(","%%%%("):gsub("%%%)","%%%%)")
    p = p:gsub("%(","%%("):gsub("%)","%%)")
    p = p:gsub("%-","%%-"):gsub("%+","%%+")
    p = p:gsub("%.","%%.")
    p = p:gsub("%%%d%$s", "(.-)")
    p = p:gsub("%%%d%$d", "(%%d+)")
    p = p:gsub("%%s", "(.-)")
    p = p:gsub("%%d", "(%%d+)")
    return p
end

local patterns = nil
local function GetLootPatterns()
    if patterns then return patterns end
    patterns = {
        lootOther   = Invert(_G.LOOT_ITEM),
        lootOtherM  = Invert(_G.LOOT_ITEM_MULTIPLE),
        lootSelf    = Invert(_G.LOOT_ITEM_SELF),
        lootSelfM   = Invert(_G.LOOT_ITEM_SELF_MULTIPLE),
        rollOther   = Invert(_G.LOOT_ROLL_WON),
        rollSelf    = Invert(_G.LOOT_ROLL_YOU_WON),
    }
    return patterns
end

local pendingRolls = {}

local function CleanupExpiredRolls()
    local now = GetTime()
    for itemKey, players in pairs(pendingRolls) do
        for name, data in pairs(players) do
            if now - data.time > 60 then
                players[name] = nil
            end
        end
        if not next(players) then
            pendingRolls[itemKey] = nil
        end
    end
end

local function CleanPlayerName(name)
    if not name or type(name) ~= "string" then return "" end
    name = name:gsub("|Hplayer:[^|]*|h%[?([^%]|]*)%]?|h", "%1")
    name = name:gsub("[%[%]]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.$", "")
    return name
end

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
        if event ~= "CHAT_MSG_LOOT" or not msg or not CanAccess(msg) then return end

        local itemLink = msg:match("(|c.-|Hitem:[^|]+|h%[[^%]]+%]%|h|r)")
            or msg:match("(|Hitem:[^|]+|h%[[^%]]+%]%|h)")
        if not itemLink or not CanAccess(itemLink) then return end

        local clean = msg:gsub("|HlootHistory:[^|]*|h.-|h:?%s*", "")
        CleanupExpiredRolls()

        -- 0. Intercept active roll lines (e.g. "[Loot]: Greed Roll - 91 for [Item] by Player")
        local rTypeStr, rNum, rName = clean:match("(%a+)%s+Roll%s*%-%s*(%d+)%s+for%s+.-%s+by%s+(.+)")
        if not rTypeStr then
            rName, rTypeStr, rNum = clean:match("^(.+)%s+has rolled%s+(%a+)%s*%-%s*(%d+)%s+for")
        end

        if rTypeStr and rNum and rName then
            local rType = 1
            local lower = rTypeStr:lower()
            if lower:find("greed") or lower:find("не откажусь") then
                rType = 2
            elseif lower:find("disenchant") or lower:find("распылен") then
                rType = 3
            end

            local itemID = tonumber(itemLink:match("item:(%d+)"))
            local key = itemID or itemLink:match("%[(.-)%]") or itemLink
            local cleanName = CleanPlayerName(rName)
            if cleanName ~= "" then
                pendingRolls[key] = pendingRolls[key] or {}
                pendingRolls[key][cleanName] = {
                    rollType = rType,
                    rollNum = tonumber(rNum),
                    time = GetTime()
                }
            end
            return
        end

        local p = GetLootPatterns()
        local winner = nil
        local isRoll = false

        -- 1. Roll won by player
        if p.rollSelf and clean:match(p.rollSelf) then
            winner = UnitName("player")
            isRoll = true
        elseif clean:find("You have won") or clean:find("You won") or clean:find("Вы выиграли") then
            winner = UnitName("player")
            isRoll = true
        -- 2. Roll won by another player
        elseif p.rollOther and clean:match(p.rollOther) then
            winner = clean:match(p.rollOther)
            isRoll = true
        elseif clean:find("won:") or clean:find("побеждает в розыгрыше") then
            winner = clean:match("([%w%-%s\128-\255]+)%s+won:") or clean:match("([%w%-%s\128-\255]+)%s+побеждает в розыгрыше")
            isRoll = true
        -- 3. Direct loot by player
        elseif (p.lootSelf and clean:match(p.lootSelf)) or (p.lootSelfM and clean:match(p.lootSelfM)) then
            winner = UnitName("player")
        elseif clean:find("You receive loot") or clean:find("Ваша добыча") or clean:find("Вы получаете добычу") then
            winner = UnitName("player")
        -- 4. Direct loot by another player
        elseif p.lootOther and clean:match(p.lootOther) then
            winner = clean:match(p.lootOther)
        elseif p.lootOtherM and clean:match(p.lootOtherM) then
            winner = clean:match(p.lootOtherM)
        elseif clean:find("receives loot") or clean:find("получает добычу") then
            winner = clean:match("([%w%-%s\128-\255]+)%s+receives loot") or clean:match("([%w%-%s\128-\255]+)%s+получает добычу")
        end

        if not winner or not CanAccess(winner) then return end
        winner = CleanPlayerName(winner)
        if winner == "" then return end

        local rollType = 0
        local rollNum = clean:match("%((%d+)%)") or clean:match("%-%s*(%d+)%)")

        if isRoll then
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            local key = itemID or itemLink:match("%[(.-)%]") or itemLink
            local cached = pendingRolls[key] and pendingRolls[key][winner]

            if cached then
                rollType = cached.rollType
                rollNum = cached.rollNum
                pendingRolls[key][winner] = nil
            else
                if clean:find("Need") or clean:find("Нужно") then
                    rollType = 1
                elseif clean:find("Greed") or clean:find("Не откажусь") then
                    rollType = 2
                elseif clean:find("Disenchant") or clean:find("Распыление") then
                    rollType = 3
                else
                    rollType = 1
                end
            end
        end

        local shortName = winner:match("^([^-]+)") or winner
        local playerClass = select(2, UnitClass(shortName))
        LootService:SpawnToast(winner, playerClass, itemLink, rollType, rollNum)
    end)
    self.eventFrame = frame
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
    local rNum = math.random(40, 100)
    local isSelf = math.random() > 0.5

    -- Passes authentic WoW Forever chat string into the event handler
    local realChatLine
    if isSelf then
        realChatLine = string.format("You have won: |cnIQ%d:|Hitem:%d::::::::43:1488::1::1:28:5245:::::|h[%s]|h|r (%d)",
            item.q, item.id, item.name, rNum)
    else
        realChatLine = string.format("|HlootHistory:1|h[Loot]|h: %s won: |cnIQ%d:|Hitem:%d::::::::43:1488::1::1:28:5245:::::|h[%s]|h|r (Need - %d)",
            player.name, item.q, item.id, item.name, rNum)
    end

    if self.eventFrame then
        local onEvent = self.eventFrame:GetScript("OnEvent")
        if onEvent then
            onEvent(self.eventFrame, "CHAT_MSG_LOOT", realChatLine)
            return
        end
    end

    local fakeLink = string.format("|cnIQ%d:|Hitem:%d::::::::43:1488::1::1:28:5245:::::|h[%s]|h|r",
        item.q, item.id, item.name)
    self:SpawnToast(player.name, player.class, fakeLink, 1, rNum)
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
