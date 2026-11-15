local addonName, ns = ...

-- Gate strictly to WoW Forever (TOC 16001). Leave all other clients untouched.
local _, _, _, tocversion = GetBuildInfo()
if tocversion ~= 16001 and not ns.IsDev then
    return
end

local LfgService = {}
ns.Core.LfgService = LfgService
local L = ns.L

local ROLES = (ns.LfgData and ns.LfgData.ROLES) or {"TANK", "HEALER", "DAMAGER"}
local CLASSES = (ns.LfgData and ns.LfgData.CLASSES) or {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
local ROLE_ATLASES = (ns.LfgData and ns.LfgData.ROLE_ATLASES) or {}
local ROLE_MICRO_ATLASES = (ns.LfgData and ns.LfgData.ROLE_MICRO_ATLASES) or {}
local LFG_ROLE_KEYS = {["TANK"] = "tank", ["HEALER"] = "healer", ["DAMAGER"] = "dps"}

local ALL_LANG_CODES = {
    "ruRU", "enUS", "deDE", "frFR", "esES", "itIT", "ptBR", "zhCN", "zhTW", "koKR"
}

local REGION_LANGUAGES = {
    [1] = { "enUS", "esMX", "ptBR" },                         -- US / Americas
    [2] = { "koKR" },                                         -- Korea
    [3] = { "enUS", "deDE", "frFR", "esES", "itIT", "ruRU" }, -- Europe
    [4] = { "zhTW" },                                         -- Taiwan
    [5] = { "zhCN" },                                         -- China
}

local LANG_LOCALE_KEYS = {
    ["ruRU"] = "LFG_LANG_RU",
    ["enUS"] = "LFG_LANG_EN",
    ["deDE"] = "LFG_LANG_DE",
    ["frFR"] = "LFG_LANG_FR",
    ["esES"] = "LFG_LANG_ES",
    ["esMX"] = "LFG_LANG_ES",
    ["itIT"] = "LFG_LANG_IT",
    ["ptBR"] = "LFG_LANG_PT",
    ["zhCN"] = "LFG_LANG_ZHCN",
    ["zhTW"] = "LFG_LANG_ZHTW",
    ["koKR"] = "LFG_LANG_KO"
}

-- Instance MapID -> World Area IDs (dungeon entrance zones) decoupled into Core/LfgData.lua
local INSTANCE_ZONE_AREAS = (ns.LfgData and ns.LfgData.INSTANCE_ZONE_AREAS) or {}

local instanceZoneNamesCache = {}
local function GetInstanceZoneNames(mapID)
    if not mapID or mapID <= 0 then return nil end
    if instanceZoneNamesCache[mapID] then return instanceZoneNamesCache[mapID] end
    local names = {}
    local instanceName = GetRealZoneText and GetRealZoneText(mapID)
    if instanceName and instanceName ~= "" then names[instanceName] = true end
    for _, areaID in ipairs(INSTANCE_ZONE_AREAS[mapID] or {}) do
        local areaName = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areaID)
        if areaName and areaName ~= "" then names[areaName] = true end
    end
    instanceZoneNamesCache[mapID] = names
    return names
end

local function IsMemberNearActivity(resultID, resultInfo)
    if not resultInfo or resultInfo.hasSelf then return false end
    local zoneNames = {}
    local hasZone = false
    for _, activityID in ipairs(resultInfo.activityIDs or {}) do
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
        local names = activityInfo and GetInstanceZoneNames(activityInfo.mapID)
        if names then
            for name in pairs(names) do
                zoneNames[name] = true
                hasZone = true
            end
        end
    end
    if not hasZone then return false end

    for memberIndex = 1, (resultInfo.numMembers or 1) do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
        if memberInfo and memberInfo.areaName and zoneNames[memberInfo.areaName] then
            return true
        end
    end
    return false
end

local function GetMemberLevel(resultID, resultInfo)
    local solo = (resultInfo.numMembers or 1) <= 1
    local member = solo and C_LFGList.GetSearchResultPlayerInfo(resultID, 1) 
        or (C_LFGList.GetSearchResultLeaderInfo and C_LFGList.GetSearchResultLeaderInfo(resultID) or C_LFGList.GetSearchResultPlayerInfo(resultID, 1))
    return member and tonumber(member.level) or 0
