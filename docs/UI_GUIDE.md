# Chronocounter UI guide

All later screens reuse this system and follow SPEC §6. `res://` refers to `godot/`. The photo is the hero; use quiet, dark chrome and one accent. Keep actions in the lower third, within thumb reach. Top bars contain only back/menu and status. The app stays portrait with a 1080 × 1920 base viewport, `canvas_items` stretch and `expand` aspect. Layout must also work at 1080 × 2400; never assume a fixed screen height.

## Tokens and theme

`res://theme/DesignTokens.gd` is the source of truth. Do not put literal colours or dimensions into scenes. Use the project theme `res://theme/app_theme.tres`; component variants inherit it. `ThemeFactory.gd` builds the resource from tokens. After changing tokens or theme construction, regenerate from the repository root:

```sh
godot --headless --path godot --import
godot --headless --path godot -s res://theme/build_theme.gd
godot --headless --path godot -s res://tests/run_all.gd
```

| Colour constant | Value | Usage |
| --- | --- | --- |
| BG | #0E0F12 | Screen and project clear colour |
| SURFACE | #1A1C21 | Panels, sheets |
| SURFACE_RAISED | #252830 | Secondary buttons, pills, fields |
| SCRIM | Black at 60% | Modal sheet background |
| TEXT_PRIMARY | #F2F3F5 | Main text on dark surfaces |
| TEXT_SECONDARY | #A4A9B4 | Captions, hints and disabled text on dark surfaces |
| ACCENT | #FFC83D | Primary actions and selection |
| ACCENT_INK | #1A1400 | Text on accent or danger fills |
| DANGER | #FF5C5C | Delete and error text on SURFACE |
| SUCCESS | #4CD38A | Positive status text on SURFACE |
| BAR | #1E6BFF | Bar outline over paper |
| DOUBLE_BAR | #8A3FFC | Double-bar outline over paper |
| REPEAT_BAR | #FF7A00 | Repeat-bar outline over paper |
| LONG_REST | #00A86B | Long-rest outline over paper |
| LONG_REST_BOTTOM | #00A3A3 | Long-rest-bottom outline over paper |

| Dimension or duration | Constants / values |
| --- | --- |
| Type | CAPTION_SIZE 32, BODY_SIZE 40, BUTTON_SIZE 44, HEADING_SIZE 56, TITLE_SIZE 72 |
| Spacing | SPACE_12, SPACE_24, SPACE_36, SPACE_48, SPACE_72 |
| Corners | RADIUS 24; SHEET_RADIUS 36 on the top corners only |
| Touch target | HIT_SIZE 144 in both dimensions |
| Icon | ICON_SIZE 96; ICON_STROKE 4 |
| Safe side margin | SIDE_MARGIN 24 for taps; GESTURE_MARGIN 96 for swipes, drags and page arrows |
| Screen transition | SCREEN_FADE 0.3 seconds, including both halves of the fade |
| Sheet transition | SHEET_SLIDE 0.2 seconds |
| Maximum transition | MAX_MOTION 0.3 seconds |
| Snackbar lifetime | SNACKBAR_DURATION 5 seconds; SETTINGS_SAVED_DURATION 5/3 seconds for settings confirmation |

Transitions use ease-out. The loading spinner is a continuous rotation, stopped automatically when hidden or freed. Compatibility aliases MIN_BUTTON_HEIGHT and GAP refer to HIT_SIZE and SPACE_24.

Text must contrast at least 4.5:1. `DesignTokens.TEXT_PAIRS` lists the supported combinations and the headless rule test verifies every pair. Use ACCENT_INK on filled primary/danger actions; disabled actions use TEXT_SECONDARY on SURFACE. Do not use white text on accent. Class colours are detection outlines, not text colours; accompanying labels and shapes identify their classes. Never rely on colour alone: use copy, icons, borders, switch thumb positions, or other shape changes. Progress bars should set `show_percentage = false` and put the percentage in a separate label on the dark background (as in the gallery).

The theme styles Button, Label, CheckButton, LineEdit, PanelContainer, ProgressBar and ScrollContainer. For native fields/switches also set `custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE`. Use the reusable button scenes for actions. Long text may enlarge controls beyond the minimum. Avoid small built-in scrollbar handles on mobile: use `SCROLL_MODE_SHOW_NEVER` for vertical scrolling and `SCROLL_MODE_DISABLED` horizontally, then allow touch scrolling within a 96 px safe-side wrapper.

## Fonts and icons

No `reference/assets/` font or SVGs were supplied. This version uses Godot's default font, Noto Sans (SIL Open Font License 1.1, bundled by Godot; see Godot's third-party notices). No font files are redistributed separately. Keep one font family across all type sizes. If a reference font is supplied later, copy it into `theme/fonts/`, record its actual licence here, and assign it in ThemeFactory before regenerating the theme.

