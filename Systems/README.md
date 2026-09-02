# WoWX Systems Layout

This folder is the browseable module boundary for WoWX-owned systems.

The goal is to make the addon readable for ongoing review and clean expansion,
instead of growing one flat directory of unrelated Lua files.

## Current folders

- `Base`: addon bootstrap and core runtime ownership.
- `Core`: shared primitives such as system registry and realm/game detection.
- `Input/Gamepad`: controller-specific helpers and future controller surfaces.
- `Input/Keyboard`: keyboard-specific helpers and future keyboard-only surfaces.
- `Transport`: action paging, proxy routing, and bar transport behavior.
- `Bags`: bag button and bag window ownership.
- `SpellGrid`: Gridbook, SpellRing, and related assignment UI.
- `UI`: control center, setup flows, navigation, and shared addon UI.
- `Cues`: prompts, frame highlights, and status overlays.
- `UnitFrames`: WoWX-owned unit frame system foundation.
- `Integration`: compatibility shims for external forks (kept thin).

## Review intent

This structure exists for two audiences:
- the primary builder maintaining WoWX long-term
- other people browsing the addon to understand how it is organized

## Design rules

- Keep gameplay ownership in WoWX.
- Keep compatibility logic in `Integration`.
- Prefer data-driven behavior over server-name conditionals spread across modules.
- Build original implementations; do not copy external addon code verbatim.
- When adding a new surface, decide first which system owns it before adding code.

## Related docs

- `GAMETYPE_DB.md`: game type / realm type / expansion type direction.
