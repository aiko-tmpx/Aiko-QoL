local addonName, ns = ...

local Controls = {}
ns.UI.SettingsControls = Controls

local Repository = ns.Core.Repository

local function RegisterWidget(registry, kind, widget, moduleKey, path)
    registry.items[#registry.items + 1] = {
        kind = kind,
        widget = widget,
        module = moduleKey,
        path = path,
    }
end

local function ResolveCheckboxTextRegion(checkbox)
    return checkbox.Text or _G[checkbox:GetName() and (checkbox:GetName() .. "Text") or ""]
end

local function CreateCheckbox(parent, label, path, x, y, registry, moduleKey)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", x, y)

    local textRegion = ResolveCheckboxTextRegion(checkbox)
    if textRegion then
        textRegion:SetText(label or "")
        textRegion:SetWidth(260)
        textRegion:SetJustifyH("LEFT")
    end

    checkbox:SetScript("OnClick", function(self)
        Repository:Set(path, self:GetChecked() and true or false)
        ns.Core.App:Update()
        if registry and registry.RefreshAll then registry:RefreshAll() end
    end)

    function checkbox:Refresh()
        self:SetChecked(Repository:Get(path) and true or false)
    end

    function checkbox:SetLogicalEnabled(enabled)
        if enabled then
            self:Enable()
            if textRegion then textRegion:SetTextColor(1, 0.82, 0) end
        else
            self:Disable()
            if textRegion then textRegion:SetTextColor(0.5, 0.5, 0.5) end
        end
    end

    RegisterWidget(registry, "checkbox", checkbox, moduleKey, path)
    return checkbox
end

function Controls:CreateSectionTitle(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

function Controls:CreateDescription(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetNonSpaceWrap(true)
    fs:SetText(text)
    return fs
end

function Controls:CreateHeaderText(parent, text, x, y, registry, moduleKey, template, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    if width then fs:SetWidth(width) end
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    RegisterWidget(registry, "text", fs, moduleKey)
    return fs
end

function Controls:CreateOptimizeButton(parent, label, moduleKey, y, registry)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", 16, y)
    button:SetSize(300, 24)
    button:SetText(label)

    button:SetScript("OnClick", function()
        if moduleKey == "nameplates" then
            Repository:Set("zones.raid.players", true)
            Repository:Set("zones.raid.npcs", false)
            Repository:Set("zones.dungeon.players", true)
            Repository:Set("zones.dungeon.npcs", false)
            Repository:Set("zones.arena.players", false)
            Repository:Set("zones.arena.npcs", false)
            Repository:Set("zones.battleground.players", false)
            Repository:Set("zones.battleground.npcs", false)
            Repository:Set("zones.openWorld.players", true)
            Repository:Set("zones.openWorld.npcs", false)
        elseif moduleKey == "audio" then
            ns.Core.AudioService:ApplyOptimizedDefaults()
        end

        ns.Core.App:Update()
        if registry and registry.RefreshAll then registry:RefreshAll() end
    end)

    function button:Refresh()
        local enabled = Repository:Get("modules." .. moduleKey .. ".enabled") and true or false
        if enabled then self:Enable() else self:Disable() end
    end

    RegisterWidget(registry, "button", button, moduleKey, nil)
    return button
end

function Controls:CreateModuleCheckbox(parent, label, path, y, registry, moduleKey)
    return CreateCheckbox(parent, label, path, 16, y, registry, moduleKey)
end

local function SetCVarValue(cvar, val)
    if type(cvar) == "table" then
        for _, c in ipairs(cvar) do
            if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(c, val) elseif SetCVar then SetCVar(c, val) end
        end
    elseif type(cvar) == "string" then
        if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(cvar, val) elseif SetCVar then SetCVar(cvar, val) end
    end
end

local function GetCVarValue(cvar)
    local primary = type(cvar) == "table" and cvar[1] or cvar
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(primary)
    elseif GetCVar then
        return GetCVar(primary)
    end
end

function Controls:CreateCVarCheckbox(parent, label, cvar, y, registry, moduleKey, tooltipText, inverted, extraCVar, extraValOn, extraValOff)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 16, y)

    local textRegion = ResolveCheckboxTextRegion(checkbox)
    if textRegion then
        textRegion:SetText(label or "")
        textRegion:SetWidth(400)
        textRegion:SetJustifyH("LEFT")
    end

    if tooltipText or label then
        checkbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 380, 0)
            GameTooltip:AddLine(label or "", 1, 1, 1)
            if tooltipText and tooltipText ~= "" then
                GameTooltip:AddLine(tooltipText, 1, 0.82, 0, true)
            end
            GameTooltip:Show()
        end)
        checkbox:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    checkbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        local val
        if inverted then
            val = isChecked and "0" or "1"
        else
            val = isChecked and "1" or "0"
        end
        SetCVarValue(cvar, val)
        if extraCVar then
            SetCVarValue(extraCVar, isChecked and (extraValOn or "1") or (extraValOff or "0"))
        end
        if registry and registry.RefreshAll then registry:RefreshAll() end
    end)

    function checkbox:Refresh()
        local val = GetCVarValue(cvar)
        if inverted then
            self:SetChecked(val == "0")
        else
            self:SetChecked(val == "1")
        end
    end

    function checkbox:SetLogicalEnabled(enabled)
        if enabled then
            self:Enable()
            if textRegion then textRegion:SetTextColor(1, 0.82, 0) end
        else
            self:Disable()
            if textRegion then textRegion:SetTextColor(0.5, 0.5, 0.5) end
        end
    end

    checkbox:Refresh()
    RegisterWidget(registry, "checkbox", checkbox, moduleKey, nil)
    return checkbox
