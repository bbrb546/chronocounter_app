extends Node2D

signal marker_tapped(marker: DetectionMarker)

const MARKER: PackedScene = preload("res://scenes/detection_marker/detection_marker.tscn")
const ICON_BUTTON: PackedScene = preload("res://ui/IconButton/IconButton.tscn")
const PILL: PackedScene = preload("res://ui/Pill/Pill.tscn")
const SPINNER: PackedScene = preload("res://ui/Spinner/Spinner.tscn")

@onready var photo: Sprite2D = $World/Photo
@onready var markers: Node2D = $World/Markers
@onready var line_numbers: LineNumberOverlay = $World/LineNumberOverlay
@onready var camera: Camera2D = $World/Camera2D
@onready var picker: MarkerPicker = $World/MarkerPicker
@onready var chrome: Control = $UI/SafeArea/Chrome
var left_arrow: IconButton
var right_arrow: IconButton
var edit_popup: EditPopup
var snackbar: Snackbar
var check_pill: Pill
var _view_before_edit: Dictionary = {}
var _selected: DetectionMarker
var _undo: Dictionary = {}
var _undo_deadline: int = 0
var indicator: Pill
var labels: CheckButton
var message: Label
var loading: VBoxContainer
var _task: int = -1
var _decoded: Image
var _decode_error: Error = OK
var _decode_index: int = -1
var _started_ms: int = 0
var _idle: float = 0.0
var _image_size: Vector2 = Vector2.ZERO
var _top: Panel
var _bottom: HBoxContainer

func _ready() -> void:
	$Backdrop/Background.color = DesignTokens.BG
	camera.ui_root = $UI
	camera.marker_picker = picker
	_build_ui()
	camera.view_zoom_changed.connect(_on_zoom_changed)
	chrome.resized.connect(_layout_ui)
	get_viewport().size_changed.connect(fit_to_screen)
	AppState.numbering_changed.connect(_on_numbering_changed)
	edit_popup = preload("res://scenes/edit_popup/edit_popup.tscn").instantiate()
	$UI.add_child(edit_popup)
	edit_popup.applied.connect(func(_data: DetectionData) -> void: _renumber())
	edit_popup.delete_requested.connect(_delete_detection)
	edit_popup.closed.connect(_on_edit_closed)
	picker.empty_tapped.connect(edit_popup.close)
	snackbar = preload("res://ui/Snackbar/Snackbar.tscn").instantiate()
	$UI.add_child(snackbar)
	snackbar.action_pressed.connect(_undo_delete)
	show_page(AppState.current_page_index)
	_layout_ui.call_deferred()

func _icon(name_: String, description: String) -> IconButton:
	var button: IconButton = ICON_BUTTON.instantiate()
	button.icon = load("res://theme/icons/%s.svg" % name_)
	button.tooltip_text = description
	return button

func _build_ui() -> void:
	_top = Panel.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_theme_stylebox_override("panel", ThemeFactory.box(DesignTokens.RESULTS_TOP_SURFACE, DesignTokens.RADIUS, 0))
	chrome.add_child(_top)
	var menu: IconButton = _icon("settings", "Menu")
	_top.add_child(menu)
	indicator = PILL.instantiate()
	_top.add_child(indicator)
	check_pill = PILL.instantiate()
	_top.add_child(check_pill)
	left_arrow = _icon("chevron-left", "Previous page")
	right_arrow = _icon("chevron-right", "Next page")
	for arrow: IconButton in [left_arrow, right_arrow]:
		chrome.add_child(arrow)
		var style: StyleBoxFlat = ThemeFactory.box(Color(DesignTokens.BG, DesignTokens.RESULTS_ARROW_ALPHA), DesignTokens.HIT_SIZE / 2, DesignTokens.SPACE_24)
		for state: String in ["normal", "hover", "disabled"]:
			arrow.add_theme_stylebox_override(state, style)
	left_arrow.pressed.connect(func() -> void: show_page(AppState.current_page_index - 1))
	right_arrow.pressed.connect(func() -> void: show_page(AppState.current_page_index + 1))
	_bottom = HBoxContainer.new()
	_bottom.add_theme_constant_override("separation", DesignTokens.SPACE_48)
	chrome.add_child(_bottom)
	var reset: IconButton = _icon("reset-view", "Reset view")
	reset.pressed.connect(fit_to_screen)
	_bottom.add_child(reset)
	labels = CheckButton.new()
	labels.text = "Labels"
	labels.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	labels.toggled.connect(_set_labels)
	_bottom.add_child(labels)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_stylebox_override("normal", ThemeFactory.box(DesignTokens.SURFACE, DesignTokens.RADIUS, DesignTokens.SPACE_24))
	chrome.add_child(message)
	loading = VBoxContainer.new()
	loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spinner: Spinner = SPINNER.instantiate()
	spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	loading.add_child(spinner)
	var caption: Label = Label.new()
	caption.text = "Loading photo…"
	loading.add_child(caption)
	chrome.add_child(loading)
	loading.hide()

