class_name UiPalette
extends RefCounted
## The colours every screen shares: gold leaf on dark parchment (GDD "Art Direction": heraldic
## tinctures carry meaning, blattgold on UI frames).

const GOLD := Color(1.0, 0.82, 0.30)
const TEXT := Color(0.96, 0.91, 0.80)
const MUTED := Color(0.74, 0.66, 0.54)
const GOOD := Color(0.62, 0.86, 0.46)
const BAD := Color(1.0, 0.52, 0.40)
const INK := Color(0.10, 0.07, 0.05)
const PANEL := Color(0.17, 0.12, 0.08, 0.96)
## Panels inside panels, tooltips and dropdown lists.
const INSET := Color(0.12, 0.08, 0.05, 0.98)
const BUTTON := Color(0.27, 0.19, 0.12)
const BUTTON_HOVER := Color(0.36, 0.26, 0.16)
const BUTTON_PRESSED := Color(0.48, 0.33, 0.14)
const BUTTON_DISABLED := Color(0.20, 0.15, 0.11)
## Backdrop behind modal screens; use it opaque to hide the scene, translucent to dim it.
const SHADE := Color(0.07, 0.05, 0.04)
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