end

local function IsFriendOrGuild(resultInfo)
    if not resultInfo then return false end
    local bnet = tonumber(resultInfo.numBNetFriends) or 0
    local charF = tonumber(resultInfo.numCharFriends) or 0
    local guild = tonumber(resultInfo.numGuildMates) or 0
    return (bnet + charF + guild) > 0
end

local ENGLISH_CLASS_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
    ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
    MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid"
}

function LfgService:IsPlayerNearActivity(activityIDs)
    if not activityIDs then return false end
    local currentZone = GetRealZoneText and GetRealZoneText()
    local currentSubZone = GetSubZoneText and GetSubZoneText()
    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local currentMapName = currentMapID and C_Map.GetMapInfo and C_Map.GetMapInfo(currentMapID) and C_Map.GetMapInfo(currentMapID).name

    for _, activityID in ipairs(activityIDs) do
        local actInfo = C_LFGList.GetActivityInfoTable(activityID)
        if actInfo and actInfo.mapID then
            local zoneNames = GetInstanceZoneNames(actInfo.mapID)
            if zoneNames then
                if currentZone and zoneNames[currentZone] then return true end
                if currentSubZone and zoneNames[currentSubZone] then return true end
                if currentMapName and zoneNames[currentMapName] then return true end
            end
        end
    end
    return false
end

function LfgService:GetAutoWhisperMessage(resultInfo)
    local _, classFilename = UnitClass("player")
    local className = ENGLISH_CLASS_NAMES[classFilename] or "Player"
    local level = UnitLevel("player") or 0
    local isNear = self:IsPlayerNearActivity(resultInfo and resultInfo.activityIDs)

    if isNear then
        return string.format("Hi! Lvl %d %s. Already near dungeon, inv please!", level, className)
    else
        return string.format("Hi! Lvl %d %s, inv please!", level, className)
    end
end

-- =========================================================================
-- STATE
-- =========================================================================
LfgService.state = {
    roles = { TANK = true, HEALER = true, DAMAGER = true },
    classes = {},
    languages = {},
    langMode = "ALL", -- "ALL" or "CUSTOM"
    sortNear = true,
    sortFriends = true,
    sortLevel = true,
    panelShown = true,
}
for _, c in ipairs(CLASSES) do
    LfgService.state.classes[c] = true
end
for _, code in ipairs(ALL_LANG_CODES) do
    LfgService.state.languages[code] = true
end

function LfgService:IsEnabled()
    local profile = ns.Core.Repository and ns.Core.Repository:GetProfile()
    return profile and profile.modules and profile.modules.lfg and profile.modules.lfg.enabled == true
end

function LfgService:GetClientLocale()
    local locale = GetLocale()
    if locale == "enGB" then return "enUS" end
    return locale
end

