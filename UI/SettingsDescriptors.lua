local addonName, ns = ...

local L = ns.L

ns.UI.SettingsDescriptors = {
    nameplates = {
        moduleKey = "nameplates",
        title = L["TAB_FRIENDLY_NAMEPLATES"],
        description = L["DESC_NAMEPLATES"],
        controls = {
            { type = "checkbox", path = "modules.nameplates.enabled", label = L["MODULE_ENABLED"] },
            { type = "checkbox", path = "modules.nameplates.notifications", label = L["CHAT_NOTIFICATIONS"] },
            { type = "optimizeButton", label = L["OPTIMIZE_FRIENDLY_NAMEPLATES_SETTINGS"] },
            { type = "spacer" },
            { type = "headerRow" },
            { type = "zoneRow", label = L["RAIDS"], pathBase = "zones.raid" },
            { type = "zoneRow", label = L["DUNGEONS"], pathBase = "zones.dungeon" },
            { type = "zoneRow", label = L["ARENA"], pathBase = "zones.arena" },
            { type = "zoneRow", label = L["BATTLEGROUNDS"], pathBase = "zones.battleground" },
            { type = "zoneRow", label = L["OPEN_WORLD"], pathBase = "zones.openWorld" },
        },
    },
    audio = {
        moduleKey = "audio",
        title = L["TAB_AUDIO"],
        description = L["DESC_AUDIO"],
        controls = {
            { type = "checkbox", path = "modules.audio.enabled", label = L["MODULE_ENABLED"] },
            { type = "checkbox", path = "modules.audio.notifications", label = L["CHAT_NOTIFICATIONS"] },
            { type = "optimizeButton", label = L["OPTIMIZE_AUDIO_SETTINGS"] },
            { type = "spacer" },
            { type = "audioMatrix" },
        },
    },
    tooltip = {
        moduleKey = "tooltip",
        title = L["TAB_TOOLTIP"],
        description = L["DESC_TOOLTIP"],
        controls = {
            { type = "checkbox", path = "modules.tooltip.enabled", label = L["MODULE_ENABLED"] },
            { type = "spacer" },
            { type = "checkbox", path = "modules.tooltip.showZone", label = L["TOOLTIP_SHOW_ZONE"] },
            { type = "checkbox", path = "modules.tooltip.showDistance", label = L["TOOLTIP_SHOW_DISTANCE"] },
        },
    },
    chat = {
        moduleKey = "chat",
        title = L["TAB_CHAT"],
        description = L["DESC_CHAT"],
        controls = {
            { type = "checkbox", path = "modules.chat.enabled", label = L["MODULE_ENABLED"] },
            { type = "spacer" },
            { type = "checkbox", path = "modules.chat.whisperSound", label = L["CHAT_WHISPER_SOUND"] },
        },
    },
    scale = {
        moduleKey = "scale",
        title = L["TAB_SCALE"],
        description = L["DESC_SCALE"],
        controls = {
            { type = "checkbox", path = "modules.scale.enabled", label = L["MODULE_ENABLED"] },
            { type = "spacer" },
            { type = "input", path = "modules.scale.value", label = L["SCALE_SLIDER_LABEL"] },
        },
    },
    lfg = {
        moduleKey = "lfg",
        title = L["TAB_LFG"] or "Group Finder",
        description = L["DESC_LFG"] or "LFG Enhancements",
        controls = {
            { type = "checkbox", path = "modules.lfg.enabled", label = L["LFG_ENABLED"] or L["MODULE_ENABLED"] },
            { type = "checkbox", path = "modules.lfg.autoWhisper", label = L["LFG_AUTO_WHISPER"] or "Automate Whispers" },
        },
    },
}