The ten requested icons in `res://theme/icons/` are original simple SVG paths created for this project; they incorporate no external artwork or third-party icon licence. Each has a 96 px box, white 4 px rounded strokes: chevron-left, chevron-right, close, trash, undo, reset-view, minus, plus, settings and check. Set an accessible descriptive tooltip on every icon action. Two additional original switch-on/switch-off SVGs use the same box and stroke; their thumb positions distinguish on and off without relying on colour.

## Components

Instantiate the `.tscn` under `res://ui/<Name>/<Name>.tscn`. Scenes have scripts; dimensions and styles come from tokens. Signals travel up to the screen, which calls methods down to components.

| Component | Usage |
| --- | --- |
| PrimaryButton | Accent-filled main action. Set `text` and connect `pressed`. `disabled` and `toggle_mode`/`button_pressed` use the native Button API. One main action per context. |
| SecondaryButton | Raised-surface supporting action. Same Button API and 144 px minimum. |
| IconButton | 144 × 144 minimum hit area, 96 px icon. Assign `icon`, leave text empty, set `tooltip_text`; set `filled = true` before adding it to the tree for a filled circle. Pressed state gets an accent border. Put page arrows inside a 96 px safe-side wrapper. |
| Pill | Rounded, noninteractive counter/page indicator. Set `text`, e.g. `12 measures` or `1 / 3`. Use the scene (it contains its Label). |
| BottomSheet | Add as a full-screen overlay sibling of the screen's SafeAreaContainer. After it enters the tree, add fields/actions to its `content` VBoxContainer. Call `open()` / `close()`; listen for `opened` / `closed`. `modal = true` shows a full-screen scrim that closes on tap. `modal = false` hides the scrim and leaves outside pointer input available. Content scrolls on short viewports. The 144 px drag handle sits at least 96 px from the side edges; drag it down 96 px to dismiss. The sheet animates for 200 ms, applies its own side/bottom safe insets and restores prior focus when closed. |
| Snackbar | Add at screen root, call `show_message("Photo removed.", "Undo")`, connect `action_pressed`. Omitting the action hides its button. Auto-dismisses after 5 seconds by default; the optional third `duration` argument overrides this. Settings saved uses SETTINGS_SAVED_DURATION (about 1.67 seconds). A new message restarts the timer. `dismiss()` hides it immediately. It places itself above the bottom safe inset. |
| ConfirmDialog | A modal BottomSheet with `title`, `message`, `confirm_text`, and optional `danger`. Set properties then call `open()`. Connect `confirmed` / `cancelled`. Scrim, back, drag and Cancel dismissals emit cancelled after closing. Use explicit action copy, e.g. Delete, rather than OK. |
| Spinner | A token-coloured rotating arc drawn by `_draw`. Show with a short loading label; hide/free when work completes. It is not an interactive control. |
| SafeAreaContainer | A MarginContainer. Set `side_margin` to SIDE_MARGIN (default) or GESTURE_MARGIN. It converts DisplayServer's physical safe rectangle to viewport units and updates on resize. Every screen wraps UI in one; camera preview/photos remain full bleed behind it. `include_top_inset = false` is for a bottom sheet that must avoid only the bottom/side system areas. |

Modal sheets block pointer input outside the panel; nonmodal sheets do not. Android back dismisses the top visible sheet before navigation. Unsaved settings edits are discarded when the Settings sheet is dismissed. Settings exposes server URL, mock mode and the haptics preference; Save persists all three and shows a success snackbar. Invalid URLs and failed saves display plain error copy inside the sheet.

## Screen and device rules

- Portrait only; never rotate. Full-bleed photos/previews go behind safe-area UI.
- Every button, switch and field has a minimum hit area of 144 × 144 base px, including disabled states. Detection markers follow their separate SPEC rule when implemented.
- Keep UI clear of the status bar, camera cutout and gesture bar. Taps need 24 px side margins; swipes, drags and page arrows need 96 px. Use nested safe wrappers only when necessary and avoid applying the same system inset twice.
- Each data screen must provide empty, loading and error states with short, sentence-case copy. The menu opens in its ready state; settings provides an error label and saved snackbar. Future camera/results implementations must add their state-specific views.
- Motion is 300 ms screen fades and 200 ms sheet slides, ease-out; transitions never exceed 300 ms. The screen fade duration overrides SPEC §6 at the user’s request.
- Haptics.tap() and Haptics.heavy() are no-ops on desktop or with Settings.haptics_enabled false. Action buttons call tap automatically; danger confirmation adds heavy feedback.
- The user must enable Android **VIBRATE** when exporting, alongside INTERNET/CAMERA. See ANDROID.md. Export presets, build templates and manifests are user-owned and were not changed by this task.
- Verify safe areas and keyboard behaviour on the Pixel 6a with gesture navigation and three-button navigation, particularly on Android 16. Headless checks cannot validate the phone's physical insets, vibration or appearance.

## Review and validation

Run the gallery with:

```sh
godot --path godot res://tests/ui_gallery.tscn
```

It shows normal, disabled and pressed buttons; outlined/filled icon buttons and all icons; on/off/disabled switches; empty/filled/read-only fields; pills; spinner/progress; modal/nonmodal sheets; snackbar with/without action; normal/danger confirmation. Controls open live overlays for testing scrim dismissal, drag dismissal and outside interaction.

