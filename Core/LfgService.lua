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

local DUNGEON_NAME_AREAS = {
    ["The Drowned City"] = {33},
    ["City of Dalaran"] = {36, 130, 267},
    ["Hall of Thanes"] = {1, 1537},
    ["The Hall of Thanes"] = {1, 1537},
    ["Ruins of Lordaeron"] = {85, 1497},
    ["The Ruins of Lordaeron"] = {85, 1497},
    ["Excavation Site: Wetlands"] = {11},
    ["Krol'dok Stronghold"] = {44, 2548},
    ["Alcaz Prison"] = {15},
    ["Blackmaw Hold"] = {16},
    ["Shaper's Terrace"] = {490},
    ["The Shaper's Terrace"] = {490},
}

local instanceZoneNamesCache = {}
local function GetInstanceZoneNames(mapID, actName)
    local cacheKey = tostring(mapID or 0) .. "_" .. tostring(actName or "")
    if instanceZoneNamesCache[cacheKey] then return instanceZoneNamesCache[cacheKey] end
    local names = {}
    local instanceName = (mapID and mapID > 0 and GetRealZoneText) and GetRealZoneText(mapID)
    if instanceName and instanceName ~= "" then names[instanceName] = true end
    local areaIDs = (mapID and INSTANCE_ZONE_AREAS[mapID]) or (actName and DUNGEON_NAME_AREAS[actName])
    if areaIDs then
        for _, areaID in ipairs(areaIDs) do
            local areaName = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areaID)
            if areaName and areaName ~= "" then names[areaName] = true end
        end
    end
    instanceZoneNamesCache[cacheKey] = names
    return names
end

local function IsMemberNearActivity(resultID, resultInfo)
    if not resultInfo or resultInfo.hasSelf then return false end
    local zoneNames = {}
    local hasZone = false
    for _, activityID in ipairs(resultInfo.activityIDs or {}) do
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
        local names = activityInfo and GetInstanceZoneNames(activityInfo.mapID, activityInfo.shortName or activityInfo.fullName)
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
function LfgService:IsMemberNearActivity(resultID, resultInfo)
    return IsMemberNearActivity(resultID, resultInfo)
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

