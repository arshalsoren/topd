# topd: product brief (v0.1)

Status: scope accepted by the founder, 2026-11-17. Local only.

## Problem

Activity Monitor needs a window and a trip to a separate app. Menu bar stats apps show numbers, but not the answer to "what is making my Mac slow?" Process monitoring is the hero feature.

## User and journey

Mac users who reach for `htop` or Activity Monitor when the fan spins up. They want the answer from the menu bar in one click.

1. **Glance.** The menu bar shows the chosen metrics as icons and numbers (1 to 3).
2. **Click.** A glass popover shows six metric cards in a 3×2 grid, then the top 5 processes by CPU and by memory.
3. **Find.** Search filters all processes by name or PID. Sort orders the rows.
4. **Leave.** Escape or click away. Nothing stays open.
5. **Configure.** Right-click for Preferences, all in menu items. No settings window.

## v0.1 scope

- Six cards: CPU, Memory, GPU, Storage, System, Network. Each has its own chart. Charts follow the validated categorical palette, with one fixed hue per card.
- Two process lists: top 5 by CPU (CPU % and RAM), top 5 by memory (CPU % and RAM).
- Search and sort across the process lists.
- Preferences: toggle each card and each process list. At least one card stays on. At-a-glance shows 1 to 3 cards that are on.
- Menu bar only: no Dock icon, no window.
- Launch with `run.sh`. The README suggests an alias.

## Non-goals for v0.1

- Killing, renicing, or otherwise changing processes.
- Privileged data. Processes the user cannot inspect are skipped.
- Notifications, alerts, history beyond 60 seconds, telemetry, accounts, sync, or any network access.

## Success measures

- Primary: a user answers "which process is using my CPU?" from the menu bar within 3 seconds of clicking. Not yet measured; needs five people.
- Guardrail: idle CPU under 1% with the popover closed. Measured at 0.38% average over 30 seconds on the development Mac.
- Guardrail: CPU under 2% with the popover open. Not yet measured.

## Assumptions

- Per-process CPU and memory are readable through `libproc` for the current user's processes.
- The GPU counter is readable without privileges on Apple Silicon. It is undocumented, so the card falls back to "not reported" if it disappears.
- Minimum macOS 14 (Swift Charts, Observation).
