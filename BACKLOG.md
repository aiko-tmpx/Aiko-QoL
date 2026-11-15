# AikoQoL - Development Backlog & Technical Debt

This document tracks identified architectural improvements, technical debt, and planned feature enhancements for **AikoQoL**.

---

## 🔴 Completed

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
