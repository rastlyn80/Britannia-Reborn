# UltimaClone continuity

Read docs/MASTER_PLAN.md, docs/PROGRESS.md and docs/ROADMAP.md before continuing. Preserve the imported converter/IR/Godot foundation. Work in this repository; leave the original Documents/Codex prototype and UO installation unchanged.

ModernUO is authoritative and pinned in Server/dependencies.json. Its source checkout and runtime are separate and ignored by the root repository. Follow its local instructions when working inside it; prefer isolated extension modules and avoid core/gameplay edits. ClassicUO in work/reference is a reference, not a linked client dependency.

Run scripts/verify.ps1 after relevant changes and scripts/test-login.ps1 for live login changes. Server setup/build/start commands are documented in README.md. Never call a game relay world entry, or fixture/offline movement multiplayer. Update progress/roadmap with actual evidence and remaining gaps.

Do not commit game source files, game-derived local IR/screenshots, credentials, configurations, saves, tools or caches. Keep new assets traceable to exact sources/licenses. No publication, purchases or upstream submissions without user authorization.
