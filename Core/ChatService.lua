local addonName, ns = ...

local ChatService = {}
ns.Core.ChatService = ChatService

local SOUND_FILE = [[Interface\AddOns\AikoQoL\Media\whisper.ogg]]
local BLIZZARD_WHISPER_SOUND_FILE_ID = 567421
local WHISPER_THROTTLE_SECONDS = 5
local MAX_HISTORY_LINES = 32

local lastWhisperAlert = -WHISPER_THROTTLE_SECONDS
local isMuted = false

ChatService.history = {}

local function IsProtectedCommand(msg)
    if not msg or msg == "" then return false end
    local cmd = msg:match("^(/%S+)")
    if not cmd then return false end
    cmd = string.lower(cmd)
    if IsSecureCmd and IsSecureCmd(cmd) then return true end
    local SECURE_SLASH = {
        ["/tar"] = true, ["/target"] = true, ["/targetexact"] = true, ["/targetnearestenemy"] = true,
        ["/targetlasttarget"] = true, ["/assist"] = true, ["/cast"] = true, ["/use"] = true,
        ["/castsequence"] = true, ["/castrandom"] = true, ["/cancelaura"] = true, ["/cancelform"] = true,
        ["/equip"] = true, ["/equipset"] = true, ["/stopcasting"] = true, ["/focus"] = true,
        ["/clearfocus"] = true, ["/cleartarget"] = true, ["/petattack"] = true, ["/petfollow"] = true,
        ["/startattack"] = true, ["/stopattack"] = true
    }
    return SECURE_SLASH[cmd] == true
end

local function SaveHistoryLine(editBox, text)
    if text and IsProtectedCommand(text) then return end
    if not text or text == "" then
        local t = ""
        local chatType = editBox and editBox.GetAttribute and editBox:GetAttribute("chatType")
        local header = chatType and _G["SLASH_" .. chatType .. "1"]
        if header then
            t = header
        end
        if chatType == "WHISPER" and editBox:GetAttribute("tellTarget") then
            t = t .. " " .. editBox:GetAttribute("tellTarget")
        elseif chatType == "CHANNEL" and editBox:GetAttribute("channelTarget") then
            t = "/" .. editBox:GetAttribute("channelTarget")
        end
        local editBoxText = editBox and editBox.GetText and editBox:GetText() or ""
        if #editBoxText > 0 then
            if not IsProtectedCommand(editBoxText) then
                text = (header and (t .. " ") or "") .. editBoxText
            end
        end
    end
    if not text or text == "" or IsProtectedCommand(text) then return end

    local history = ChatService.history
    if not history then return end

    if history[1] == text then
        if editBox then editBox.history_index = 0 end
        return
    end

    table.insert(history, 1, text)
    while #history > MAX_HISTORY_LINES do
        table.remove(history)
    end
    if editBox then editBox.history_index = 0 end
end

local function OnArrowPressed(self, key)
    if not ChatService:IsArrowKeysEnabled() then return end
    if (InCombatLockdown and InCombatLockdown()) or
       (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) then
        return
    end
    local history = ChatService.history
    if not history or #history == 0 then return end
    if key ~= "DOWN" and key ~= "UP" then return end

    if key == "DOWN" then
        self.history_index = (self.history_index or 0) - 1
        if self.history_index < 1 then
            self.history_index = #history
        end
    elseif key == "UP" then
        self.history_index = (self.history_index or 0) + 1
        if self.history_index > #history then
            self.history_index = 1
        end
    end

    local line = history[self.history_index]
    if line and not IsProtectedCommand(line) then
        self:SetText(line)
    end
end

local function HookChatEditBox(editBox)
    if not editBox or editBox.aikoArrowHooked then return end
    editBox.aikoArrowHooked = true
    editBox.history_index = 0

    if editBox.HookScript then
        editBox:HookScript("OnArrowPressed", OnArrowPressed)
        editBox:HookScript("OnEditFocusGained", function(self)
            self.history_index = 0
            if ChatService:IsArrowKeysEnabled() and self.SetAltArrowKeyMode then
                self:SetAltArrowKeyMode(false)
            end
        end)
        editBox:HookScript("OnShow", function(self)
            self.history_index = 0
            if ChatService:IsArrowKeysEnabled() and self.SetAltArrowKeyMode then
                self:SetAltArrowKeyMode(false)
            end
        end)
    end

    if type(hooksecurefunc) == "function" and editBox.AddHistoryLine then
        hooksecurefunc(editBox, "AddHistoryLine", function(self, text)
            SaveHistoryLine(self, text)
        end)
    end
    if type(hooksecurefunc) == "function" and editBox.ClearHistory then
        hooksecurefunc(editBox, "ClearHistory", function(self)
            self.history_index = 0
        end)
    end
