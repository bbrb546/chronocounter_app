extends Node2D

signal marker_tapped(marker: DetectionMarker)

const MARKER: PackedScene = preload("res://scenes/detection_marker/detection_marker.tscn")
const ICON_BUTTON: PackedScene = preload("res://ui/IconButton/IconButton.tscn")
const PILL: PackedScene = preload("res://ui/Pill/Pill.tscn")
const SPINNER: PackedScene = preload("res://ui/Spinner/Spinner.tscn")

@onready var photo: Sprite2D = $World/Photo
@onready var markers: Node2D = $World/Markers
@onready var camera: Camera2D = $World/Camera2D
@onready var picker: MarkerPicker = $World/MarkerPicker
@onready var chrome: Control = $UI/SafeArea/Chrome
var left_arrow: IconButton
var right_arrow: IconButton
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
	_build_ui()
	camera.view_zoom_changed.connect(_on_zoom_changed)
	chrome.resized.connect(_layout_ui)
	get_viewport().size_changed.connect(fit_to_screen)
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
	_bottom.add_child(_icon("reset-view", "Reset view"))
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
	indicator.size = indicator.get_combined_minimum_size()
	indicator.position = Vector2((extent.x - indicator.size.x) / 2, (DesignTokens.HIT_SIZE - indicator.size.y) / 2)
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
	AppState.current_page_index = clampi(index, 0, maxi(0, AppState.pages.size() - 1))
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
	for child: DetectionMarker in markers.get_children():
		child.set_selected(child == marker)
	marker_tapped.emit(marker)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or event is InputEventScreenDrag:
		_idle = 0.0

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
	_decoded = null
	photo.texture = null
