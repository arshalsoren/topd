# Preferences guide

Open Preferences from the gear button in the popover, or right-click the menu bar icon.

| Section | What it controls |
| --- | --- |
| General | Launch at login |
| Customize | Icon (topd logo, gauge, waveform, chip, trend) and theme. With the System theme, choose the dark and light themes |
| At a glance | Show one to three cards with their values in the menu bar, in place of the icon |
| Cards | Turn each card on or off, and drag the handle to reorder. At least one card stays on |
| Processes | Show or hide the top-5 CPU list and the top-5 memory list |

## Themes

Default (translucent), System, Dracula, Nord, One Dark, GitHub Light, Ayu Light,
Gruvbox Light, Synthwave, Ember, Slate, and Ocean. Themes change the app's chrome only. Chart
colors stay on one fixed, contrast-checked palette.

## Launch at login

Turn it on in General. topd registers through `SMAppService`, which needs the app bundle that
`run.sh` builds. If macOS asks for approval, allow topd in System Settings, General, Login Items.
