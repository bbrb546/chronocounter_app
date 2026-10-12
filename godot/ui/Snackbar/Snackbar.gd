class_name Snackbar
extends PanelContainer

signal action_pressed

var _label: Label
var _action: SecondaryButton
var _timer: Timer

func _init() -> void:
	visible = false

func _ready() -> void:
	add_theme_stylebox_override("panel", ThemeFactory.box(DesignTokens.SURFACE_RAISED))
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_label)
	_action = SecondaryButton.new()
	row.add_child(_action)
	_action.pressed.connect(func() -> void:
		action_pressed.emit()
		dismiss())
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(dismiss)
	add_child(_timer)
	get_viewport().size_changed.connect(_place)

func show_message(message: String, action: String = "", duration: float = DesignTokens.SNACKBAR_DURATION) -> void:
	_label.text = message
	_action.text = action
	_action.visible = not action.is_empty()
	show()
	_place.call_deferred()
	_timer.start(duration)

func dismiss() -> void:
	_timer.stop()
	hide()

func _place() -> void:
	var insets: Vector4 = SafeAreaContainer.viewport_insets(get_viewport_rect().size)
	var viewport_size: Vector2 = get_viewport_rect().size
	size = Vector2(viewport_size.x - insets.x - insets.z - DesignTokens.SPACE_48, get_combined_minimum_size().y)
	position = Vector2(insets.x + DesignTokens.SIDE_MARGIN, viewport_size.y - insets.w - DesignTokens.SPACE_24 - size.y)
