local addonName, ns = ...

-- Gate strictly to WoW Forever (TOC 16001). Leave all other clients untouched.
local _, _, _, tocversion = GetBuildInfo()
if tocversion ~= 16001 and not ns.IsDev then
    return
end

ns.UI = ns.UI or {}
local LootToastView = {}
ns.UI.LootToastView = LootToastView

local L = ns.Locales or {}

-- =========================================================================
-- CONSTANTS & ROLL CONFIG
-- =========================================================================
local MAX_TOASTS = 10
local TOAST_WIDTH = 248
local TOAST_HEIGHT = 40
local STACK_STEP = 48

local ROLL_CONFIG = {
    [1] = { tex = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", y = -1 },
    [2] = { tex = "Interface\\Buttons\\UI-GroupLoot-Coin-Up", y = -2 },
    [3] = { tex = "Interface\\Buttons\\UI-GroupLoot-DE-Up",   y = 0 },
}

-- =========================================================================
-- ANCHOR FRAME (Draggable)
-- =========================================================================
local anchorFrame = nil

local function SaveAnchorPosition()
    if not anchorFrame then return end
    anchorFrame:StopMovingOrSizing()
    local cx, cy = UIParent:GetCenter()
    local ax, ay = anchorFrame:GetCenter()
    if cx and ax and ns.Core.Repository then
        local ox = math.floor(ax - cx + 0.5)
        local oy = math.floor(ay - cy + 0.5)
        ns.Core.Repository:Set("modules.loot.anchorX", ox)
        ns.Core.Repository:Set("modules.loot.anchorY", oy)
    end
end

local function GetCurrentToastWidth()
    if ns.Core.LootService and ns.Core.LootService.GetWidth then
        return ns.Core.LootService:GetWidth()
    end
    return TOAST_WIDTH
end

local function EnsureAnchor()
    if anchorFrame then return anchorFrame end

    local f = CreateFrame("Frame", "AikoLootToastAnchor", UIParent, "BackdropTemplate")
    f:SetSize(GetCurrentToastWidth(), TOAST_HEIGHT)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0.10, 0.09, 0.12, 0.90)
    f:SetBackdropBorderColor(0.70, 0.58, 0.20, 0.95)

    local txt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("CENTER", 0, 0)
    txt:SetText(L["LOOT_ANCHOR_TITLE"] or "AikoQoL Loot Toast Anchor")
    txt:SetTextColor(1, 0.82, 0)
    f.Title = txt

    f:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        SaveAnchorPosition()
    end)

    local x, y = 350, 0
    if ns.Core.LootService then
        x, y = ns.Core.LootService:GetAnchorCoords()
    end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    f:Hide()

    anchorFrame = f
    return f
end

function LootToastView:LockAnchor()
    if anchorFrame and anchorFrame:IsShown() then
        SaveAnchorPosition()
        anchorFrame:Hide()
        return true
    end
    return false
end

function LootToastView:ToggleAnchor()
    if InCombatLockdown and InCombatLockdown() then return false end
    local a = EnsureAnchor()
    if a:IsShown() then
        a:Hide()
        return false
    else
        local x, y = 350, 0
        if ns.Core.LootService then
            x, y = ns.Core.LootService:GetAnchorCoords()
        end
        a:ClearAllPoints()
        a:SetPoint("CENTER", UIParent, "CENTER", x, y)
        a:Show()
        return true
    end
end

function LootToastView:IsAnchorUnlocked()
    return anchorFrame and anchorFrame:IsShown() and true or false
end

-- =========================================================================
-- TOAST POOL & DF VISUALS
-- =========================================================================
local activeToasts = {}
local toastPool = {}
local hoveredCount = 0

local tickerFrame = CreateFrame("Frame")
tickerFrame:Hide()

local function RepositionToasts()
    local a = EnsureAnchor()
    local dir = ns.Core.LootService and ns.Core.LootService:GetDirection() or "UP"
    local step = (dir == "UP") and STACK_STEP or -STACK_STEP

    for i, toast in ipairs(activeToasts) do
        toast:ClearAllPoints()
        local offset = (i - 1) * step
        toast:SetPoint("CENTER", a, "CENTER", 0, offset)
    end
end