end

local function ApplyArrowKeyMode(enabled)
    local altArrowMode = not enabled
    for i = 1, 50 do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox then
            if editBox.SetAltArrowKeyMode then
                editBox:SetAltArrowKeyMode(altArrowMode)
            end
            HookChatEditBox(editBox)
        end
    end
    if ChatEdit_ChooseBoxForSend then
        local activeBox = ChatEdit_ChooseBoxForSend()
        if activeBox then
            if activeBox.SetAltArrowKeyMode then
                activeBox:SetAltArrowKeyMode(altArrowMode)
            end
            HookChatEditBox(activeBox)
        end
    end
end

function ChatService:IsArrowKeysEnabled()
    local profile = ns.Core.Repository:GetProfile()
    local chatConfig = profile and profile.modules and profile.modules.chat
    return chatConfig and chatConfig.enabled and chatConfig.arrowKeys == true
end

function ChatService:UpdateState()
    local profile = ns.Core.Repository:GetProfile()
    local chatConfig = profile and profile.modules and profile.modules.chat
    local shouldPlay = chatConfig and chatConfig.enabled and chatConfig.whisperSound

    if shouldPlay then
        if not isMuted and type(MuteSoundFile) == "function" then
            MuteSoundFile(BLIZZARD_WHISPER_SOUND_FILE_ID)
            isMuted = true
        end
    else
        if isMuted and type(UnmuteSoundFile) == "function" then
            UnmuteSoundFile(BLIZZARD_WHISPER_SOUND_FILE_ID)
            isMuted = false
        end
    end

    ApplyArrowKeyMode(self:IsArrowKeysEnabled())
end

function ChatService:OnWhisper()
    local profile = ns.Core.Repository:GetProfile()
    local chatConfig = profile and profile.modules and profile.modules.chat
    if not (chatConfig and chatConfig.enabled and chatConfig.whisperSound) then
        return
    end

    local now = GetTime and GetTime() or 0
    if now - lastWhisperAlert < WHISPER_THROTTLE_SECONDS then
        return
    end
    lastWhisperAlert = now

    if PlaySoundFile then
        PlaySoundFile(SOUND_FILE, "Master")
    end
end

function ChatService:Init()
    if self.initialized then return end
    self.initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_WHISPER")
    frame:RegisterEvent("CHAT_MSG_BN_WHISPER")

    frame:SetScript("OnEvent", function()
        self:OnWhisper()
    end)
    self.frame = frame

    if type(FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            if self:IsArrowKeysEnabled() then
                local cf = FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
                local cfName = cf and cf:GetName()
                local editBox = cfName and _G[cfName .. "EditBox"]
                if editBox and editBox.SetAltArrowKeyMode then
                    editBox:SetAltArrowKeyMode(false)
                    HookChatEditBox(editBox)
                end
            end
        end)
    end

    if type(ChatEdit_ActivateChat) == "function" then
        hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
            if self:IsArrowKeysEnabled() and editBox then
                editBox.history_index = 0
                if editBox.SetAltArrowKeyMode then
                    editBox:SetAltArrowKeyMode(false)
                end
                HookChatEditBox(editBox)
            end
        end)
    end

    if ChatFrameUtil and type(ChatFrameUtil.OpenChat) == "function" then
        hooksecurefunc(ChatFrameUtil, "OpenChat", function(_, chatFrame)
            if self:IsArrowKeysEnabled() then
                local eb = ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend(chatFrame)
                if eb then
                    eb.history_index = 0
                    HookChatEditBox(eb)
                end
            end
        end)
    elseif type(ChatFrame_OpenChat) == "function" then
        hooksecurefunc("ChatFrame_OpenChat", function(_, chatFrame)
            if self:IsArrowKeysEnabled() then
                local eb = ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend(chatFrame)
                if eb then
                    eb.history_index = 0
                    HookChatEditBox(eb)
                end
            end
        end)
    end

    if type(ChatEdit_AddHistory) == "function" then
        hooksecurefunc("ChatEdit_AddHistory", function(editBox)
            SaveHistoryLine(editBox)
        end)
    end

    self:UpdateState()
end
