### 0. Repository layout and ground rules

```
chronocounter/
  docs/        SPEC.md  UI_GUIDE.md  SERVER.md  ANDROID.md  QA.md  UI_STATES.md  screenshots/
  godot/       the Godot 4.6.3 project; res:// maps to this folder
  reference/   pipeline/ (read-only Python)  native-camera/ (README + demo)  assets/ (optional fonts, icons)
```

- Paths like `docs/SPEC.md` are relative to the repository root. Paths starting `res://` are inside `godot/`.
- Treat `reference/` as read-only. Read the pipeline files to confirm numbering and the JSON shape, but never edit or run them, and never put an API key anywhere in the repository. `reference/pipeline/` already contains the Appendix A changes, which the user makes in the real pipeline before copying it; Prompt 1 checks this.
- The project already exists and the Native Camera Plugin is already installed. The user exports and installs the project personally: never edit export presets, the Android build template or the manifest, never touch SDK or JDK settings, and never try to build an APK or AAB. Anything else that needs the Godot editor UI (such as a plugin toggle) is the user's job too: list it instead of attempting it.
- At the start, check whether you can run `godot --headless` here. If you cannot, give exact commands for me to run and I will paste the output back.

### 1. What we are building

Chronocounter is a Godot 4.6.3 mobile app (typed GDScript, Compatibility renderer, portrait only, dark camera-style UI, Android first, iOS later; developed and tested on a Google Pixel 6a). The user photographs pages of sheet music, the app sends them one at a time to a FastAPI server on the local network, and the server returns detected bars and long rests. The app draws the detections over each photo, shows the running measure number at the start of every staff line (the main output), and lets the user fix mistakes by changing a long rest's length or deleting a detection. Everything lives in memory for the session. Only settings persist: the server URL, the mock-mode flag, the haptics switch and which first-run hints have been shown.

### 2. Server API (do not change the server)

- `POST {base_url}/count?initial_measure_number=N`, N >= 1.
- Body is the raw image bytes. Content-Type must be exactly `image/png`, `image/jpeg` or `image/webp` and must match the bytes. The server limit is 10 MB; the app keeps uploads at or under 9.5 MiB (9,961,472 bytes).
- A 200 response is a JSON array of staff lines, top to bottom. Each line is an array of detections, left to right: `{class, x, y, width, height, measure_number, measures_spanned?, measures_spanned_confident?}`. x and y are the box CENTER in pixels of the image that was sent. `measures_spanned` and `measures_spanned_confident` exist only on long rests. `measures_spanned_confident` is false when the server could not read the rest's number confidently and used a fallback guess (see Appendix A). The app treats a missing value as true, so older fixtures still work, and the flag never affects numbering.
- Classes: `bar`, `repeat bar`, `double bar`, `long rest`, `long rest bottom`.
- Errors: 400 invalid or empty image, 413 over 10 MB, 415 wrong content type, 503 server has no Roboflow key. A request can take tens of seconds.
- The server runs with `uvicorn api:app --host 0.0.0.0 --port 8000` and the environment variable `ROBOFLOW_API_KEY`. Local network, plain HTTP.
- Constant `DEFAULT_API_URL = 'http://192.168.1.100:8000'`, editable in Settings.
- The `initial_measure_number` the app sends is provisional (see section 4). The app resolves the real initial number after each response and renumbers locally; it never displays the server's numbers.

### 3. Coordinates

The app displays exactly the image it uploaded, so detection coordinates map 1:1 to that image's pixels. No scaling anywhere. World space equals image pixel space.

### 4. Numbering rules

The server numbers detections with the algorithm below. Port it exactly into `NumberingEngine.gd` so the app can renumber locally after edits.

```
measure_num = initial; first_counted = true; pcls = 'fpbar'
for each line:
  for each detection d, left to right:
    cls = d.class
    d.measure_number = measure_num
    if cls is 'long rest' or 'long rest bottom':
      first_counted = false
      d.measures_spanned = n          # the editable duration
      measure_num += n
    elif cls is 'bar', 'repeat bar' or 'double bar':
      if not first_counted and pcls in {bar, repeat bar, double bar, 'pbar', 'fpbar'}:
        measure_num += 1
      d.measure_number = measure_num
      first_counted = false
    pcls = cls
  pcls = 'pbar'                       # reset at the end of every line
```

