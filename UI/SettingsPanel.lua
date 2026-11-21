local addonName, ns = ...

local SettingsPanel = {}
ns.UI.SettingsPanel = SettingsPanel

local Controls = ns.UI.SettingsControls
local Descriptors = ns.UI.SettingsDescriptors

function SettingsPanel:CreateRegistry()
    return {
        items = {},
        RefreshAll = function(self)
            for _, item in ipairs(self.items) do
                if item.widget.Refresh then item.widget:Refresh() end
            end
            Controls:ApplyModuleStates(self)
        end,
    }
end

function SettingsPanel:CreateCanvas(name)
    local canvas = CreateFrame("Frame")
    canvas.name = name
    canvas:Hide()
    return canvas
end

function SettingsPanel:CreateScrollContainer(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(680, 1)
    scrollFrame:SetScrollChild(content)

    parent.scrollFrame = scrollFrame
    parent.content = content
    return content
end

function SettingsPanel:BuildControl(parent, moduleKey, control, y, registry)
    if control.type == "checkbox" then
        Controls:CreateModuleCheckbox(parent, control.label, control.path, y, registry, moduleKey)
        return y - 30
    end
    if control.type == "cvarCheckbox" then
        Controls:CreateCVarCheckbox(parent, control.label, control.cvar, y, registry, moduleKey, control.tooltip, control.inverted, control.extraCVar, control.extraValOn, control.extraValOff)
        return y - 30
    end
    if control.type == "cvarInput" then
        Controls:CreateCVarInput(parent, control.label, control.cvar, y, registry, moduleKey, control.tooltip, control.min, control.max)
        return y - 52
    end
    if control.type == "sectionHeader" then
        Controls:CreateHeaderText(parent, control.label, 16, y, registry, moduleKey, "GameFontNormalLarge")
        return y - 28
    end
    if control.type == "optimizeButton" then
        Controls:CreateOptimizeButton(parent, control.label, moduleKey, y, registry)
        return y - 34
    end
    if control.type == "input" then
        Controls:CreateInputControl(parent, control.label, control.path, y, registry, moduleKey, control)
        return y - 48
    end
    if control.type == "dropdown" then
        Controls:CreateDropdownControl(parent, control.label, control.path, control.options, y, registry, moduleKey)
        return y - 56
    end
    if control.type == "lootActionRow" then
        Controls:CreateLootActionRow(parent, y, registry, moduleKey)
        return y - 36
    end
    if control.type == "spacer" then
        return y - (control.height or 16)
    end
    if control.type == "headerRow" then
        Controls:BuildZoneHeader(parent, y, registry)
        return y - 28
    end
    if control.type == "zoneRow" then
        Controls:BuildZoneRow(parent, control.label, control.pathBase, y, registry)
        return y - 32
    end
    if control.type == "audioMatrix" then
        return Controls:BuildAudioMatrix(parent, y, registry)
    end
    return y
end

function SettingsPanel:BuildSubPanel(moduleKey, descriptor)
    local panel = self:CreateCanvas(descriptor.title)
    local content = self:CreateScrollContainer(panel)
    local registry = self:CreateRegistry()

    Controls:CreateSectionTitle(content, descriptor.title, 16, -16)
    local descFs = Controls:CreateDescription(content, descriptor.description, 16, -44, 620)

    local descH = descFs and descFs.GetStringHeight and descFs:GetStringHeight() or 36
    local y = math.min(-84, -44 - descH - 14)
    for _, control in ipairs(descriptor.controls) do
        y = self:BuildControl(content, moduleKey, control, y, registry)
    end

    content:SetHeight(math.abs(y) + 40)
    panel.refresh = function() registry:RefreshAll() end
    panel.registry = registry
    registry:RefreshAll()
    return panel
end

function SettingsPanel:RegisterLegacy(root, children, orderedKeys)
    InterfaceOptions_AddCategory(root)
    for _, key in ipairs(orderedKeys or {}) do
        local panel = children[key]
        if panel then
            panel.parent = root.name
            InterfaceOptions_AddCategory(panel)
        end
    end
end

function SettingsPanel:RegisterModern(root, children, orderedKeys)
    local rootCategory = Settings.RegisterCanvasLayoutCategory(root, root.name, root.name)
    Settings.RegisterAddOnCategory(rootCategory)
    self.rootCategory = rootCategory

    self.categories = {}
    for _, key in ipairs(orderedKeys or {}) do
        local panel = children[key]
        if panel then
            local category = Settings.RegisterCanvasLayoutSubcategory(rootCategory, panel, panel.name, panel.name)
            Settings.RegisterAddOnCategory(category)
            self.categories[key] = category
        end
    end
end

function SettingsPanel:Register()
    if self.isRegistered then return end

    local root = self:CreateCanvas(ns.L["ADDON_NAME"])

    local title = root:CreateFontString(nil, "ARTWORK", "QuestTitleFont")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns.L["ADDON_NAME"])
    title:SetTextColor(1, 0.82, 0)

    local subtitle = root:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    subtitle:SetPoint("TOPLEFT", 16, -52)
    subtitle:SetText(ns.L["ROOT_SUBTITLE"])
    subtitle:SetTextColor(1, 0.82, 0)

    local description = root:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 16, -84)
    description:SetWidth(650)
    description:SetJustifyH("LEFT")
    description:SetText(ns.L["ROOT_DESC"])

    local discord = root:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    discord:SetPoint("TOPLEFT", 16, -154)
    discord:SetText(ns.L["DISCORD_TAG"])
    discord:SetTextColor(0.64, 0.19, 0.79)

    local hint = root:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    hint:SetPoint("TOPLEFT", 16, -194)
    hint:SetWidth(650)
    hint:SetJustifyH("LEFT")
    hint:SetText(ns.L["ROOT_HINT"])

    root.refresh = function() end

    local panels = {
        nameplates = self:BuildSubPanel("nameplates", Descriptors.nameplates),
        audio = self:BuildSubPanel("audio", Descriptors.audio),
        tooltip = self:BuildSubPanel("tooltip", Descriptors.tooltip),
        chat = self:BuildSubPanel("chat", Descriptors.chat),
        scale = self:BuildSubPanel("scale", Descriptors.scale),
    }

    if Descriptors.tweaks then
        panels.tweaks = self:BuildSubPanel("tweaks", Descriptors.tweaks)
    end

    if Descriptors.lfg and (select(4, GetBuildInfo()) == 16001 or ns.IsDev) then
        panels.lfg = self:BuildSubPanel("lfg", Descriptors.lfg)
    end
    if Descriptors.loot and (select(4, GetBuildInfo()) == 16001 or ns.IsDev) then
        panels.loot = self:BuildSubPanel("loot", Descriptors.loot)
    end

    self.rootPanel = root
    self.panels = panels

    local orderedKeys = {}
    if Descriptors.lfg and (select(4, GetBuildInfo()) == 16001 or ns.IsDev) then
        table.insert(orderedKeys, "lfg")
    end
    if Descriptors.loot and (select(4, GetBuildInfo()) == 16001 or ns.IsDev) then
        table.insert(orderedKeys, "loot")
    end
    table.insert(orderedKeys, "nameplates")
    table.insert(orderedKeys, "tooltip")
    table.insert(orderedKeys, "chat")
    table.insert(orderedKeys, "audio")
    table.insert(orderedKeys, "scale")
    if Descriptors.tweaks then
        table.insert(orderedKeys, "tweaks")
    end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterCanvasLayoutSubcategory and Settings.RegisterAddOnCategory then
        self:RegisterModern(root, panels, orderedKeys)
    elseif InterfaceOptions_AddCategory then
        self:RegisterLegacy(root, panels, orderedKeys)
    end

    self.isRegistered = true
end

function SettingsPanel:Open()
    if InCombatLockdown and InCombatLockdown() then
        print(string.format("|cffA330C9Aiko QoL:|r %s", ns.L["ERR_COMBAT"] or "Settings cannot be opened while in combat."))
        return
    end

    self:Register()

    if Settings and Settings.OpenToCategory and self.rootCategory then
        Settings.OpenToCategory(self.rootCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and self.rootPanel then
        InterfaceOptionsFrame_OpenToCategory(self.rootPanel)
        InterfaceOptionsFrame_OpenToCategory(self.rootPanel)
    end
end

SLASH_AIKOQOL1 = "/aiko"
SLASH_AIKOQOL2 = "/aqol"
SLASH_AIKOQOL3 = "/aikoqol"
SlashCmdList["AIKOQOL"] = function()
    SettingsPanel:Open()
end
