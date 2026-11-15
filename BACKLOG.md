# AikoQoL - Development Backlog & Technical Debt

This document tracks identified architectural improvements, technical debt, and planned feature enhancements for **AikoQoL**.

---

## 🟡 Planned / Backlog

*(All pending backlog tickets completed)*

---

## 🔴 Completed

- [x] **Player Talent Spec Detection in Auto-Whisper (`%spec% %class%`)**
  - Determined the player's active specialization based on talent tree point allocation using modern `C_SpecializationInfo` and `C_Traits` API (with fallback to Classic `GetTalentTabInfo`). Dominant spec name is dynamically prefixed to class in auto-whisper (e.g., `"Hi! Lvl 60 Arms Warrior, inv please!"`).
- [x] **Dynamic Language Discovery via `C_LFGList.GetAvailableLanguageSearchFilter()`**
  - Replaced static `REGION_LANGUAGES` fallback table with dynamic client/server API `C_LFGList.GetAvailableLanguageSearchFilter()` to support all realm-available languages regardless of `GetCurrentRegion()`.
- [x] **Secret String & Taint Protection in Combat Lockdown**
  - Guarded `info.leaderName` reading and auto-whisper sending with `canaccessvalue(info.leaderName)` to prevent `attempt to concatenate a secret string` errors during combat or chat messaging lockdown.
- [x] **Dynamic Module Schema Migration in `Repository.lua`**
  - Added `TableUtils:EnsureTable(profile.modules, "lfg", defaults.profile.modules.lfg)` and fallback for `autoWhisper`.
- [x] **Integrate `LfgService` into `App:Update()` Pipeline**
  - Added `LfgService:UpdateState()` and integrated it into `App:Update()` for instant UI sync when module settings toggle.
- [x] **Decouple LFG Dungeon Map Registry**
  - Extracted `INSTANCE_ZONE_AREAS` registry from `Core/LfgService.lua` into dedicated `Core/LfgData.lua`.
- [x] **Deduplicate Constants between Core and UI**
  - Consolidated `CLASSES`, `ROLES`, `ROLE_ATLASES`, and `ROLE_MICRO_ATLASES` into `Core/LfgData.lua` under `ns.LfgData`.
- [x] **Standardize Service Lifecycle across `Core/`**
  - Routed `LfgService:Init()` through `App:Init()`, eliminated standalone file-scope invocation, and ensured loader unregisters once hooked.
