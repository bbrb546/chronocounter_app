class_name DesignTokens
extends RefCounted

# SPEC §6: all dimensions are base-viewport pixels.
const BG: Color = Color("0e0f12")
const SURFACE: Color = Color("1a1c21")
const SURFACE_RAISED: Color = Color("252830")
const SCRIM: Color = Color(0, 0, 0, 0.6)
const TEXT_PRIMARY: Color = Color("f2f3f5")
const TEXT_SECONDARY: Color = Color("a4a9b4")
const ACCENT: Color = Color("ffc83d")
const ACCENT_INK: Color = Color("1a1400")
const DANGER: Color = Color("ff5c5c")
const SUCCESS: Color = Color("4cd38a")
const BAR: Color = Color("1e6bff")
const DOUBLE_BAR: Color = Color("8a3ffc")
const REPEAT_BAR: Color = Color("ff7a00")
const LONG_REST: Color = Color("00a86b")
const LONG_REST_BOTTOM: Color = Color("00a3a3")
const CAPTION_SIZE: int = 32
const BODY_SIZE: int = 40
const BUTTON_SIZE: int = 44
const HEADING_SIZE: int = 56
const TITLE_SIZE: int = 72
const SPACE_12: int = 12
const SPACE_24: int = 24
const SPACE_36: int = 36
const SPACE_48: int = 48
const SPACE_72: int = 72
const RADIUS: int = 24
const SHEET_RADIUS: int = 36
const HIT_SIZE: int = 144
const ICON_SIZE: int = 96
const ICON_STROKE: int = 4
const SIDE_MARGIN: int = 24
const GESTURE_MARGIN: int = 96
const SCREEN_FADE: float = 0.3
const SHEET_SLIDE: float = 0.2
const MAX_MOTION: float = 0.3
const SNACKBAR_DURATION: float = 5.0
const SETTINGS_SAVED_DURATION: float = SNACKBAR_DURATION / 3.0
const SPINNER_PERIOD: float = 1.0
const SPINNER_SWEEP: float = TAU * 0.75
const SPINNER_SEGMENTS: int = 48
const BASE_VIEWPORT: Vector2 = Vector2(1080, 1920)
const MIN_BUTTON_HEIGHT: float = HIT_SIZE
const GAP: int = SPACE_24
const HAPTIC_TAP_MS: int = 20
const HAPTIC_HEAVY_MS: int = 50
# Explicit text/background pairings; detection colours are outlines on paper, not text.
const TEXT_PAIRS: Dictionary = {
	"primary/bg": [TEXT_PRIMARY, BG],
	"primary/surface": [TEXT_PRIMARY, SURFACE],
	"primary/raised": [TEXT_PRIMARY, SURFACE_RAISED],
	"secondary/bg": [TEXT_SECONDARY, BG],
	"secondary/surface": [TEXT_SECONDARY, SURFACE],
	"secondary/raised": [TEXT_SECONDARY, SURFACE_RAISED],
	"accent ink/accent": [ACCENT_INK, ACCENT],
	"accent ink/danger": [ACCENT_INK, DANGER],
	"danger/surface": [DANGER, SURFACE],
	"success/surface": [SUCCESS, SURFACE],
}