local function DismissToast(toast)
    if toast.isMouseOver then
        toast.isMouseOver = false
        hoveredCount = math.max(0, hoveredCount - 1)
    end
    toast.fadingOut = false
    UIFrameFadeRemoveFrame(toast)

    for i, t in ipairs(activeToasts) do
        if t == toast then
            table.remove(activeToasts, i)
            break
        end
    end

    toast:Hide()
    toast:SetAlpha(0)
    table.insert(toastPool, toast)
    RepositionToasts()

    if #activeToasts == 0 then
        tickerFrame:Hide()
    end
end

tickerFrame:SetScript("OnUpdate", function(self, elapsed)
    if hoveredCount > 0 then return end
    if #activeToasts == 0 then
        self:Hide()
        return
    end

    local i = 1
    while i <= #activeToasts do
        local toast = activeToasts[i]
        toast.timeLeft = (toast.timeLeft or 4.5) - elapsed
        if toast.timeLeft <= 0 then
            DismissToast(toast)
        elseif toast.timeLeft <= 0.4 and not toast.fadingOut then
            toast.fadingOut = true
            UIFrameFadeOut(toast, 0.4, toast:GetAlpha(), 0)
            i = i + 1
        else
            i = i + 1
        end
    end
end)

local function CreateToastFrame()
    local t = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    t:SetSize(GetCurrentToastWidth(), TOAST_HEIGHT)
    t:SetFrameStrata("HIGH")
    t:SetClampedToScreen(true)
    t:EnableMouse(true)

    -- Sleek rounded Dragonflight card backdrop
    t:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    t:SetBackdropColor(0.07, 0.07, 0.08, 0.88)
    t:SetBackdropBorderColor(0.28, 0.25, 0.22, 0.85)

    -- Clean cropped Item Icon
    local icon = t:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", t, "LEFT", 7, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.Icon = icon

    -- Fixed-width Roll Badge Container on the right
    local badgeBox = CreateFrame("Frame", nil, t)
    badgeBox:SetSize(52, 22)
    badgeBox:SetPoint("RIGHT", t, "RIGHT", -10, 0)
    t.BadgeBox = badgeBox

    local badgeIcon = badgeBox:CreateTexture(nil, "ARTWORK")
    badgeIcon:SetSize(19, 19)
    badgeIcon:SetPoint("RIGHT", badgeBox, "RIGHT", 0, 0)
    t.BadgeIcon = badgeIcon

    local badgeText = badgeBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    badgeText:SetPoint("RIGHT", badgeBox, "RIGHT", -23, 0)
    badgeText:SetShadowOffset(1, -1)
    badgeText:SetShadowColor(0, 0, 0, 0.95)
    badgeText:SetJustifyH("RIGHT")
    t.BadgeText = badgeText

    -- Top Line: Winner Name (class colored, anchored just above center)
    local winnerText = t:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    winnerText:SetPoint("BOTTOMLEFT", icon, "RIGHT", 7, 2)
    winnerText:SetPoint("RIGHT", badgeBox, "LEFT", -6, 0)
    winnerText:SetJustifyH("LEFT")
    winnerText:SetWordWrap(false)
    winnerText:SetShadowOffset(1, -1)
    winnerText:SetShadowColor(0, 0, 0, 0.95)
    t.WinnerText = winnerText

    -- Bottom Line: Clean Item Name (quality colored, anchored just below center)
    local itemName = t:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    itemName:SetPoint("TOPLEFT", icon, "RIGHT", 7, -1)
    itemName:SetPoint("RIGHT", badgeBox, "LEFT", -6, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(false)
    itemName:SetShadowOffset(1, -1)
    itemName:SetShadowColor(0, 0, 0, 0.95)
    t.ItemName = itemName

    t:SetScript("OnEnter", function(self)
        if not self.isMouseOver then
            self.isMouseOver = true
            hoveredCount = hoveredCount + 1
        end
        self:SetBackdropColor(0.12, 0.12, 0.13, 0.96)

        -- Freeze: restore full visibility to any toast that was fading out
        for _, active in ipairs(activeToasts) do
            if active.fadingOut then
                active.fadingOut = false
                UIFrameFadeRemoveFrame(active)
                active:SetAlpha(1)
            end
        end

        if self.itemLink and type(self.itemLink) == "string" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)

    t:SetScript("OnLeave", function(self)
        if self.isMouseOver then
            self.isMouseOver = false
            hoveredCount = math.max(0, hoveredCount - 1)
        end
        self:SetBackdropColor(0.07, 0.07, 0.08, 0.88)
        GameTooltip:Hide()

        -- When mouse leaves all toasts, ensure remaining time is at least 2.5s
        if hoveredCount == 0 then
            for _, active in ipairs(activeToasts) do
                if (active.timeLeft or 0) < 2.5 then
                    active.timeLeft = 2.5
                end
            end
        end
    end)

    t:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            DismissToast(self)
        elseif button == "LeftButton" and self.itemLink then
            if ChatEdit_InsertLink then
                ChatEdit_InsertLink(self.itemLink)
            end
        end
    end)

    return t