function LfgService:GetAvailableLanguages()
    if self.availableLanguages then return self.availableLanguages end

    local region = GetCurrentRegion and GetCurrentRegion() or 3
    local allowedList = REGION_LANGUAGES[region] or REGION_LANGUAGES[3]

    local langs = {}
    local seen = {}
    local clientLocale = self:GetClientLocale()

    for _, code in ipairs(allowedList) do
        if not seen[code] then
            langs[#langs + 1] = code
            seen[code] = true
        end
    end

    if not seen[clientLocale] then
        table.insert(langs, 1, clientLocale)
        seen[clientLocale] = true
    end

    self.availableLanguages = langs
    return self.availableLanguages
end

function LfgService:GetLanguageDisplayName(code)
    local key = LANG_LOCALE_KEYS[code]
    if key and L[key] then
        return L[key]
    end
    local blizzName = _G["LFG_LIST_LANGUAGE_" .. string.upper(code)]
    if type(blizzName) == "string" and blizzName ~= "" then
        return (blizzName:gsub("%s*%b()", ""))
    end
    return code
end

-- =========================================================================
-- FILTERING & SORTING LOGIC (Matching LfgUtils Engine)
-- =========================================================================
local function MatchesRole(memberInfo, isSolo, roleState)
    if isSolo then
        local lfgRoles = memberInfo.lfgRoles
        if not lfgRoles then return false end
        for _, role in ipairs(ROLES) do
            local key = LFG_ROLE_KEYS[role]
            if lfgRoles[key] and roleState[role] then
                return true
            end
        end
        return false
    end

    local role = memberInfo.assignedRole
    return role and LFG_ROLE_KEYS[role] ~= nil and roleState[role] == true
end

local function MatchesMember(memberInfo, isSolo, roleState, classState)
    if not memberInfo then return false end

    -- Class check
    local classFilename = memberInfo.classFilename
    if classFilename and classState[classFilename] == false then
        return false
    end

    -- Role check
    if not MatchesRole(memberInfo, isSolo, roleState) then
        return false
    end

    return true
end

function LfgService:MatchesResult(resultID)
    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info or info.hasSelf then return true end

    local numMembers = info.numMembers or 1
    local isSolo = numMembers == 1

    local foundMember = false
    for memberIndex = 1, numMembers do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
        if memberInfo then
            foundMember = true
            if MatchesMember(memberInfo, isSolo, self.state.roles, self.state.classes) then
                return true
            end
        end
    end

    return not foundMember
end

function LfgService:SortResults(results)
    local contexts = {}
    local blockRanks = { count = 0 }
    for index, resultID in ipairs(results) do
        local info = C_LFGList.GetSearchResultInfo(resultID)
        local block = 0
        if info and not info.hasSelf then
            local bType = (info.numMembers == 1) and "SOLO" or "GROUP"
            if not blockRanks[bType] then
                blockRanks.count = blockRanks.count + 1
                blockRanks[bType] = blockRanks.count
            end
            block = blockRanks[bType]
        end

        contexts[resultID] = {
            block = block,
            index = index,
            isFriend = IsFriendOrGuild(info),
            isNear = info and IsMemberNearActivity(resultID, info) or false,
            level = info and GetMemberLevel(resultID, info) or 0
        }
    end

    table.sort(results, function(a, b)
        local cA = contexts[a]
        local cB = contexts[b]
        if not cA or not cB then return a < b end

        -- 0. CRITICAL: Never mix Groups and Solo Players! Blizzard creates a new divider on each type change!
        if cA.block ~= cB.block then
            return cA.block < cB.block
        end

        -- 1. Friends & Guild
        if LfgService.state.sortFriends and cA.isFriend ~= cB.isFriend then
            return cA.isFriend
        end

        -- 2. Near dungeon
        if LfgService.state.sortNear and cA.isNear ~= cB.isNear then
            return cA.isNear
        end

        -- 3. Level (high to low)
        if LfgService.state.sortLevel and cA.level ~= cB.level then
            return cA.level > cB.level
        end

        return cA.index < cB.index
    end)
end

function LfgService:ApplyFilters(frame)
    if not self:IsEnabled() then return end
    if not frame then return end
    if not self.unfilteredResults or #self.unfilteredResults == 0 then
        local raw = frame.results or {}
        if #raw > 0 then
            self.unfilteredResults = {}
            for i, v in ipairs(raw) do
                self.unfilteredResults[i] = v
            end
        end
    end
    if not self.unfilteredResults or #self.unfilteredResults == 0 then return end
    self.isFiltering = true

    local filtered = {}
    for _, resultID in ipairs(self.unfilteredResults) do
        if self:MatchesResult(resultID) then
            filtered[#filtered + 1] = resultID
        end
    end

    self:SortResults(filtered)

    if frame.results then
        table.wipe(frame.results)
        for i, id in ipairs(filtered) do
            frame.results[i] = id
        end
    else
        frame.results = filtered
    end
    frame.totalResults = #filtered
    frame:UpdateResults()

    self.isFiltering = false
end

-- =========================================================================
-- SEARCH TRIGGER (Multi-language handling matching LfgUtils)
-- =========================================================================
function LfgService:BuildLanguageFilter()
    local available = self:GetAvailableLanguages()
    if self.state.langMode == "ALL" then
        local filter = {}
        for _, code in ipairs(available) do
            filter[code] = true
        end
        return filter
    end

    local filter = {}
    local any = false
    local clientLocale = self:GetClientLocale()
    for _, code in ipairs(available) do
        if code == clientLocale or self.state.languages[code] then
            filter[code] = true
            any = true
        end
    end
    if not any then
        filter[clientLocale] = true
    end
    return filter
end

local function IsActivityInLevelRange(activityID, playerLevel)
    local info = C_LFGList.GetActivityInfoTable(activityID)
    if not info then return true end
    if (info.minLevelSuggestion or 0) > 0 and info.minLevelSuggestion > playerLevel then return false end
    if (info.maxLevelSuggestion or 0) > 0 and info.maxLevelSuggestion < playerLevel then return false end
    return true
end

function LfgService:GetActivities(categoryID)
    local activities = {}
    local dropdown = LFGBrowseFrame and LFGBrowseFrame.ActivityDropdown
    for _, activityID in ipairs(dropdown and dropdown.selectedValues or {}) do
        activities[#activities + 1] = activityID
    end
    if #activities > 0 then return activities end

    local ignoreLevel = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("disableSuggestedLevelActivityFilter")
    local listed = {}
    local entry = C_LFGList.GetActiveEntryInfo()
    for _, activityID in ipairs(entry and entry.activityIDs or {}) do
        listed[activityID] = true
    end

    local playerLevel = UnitLevel("player")
    for _, activityID in ipairs(C_LFGList.GetAvailableActivities(categoryID) or {}) do
        if ignoreLevel or listed[activityID] or IsActivityInLevelRange(activityID, playerLevel) then
            activities[#activities + 1] = activityID
        end
    end
    return activities
end

function LfgService:DoSearch()
    if not self:IsEnabled() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not LFGBrowseFrame or not LFGBrowseFrame:IsVisible() then return end
    local categoryDropdown = LFGBrowseFrame.CategoryDropdown
    if not categoryDropdown then return end
    local categoryID = 0
    if categoryDropdown.GetValue then
        local ok, val = pcall(categoryDropdown.GetValue, categoryDropdown)
        if ok and type(val) == "number" then categoryID = val end
    end
    if categoryID <= 0 and categoryDropdown.selectedValue then
        categoryID = categoryDropdown.selectedValue or 0
    end
    if categoryID <= 0 then return end

    local activities = self:GetActivities(categoryID)
    local langFilter = self:BuildLanguageFilter()

    pcall(C_LFGList.Search, categoryID, 0, 0, langFilter, false, nil, activities)
end

-- =========================================================================
-- ROW DECORATION (Variant 3: DF Squircle Chip Action Button & Zone line)
-- =========================================================================
local CHIP_BORDER_NORMAL = { r = 0.38, g = 0.32, b = 0.22, a = 0.90 }
local CHIP_BORDER_HOVER  = { r = 1.00, g = 0.82, b = 0.20, a = 1.00 }
local CHIP_BG_NORMAL     = { r = 0.12, g = 0.10, b = 0.09, a = 0.85 }
local CHIP_BG_HOVER      = { r = 0.20, g = 0.17, b = 0.14, a = 0.95 }

local function UpdateChipGlyphColor(btn, r, g, b, a)
    if btn.PlusIcon and btn.PlusIcon:IsShown() then
        btn.PlusIcon:SetVertexColor(r, g, b, a)
    end
    if btn.PlusH and btn.PlusH:IsShown() then
        btn.PlusH:SetColorTexture(r, g, b, a)
        btn.PlusV:SetColorTexture(r, g, b, a)
    end
    if btn.Chevron and btn.Chevron:IsShown() then
        btn.Chevron:SetVertexColor(r, g, b, a)
    end
    if btn.ChevronText and btn.ChevronText:IsShown() then
        btn.ChevronText:SetTextColor(r, g, b, a)
    end
end

local function SetupDfChipButton(btn, isSolo)
    btn:SetSize(22, 22)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    btn:SetBackdropColor(CHIP_BG_NORMAL.r, CHIP_BG_NORMAL.g, CHIP_BG_NORMAL.b, CHIP_BG_NORMAL.a)
    btn:SetBackdropBorderColor(CHIP_BORDER_NORMAL.r, CHIP_BORDER_NORMAL.g, CHIP_BORDER_NORMAL.b, CHIP_BORDER_NORMAL.a)

    -- Hide old components if any
    if btn.Text then btn.Text:Hide() end
    if btn.Icon then btn.Icon:Hide() end
    if btn.PlusH then btn.PlusH:Hide() end
    if btn.PlusV then btn.PlusV:Hide() end

    -- 1. Sharp texture icon "+" for Solo invites (custom TGA with fallback)
    if not btn.PlusIcon then
        local plus = btn:CreateTexture(nil, "ARTWORK")
        plus:SetSize(16, 16)
        plus:SetPoint("CENTER", 0, 0)
        plus:SetTexture("Interface\\AddOns\\AikoQoL\\Media\\plus.tga")
        if not plus:GetTexture() then
            -- Fallback if client was running when TGA was added
            local ok = pcall(plus.SetAtlas, plus, "Garr_Building-AddFollowerPlus")
            if not ok or not plus:GetTexture() then
                plus:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
            end
        end
        btn.PlusIcon = plus
    end

    -- 2. Sharp modern forward chevron ">" for Group whispers
    if not btn.Chevron and not btn.ChevronText then
        local chevron = btn:CreateTexture(nil, "ARTWORK")
        chevron:SetSize(8, 12)
        chevron:SetPoint("CENTER", 0.5, 0)
        local ok = pcall(chevron.SetAtlas, chevron, "common-icon-forwardarrow", false)
        if ok and chevron:GetTexture() then
            btn.Chevron = chevron
        else
            chevron:Hide()
            local txt = btn:CreateFontString(nil, "ARTWORK")
            txt:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
            txt:SetShadowOffset(0, 0)
            txt:SetPoint("CENTER", 0.5, 0)
            txt:SetText(">")
            btn.ChevronText = txt
        end
    end

    if isSolo then
        btn.PlusIcon:Show()
        if btn.Chevron then btn.Chevron:Hide() end
        if btn.ChevronText then btn.ChevronText:Hide() end
    else
        btn.PlusIcon:Hide()
        if btn.Chevron then btn.Chevron:Show() end
        if btn.ChevronText then btn.ChevronText:Show() end
    end

    UpdateChipGlyphColor(btn, 1.0, 0.82, 0.20, 1.0)
end

local function DecorateRow(row)
    if not LfgService:IsEnabled() then
        if row.AikoInviteButton then row.AikoInviteButton:Hide() end
        if row.AikoZoneText then row.AikoZoneText:Hide() end
        return
    end

    if not row or not row.resultID then
        if row.AikoInviteButton then row.AikoInviteButton:Hide() end
        if row.AikoZoneText then row.AikoZoneText:Hide() end
        return
    end

    local info = C_LFGList.GetSearchResultInfo(row.resultID)
    if not info or info.hasSelf or info.isDelisted then
        if row.AikoInviteButton then row.AikoInviteButton:Hide() end
        if row.AikoZoneText then row.AikoZoneText:Hide() end
        return
    end

    local solo = (info.numMembers or 1) <= 1
    local member = solo and C_LFGList.GetSearchResultPlayerInfo(row.resultID, 1)
        or (C_LFGList.GetSearchResultLeaderInfo and C_LFGList.GetSearchResultLeaderInfo(row.resultID) or C_LFGList.GetSearchResultPlayerInfo(row.resultID, 1))

    -- 1. Compact Action Button (positioned directly to the right of roles)
    if not row.AikoInviteButton then
        local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
        btn:SetSize(22, 22)
        btn:SetPoint("RIGHT", row, "RIGHT", -15, 0)
        btn:SetFrameLevel(row:GetFrameLevel() + 2)

        btn:SetScript("OnEnter", function(selfBtn)
            selfBtn:SetBackdropBorderColor(CHIP_BORDER_HOVER.r, CHIP_BORDER_HOVER.g, CHIP_BORDER_HOVER.b, CHIP_BORDER_HOVER.a)
            selfBtn:SetBackdropColor(CHIP_BG_HOVER.r, CHIP_BG_HOVER.g, CHIP_BG_HOVER.b, CHIP_BG_HOVER.a)
            UpdateChipGlyphColor(selfBtn, 1.0, 0.95, 0.40, 1.0)
            if selfBtn.tooltipText then
                GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                GameTooltip:SetText(selfBtn.tooltipText)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(selfBtn)
            selfBtn:SetBackdropBorderColor(CHIP_BORDER_NORMAL.r, CHIP_BORDER_NORMAL.g, CHIP_BORDER_NORMAL.b, CHIP_BORDER_NORMAL.a)
            selfBtn:SetBackdropColor(CHIP_BG_NORMAL.r, CHIP_BG_NORMAL.g, CHIP_BG_NORMAL.b, CHIP_BG_NORMAL.a)
            UpdateChipGlyphColor(selfBtn, 1.0, 0.82, 0.20, 1.0)
            GameTooltip:Hide()
        end)
        btn:SetScript("OnMouseDown", function(selfBtn)
            if selfBtn:IsEnabled() then
                if selfBtn.PlusIcon and selfBtn.PlusIcon:IsShown() then
                    selfBtn.PlusIcon:SetPoint("CENTER", 0, -1)
                end
                if selfBtn.PlusH and selfBtn.PlusH:IsShown() then
                    selfBtn.PlusH:SetPoint("CENTER", 0, -1)
                    selfBtn.PlusV:SetPoint("CENTER", 0, -1)
                end
                if selfBtn.Chevron and selfBtn.Chevron:IsShown() then
                    selfBtn.Chevron:SetPoint("CENTER", 0.5, -1)
                end
                if selfBtn.ChevronText and selfBtn.ChevronText:IsShown() then
                    selfBtn.ChevronText:SetPoint("CENTER", 0.5, -1)
                end
            end
        end)
        btn:SetScript("OnMouseUp", function(selfBtn)
            if selfBtn.PlusIcon and selfBtn.PlusIcon:IsShown() then
                selfBtn.PlusIcon:SetPoint("CENTER", 0, 0)
            end
            if selfBtn.PlusH and selfBtn.PlusH:IsShown() then
                selfBtn.PlusH:SetPoint("CENTER", 0, 0)
                selfBtn.PlusV:SetPoint("CENTER", 0, 0)
            end
            if selfBtn.Chevron and selfBtn.Chevron:IsShown() then
                selfBtn.Chevron:SetPoint("CENTER", 0.5, 0)
            end
            if selfBtn.ChevronText and selfBtn.ChevronText:IsShown() then
                selfBtn.ChevronText:SetPoint("CENTER", 0.5, 0)
            end
        end)
        row.AikoInviteButton = btn
    end

    local btn = row.AikoInviteButton
    SetupDfChipButton(btn, solo)

    if solo then
        btn.tooltipText = L["LFG_BTN_INVITE"] or INVITE or "Invite"
        local _, inviteAction = LFGBrowseUtil_GetInviteActionForResult(row.resultID)
        btn:SetEnabled(inviteAction ~= nil)
        btn:SetScript("OnClick", function()
            local _, inv = LFGBrowseUtil_GetInviteActionForResult(row.resultID)
            if inv then
                inv()
            end
        end)
    else
        btn.tooltipText = (L["LFG_BTN_WHISPER"] or WHISPER or "Whisper") .. "\n|cff888888Shift-Click: Edit before sending|r"
        btn:SetEnabled(true)
        btn:SetScript("OnClick", function()
            local leader = info.leaderName
            if leader and leader ~= "" then
                local profile = ns.Core.Repository and ns.Core.Repository:GetProfile()
                local autoWhisper = profile and profile.modules and profile.modules.lfg and profile.modules.lfg.autoWhisper ~= false
                if autoWhisper then
                    local msg = LfgService:GetAutoWhisperMessage(info)
                    if IsShiftKeyDown() then
                        ChatFrame_OpenChat("/w " .. leader .. " " .. msg)
                    else
                        SendChatMessage(msg, "WHISPER", nil, leader)
                    end
                else
                    ChatFrame_OpenChat("/w " .. leader .. " ")
                end
            end
        end)
    end
    btn:Show()

    -- 2. Zone text line under activity (and hide overlapping Blizzard playstyle text)
    if row.PlayStyle then row.PlayStyle:Hide() end
    if row.Playstyle then row.Playstyle:Hide() end
    if row.PlaystyleText then row.PlaystyleText:Hide() end
    if row.PlaystyleLabel then row.PlaystyleLabel:Hide() end

    if not row.AikoZoneText then
        local zone = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
        if not zone:GetFont() then zone:SetFontObject("GameFontGreen") end
        zone:SetHeight(14)
        zone:SetWordWrap(false)
        zone:SetJustifyH("LEFT")
        row.AikoZoneText = zone
    end

    local area = member and member.areaName
    if area and area ~= "" then
        local prefix = L["LFG_ZONE_PREFIX"] or (solo and "Zone: " or "Leader zone: ")
        row.AikoZoneText:SetText(prefix .. area)
        row.AikoZoneText:ClearAllPoints()
        if row.ActivityName then
            row.AikoZoneText:SetPoint("TOPLEFT", row.ActivityName, "BOTTOMLEFT", 0, -2)
        else
            row.AikoZoneText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 24, 6)
        end
        row.AikoZoneText:Show()
    else
        row.AikoZoneText:Hide()
    end
end

-- =========================================================================
-- SIDE PANEL UI (Delegated to UI/LfgFilterPanel.lua)
-- =========================================================================
function LfgService:CreateSidePanel()
    if self.sidePanel or not LFGParentFrame then return end
    if ns.UI and ns.UI.LfgFilterPanel then
        self.sidePanel = ns.UI.LfgFilterPanel:Create(self)
        self.toggleButton = ns.UI.LfgFilterPanel.toggleButton
    end
end

-- =========================================================================
-- DIVIDER COLLAPSE STATE PRESERVATION (Groups / Players)
-- =========================================================================
local function GetDividerKey(dividerType)
    return "BROWSE_COLLAPSED_" .. tostring(dividerType)
end

local function UpdateDividerIcons(button, collapsed)
    if button.ExpandIcon then button.ExpandIcon:SetShown(collapsed) end
    if button.CollapseIcon then button.CollapseIcon:SetShown(not collapsed) end
end

local function OnDividerClick(button)
    local node = button.GetElementData and button:GetElementData()
    local data = node and node.GetData and node:GetData()
    if not data or not data.dividerType then return end
    LfgService.state[GetDividerKey(data.dividerType)] = (node:IsCollapsed() == true)
end

local function OnBrowseFrameInitialized(_, button, node)
    local data = node and node.GetData and node:GetData()
    if not data or not data.dividerType then return end
    button:HookScript("OnClick", OnDividerClick)
    UpdateDividerIcons(button, node:IsCollapsed() == true)
end

local function SaveDividerStates(dataProvider)
    if not dataProvider or not dataProvider.GetChildrenNodes then return end
    for _, node in ipairs(dataProvider:GetChildrenNodes()) do
        local data = node:GetData()
        if data and data.dividerType then
            LfgService.state[GetDividerKey(data.dividerType)] = (node:IsCollapsed() == true)
        end
    end
end

local function RestoreDividerStates(frame)
    if InCombatLockdown and InCombatLockdown() then return end
    local dataProvider = frame.ScrollBox and frame.ScrollBox:GetDataProvider()
    if not dataProvider or not dataProvider.GetChildrenNodes then return end

    local changed = false
    for _, node in ipairs(dataProvider:GetChildrenNodes()) do
        local data = node:GetData()
        if data and data.dividerType and LfgService.state[GetDividerKey(data.dividerType)] == true and not node:IsCollapsed() then
            node:SetCollapsed(true, false, true)
            changed = true
        end
    end

    if not changed then return end
    dataProvider:Invalidate()
    frame.ScrollBox:ForEachFrame(function(button, node)
        local data = node and node.GetData and node:GetData()
        if data and data.dividerType then
            UpdateDividerIcons(button, node:IsCollapsed() == true)
        end
    end)
end

local function HookDividers(frame)
    local view = frame.ScrollBox and frame.ScrollBox:GetView()
    if not view or not view.RegisterCallback or not ScrollBoxListViewMixin then return end
    view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, OnBrowseFrameInitialized, LfgService)
    hooksecurefunc(frame, "UpdateResults", RestoreDividerStates)
end

-- =========================================================================
-- HOOKS & LIFECYCLE
-- =========================================================================
function LfgService:HookLFG()
    if self.hooked then return end
    if not LFGBrowseFrame or not LFGParentFrame then return end
    self.hooked = true

    self:CreateSidePanel()
    HookDividers(LFGBrowseFrame)

    -- 1. Decorate search rows (Action button + Zone text)
    hooksecurefunc("LFGBrowseSearchEntry_Update", function(row)
        DecorateRow(row)
    end)

    -- 2. Intercept result list for role/class filtering & multi-tier sorting
    hooksecurefunc(LFGBrowseFrame, "UpdateResultList", function(frame)
        if not LfgService:IsEnabled() then return end
        if self.isFiltering then return end
        local raw = frame.results or {}
        self.unfilteredResults = {}
        for i, v in ipairs(raw) do
            self.unfilteredResults[i] = v
        end
        self:ApplyFilters(frame)
    end)

    -- 3. Visibility sync with LFGParentFrame & LFGBrowseFrame
    local function SyncPanelVisibility()
        LfgService:UpdateState()
    end

    LFGParentFrame:HookScript("OnShow", SyncPanelVisibility)
    LFGParentFrame:HookScript("OnHide", function()
        if LfgService.sidePanel then LfgService.sidePanel:Hide() end
        if LfgService.toggleButton then LfgService.toggleButton:Hide() end
    end)
    if LFGBrowseFrame then
        LFGBrowseFrame:HookScript("OnShow", SyncPanelVisibility)
        LFGBrowseFrame:HookScript("OnHide", function()
            if LfgService.sidePanel then LfgService.sidePanel:Hide() end
            if LfgService.toggleButton then LfgService.toggleButton:Hide() end
        end)
    end
end

function LfgService:UpdateState()
    if not self.hooked then return end
    local enabled = self:IsEnabled()
    local lfgShown = LFGParentFrame and LFGParentFrame:IsShown() and (not LFGBrowseFrame or LFGBrowseFrame:IsShown())
    if self.sidePanel then
        self.sidePanel:SetShown(lfgShown and enabled and self.state.panelShown)
    end
    if self.toggleButton then
        self.toggleButton:SetShown(lfgShown and enabled)
    end
    if LFGBrowseFrame and LFGBrowseFrame:IsShown() and LFGBrowseFrame.ScrollBox and LFGBrowseFrame.ScrollBox.ForEachFrame then
        LFGBrowseFrame.ScrollBox:ForEachFrame(function(row)
            if row.AikoInviteButton then
                row.AikoInviteButton:SetShown(enabled and not not row.resultID)
            end
            if row.AikoZoneText then
                row.AikoZoneText:SetShown(enabled and not not row.resultID)
            end
        end)
    end
end

function LfgService:Init()
    if self.initialized then return end
    self.initialized = true

    if LFGBrowseFrame and LFGParentFrame then
        self:HookLFG()
        return
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(frame, event, arg1)
        if event == "PLAYER_LOGIN" or arg1 == "Blizzard_GroupFinder_VanillaStyle" or arg1 == addonName then
            if LFGBrowseFrame and LFGParentFrame then
                LfgService:HookLFG()
                frame:UnregisterAllEvents()
            end
        end
    end)
end
