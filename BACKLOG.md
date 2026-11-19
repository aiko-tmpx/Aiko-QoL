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
- [x] **Remove LFG Module**
  - Removed LFG companion module entirely due to Blizzard's `## Secure: 1` Group Finder restrictions causing persistent execution taints and search blocking. Players can use dedicated standalone alternatives like `LFGForever`.
