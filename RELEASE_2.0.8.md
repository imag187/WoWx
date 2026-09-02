# WoWX 2.0.8 Hotfix

## Summary
Always-on (platformer) mouse-look now supports a temporary cursor escape window.

## Fixed
- Manual mouselook release in always-on mode no longer re-captures instantly.
- New controller setting `platformerCursorEscapeMs` (default 3000 ms) controls how long cursor mode stays available.
- If movement resumes during the escape window, WoWX immediately re-captures mouselook.

## Why
Always-on mode previously re-entered mouselook too aggressively, making it difficult to use cursor-driven interactions like bags or game menu actions while standing still.