func _layout_ui() -> void:
	var extent: Vector2 = chrome.size
	_top.size = Vector2(extent.x, DesignTokens.HIT_SIZE)
	_layout_status_pills()
	var inset: float = DesignTokens.GESTURE_MARGIN - DesignTokens.SIDE_MARGIN
	left_arrow.position = Vector2(inset, (extent.y - DesignTokens.HIT_SIZE) / 2)
	right_arrow.position = Vector2(extent.x - inset - DesignTokens.HIT_SIZE, left_arrow.position.y)
	_bottom.size = _bottom.get_combined_minimum_size()
	_bottom.position = Vector2((extent.x - _bottom.size.x) / 2, extent.y - _bottom.size.y - DesignTokens.SPACE_72)
	message.size = Vector2(extent.x - 2 * DesignTokens.GESTURE_MARGIN, DesignTokens.HIT_SIZE * 2)
	message.position = Vector2(DesignTokens.GESTURE_MARGIN, extent.y * 0.65)
	loading.size = loading.get_combined_minimum_size()
	loading.position = (extent - loading.size) / 2
	fit_to_screen()

func show_page(index: int) -> void:
	_view_before_edit.clear()
	edit_popup.close()
	_clear_selection()
	AppState.current_page_index = clampi(index, 0, maxi(0, AppState.pages.size() - 1))
	_refresh_line_numbers()
	_refresh_check_count()
	photo.texture = null
	_image_size = Vector2.ZERO
	for child: Node in markers.get_children():
		child.free()
	loading.hide()
	indicator.text = "%d / %d" % [AppState.current_page_index + 1 if not AppState.pages.is_empty() else 0, AppState.pages.size()]
	left_arrow.disabled = AppState.current_page_index <= 0
	right_arrow.disabled = AppState.current_page_index >= AppState.pages.size() - 1
	message.text = "No bars or rests found on this page"
	message.show()
	_idle = 0.0
	if AppState.pages.is_empty():
		message.text = "No pages to show"
		return
	var page: PhotoPage = AppState.pages[AppState.current_page_index]
	if page.status == PhotoPage.Status.DONE:
		for line: Array in page.lines:
			for detection: DetectionData in line:
				var marker: DetectionMarker = MARKER.instantiate()
				markers.add_child(marker)
				marker.setup(detection)
				marker.show_labels = labels.button_pressed
				marker.tapped.connect(_on_marker_tapped)
	message.visible = markers.get_child_count() == 0
	# One worker at a time; a superseded decode is discarded before starting another.
	if _task == -1:
		_start_decode()

func _refresh_line_numbers() -> void:
	var index: int = AppState.current_page_index
	line_numbers.refresh(AppState.pages[index] if index >= 0 and index < AppState.pages.size() else null)

func _start_decode() -> void:
	_decode_index = AppState.current_page_index
	var page: PhotoPage = AppState.pages[_decode_index]
	_started_ms = Time.get_ticks_msec()
	_task = WorkerThreadPool.add_task(_decode.bind(page.bytes, page.mime))

func _decode(bytes: PackedByteArray, mime: String) -> void:
	var image: Image = Image.new()
	match mime:
		"image/png": _decode_error = image.load_png_from_buffer(bytes)
		"image/jpeg": _decode_error = image.load_jpg_from_buffer(bytes)
		"image/webp": _decode_error = image.load_webp_from_buffer(bytes)
		_: _decode_error = ERR_FILE_UNRECOGNIZED
	_decoded = image if _decode_error == OK else null

func _process(delta: float) -> void:
	_keep_selection_visible()
	_idle += delta
	for arrow: IconButton in [left_arrow, right_arrow]:
		arrow.modulate.a = DesignTokens.RESULTS_IDLE_ALPHA / DesignTokens.RESULTS_ARROW_ALPHA if _idle >= DesignTokens.RESULTS_IDLE_SECONDS else 1.0
	if _task == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task):
		loading.visible = Time.get_ticks_msec() - _started_ms >= DesignTokens.RESULTS_SPINNER_DELAY_MS
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	loading.hide()
	if _decode_index != AppState.current_page_index or AppState.pages.is_empty():
		_decoded = null
		if not AppState.pages.is_empty():
			_start_decode()
		return
	if _decoded != null:
		_image_size = _decoded.get_size()
		photo.texture = ImageTexture.create_from_image(_decoded)
		_decoded = null
		fit_to_screen()
	else:
		message.text = "Could not load this photo"
		message.show()

func fit_to_screen() -> void:
	var origin: Vector2 = chrome.global_position + Vector2(0, DesignTokens.HIT_SIZE + DesignTokens.SPACE_24)
	var available: Vector2 = Vector2(chrome.size.x, _bottom.global_position.y - DesignTokens.SPACE_24 - origin.y)
	camera.fit_to_screen(_image_size, Rect2(origin, available))