Extra rules the app adds on top:

- `end_measure(d)` is `d.measure_number + d.measures_spanned` for a long rest and `d.measure_number` for anything else. Use it everywhere a 'number after this detection' is needed. (The server's own hand-off uses the raw number, which is wrong after a long rest.)
- Page end value: `end_measure` of the rightmost detection in the last non-empty line. If the page has no detections, it is the page's own initial number minus 1, so an empty page passes the running count straight through.
- Page 1 initial number: 1 if the user ticked 'First bar is a pickup'. Otherwise 2, or 1 if the page's first detection is a long rest (so that rest starts at measure 1).
- Page N+1 initial number: `prev_end + 1`, where `prev_end` is the page N end value, or `prev_end` itself if page N+1's first detection is a long rest. The first detection is the leftmost detection of the page's first non-empty line. A page with no detections counts as starting with a bar.
- Provisional server initial: the app cannot know a page's first detection before the server answers, so it sends a provisional `initial_measure_number` (page 1: 1 with a pickup, otherwise 2; page N+1: `prev_end + 1`). After the response it resolves the real initial number with the rules above and renumbers locally. The two differ by exactly 1 whenever a page's first detection is a long rest, except on page 1 with a pickup, where they match. The server's numbers are never displayed. Server-parity checks compare against the provisional initial that was sent, so they must pass on every page.
- Line-start labels (drawn at the left of each staff line): the first non-empty line shows `first.measure_number - 1`, where `first` is its leftmost detection, unless `first` is a long rest, in which case it shows `first.measure_number`. A label can therefore be 0 (a pickup page). Each later non-empty line shows `end_measure` of the rightmost detection of the previous non-empty line. On every page after the first, the first label therefore equals the previous page's end value. This matches `algorithm1.draw_measure_numbers` after the fix in Appendix A.
- Long-rest length is an integer from 1 to 999. Delete is allowed on every detection type. There is no add-detection feature.
- `needs_check`: a long rest is flagged when the server sent `measures_spanned_confident: false` (a missing value means not flagged). The flag only prompts the user to check the number and has no effect on numbering. Applying a length in the edit sheet clears it.
- After any edit, renumber ALL pages from page 1, because an edit changes every later page's initial number. This includes a delete that changes which detection is first on a page, since that can change the page's own initial number. Never call the server again after an edit.

### 5. Architecture and conventions

```
godot/ (this is res://)
  autoload/  Settings.gd  AppState.gd  ApiClient.gd  Router.gd  GestureState.gd  Haptics.gd
  logic/     DetectionData.gd  PhotoPage.gd  NumberingEngine.gd  ImageEncoder.gd  PageProcessor.gd
  theme/     DesignTokens.gd  app_theme.tres  fonts/  icons/
  ui/        PrimaryButton  SecondaryButton  IconButton  Pill  BottomSheet  Snackbar  ConfirmDialog  Spinner  SafeAreaContainer  HintOverlay
  scenes/    main_menu  capture  processing  results  detection_marker  edit_popup
  tests/     run_all.gd (runner), test_*.gd, ui_gallery.tscn, marker_sandbox.tscn
  fixtures/  test.png, phone_photo.jpg, exif6.jpg, mock_page_<i>.jpg|png + mock_page_<i>.json pairs, predictions_<initial>.json (supplied by me)
```

Docs live outside the project, in `../docs/` (see section 0).

- Strongly typed GDScript. Logic scripts have no scene dependencies (RefCounted or static) so they run headless.
- Tests run with `godot --headless -s res://tests/run_all.gd`. The runner (created in Prompt 1) is a `SceneTree` script that finds every `res://tests/test_*.gd`, instantiates it and calls `run() -> Array`, where each element is a Dictionary `{name: String, passed: bool, detail: String}`. It prints PASS or FAIL per case and exits non-zero if any case fails or any test script errors. After adding scripts that use `class_name`, run `godot --headless --import` once so the class cache is current.
- Signals up, calls down. Constants at the top of each file, no magic numbers. Debug prints only behind `OS.is_debug_build()`. Free textures and nodes when leaving a page.
- Never guess the Native Camera Plugin's API. Read its README and demo project and use only what they document.

### 6. Visual design: dark, camera-style, portrait only

The photo is the hero. Chrome stays dark, quiet and out of the way, like a camera app, with one accent colour. Controls sit in the lower third of the screen (the thumb zone); the top bar holds only the back or menu button and status.

Units: the base viewport is 1080x1920 with `canvas_items` stretch, so on the Pixel 6a (about 411 dp wide) 1 dp is about 2.6 base px. Every size below is in base px.

| Token | Value | Use |
| --- | --- | --- |
| bg | #0E0F12 | Screen background |
| surface | #1A1C21 | Panels and sheets |
| surface\_raised | #252830 | Buttons, pills, fields |
| scrim | #000000 at 60% | Behind modal sheets |
| text\_primary | #F2F3F5 | Main text |
| text\_secondary | #A4A9B4 | Captions, hints |
| accent | #FFC83D | Primary action, selection |
| accent\_ink | #1A1400 | Text on accent |
| danger | #FF5C5C | Delete |
| success | #4CD38A | Positive status |
| class colours (drawn over white paper) | bar #1E6BFF, double bar #8A3FFC, repeat bar #FF7A00, long rest #00A86B, long rest bottom #00A3A3 | Detection boxes |
| type sizes | caption 32, body 40, button 44, heading 56, title 72 | One font family |
| spacing | 12, 24, 36, 48, 72 | Margins and gaps |
| radius | 24 (36 on the top corners of sheets) | Panels, buttons |

Rules:

- Portrait only; never rotate.
- Every button and icon button has a hit area of at least 144 px (about 55 dp on the Pixel 6a; Android's minimum is 48 dp, about 126 px). Detection markers follow their own rule in Prompt 7.
- Keep UI clear of the status bar, camera cutout and gesture bar (safe areas). Controls that are swiped or dragged (such as the thumbnail strip) and the page arrows stay at least 96 px from the left and right screen edges, where Android's back-swipe gesture lives. Plain tap targets (buttons, switches, fields) only need the SafeAreaContainer side margin of 24 px.
- Text contrast at least 4.5:1. Never rely on colour alone to show a state.
- Every screen has empty, loading and error states with short, plain, sentence-case copy.
- Motion: 150 ms screen fades, 200 ms sheet slides, ease-out, nothing over 250 ms.
- Icons are simple SVGs, 4 px stroke, 96 px box, in `res://theme/icons/`.
- Use only tokens from `DesignTokens.gd`; no hard-coded colours or sizes in scenes.

### 7. Target device: Google Pixel 6a

Sizes, performance targets and device tests assume a Google Pixel 6a. The figures come from published specs; wherever a prompt says to log or report a value, the real value on my phone wins over this table.

| Item | Pixel 6a | What it means for the app |
| --- | --- | --- |
| Screen | 6.1 in OLED, 1080x2400 (20:9), about 430 ppi, 60 Hz, punch-hole camera at top centre | With the 1080x1920 base size and `expand` aspect the viewport is 1080x2400. Layouts must stretch to the taller 20:9 shape and never assume 16:9. Target 60 fps (16.7 ms per frame); do not plan for 90 or 120 Hz. |
| Density | about 411 dp wide, so 1 dp is about 2.6 base px | 144 px is about 55 dp and 96 px is about 37 dp. Android's 48 dp minimum is about 126 px. |
| Android | ships with Android 12; has since been updated to Android 16 | Expect API 31 to 36, and API 36 on my phone unless updates are held back. Android 15 draws apps edge to edge when they target API 35, and Android 16 removes the opt-out for apps targeting API 36, so safe areas must be checked on the phone, not assumed. |
| Chip and memory | Google Tensor, 6 GB RAM, Mali-G78 GPU, 64-bit ARM | The Compatibility renderer is fine. A full 12 MP image decodes to about 48 MB, so hold at most one full-size decoded image at a time. |
| Rear camera | main 12.2 MP (4032x3024, 4:3) with OIS, plus a 12 MP ultrawide | Use the main camera. An upright portrait photo is 3024x4032. The 4:3 image does not match the 20:9 screen, so the live preview is cropped or letterboxed. |
| Navigation | gesture navigation by default, 3-button optional | Test both, including the back button and back gesture (set up in Prompt 1). Keep swipe and drag controls 96 px from the side edges and clear of the bottom gesture bar. |
