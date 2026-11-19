# AikoQoL - Development Backlog & Technical Debt

This document tracks identified architectural improvements, technical debt, and planned feature enhancements for **AikoQoL**.

---

## 🟡 Planned / Backlog

- [ ] **Loot Toast Notification Customization**
  - Add sound effects and custom display duration for won group loot rolls.

---

## 🔴 Completed

- [x] **Arrow Keys for Chat History in `ChatService`**
  - Added option and implementation to cycle chat history with `Up` / `Down` arrows directly without Alt via `SetAltArrowKeyMode(false)`.
- [x] **Pure Client-Side LFG Companion (Zero Taint, No Server-Side Language Overrides)**
  - Retained LFG quick-action buttons (1-click invite and leader auto-whisper with spec detection), member dungeon proximity indicators, and client-side role/class filtering and sorting.
  - Omitted server-side language search parameter overrides to guarantee zero execution taint on Blizzard's `LFGBrowseFrame`.
