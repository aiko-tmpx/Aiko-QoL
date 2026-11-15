local addonName, ns = ...

-- Gate strictly to WoW Forever (TOC 16001). Leave all other clients untouched.
local _, _, _, tocversion = GetBuildInfo()
if tocversion ~= 16001 and not ns.IsDev then
    return
end

local L = ns.L or {}
local UI = ns.UI or {}
ns.UI = UI

local LfgFilterPanel = {}
UI.LfgFilterPanel = LfgFilterPanel

local ROLES = (ns.LfgData and ns.LfgData.ROLES) or {"TANK", "HEALER", "DAMAGER"}
local CLASSES = (ns.LfgData and ns.LfgData.CLASSES) or {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
local ROLE_ATLASES = (ns.LfgData and ns.LfgData.ROLE_ATLASES) or {}
local ROLE_MICRO_ATLASES = (ns.LfgData and ns.LfgData.ROLE_MICRO_ATLASES) or {}

local ROLE_COLORS = {
    ["TANK"] = { r = 0.25, g = 0.65, b = 1.0 },   -- Blizzard Blue
    ["HEALER"] = { r = 0.25, g = 0.85, b = 0.35 }, -- Blizzard Green
    ["DAMAGER"] = { r = 1.0, g = 0.30, b = 0.25 }  -- Blizzard Red
}

local CLASS_COORDS = CLASS_ICON_TCOORDS or {
    ["WARRIOR"] = {0, 0.25, 0, 0.25},
    ["MAGE"]    = {0.25, 0.49609375, 0, 0.25},
    ["ROGUE"]   = {0.49609375, 0.7421875, 0, 0.25},
    ["DRUID"]   = {0.7421875, 0.98828125, 0, 0.25},
    ["HUNTER"]  = {0, 0.25, 0.25, 0.5},
    ["SHAMAN"]  = {0.25, 0.49609375, 0.25, 0.5},
    ["PRIEST"]  = {0.49609375, 0.7421875, 0.25, 0.5},
    ["WARLOCK"] = {0.7421875, 0.98828125, 0.25, 0.5},
    ["PALADIN"] = {0, 0.25, 0.5, 0.75},
}

-- ---------------------------------------------------------------------------
-- Panel Builder (Spacious 300px Blizz-like Frame)
-- ---------------------------------------------------------------------------
function LfgFilterPanel:Create(service)
    if self.frame or not LFGParentFrame then return self.frame end

    local PANEL_WIDTH = 300

    -- Base Window (ButtonFrameTemplate gives official NineSlice + Inset + CloseButton)
    local panel = CreateFrame("Frame", "AikoLfgFilterPanel", LFGParentFrame, "ButtonFrameTemplate")
    panel:SetWidth(PANEL_WIDTH)
    -- Docked neatly to the right of LFGParentFrame, clearing side tabs
    panel:SetPoint("TOPLEFT", LFGParentFrame, "TOPRIGHT", 53, 0)
    panel:SetPoint("BOTTOMLEFT", LFGParentFrame, "BOTTOMRIGHT", 53, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(LFGParentFrame:GetFrameLevel() + 2)
    panel:Hide()

    -- Title in Header
    if panel.SetTitle then
        panel:SetTitle(L["LFG_PANEL_TITLE"] or "Filters")
    elseif panel.TitleText then
        panel.TitleText:SetText(L["LFG_PANEL_TITLE"] or "Filters")
    end

    -- Portrait Icon in Top-Left Circle (Iconic LFG Eye)
    local portraitTex = "Interface\\Icons\\INV_Misc_Eye_02"
    if panel.SetPortraitToAsset then
        pcall(panel.SetPortraitToAsset, panel, portraitTex)
    end
    if panel.portrait then
        panel.portrait:SetTexture(portraitTex)
    end
    if panel.PortraitContainer and panel.PortraitContainer.portrait then
        panel.PortraitContainer.portrait:SetTexture(portraitTex)
    end

    -- Hook CloseButton
    if panel.CloseButton then
        panel.CloseButton:SetScript("OnClick", function()
            service.state.panelShown = false
            panel:Hide()
        end)
    end

    -- Inset content container
    local inset = panel.Inset or panel

    self.roleButtons = {}
    self.classButtons = {}
    self.checkboxes = {}

    local PAD_X = 14

    -- -----------------------------------------------------------------------
    -- 1. SEARCH LANGUAGES (Sleek Blizz-like Dropdown Selector)
    -- -----------------------------------------------------------------------
    local langHeader = inset:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    if not langHeader:GetFont() then langHeader:SetFontObject("GameFontNormal") end
    langHeader:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD_X, -10)
    langHeader:SetText(L["LFG_LANGUAGES"] or "Search Languages")

    local langBtn = CreateFrame("Button", nil, inset, "BackdropTemplate")
    langBtn:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD_X, -30)
    langBtn:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -PAD_X, -30)
    langBtn:SetHeight(26)
    langBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    langBtn:SetBackdropColor(0.12, 0.11, 0.10, 0.85)
    langBtn:SetBackdropBorderColor(0.42, 0.36, 0.24, 0.9)

    local langLabel = langBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    langLabel:SetPoint("LEFT", langBtn, "LEFT", 10, 0)
    langLabel:SetPoint("RIGHT", langBtn, "RIGHT", -26, 0)
    langLabel:SetJustifyH("LEFT")
    langLabel:SetWordWrap(false)
    langBtn.Text = langLabel

    -- Crisp, authentic dropdown arrow
    local langArrow = langBtn:CreateTexture(nil, "ARTWORK")
    langArrow:SetSize(12, 12)
    langArrow:SetPoint("RIGHT", langBtn, "RIGHT", -8, -3)
    if not langArrow:SetAtlas("uiframe-arrow-dropdown-down") then
        langArrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    end

    langBtn:SetScript("OnEnter", function()
        langBtn:SetBackdropBorderColor(1, 0.82, 0.2, 1)
        langBtn:SetBackdropColor(0.18, 0.16, 0.14, 0.95)
    end)
    langBtn:SetScript("OnLeave", function()
        langBtn:SetBackdropBorderColor(0.42, 0.36, 0.24, 0.9)
        langBtn:SetBackdropColor(0.12, 0.11, 0.10, 0.85)
    end)

    local function UpdateLangBtnLabel()
        local available = service:GetAvailableLanguages()
        if service.state.langMode == "ALL" then
            langLabel:SetText(L["LFG_LANG_ALL"] or "All Languages")
        else
            local count = 0
            for _, code in ipairs(available) do
                if service.state.languages[code] then count = count + 1 end
            end
            if count == #available or count == 0 then
                langLabel:SetText(L["LFG_LANG_ALL"] or "All Languages")
            elseif count == 1 then
                for _, code in ipairs(available) do
                    if service.state.languages[code] then
                        langLabel:SetText(service:GetLanguageDisplayName(code))
                        break
                    end
                end
            else
                langLabel:SetText(string.format("%s (%d)", L["LFG_LANGUAGES"] or "Languages", count))
            end
        end
    end
    self.UpdateLangBtnLabel = UpdateLangBtnLabel
    UpdateLangBtnLabel()

    -- -----------------------------------------------------------------------
    -- Standalone Language Menu (Custom frame to ensure ZERO Blizzard_Menu taint)
    -- -----------------------------------------------------------------------
    local langMenu = CreateFrame("Frame", "AikoLfgLanguageMenu", UIParent, "BackdropTemplate")
    langMenu:SetFrameStrata("DIALOG")
    langMenu:SetClampedToScreen(true)
    langMenu:EnableMouse(true)
    langMenu:SetWidth(182)
    langMenu:Hide()
    langMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    langMenu:SetBackdropColor(0.08, 0.08, 0.12, 0.90)
    langMenu:SetBackdropBorderColor(0.65, 0.55, 0.35, 0.9)

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(langMenu:GetFrameLevel() - 1)
    catcher:SetAllPoints(UIParent)
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnClick", function()
        langMenu:Hide()
    end)
    langMenu:SetScript("OnHide", function()
        catcher:Hide()
    end)
    panel:HookScript("OnHide", function()
        langMenu:Hide()
    end)

    local function CreateMenuItem(parent, yOffset, labelText, isRadio)
        local itemBtn = CreateFrame("Button", nil, parent)
        itemBtn:SetHeight(22)
        itemBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, yOffset)
        itemBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, yOffset)

        local check = itemBtn:CreateTexture(nil, "ARTWORK")
        check:SetSize(16, 16)
        check:SetPoint("LEFT", itemBtn, "LEFT", 4, 0)
        if isRadio then
            check:SetTexture("Interface\\Buttons\\UI-RadioButton")
            check:SetTexCoord(0.25, 0.49, 0, 1)
        else
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        end

        local text = itemBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", itemBtn, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetText(labelText)

        local hl = itemBtn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.5)
        hl:SetAllPoints()

        itemBtn.Check = check
        itemBtn.Text = text
        return itemBtn
    end

    local available = service:GetAvailableLanguages()
    local clientCode = service:GetClientLocale()

    local allBtn = CreateMenuItem(langMenu, -8, L["LFG_LANG_ALL"] or "All Languages", true)
    local clientBtn = CreateMenuItem(langMenu, -30, L["LFG_LANG_CLIENT"] or "Current Client Only", true)

    local mDiv = langMenu:CreateTexture(nil, "ARTWORK")
    mDiv:SetHeight(1)
    mDiv:SetColorTexture(0.45, 0.38, 0.25, 0.6)
    mDiv:SetPoint("TOPLEFT", langMenu, "TOPLEFT", 8, -54)
    mDiv:SetPoint("TOPRIGHT", langMenu, "TOPRIGHT", -8, -54)

    local langCheckButtons = {}
    local curY = -58
    for _, code in ipairs(available) do
        local langText = service:GetLanguageDisplayName(code)
        local btn = CreateMenuItem(langMenu, curY, langText, false)
        langCheckButtons[code] = btn
        curY = curY - 22
    end
    langMenu:SetHeight(-curY + 7)

    local function RefreshMenuVisuals()
        local isAll = (service.state.langMode == "ALL")
        allBtn.Check:SetShown(isAll)

        local isClientOnly = (service.state.langMode == "CUSTOM")
        if isClientOnly then
            for _, code in ipairs(available) do
                if code == clientCode and not service.state.languages[code] then isClientOnly = false break end
                if code ~= clientCode and service.state.languages[code] then isClientOnly = false break end
            end
        end
        clientBtn.Check:SetShown(isClientOnly)

        for _, code in ipairs(available) do
            local btn = langCheckButtons[code]
            if btn then
                local checked = isAll or (service.state.languages[code] == true)
                btn.Check:SetShown(checked)
            end
        end
    end

    allBtn:SetScript("OnClick", function()
        service.state.langMode = "ALL"
        for _, code in ipairs(available) do
            service.state.languages[code] = true
        end
        UpdateLangBtnLabel()
        RefreshMenuVisuals()
        service:DoSearch()
    end)

    clientBtn:SetScript("OnClick", function()
        service.state.langMode = "CUSTOM"
        for _, code in ipairs(available) do
            service.state.languages[code] = (code == clientCode)
        end
        UpdateLangBtnLabel()
        RefreshMenuVisuals()
        service:DoSearch()
    end)

    for _, code in ipairs(available) do
        local btn = langCheckButtons[code]
        if btn then
            btn:SetScript("OnClick", function()
                if service.state.langMode == "ALL" then
                    service.state.langMode = "CUSTOM"
                    for _, c in ipairs(available) do
                        service.state.languages[c] = (c ~= code)
                    end
                else
                    service.state.languages[code] = not service.state.languages[code]
                    local allChecked = true
                    local anyChecked = false
                    for _, c in ipairs(available) do
                        if service.state.languages[c] then
                            anyChecked = true
                        else
                            allChecked = false
                        end
                    end
                    if allChecked then
                        service.state.langMode = "ALL"
                        for _, c in ipairs(available) do
                            service.state.languages[c] = true
                        end
                    elseif not anyChecked then
                        service.state.languages[clientCode] = true
                    end
                end
                UpdateLangBtnLabel()
                RefreshMenuVisuals()
                service:DoSearch()
            end)
        end
    end

    langBtn:SetScript("OnClick", function()
        if langMenu:IsShown() then
            langMenu:Hide()
        else
            RefreshMenuVisuals()
            langMenu:ClearAllPoints()
            langMenu:SetPoint("TOPLEFT", langBtn, "BOTTOMLEFT", 0, -3)
            langMenu:SetPoint("TOPRIGHT", langBtn, "BOTTOMRIGHT", 0, -3)
            catcher:Show()
            langMenu:Show()
        end
    end)

    -- -----------------------------------------------------------------------
    -- 2. ROLES (Clean Round Medallions, Active Color / Inactive Grayscale)
    -- -----------------------------------------------------------------------
    local roleHeader = inset:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    if not roleHeader:GetFont() then roleHeader:SetFontObject("GameFontNormal") end
    roleHeader:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD_X, -70)
    roleHeader:SetText(L["LFG_ROLES"] or ROLE or "Roles")

    local NODE_SIZE = 41
    local NODE_GAP = 8

    for i, role in ipairs(ROLES) do
        local btn = CreateFrame("Button", nil, inset)
        btn:SetSize(NODE_SIZE, NODE_SIZE)
        btn:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD_X + (i - 1) * (NODE_SIZE + NODE_GAP), -92)

        -- Authentic round Blizzard role medallion
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        if not tex:SetAtlas(ROLE_ATLASES[role]) then
            tex:SetAtlas(ROLE_MICRO_ATLASES[role])
        end
        btn.Texture = tex

        -- Subtle, soft hover glow
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.3)

        local function UpdateVisual()
            local active = service.state.roles[role]
            tex:SetDesaturated(not active)
            tex:SetAlpha(active and 1.0 or 0.25)
        end
        UpdateVisual()

        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            service.state.roles[role] = not service.state.roles[role]
            UpdateVisual()
            service:ApplyFilters(LFGBrowseFrame)
        end)

        self.roleButtons[role] = { btn = btn, update = UpdateVisual }
    end

    -- -----------------------------------------------------------------------
    -- 3. CLASSES (Clean Square Icons with 1px Shadow Edge, Active Color / Inactive Grayscale)
    -- -----------------------------------------------------------------------
    local classHeader = inset:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    if not classHeader:GetFont() then classHeader:SetFontObject("GameFontNormal") end
    classHeader:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD_X, -149)
    classHeader:SetText(L["LFG_CLASSES"] or CLASS or "Classes")

    local function CreateClassNode(cName, x, y)
        local btn = CreateFrame("Button", nil, inset, "BackdropTemplate")
        btn:SetSize(NODE_SIZE, NODE_SIZE)
        btn:SetPoint("TOPLEFT", inset, "TOPLEFT", x, y)
        btn:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropBorderColor(0, 0, 0, 0.85)

        -- Recessed dark slot
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", -1, 1)
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.8)

        -- Crisp square class icon (cropped 9% to remove border dots and edge artifacts)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", -1, 1)
        local coords = CLASS_COORDS[cName]
        if coords then
            tex:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            local left, right, top, bottom = unpack(coords)
            local xZoom = (right - left) * 0.09
            local yZoom = (bottom - top) * 0.09
            tex:SetTexCoord(left + xZoom, right - xZoom, top + yZoom, bottom - yZoom)
        else
            tex:SetAtlas("groupfinder-icon-class-" .. string.lower(cName))
        end
        btn.Texture = tex

        -- Hover highlight
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 1)
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD")

        local function UpdateVisual()
            local active = service.state.classes[cName] ~= false
            tex:SetDesaturated(not active)
            tex:SetAlpha(active and 1.0 or 0.25)
        end
        UpdateVisual()

        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            service.state.classes[cName] = not (service.state.classes[cName] ~= false)
            UpdateVisual()
            service:ApplyFilters(LFGBrowseFrame)
        end)

        self.classButtons[cName] = { btn = btn, update = UpdateVisual }
    end

    -- Row 1: 5 classes (Warrior, Paladin, Hunter, Rogue, Priest)
    local classStartY = -173
    for i = 1, 5 do
        CreateClassNode(CLASSES[i], PAD_X + (i - 1) * (NODE_SIZE + NODE_GAP), classStartY)
    end

    -- Row 2: 4 classes (Shaman, Mage, Warlock, Druid) left-aligned under Row 1
    local classRow2Y = classStartY - (NODE_SIZE + 6)
    for i = 6, 9 do
        CreateClassNode(CLASSES[i], PAD_X + (i - 6) * (NODE_SIZE + NODE_GAP), classRow2Y)
    end

    -- -----------------------------------------------------------------------
    -- 4. SORTING: Clean Native Blizzard Checkboxes (UICheckButtonTemplate)
    -- -----------------------------------------------------------------------
    local sortHeader = inset:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    if not sortHeader:GetFont() then sortHeader:SetFontObject("GameFontNormal") end
    sortHeader:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD_X, classRow2Y - NODE_SIZE - 16)
    sortHeader:SetText(L["LFG_SORTING"] or "Sorting Priorities")

    local function CreateSortCheckbox(labelText, getVal, setVal, offsetY)
        local cb = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
        cb:SetSize(28, 28)
        cb:SetPoint("TOPLEFT", sortHeader, "BOTTOMLEFT", -2, offsetY)
        cb.Text:SetText(labelText)
        cb.Text:SetFontObject("GameFontHighlight")
        cb:SetChecked(getVal())
        local textWidth = cb.Text:GetStringWidth()
        cb:SetHitRectInsets(0, -((textWidth and textWidth > 0) and textWidth or 140) - 10, 0, 0)
        cb:SetScript("OnClick", function(selfBtn)
            setVal(selfBtn:GetChecked())
            service:ApplyFilters(LFGBrowseFrame)
        end)
        return cb
    end

    local cbNear = CreateSortCheckbox(L["LFG_SORT_NEAR"] or "Near Dungeon",
        function() return service.state.sortNear end,
        function(val) service.state.sortNear = val end,
        -8
    )
    self.checkboxes.near = cbNear

    local cbFriends = CreateSortCheckbox(L["LFG_SORT_FRIENDS"] or "Friends & Guild",
        function() return service.state.sortFriends end,
        function(val) service.state.sortFriends = val end,
        -40
    )
    self.checkboxes.friends = cbFriends

    local cbLevel = CreateSortCheckbox(L["LFG_SORT_LEVEL"] or "Highest Level",
        function() return service.state.sortLevel end,
        function(val) service.state.sortLevel = val end,
        -72
    )
    self.checkboxes.level = cbLevel

    -- -----------------------------------------------------------------------
    -- 5. RESET BUTTON (Centered Native Blizzard Button)
    -- -----------------------------------------------------------------------
    local resetBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 22)
    resetBtn:SetPoint("BOTTOM", inset, "BOTTOM", 0, 10)
    resetBtn:SetText(RESET or L["LFG_RESET_ALL"] or "Reset")
    resetBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        for _, r in ipairs(ROLES) do
            service.state.roles[r] = true
            if self.roleButtons[r] then self.roleButtons[r].update() end
        end
        for _, c in ipairs(CLASSES) do
            service.state.classes[c] = true
            if self.classButtons[c] then self.classButtons[c].update() end
        end
        service.state.langMode = "ALL"
        local available = service:GetAvailableLanguages()
        for _, code in ipairs(available) do
            service.state.languages[code] = true
        end
        UpdateLangBtnLabel()

        service.state.sortNear = true
        service.state.sortFriends = true
        service.state.sortLevel = true
        cbNear:SetChecked(true)
        cbFriends:SetChecked(true)
        cbLevel:SetChecked(true)

        service:ApplyFilters(LFGBrowseFrame)
        service:DoSearch()
    end)

    -- Toggle Button on LFGParentFrame Header (Visible only when LFGBrowseFrame is shown)
    local close = LFGParentFrame.CloseButton or _G["LFGParentFrameCloseButton"]
    local toggleBtn = CreateFrame("Button", "AikoLfgFilterToggle", LFGParentFrame, "UIPanelButtonTemplate")
    toggleBtn:SetText(L["LFG_PANEL_TITLE"] or "Filters")
    toggleBtn:SetSize(toggleBtn:GetTextWidth() + 20, 20)
    if close then
        toggleBtn:SetPoint("RIGHT", close, "LEFT", -4, 0)
        toggleBtn:SetFrameLevel(close:GetFrameLevel() + 1)
    else
        toggleBtn:SetPoint("TOPRIGHT", LFGParentFrame, "TOPRIGHT", -32, -4)
    end
    toggleBtn:SetScript("OnClick", function()
        service.state.panelShown = not service.state.panelShown
        panel:SetShown(service.state.panelShown)
    end)
    self.toggleButton = toggleBtn

    panel:Hide()
    toggleBtn:Hide()
    return panel
end

function LfgFilterPanel:UpdateAllVisuals()
    if self.UpdateLangBtnLabel then self.UpdateLangBtnLabel() end
    for _, item in pairs(self.roleButtons or {}) do
        if item.update then item.update() end
    end
    for _, item in pairs(self.classButtons or {}) do
        if item.update then item.update() end
    end
    if self.checkboxes then
        if self.checkboxes.near then self.checkboxes.near:SetChecked(ns.Core.LfgService.state.sortNear) end
        if self.checkboxes.friends then self.checkboxes.friends:SetChecked(ns.Core.LfgService.state.sortFriends) end
        if self.checkboxes.level then self.checkboxes.level:SetChecked(ns.Core.LfgService.state.sortLevel) end
    end
end
