# Results verification

Verified on the desktop Compatibility renderer (Mesa llvmpipe), with a 1080 × 2400 window:

```sh
godot --path godot --display-driver x11 --rendering-method gl_compatibility -s res://tests/results_fixture_check.gd
```

The check uses all three mock PNG/JSON pairs, locally renumbers their detections, and drives the Results arrow signals. It checks all 119 / 40 / 65 marker positions and dimensions, shared photo/marker transforms, page indicators and first/last disabled states. Captured screenshots show boxes over the corresponding bars and rests.

`Performance.RENDER_TEXTURE_MEM_USED` reports **35,261,912 bytes** after each of twelve complete 3 → 2 → 3 cycles: minimum and maximum are identical. This is renderer texture memory including other textures; it is not total process memory or a phone measurement. A real renderer is required; the check rejects a zero headless measurement.

Labels toggles `show_labels` on every current-page marker in both directions. Rendered class and `m#` labels appear and disappear; at fit zoom they overlap in dense passages. Zoom/label collision behavior remains a visual limitation of the marker component.

For the format check, the third mock photo is encoded as JPEG at quality 0.95 and displayed with the same detections. PNG/JPEG dimensions, origin, rotation and scale agree; mean sampled per-channel pixel error is 0.0039061 (normalized 0–1). Screenshots confirm identical placement. This isolates format handling; it does not establish native-camera or EXIF orientation handling on Android.

`test_debug.png` is not present in this checkout. The marker endpoints agree with the formula in read-only `reference/pipeline/test.py` to less than one image pixel (the Python code truncates endpoint coordinates to integers). A direct comparison to the actual Python output remains unverified; the pipeline was not run.

The script saves screenshots to `/tmp/results-page-1.png`, `/tmp/results-page-2.png`, `/tmp/results-page-3.png`, `/tmp/results-labels-on.png`, and `/tmp/results-jpeg.png`.