`tests/test_ui_rules.gd` follows SPEC §5: `run() -> Array` of `{name, passed, detail}` dictionaries. It checks supported WCAG text pairs and recursively inspects actual component, screen and gallery minimum sizes. Keep it passing as screens evolve. Refresh the class cache with `godot --headless --path godot --import` after adding `class_name` scripts.

## Capture screen

`scenes/capture/capture.tscn` fits the complete, uncropped camera preview inside the safe-area space above the bottom controls. It preserves aspect ratio with letterboxing, and the framing brackets follow the displayed image bounds. The translucent bottom panel stays below 45% of screen height at both 1080 × 1920 and 1080 × 2400. Its sideways thumbnail strip has 96 px gesture margins. Pickup is session state and defaults off. Switches show a filled track and a dark thumb on the right when on; off switches use an outline and a thumb on the left. The 216 px shutter gives tap feedback and an 80 ms white flash. Waiting for the full-resolution photo and preparing it show a Spinner and block capture, page editing and processing until the worker completes. The framing caption disappears after the first photo; a later HintOverlay can replace it.

Thumbnails open a modal BottomSheet with a larger preview, Delete and Retake. Retake selects the existing slot; use the shutter after composing the replacement. Failed or cancelled captures leave the existing page intact. Delete renumbers the thumbnail badges. There is no reordering. At 30 pages the shutter is disabled, with an explanatory message; deleting or retaking remains available. Back and Android back gestures ask the shared ConfirmDialog before discarding photos. Process currently logs page metadata in debug builds and displays a brief placeholder message.

`services/CameraService.gd` is the plugin boundary. The plugin is already enabled in `project.godot` and its installed version is 1.1.1. Runtime CAMERA permission uses its documented request/granted/denied API. Denial displays Allow camera and Open app settings; the latter opens this app's Android permission settings via Godot's AndroidRuntime/JavaClassWrapper bridge. Resume rechecks permission. The service stops the feed on pause, during encoding, while viewing a photo and on screen exit.

The reference README documents a newer wrapper than the installed files: installed FeedRequest lacks auto-upright/scaling/mirroring setters and CameraInfo lacks sensor orientation. This implementation uses only installed documented camera methods. It reads the Camera2 sensor orientation through AndroidRuntime, with a 90° Pixel 6a fallback, then uses gravity/accelerometer orientation and documented `set_rotation` to keep captures upright, including landscape-held phones despite the locked portrait UI. A diagonal dead band avoids repeated stream restarts. Orientation changes invalidate the old frame before accepting a fresh one.

The plugin has **no separate still-photo method**. The service selects the rear camera with the largest advertised output by pixel area and requests that resolution without scaling, aiming for at least 3000 px on the long side (Pixel 6a main-camera target: 4032 × 3024, or upright 3024 × 4032). The live stream instead requests a supported size close to 960 px on the long side (at most 1280 px), matching the full-resolution photo aspect ratio. If no such size exists it falls back to the full-resolution stream to preserve framing. Frames are not deliberately skipped. On shutter, the service switches to the largest-resolution stream, retains the last small preview texture, and waits for a fresh frame at the requested dimensions and rotation before emitting the photo. Late preview frames and stale generations are rejected, and a 10-second timeout restores preview and reports failure. This adds a camera-session reconfiguration delay at capture time but avoids full-resolution conversion for every preview frame. Requested preview/capture sizes and actual photo dimensions/rotation are logged in debug builds; stored pages contain encoded bytes, MIME, dimensions and a thumbnail at most 256 px, with no full-size Image retained. Encoding and thumbnail resizing run in WorkerThreadPool; texture creation stays on the main thread. Desktop/editor shutter opens a PNG/JPEG/WebP FileDialog and sends original bytes and MIME through ImageEncoder, preserving eligible PNG bytes exactly.

**Torch and tap-to-focus are omitted:** the plugin README documents neither API. No simulated controls are shown.

Run `godot --headless --path godot -s res://tests/run_all.gd` for import/encoding, replacement, deletion, page-cap, discard and layout checks. On the Pixel 6a verify live preview throughput, the logged largest output and actual photo dimensions, upright captures in all four held orientations, denial twice then app-settings recovery, pause/resume, safe areas with both navigation modes, flash/haptics and thumbnail swiping. Headless tests cannot establish native-camera resolution or performance; the streaming plugin may advertise a maximum below the sensor's still-photo resolution.

The settings bridge follows [Godot's Android API integration documentation](https://docs.godotengine.org/en/stable/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html). No export presets, Android templates, manifests, SDK/JDK configuration or plugin files were changed.

Snackbar geometry is measured from the message font at its final width before the first display; it does not depend on initial container layout caches. The label receives its rectangle directly, clearing the initial zero-width text layout before restoring the message so the first display contains readable text. The message and background allow pointer input to pass through, while an optional action button remains interactive. Regression tests cover first/repeated size and menu input while the first snackbar is visible.