local CLASS_SPEC_NAMES = {
    WARRIOR = { "Arms", "Fury", "Prot" },
    PALADIN = { "Holy", "Prot", "Ret" },
    HUNTER = { "BM", "MM", "Surv" },
    ROGUE = { "Assassination", "Combat", "Sub" },
    PRIEST = { "Disc", "Holy", "Shadow" },
    SHAMAN = { "Ele", "Enh", "Resto" },
    MAGE = { "Arcane", "Fire", "Frost" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" },
    DRUID = { "Balance", "Feral", "Resto" },
}

function LfgService:GetPlayerSpecName(classFilename)
    if not classFilename then return nil end
    local specNames = CLASS_SPEC_NAMES[classFilename]
    if not specNames then return nil end

    local bestIndex, bestSpent = nil, 0

    -- Modern client / Project Epoch C_Traits API
    if C_SpecializationInfo and C_Traits then
        local specGroup = C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup()
        local configID = specGroup and C_SpecializationInfo.GetCombatConfigIDForSpecGroup and C_SpecializationInfo.GetCombatConfigIDForSpecGroup(specGroup)
        local configInfo = configID and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID)
        local treeID = configInfo and configInfo.treeIDs and configInfo.treeIDs[1]
        local displayInfos = treeID and C_Traits.GetGroupDisplayInfoByTreeID and C_Traits.GetGroupDisplayInfoByTreeID(treeID)

        if displayInfos and #displayInfos > 0 then
            local groupIDs = {}
            for _, info in ipairs(displayInfos) do
                groupIDs[#groupIDs + 1] = info.groupID
            end

            local spentByGroup = {}
            local currencies = C_Traits.GetGroupCurrencyInfo and C_Traits.GetGroupCurrencyInfo(configID, groupIDs)
            if currencies then
                for _, groupInfo in ipairs(currencies) do
                    local currencyInfo = groupInfo.currencyInfos and groupInfo.currencyInfos[1]
                    if currencyInfo and groupInfo.traitNodeGroupID then
                        spentByGroup[groupInfo.traitNodeGroupID] = currencyInfo.spent or 0
                    end
                end
            end

            local trees = {}
            for _, info in ipairs(displayInfos) do
                trees[#trees + 1] = {
                    orderIndex = info.orderIndex or 0,
                    spent = spentByGroup[info.groupID] or 0,
                }
            end
            table.sort(trees, function(a, b) return a.orderIndex < b.orderIndex end)

            for i, tree in ipairs(trees) do
                if tree.spent > bestSpent then
                    bestIndex, bestSpent = i, tree.spent
                end
            end
        end
    end

    -- Classic / fallback talent API
    if not bestIndex and GetNumTalentTabs and GetTalentTabInfo then
        local numTabs = GetNumTalentTabs()
        if numTabs and numTabs > 0 then
            for i = 1, numTabs do
                local _, _, pointsSpent = GetTalentTabInfo(i)
                if pointsSpent and pointsSpent > bestSpent then
                    bestIndex, bestSpent = i, pointsSpent
                end
            end
        end
    end

    if bestIndex and bestSpent > 0 then
        return specNames[bestIndex]
    end
    return nil
end

function LfgService:IsPlayerNearActivity(activityIDs)
    if not activityIDs then return false end
    local currentZone = GetRealZoneText and GetRealZoneText()
    local currentSubZone = GetSubZoneText and GetSubZoneText()
    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local currentMapName = currentMapID and C_Map.GetMapInfo and C_Map.GetMapInfo(currentMapID) and C_Map.GetMapInfo(currentMapID).name

    for _, activityID in ipairs(activityIDs) do
        local actInfo = C_LFGList.GetActivityInfoTable(activityID)
        if actInfo then
            local zoneNames = GetInstanceZoneNames(actInfo.mapID, actInfo.shortName or actInfo.fullName)
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
    local specName = self:GetPlayerSpecName(classFilename)
    local classDisplay = (specName and specName ~= "") and (specName .. " " .. className) or className
    local level = UnitLevel("player") or 0
    local isNear = self:IsPlayerNearActivity(resultInfo and resultInfo.activityIDs)

    if isNear then
        return string.format("Hi! Lvl %d %s. Already near dungeon, inv please!", level, classDisplay)
    else
        return string.format("Hi! Lvl %d %s, inv please!", level, classDisplay)
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
    if self.availableLanguages and #self.availableLanguages > 0 then
        return self.availableLanguages
    end

    local apiLangs = C_LFGList and C_LFGList.GetAvailableLanguageSearchFilter and C_LFGList.GetAvailableLanguageSearchFilter()
    local isDynamic = type(apiLangs) == "table" and #apiLangs > 0
    local sourceList = isDynamic and apiLangs
    if not sourceList then
        local region = GetCurrentRegion and GetCurrentRegion() or 3
        sourceList = REGION_LANGUAGES[region] or REGION_LANGUAGES[3]
    end

    local langs = {}
    local seen = {}
    local clientLocale = self:GetClientLocale()

    for _, code in ipairs(sourceList) do
        if type(code) == "string" and not seen[code] then
            langs[#langs + 1] = code
            seen[code] = true
        end
    end

    if clientLocale and not seen[clientLocale] then
        table.insert(langs, 1, clientLocale)
        seen[clientLocale] = true
    end

    if isDynamic then
        self.availableLanguages = langs
    end

    return langs
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
    for index, resultID in ipairs(results) do
        local info = C_LFGList.GetSearchResultInfo(resultID)
        local block = 0
        if info and not info.hasSelf then
            block = (info.numMembers and info.numMembers > 1) and 1 or 2
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
    if InCombatLockdown and InCombatLockdown() then return end
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
-- ROW DECORATION (Delegated to UI/LfgRowDecorator.lua)
-- =========================================================================
local function DecorateRow(row)
    if ns.UI and ns.UI.LfgRowDecorator then
        ns.UI.LfgRowDecorator:Decorate(row, LfgService)
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
        if InCombatLockdown and InCombatLockdown() then return end
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
