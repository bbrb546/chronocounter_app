extends "res://ui/plain_screen.gd"

@onready var settings_sheet: BottomSheet = $SettingsSheet
@onready var snackbar: Snackbar = $Snackbar
var url_edit: LineEdit
var mock_switch: CheckButton
var haptics_switch: CheckButton
var status_label: Label
var report_label: Label
var test_button: SecondaryButton

func _ready() -> void:
	super._ready()
	$SafeArea/Layout/Title.add_theme_font_size_override("font_size", DesignTokens.TITLE_SIZE)
	$SafeArea/Layout/Tagline.add_theme_color_override("font_color", DesignTokens.TEXT_SECONDARY)
	$SafeArea/Layout/Version.add_theme_font_size_override("font_size", DesignTokens.CAPTION_SIZE)
	$SafeArea/Layout/Version.add_theme_color_override("font_color", DesignTokens.TEXT_SECONDARY)
	$SafeArea/Layout/Version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	var heading: Label = Label.new()
	heading.text = "Settings"
	heading.add_theme_font_size_override("font_size", DesignTokens.HEADING_SIZE)
	settings_sheet.content.add_child(heading)
	var url_label: Label = Label.new()
	url_label.text = "Server URL"
	settings_sheet.content.add_child(url_label)
	url_edit = LineEdit.new()
	url_edit.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	url_edit.placeholder_text = Settings.DEFAULT_API_URL
	url_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	settings_sheet.content.add_child(url_edit)
	mock_switch = CheckButton.new()
	mock_switch.text = "Use mock server"
	mock_switch.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	mock_switch.toggled.connect(func(_on: bool) -> void: Haptics.tap())
	settings_sheet.content.add_child(mock_switch)
	haptics_switch = CheckButton.new()
	haptics_switch.text = "Haptics"
	haptics_switch.custom_minimum_size = Vector2.ONE * DesignTokens.HIT_SIZE
	settings_sheet.content.add_child(haptics_switch)
	test_button = SecondaryButton.new()
	test_button.text = "Test connection"
	test_button.pressed.connect(_test_connection)
	settings_sheet.content.add_child(test_button)
	var save: PrimaryButton = PrimaryButton.new()
	save.text = "Save"
	save.pressed.connect(_on_save_pressed)
	settings_sheet.content.add_child(save)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", DesignTokens.DANGER)
	settings_sheet.content.add_child(status_label)
	report_label = Label.new()
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.add_theme_font_size_override("font_size", DesignTokens.CAPTION_SIZE)
	report_label.add_theme_color_override("font_color", DesignTokens.TEXT_SECONDARY)
	settings_sheet.content.add_child(report_label)
	report_label.visible = OS.is_debug_build()
	if OS.is_debug_build():
		_update_device_report()
		print(report_label.text)

func _on_take_photos_pressed() -> void:
	AppState.reset_session()
	Router.goto("capture")

func _on_settings_pressed() -> void:
	url_edit.text = Settings.api_base_url
	mock_switch.button_pressed = Settings.mock_mode
	haptics_switch.button_pressed = Settings.haptics_enabled
	status_label.text = ""
	status_label.add_theme_color_override("font_color", DesignTokens.DANGER)
	status_label.hide()
	if OS.is_debug_build():
		_update_device_report()
	settings_sheet.open()

func _on_save_pressed() -> void:
	var url: String = url_edit.text.strip_edges().trim_suffix("/")
	if not (url.begins_with("http://") or url.begins_with("https://")) or url.get_slice("://", 1).is_empty():
		status_label.text = "Enter a server URL starting with http:// or https://."
		status_label.show()
		return
	var previous_url: String = Settings.api_base_url
	var previous_mock: bool = Settings.mock_mode
	var previous_haptics: bool = Settings.haptics_enabled
	Settings.api_base_url = url
	Settings.mock_mode = mock_switch.button_pressed
	Settings.haptics_enabled = haptics_switch.button_pressed
	var error: Error = Settings.save_settings()
	if error != OK:
		Settings.api_base_url = previous_url
		Settings.mock_mode = previous_mock
		Settings.haptics_enabled = previous_haptics
		status_label.text = "Could not save settings. Please try again."
		status_label.show()
		return
	settings_sheet.close()
	snackbar.show_message("Settings saved.", "", DesignTokens.SETTINGS_SAVED_DURATION)

func _update_device_report() -> void:
	report_label.text = "Model: %s\nOS: %s\nScreen: %s; DPI: %s\nSafe area: %s" % [
		OS.get_model_name(), OS.get_version(), DisplayServer.screen_get_size(),
		DisplayServer.screen_get_dpi(), DisplayServer.get_display_safe_area()]

func _test_connection() -> void:
	test_button.disabled = true
	status_label.text = "Testing connection…"
	status_label.show()
	var response: Dictionary = await ApiClient.test_connection(url_edit.text, mock_switch.button_pressed)
	if not is_inside_tree():
		return
	test_button.disabled = false
	status_label.text = "OK (mock mode)." if response.ok and mock_switch.button_pressed else ("OK. Server is reachable." if response.ok else str(response.error))
	status_label.add_theme_color_override("font_color", DesignTokens.SUCCESS if response.ok else DesignTokens.DANGER)
