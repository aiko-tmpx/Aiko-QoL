local addonName, ns = ...

-- Gate strictly to WoW Forever (TOC 16001). Leave all other clients untouched.
local _, _, _, tocversion = GetBuildInfo()
if tocversion ~= 16001 and not ns.IsDev then
    return
end

ns.LfgData = ns.LfgData or {}

-- Shared constants across Core and UI
ns.LfgData.ROLES = { "TANK", "HEALER", "DAMAGER" }
ns.LfgData.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

ns.LfgData.ROLE_ATLASES = {
    ["TANK"] = "groupfinder-icon-role-large-tank",
    ["HEALER"] = "groupfinder-icon-role-large-heal",
    ["DAMAGER"] = "groupfinder-icon-role-large-dps"
}

ns.LfgData.ROLE_MICRO_ATLASES = {
    ["TANK"] = "groupfinder-icon-role-micro-tank",
    ["HEALER"] = "groupfinder-icon-role-micro-heal",
    ["DAMAGER"] = "groupfinder-icon-role-micro-dps"
}

-- Instance MapID -> World Area IDs (dungeon entrance zones)
ns.LfgData.INSTANCE_ZONE_AREAS = {
    [389] = {1637},       -- Ragefire Chasm (Orgrimmar)
    [36] = {40},          -- Deadmines (Westfall)
    [43] = {17},          -- Wailing Caverns (Barrens)
    [33] = {130},         -- Shadowfang Keep (Silverpine Forest)
    [34] = {1519},        -- Stormwind Stockade (Stormwind)
    [48] = {331},         -- Blackfathom Deeps (Ashenvale)
    [90] = {1},           -- Gnomeregan (Dun Morogh)
    [47] = {17},          -- Razorfen Kraul (Barrens)
    [189] = {85},         -- Scarlet Monastery (Tirisfal Glades)
    [129] = {17, 400},    -- Razorfen Downs (Barrens, Thousand Needles)
    [70] = {3},           -- Uldaman (Badlands)
    [209] = {440},        -- Zul'Farrak (Tanaris)
    [349] = {405},        -- Maraudon (Desolace)
    [109] = {8},          -- Sunken Temple (Swamp of Sorrows)
    [230] = {25, 51, 46}, -- Blackrock Depths (Searing Gorge, Burning Steppes)
    [229] = {25, 51, 46}, -- Lower Blackrock Spire
    [409] = {25, 51, 46}, -- Upper Blackrock Spire
    [469] = {25, 51, 46}, -- Blackwing Lair
    [429] = {357},        -- Dire Maul (Feralas)
    [289] = {28},         -- Scholomance (Western Plaguelands)
    [329] = {139},        -- Stratholme (Eastern Plaguelands)
    [309] = {33},         -- Zul'Gurub (Stranglethorn Vale)
    [509] = {1377},       -- Ruins of Ahn'Qiraj (Silithus)
    [531] = {1377},       -- Temple of Ahn'Qiraj (Silithus)
    [249] = {15},         -- Onyxia's Lair (Dustwallow Marsh)
    [533] = {139},        -- Naxxramas (Eastern Plaguelands)
    [572] = {1497, 85},   -- Karazhan (Deadwind Pass)

    -- WoW Forever Exclusive Dungeons (Icy Veins)
    [3065] = {1, 1537},      -- Hall of Thanes (Dun Morogh, Ironforge)
    [2999] = {85, 1497},     -- Ruins of Lordaeron (Tirisfal Glades, Undercity)
    [2998] = {11},           -- Excavation Site: Wetlands (Wetlands)
    [2959] = {36, 130, 267}, -- City of Dalaran (Alterac Mountains, Silverpine, Hillsbrad)
    [2970] = {33},           -- The Drowned City (Stranglethorn Vale)
    [3039] = {44, 2548},     -- Krol'dok Stronghold (Redridge Mountains, Riverglades)
    [2994] = {15},           -- Alcaz Prison (Dustwallow Marsh)
    [2974] = {16},           -- Blackmaw Hold (Azshara)
    [3001] = {490},          -- Shaper's Terrace (Un'Goro Crater)
}
