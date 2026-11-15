local addonName, ns = ...

-- Gate strictly to WoW Forever (TOC 16001). Leave all other clients untouched.
local _, _, _, tocversion = GetBuildInfo()
if tocversion ~= 16001 and not ns.IsDev then
    return
end

ns.UI = ns.UI or {}
local LfgRowDecorator = {}
ns.UI.LfgRowDecorator = LfgRowDecorator

local L = ns.Locales or {}

-- =========================================================================
-- VISUAL CONSTANTS: DF Squircle Chip Action Button & Zone Text
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

function LfgRowDecorator:Decorate(row, service)
    if InCombatLockdown and InCombatLockdown() then return end
    service = service or (ns.Core and ns.Core.LfgService)
    if not service or not service:IsEnabled() then
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
        local leader = info.leaderName
        local leaderAccessible = (canaccessvalue == nil) or canaccessvalue(leader)
        btn:SetEnabled(leaderAccessible and leader ~= nil and leader ~= "")
        btn:SetScript("OnClick", function()
            local currentLeader = info.leaderName
            if canaccessvalue and not canaccessvalue(currentLeader) then
                return
            end
            if currentLeader and currentLeader ~= "" then
                local profile = ns.Core.Repository and ns.Core.Repository:GetProfile()
                local autoWhisper = profile and profile.modules and profile.modules.lfg and profile.modules.lfg.autoWhisper ~= false
                if autoWhisper then
                    local msg = service:GetAutoWhisperMessage(info)
                    if IsShiftKeyDown() then
                        ChatFrame_OpenChat("/w " .. currentLeader .. " " .. msg)
                    else
                        SendChatMessage(msg, "WHISPER", nil, currentLeader)
                    end
                else
                    ChatFrame_OpenChat("/w " .. currentLeader .. " ")
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
        local zone = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if not zone:GetFont() then zone:SetFontObject("GameFontNormal") end
        zone:SetHeight(16)
        zone:SetWordWrap(false)
        zone:SetJustifyH("LEFT")
        row.AikoZoneText = zone
    end

    local area = member and member.areaName
    if area and area ~= "" then
        local isNear = service.IsMemberNearActivity and service:IsMemberNearActivity(row.resultID, info)
        if isNear then
            row.AikoZoneText:SetTextColor(0.25, 0.95, 0.25)
        else
            row.AikoZoneText:SetTextColor(1.0, 0.35, 0.35)
        end
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