func _on_zoom_changed(value: float) -> void:
	picker.set_view_zoom(value)
	for marker: DetectionMarker in markers.get_children():
		marker.set_view_zoom(value)

func _set_labels(value: bool) -> void:
	for marker: DetectionMarker in markers.get_children():
		marker.show_labels = value

func _on_marker_tapped(marker: DetectionMarker) -> void:
	if GestureState.multitouch_active:
		return
	if _view_before_edit.is_empty():
		_view_before_edit = {"position": camera.position, "zoom": camera.zoom.x}
	for child: DetectionMarker in markers.get_children():
		child.set_selected(child == marker)
	_selected = marker
	Haptics.tap()
	edit_popup.show_detection(marker)
	_keep_selection_visible.call_deferred()
	marker_tapped.emit(marker)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or event is InputEventScreenDrag:
		_idle = 0.0

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
	_decoded = null
	photo.texture = null

func _clear_selection() -> void:
	if is_instance_valid(_selected):
		_selected.set_selected(false)
	_selected = null

func _keep_selection_visible() -> void:
	if not is_instance_valid(_selected) or not edit_popup.is_open:
		return
	camera.force_update_scroll()
	var point: Vector2 = markers.get_global_transform_with_canvas() * Vector2(_selected.data.x, _selected.data.y + _selected.data.h / 2.0)
	var limit: float = edit_popup.top_edge() - DesignTokens.SPACE_48
	if point.y > limit:
		camera.position.y += (point.y - limit) / camera.zoom.y
		camera.force_update_scroll()

func _renumber() -> void:
	NumberingEngine.number_all_pages(AppState.pages, AppState.pickup_first_bar)
	AppState.numbering_changed.emit()

func _on_numbering_changed() -> void:
	_refresh_line_numbers()
	for marker: DetectionMarker in markers.get_children():
		marker.refresh()
	_refresh_check_count()

func _refresh_check_count() -> void:
	var count: int = 0
	if not AppState.pages.is_empty():
		for line: Array in AppState.pages[AppState.current_page_index].lines:
			for data: DetectionData in line:
				if data.is_long_rest() and data.needs_check:
					count += 1
	check_pill.text = "%d to check" % count
	check_pill.visible = count > 0
	_layout_status_pills()

func _delete_detection(data: DetectionData) -> void:
	var page: PhotoPage = AppState.pages[AppState.current_page_index]
	for line_index: int in range(page.lines.size()):
		var line: Array = page.lines[line_index]
		var detection_index: int = line.find(data)
		if detection_index < 0:
			continue
		_undo = {"page": page, "line": line_index, "index": detection_index, "dropped": line.size() == 1, "data": data}
		_undo_deadline = Time.get_ticks_msec() + roundi(DesignTokens.SNACKBAR_DURATION * 1000)
		line.remove_at(detection_index)
		if line.is_empty():
			page.lines.remove_at(line_index)
		edit_popup.close()
		_clear_selection()
		for marker: DetectionMarker in markers.get_children():
			if marker.data == data:
				markers.remove_child(marker)
				marker.queue_free()
		Haptics.heavy()
		_renumber()
		message.visible = markers.get_child_count() == 0
		snackbar.show_message("Detection deleted.", "Undo")
		return

func _undo_delete() -> void:
	if _undo.is_empty() or Time.get_ticks_msec() >= _undo_deadline:
		_undo.clear()
		return
	var page: PhotoPage = _undo.page
	if _undo.dropped:
		page.lines.insert(_undo.line, [])
	page.lines[_undo.line].insert(_undo.index, _undo.data)
	if not AppState.pages.is_empty() and page == AppState.pages[AppState.current_page_index]:
		var marker: DetectionMarker = MARKER.instantiate()
		markers.add_child(marker)
		marker.setup(_undo.data)
		marker.show_labels = labels.button_pressed
		marker.set_view_zoom(camera.zoom.x)
		marker.tapped.connect(_on_marker_tapped)
		message.hide()
	_undo.clear()
	_renumber()

func _layout_status_pills() -> void:
	indicator.size = indicator.get_combined_minimum_size()
	indicator.position = Vector2((chrome.size.x - indicator.size.x) / 2, (DesignTokens.HIT_SIZE - indicator.size.y) / 2)
	check_pill.size = check_pill.get_combined_minimum_size()
	var group_width: float = indicator.size.x + (DesignTokens.SPACE_12 + check_pill.size.x if check_pill.visible else 0.0)
	indicator.position.x = maxf(DesignTokens.HIT_SIZE, (chrome.size.x - group_width) / 2.0)
	check_pill.position = Vector2(indicator.position.x + indicator.size.x + DesignTokens.SPACE_12, indicator.position.y)

func _on_edit_closed() -> void:
	_clear_selection()
	if not _view_before_edit.is_empty():
		camera.position = _view_before_edit.position
		camera._set_zoom(_view_before_edit.zoom)
		camera.force_update_scroll()
		_view_before_edit.clear()