end

function Controls:CreateCVarInput(parent, label, cvar, y, registry, moduleKey, tooltipText, minVal, maxVal)
    local labelFs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelFs:SetPoint("TOPLEFT", 16, y)
    labelFs:SetText(label or "")

    local editbox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editbox:SetPoint("TOPLEFT", 20, y - 22)
    editbox:SetSize(80, 22)
    editbox:SetAutoFocus(false)
    editbox:SetJustifyH("LEFT")

    if tooltipText or label then
        local function ShowTooltip(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label or "", 1, 1, 1)
            if tooltipText and tooltipText ~= "" then
                GameTooltip:AddLine(tooltipText, 1, 0.82, 0, true)
            end
            GameTooltip:Show()
        end
        local function HideTooltip() GameTooltip:Hide() end
        editbox:SetScript("OnEnter", ShowTooltip)
        editbox:SetScript("OnLeave", HideTooltip)
    end

    local isCommitting = false
    local function Commit()
        if isCommitting then return end
        isCommitting = true
        local val = tonumber(editbox:GetText())
        if val then
            if minVal and val < minVal then val = minVal end
            if maxVal and val > maxVal then val = maxVal end
            val = math.floor(val)
            SetCVarValue(cvar, tostring(val))
            editbox:SetText(tostring(val))
        else
            local cur = GetCVarValue(cvar) or "400"
            editbox:SetText(cur)
        end
        editbox:ClearFocus()
        isCommitting = false
        if registry and registry.RefreshAll then registry:RefreshAll() end
    end

    editbox:SetScript("OnEnterPressed", Commit)
    editbox:SetScript("OnEscapePressed", function()
        local cur = GetCVarValue(cvar) or "400"
        editbox:SetText(cur)
        editbox:ClearFocus()
    end)
    editbox:SetScript("OnEditFocusLost", Commit)

    function editbox:Refresh()
        local cur = GetCVarValue(cvar) or "400"
        self:SetText(cur)
    end

    function editbox:SetLogicalEnabled(enabled)
        if enabled then
            self:Enable()
            labelFs:SetTextColor(1, 0.82, 0)
        else
            self:Disable()
            labelFs:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    editbox:Refresh()
    RegisterWidget(registry, "inputControl", editbox, moduleKey, nil)
    return editbox
end

function Controls:CreateInputControl(parent, label, path, y, registry, moduleKey)
    local labelFs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelFs:SetPoint("TOPLEFT", 16, y)
    labelFs:SetText(label or "")

    local editbox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editbox:SetPoint("TOPLEFT", 20, y - 22)
    editbox:SetSize(80, 22)
    editbox:SetAutoFocus(false)
    editbox:SetJustifyH("LEFT")

    local isCommitting = false
    local function Commit()
        if isCommitting then return end
        isCommitting = true
        local val = tonumber(editbox:GetText())
        if val then
            val = math.max(0.30, math.min(1.50, val))
            editbox:SetText(string.format("%.2f", val))
            Repository:Set(path, val)
            ns.Core.App:Update()
        else
            local current = tonumber(Repository:Get(path)) or 0.59
            editbox:SetText(string.format("%.2f", current))
        end
        editbox:ClearFocus()
        isCommitting = false
    end

    editbox:SetScript("OnEnterPressed", Commit)
    editbox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        local current = tonumber(Repository:Get(path)) or 0.59
        self:SetText(string.format("%.2f", current))
    end)

    local container = {
        editbox = editbox,
        labelFs = labelFs,
        Refresh = function(self)
            local current = tonumber(Repository:Get(path)) or 0.59
            self.editbox:SetText(string.format("%.2f", current))
        end,
        SetLogicalEnabled = function(self, enabled)
            if enabled then
                self.editbox:Enable()
                self.labelFs:SetTextColor(1, 0.82, 0)
            else
                self.editbox:Disable()
                self.labelFs:SetTextColor(0.5, 0.5, 0.5)
            end
        end,
    }

    container:Refresh()
    RegisterWidget(registry, "inputControl", container, moduleKey, path)
    return container
