local addonName, ns = ...

local ScaleService = {}
ns.Core.ScaleService = ScaleService

local function IsCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function IsEditMode()
    if EditModeManagerFrame and EditModeManagerFrame.editModeActive then
        return EditModeManagerFrame.editModeActive
    end
    if C_EditMode and C_EditMode.IsEditModeActive then
        return C_EditMode.IsEditModeActive()
    end
    return false
end

function ScaleService:Apply()
    local profile = ns.Core.Repository:GetProfile()
    local scaleConfig = profile and profile.modules and profile.modules.scale
    if not (scaleConfig and scaleConfig.enabled) then
        return
    end

    if IsCombat() or IsEditMode() then
        self.pending = true
        return
    end

    self.pending = false
    local scale = tonumber(scaleConfig.value) or 0.58
    scale = math.max(0.30, math.min(1.50, scale))

    local setCVar = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if setCVar then
        setCVar("useUiScale", "1")
        setCVar("uiScale", string.format("%.4f", scale))
    end

    if UIParent and UIParent.SetScale then
        UIParent:SetScale(scale)
    end

    if NamePlateDriverFrame and NamePlateDriverFrame.SetIgnoreParentScale then
        NamePlateDriverFrame:SetIgnoreParentScale(true)
    end
end

function ScaleService:QueueApply(delay)
    if self.timer then
        self.timer:Cancel()
    end
    self.timer = C_Timer.NewTimer(delay or 0.2, function()
        self.timer = nil
        self:Apply()
    end)
end

function ScaleService:Init()
    if self.initialized then return end
    self.initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if self.pending then
                self:Apply()
            end
            return
        end

        self:QueueApply(0.2)
    end)
    self.frame = frame

    if EditModeManagerFrame and EditModeManagerFrame.ExitEditMode and hooksecurefunc then
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            if self.pending then
                self:Apply()
            end
        end)
    end

    -- Initial delayed apply on load
    C_Timer.After(0.3, function()
        self:Apply()
    end)
end