end

local function GetToastFromPool()
    if #toastPool > 0 then
        return table.remove(toastPool)
    end
    return CreateToastFrame()
end

-- =========================================================================
-- PUBLIC VIEW METHODS
-- =========================================================================
function LootToastView:Spawn(winnerName, playerClass, itemLink, quality, rollType, rollNumber)
    EnsureAnchor()

    -- Cap maximum simultaneous active toasts
    if #activeToasts >= MAX_TOASTS then
        DismissToast(activeToasts[1])
    end

    local toast = GetToastFromPool()
    toast:SetSize(GetCurrentToastWidth(), TOAST_HEIGHT)
    toast.itemLink = itemLink

    -- 1. Icon & Quality Border (100% fail-safe against uncached/nil values)
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    local itemIcon = (C_Item and C_Item.GetItemIconByID and itemID and C_Item.GetItemIconByID(itemID))
        or (GetItemIcon and itemID and GetItemIcon(itemID))
        or select(10, C_Item.GetItemInfo(itemLink))
    local tex = itemIcon or 134400
    toast.Icon:SetTexture(tex)
    toast.Icon:Show()

    local q = tonumber(quality) or 1
    local r, g, b, hex = C_Item.GetItemQualityColor(q)
    r, g, b, hex = r or 1, g or 1, b or 1, hex or "ffffffff"
    toast:SetBackdropBorderColor(r * 0.65 + 0.15, g * 0.65 + 0.15, b * 0.65 + 0.15, 0.75)

    -- 2. Winner Name with Class Color (Top Line)
    local classColor = playerClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[playerClass]
    local nameText = winnerName
    if classColor and classColor.colorStr then
        nameText = string.format("|c%s%s|r", classColor.colorStr, winnerName)
    end
    toast.WinnerText:SetText(nameText)

    -- 3. Item Name without chat brackets (Bottom Line)
    local cleanItemName = itemLink:match("%[(.-)%]") or "Item"
    local coloredItemName = string.format("|c%s%s|r", hex or "ffffffff", cleanItemName)
    toast.ItemName:SetText(coloredItemName)

    -- 4. Roll Badge
    toast.BadgeIcon:ClearAllPoints()
    local cfg = ROLL_CONFIG[tonumber(rollType) or 0]

    if cfg then
        toast.BadgeIcon:SetPoint("RIGHT", toast.BadgeBox, "RIGHT", 0, cfg.y)
        toast.BadgeIcon:SetTexture(cfg.tex)
        toast.BadgeIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        toast.BadgeIcon:SetAlpha(1.0)
        toast.BadgeIcon:Show()
        toast.BadgeText:SetText(rollNumber and string.format("|cffffffff%d|r", rollNumber) or "")
    else
        toast.BadgeIcon:Hide()
        toast.BadgeText:SetText("")
    end

    toast.timeLeft = 4.5
    toast.fadingOut = false
    toast.isMouseOver = false

    table.insert(activeToasts, toast)
    RepositionToasts()

    toast:Show()
    UIFrameFadeIn(toast, 0.15, 0, 1)
    tickerFrame:Show()
end

function LootToastView:Init()
    EnsureAnchor()
end

function LootToastView:Update()
    local x, y = 350, 0
    if ns.Core.LootService then
        x, y = ns.Core.LootService:GetAnchorCoords()
    end
    local w = GetCurrentToastWidth()
    local a = EnsureAnchor()
    a:SetSize(w, TOAST_HEIGHT)
    a:ClearAllPoints()
    a:SetPoint("CENTER", UIParent, "CENTER", x, y)

    for _, active in ipairs(activeToasts) do
        active:SetSize(w, TOAST_HEIGHT)
    end
    RepositionToasts()
end
