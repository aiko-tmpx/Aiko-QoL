local addonName, ns = ...

local ScaleService = {}
ns.Core.ScaleService = ScaleService

local TOLERANCE = 0.0005
local pending = false
local pendingNameplateFix = false
local startupRetryToken = 0

local function Clamp(v, minV, maxV)
    v = tonumber(v) or minV
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function IsSimilar(a, b)
    return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < TOLERANCE
end

local function IsEditModeActive()
    if EditModeManagerFrame and EditModeManagerFrame.editModeActive then
        return EditModeManagerFrame.editModeActive
    end
    if C_EditMode and C_EditMode.IsEditModeActive then
        return C_EditMode.IsEditModeActive()
    end
    return false
end

local function ApplyGameMenuScale()
    local frames = { _G.GameMenuFrame, _G.SettingsPanel, _G.InterfaceOptionsFrame }
    for _, frame in ipairs(frames) do
        if frame and frame.SetScale then
            frame:SetScale(1)
        end
    end
end

local function FixNamePlates()
    if InCombatLockdown and InCombatLockdown() then
        pendingNameplateFix = true
        return
    end

    if NamePlateDriverFrame then
        if NamePlateDriverFrame.SetIgnoreParentScale then
            NamePlateDriverFrame:SetIgnoreParentScale(true)
        end
        if NamePlateDriverFrame.SetScale then
            NamePlateDriverFrame:SetScale(1)
        end
    end

    pendingNameplateFix = false
end

local function SyncCVars(want)
    if InCombatLockdown and InCombatLockdown() then return end
    local getCVar = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
    local setCVar = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if not getCVar or not setCVar then return end

    if tonumber(getCVar("useUiScale") or 0) ~= 1 then
        setCVar("useUiScale", "1")
    end

    local current = tonumber(getCVar("uiScale") or 0)
    if not IsSimilar(current, want) then
        setCVar("uiScale", tostring(want))
    end
end

local function TrySetScale(want)
    if IsEditModeActive() then
        pending = true
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        pending = true
        return false
    end

    SyncCVars(want)
    if UIParent and UIParent.SetScale then
        UIParent:SetScale(want)
    end
    FixNamePlates()
    ApplyGameMenuScale()
    return true
end

function ScaleService:Apply(force)
    local profile = ns.Core.Repository:GetProfile()
    local scaleConfig = profile and profile.modules and profile.modules.scale
    if not (scaleConfig and scaleConfig.enabled) then
        return
    end

    pending = false

    if IsEditModeActive() then
        pending = true
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pending = true
        return
    end

    local want = tonumber(scaleConfig.value) or 0.59
    want = Clamp(want, 0.30, 1.50)

    local current = UIParent and UIParent:GetScale()
    if force or not IsSimilar(current, want) then
        TrySetScale(want)

        for _, delay in ipairs({ 0.25, 0.75, 1.25 }) do
            C_Timer.After(delay, function()
                if IsEditModeActive() or (InCombatLockdown and InCombatLockdown()) then
                    pending = true
                    return
                end
                if not IsSimilar(UIParent:GetScale(), want) then
                    TrySetScale(want)
                end
            end)
        end
    else
        SyncCVars(want)
        ApplyGameMenuScale()
    end
end

local function ScheduleStartupRetries()
    startupRetryToken = startupRetryToken + 1
    local token = startupRetryToken

    for _, delay in ipairs({ 0.05, 0.25, 0.75, 1.25, 2.5, 5.0 }) do
        C_Timer.After(delay, function()
            if token ~= startupRetryToken then return end
            if IsEditModeActive() or (InCombatLockdown and InCombatLockdown()) then
                pending = true
                return
            end
            ScaleService:Apply(false)
        end)
    end
end

local function HookEditMode()
    local editModeFrame = _G.EditModeManagerFrame
    if not editModeFrame or not hooksecurefunc then return end

    if type(editModeFrame.EnterEditMode) == "function" then
        hooksecurefunc(editModeFrame, "EnterEditMode", function()
            pending = true
        end)
    end

    if type(editModeFrame.ExitEditMode) == "function" then
        hooksecurefunc(editModeFrame, "ExitEditMode", function()
            if pending then
                ScaleService:Apply(true)
            end
        end)
    end
end

function ScaleService:Init()
    if self.initialized then return end
    self.initialized = true

    HookEditMode()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pending then
                self:Apply(true)
            end
            if pendingNameplateFix then
                FixNamePlates()
            end
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            ScheduleStartupRetries()
            return
        end

        if event == "DISPLAY_SIZE_CHANGED" then
            C_Timer.After(0.05, function()
                self:Apply(false)
            end)
        end
    end)
    self.frame = frame

    if C_CVar and C_CVar.RegisterCVarChangedCallback then
        C_CVar.RegisterCVarChangedCallback(function(name)
            if name == "uiScale" or name == "useUiScale" then
                C_Timer.After(0.05, function()
                    if IsEditModeActive() then
                        pending = true
                        return
                    end
                    ScaleService:Apply(false)
                end)
            end
        end, "AikoQoL_ScaleWatcher")
    end

    ScheduleStartupRetries()
end
