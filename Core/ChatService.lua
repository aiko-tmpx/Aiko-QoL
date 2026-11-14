local addonName, ns = ...

local ChatService = {}
ns.Core.ChatService = ChatService

local SOUND_FILE = [[Interface\AddOns\AikoQoL\Media\whisper.ogg]]
local BLIZZARD_WHISPER_SOUND_FILE_ID = 567421
local WHISPER_THROTTLE_SECONDS = 5

local lastWhisperAlert = -WHISPER_THROTTLE_SECONDS
local isMuted = false

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

    self:UpdateState()
end