end

local dropdownCount = 0
function Controls:CreateDropdownControl(parent, label, path, options, y, registry, moduleKey)
    local labelFs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelFs:SetPoint("TOPLEFT", 16, y)
    labelFs:SetText(label or "")

    dropdownCount = dropdownCount + 1
    local frameName = "AikoQoL_SettingsDropDown_" .. dropdownCount
    local dropdown = CreateFrame("Frame", frameName, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", -2, y - 20)
    UIDropDownMenu_SetWidth(dropdown, 190)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    local function OnSelect(self, optValue, optText)
        Repository:Set(path, optValue)
        UIDropDownMenu_SetSelectedValue(dropdown, optValue)
        UIDropDownMenu_SetText(dropdown, optText)
        ns.Core.App:Update()
        if registry and registry.RefreshAll then registry:RefreshAll() end
    end

    local function InitMenu(self, level)
        local curVal = Repository:Get(path)
        if curVal == nil and options and options[1] then
            curVal = options[1].value
        end
        for _, opt in ipairs(options or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.checked = (opt.value == curVal or tostring(opt.value) == tostring(curVal))
            info.func = function()
                OnSelect(self, opt.value, opt.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, InitMenu)

    local container = {
        dropdown = dropdown,
        labelFs = labelFs,
        Refresh = function(self)
            local current = Repository:Get(path)
            if current == nil and options and options[1] then
                current = options[1].value
            end
            local currentText = ""
            for _, opt in ipairs(options or {}) do
                if opt.value == current or tostring(opt.value) == tostring(current) then
                    currentText = opt.text
                    break
                end
            end
            UIDropDownMenu_SetSelectedValue(dropdown, current)
            UIDropDownMenu_SetText(dropdown, currentText)
        end,
        SetLogicalEnabled = function(self, enabled)
            if enabled then
                UIDropDownMenu_EnableDropDown(dropdown)
                self.labelFs:SetTextColor(1, 0.82, 0)
            else
                UIDropDownMenu_DisableDropDown(dropdown)
                self.labelFs:SetTextColor(0.5, 0.5, 0.5)
            end
        end,
    }

    container:Refresh()
    RegisterWidget(registry, "dropdown", container, moduleKey, path)
    return container
end

function Controls:CreateLootActionRow(parent, y, registry, moduleKey)
    local LootService = ns.Core.LootService
    local L = ns.Locales or {}

    local btn1 = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn1:SetPoint("TOPLEFT", 16, y)
    btn1:SetSize(126, 24)
    btn1:SetText(L["LOOT_UNLOCK_POS"] or "Unlock Position")

    btn1:SetScript("OnClick", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        if LootService and LootService.ToggleAnchor then
            local isUnlocked = LootService:ToggleAnchor()
            self:SetText(isUnlocked and (L["LOOT_LOCK_POS"] or "Lock Position") or (L["LOOT_UNLOCK_POS"] or "Unlock Position"))
        end
    end)

    function btn1:Refresh()
        local isUnlocked = LootService and LootService.IsAnchorUnlocked and LootService:IsAnchorUnlocked()
        self:SetText(isUnlocked and (L["LOOT_LOCK_POS"] or "Lock Position") or (L["LOOT_UNLOCK_POS"] or "Unlock Position"))
        if InCombatLockdown and InCombatLockdown() then
            self:Disable()
        end
    end

    btn1:RegisterEvent("PLAYER_REGEN_DISABLED")
    btn1:RegisterEvent("PLAYER_REGEN_ENABLED")
    btn1:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:SetText(L["LOOT_UNLOCK_POS"] or "Unlock Position")
            self:Disable()
        elseif event == "PLAYER_REGEN_ENABLED" then
            local isModuleEnabled = Repository:Get("modules.loot.enabled")
            if isModuleEnabled then
                self:Enable()
            end
            self:Refresh()
        end
    end)

    local btn2 = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn2:SetPoint("TOPLEFT", 150, y)
    btn2:SetSize(126, 24)
    btn2:SetText(L["LOOT_TEST_TOAST"] or "Test Toast")

    btn2:SetScript("OnClick", function()
        if LootService and LootService.SpawnTestToast then
            LootService:SpawnTestToast()
        end
    end)

    RegisterWidget(registry, "button", btn1, moduleKey, nil)
    RegisterWidget(registry, "button", btn2, moduleKey, nil)
end

function Controls:BuildZoneHeader(parent, y, registry)
    self:CreateHeaderText(parent, ns.L["ZONE"], 16, y, registry, "nameplates")
    self:CreateHeaderText(parent, ns.L["PLAYERS"], 250, y, registry, "nameplates")
    self:CreateHeaderText(parent, ns.L["NPCS"], 360, y, registry, "nameplates")
end

function Controls:BuildZoneRow(parent, label, pathBase, y, registry)
    self:CreateHeaderText(parent, label, 16, y - 4, registry, "nameplates", "GameFontHighlight", 180)
    CreateCheckbox(parent, "", pathBase .. ".players", 255, y, registry, "nameplates")
    CreateCheckbox(parent, "", pathBase .. ".npcs", 365, y, registry, "nameplates")
end

function Controls:BuildAudioMatrix(parent, y, registry)
    local L = ns.L
    local zoneDefs = {
        { key = "raid", label = L["RAID"] },
        { key = "dungeon", label = L["DUNGEON"] },
        { key = "arena", label = L["ARENA"] },
        { key = "battleground", label = L["BG"] },
        { key = "openWorld", label = L["OPEN_WORLD"] },
    }
    local channels = {
        { key = "music", label = L["MUSIC"] },
        { key = "effects", label = L["EFFECTS"] },
        { key = "ambience", label = L["AMBIENCE"] },
        { key = "dialog", label = L["DIALOG"] },
    }

    self:CreateHeaderText(parent, L["CHANNEL"], 16, y, registry, "audio", "GameFontNormal", 100)
    local startX, stepX = 128, 74
    for i, zone in ipairs(zoneDefs) do
        self:CreateHeaderText(parent, zone.label, startX + ((i - 1) * stepX), y, registry, "audio", "GameFontNormalSmall", 68)
    end

    y = y - 28
    for _, channel in ipairs(channels) do
        self:CreateHeaderText(parent, channel.label, 16, y - 4, registry, "audio", "GameFontHighlight", 100)
        for i, zone in ipairs(zoneDefs) do
            CreateCheckbox(parent, "", string.format("audio.enabledRules.%s.%s", channel.key, zone.key), startX + ((i - 1) * stepX), y, registry, "audio")
        end
        y = y - 32
    end

    return y
end

function Controls:ApplyModuleStates(registry)
    local nameplatesEnabled = Repository:Get("modules.nameplates.enabled") and true or false
    local audioEnabled = Repository:Get("modules.audio.enabled") and true or false
    local tooltipEnabled = Repository:Get("modules.tooltip.enabled") and true or false
    local chatEnabled = Repository:Get("modules.chat.enabled") and true or false
    local scaleEnabled = Repository:Get("modules.scale.enabled") and true or false
    local lfgEnabled = Repository:Get("modules.lfg.enabled") and true or false
    local lootEnabled = Repository:Get("modules.loot.enabled") and true or false

    for _, item in ipairs(registry.items) do
        local enabled = true
        if item.module == "nameplates" and item.path ~= "modules.nameplates.enabled" then
            enabled = nameplatesEnabled
        elseif item.module == "audio" and item.path ~= "modules.audio.enabled" then
            enabled = audioEnabled
        elseif item.module == "tooltip" and item.path ~= "modules.tooltip.enabled" then
            enabled = tooltipEnabled
        elseif item.module == "chat" and item.path ~= "modules.chat.enabled" then
            enabled = chatEnabled
        elseif item.module == "scale" and item.path ~= "modules.scale.enabled" then
            enabled = scaleEnabled
        elseif item.module == "lfg" and item.path ~= "modules.lfg.enabled" then
            enabled = lfgEnabled
        elseif item.module == "loot" and item.path ~= "modules.loot.enabled" then
            enabled = lootEnabled
        end

        if item.kind == "checkbox" then
            item.widget:SetLogicalEnabled(enabled)
        elseif item.kind == "inputControl" then
            item.widget:SetLogicalEnabled(enabled)
        elseif item.kind == "dropdown" then
            item.widget:SetLogicalEnabled(enabled)
        elseif item.kind == "text" then
            item.widget:SetTextColor(enabled and 1 or 0.5, enabled and 0.82 or 0.5, 0)
        elseif item.kind == "button" then
            if enabled then item.widget:Enable() else item.widget:Disable() end
        end
    end
end
