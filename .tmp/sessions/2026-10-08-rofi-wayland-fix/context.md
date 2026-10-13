# Task Context: Rofi Wayland fix (GNOME)

Session ID: 2026-10-08-rofi-wayland-fix
Created: 2026-10-08T17:40:36Z
Status: in_progress

## Current Request
Fix `vaultkit` crash: `Rofi on wayland requires support for the layer shell protocol` (lib/ui-rofi.sh linha 17).

## Context Files (Standards to Follow)
- /home/val/.opencode/context/core/standards/code-quality.md
- /home/val/.opencode/context/core/workflows/component-planning.md

## Reference Files (Source Material to Look At)
- /home/val/Github/+/rofi-snippet-holder/lib/ui-rofi.sh (rofi_menu, lines 17-23)
- /home/val/Github/+/rofi-snippet-holder/vaultkit.sh
- /home/val/Github/+/rofi-snippet-holder/install.sh

## External Docs Fetched
None — known upstream limitation: rofi 2.0 (davatorium, provides rofi-wayland) requires wlr-layer-shell; GNOME Mutter doesn't implement it.

Env discovered:
- XDG_SESSION_TYPE=wayland, XDG_CURRENT_DESKTOP=GNOME, WAYLAND_DISPLAY=wayland-0, DISPLAY=:1
- rofi 2.0.0-1.1 (cachyos-extra-v3)

## Components
- rofi_menu() Wayland backend selection (single function, single file)

## Constraints
- Minimal change, single file, no new dependencies
- Keep native layer-shell on Sway/Hyprland/wlroots; force XWayland only where needed (GNOME Wayland)
- Follow code-quality: small focused function, explicit, no global side effects

## Exit Criteria
- [ ] `rofi_menu()` detects GNOME Wayland and forces X11 backend (WAYLAND_DISPLAY="" + -normal-window)
- [ ] `bash -n lib/ui-rofi.sh` passes
- [ ] Non-GNOME Wayland behavior unchanged
