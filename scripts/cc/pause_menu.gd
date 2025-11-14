extends Control
class_name PauseMenus

var _show_time: int
var _level: GridLevelCore
var _labels: Array[CensoringLabel]

@export var invert_y_btn: BaseButton
@export var sensistivity_slider: Slider
@export var menu_dialog: MenuDialog

func _enter_tree() -> void:
    if __SignalBus.on_level_pause.connect(_handle_level_pause) != OK:
        push_error("Failed to connect to level pause")

    if __SignalBus.on_update_mouse_y_inverted.connect(_handle_mouse_invert_y) != OK:
        push_error("Failed to connect to mouse y inverted")

    if __SignalBus.on_update_mouse_sensitivity.connect(_handle_mouse_sensitivity) != OK:
        push_error("Failed to connect to mouse sensitivity")

    if __SignalBus.on_update_lost_letters.connect(_handle_lost_letters) != OK:
        push_error("Failed to connect to lost letters")

func _handle_lost_letters(letters: String) -> void:
    for label: CensoringLabel in _labels:
        label.censored_letters = letters

func _handle_mouse_invert_y(inverted: bool) -> void:
    if invert_y_btn.button_pressed != inverted:
        invert_y_btn.button_pressed = inverted

func _handle_mouse_sensitivity(sensistivity: float) -> void:
    if sensistivity_slider.value != sensistivity:
        sensistivity_slider.value = sensistivity

func _handle_level_pause(level: GridLevelCore, paused: bool) -> void:
    if paused:
        _level = level
        _show_menu()

func _ready() -> void:
    _labels.append_array(find_children("", "CensoringLabel", true, false))

    invert_y_btn.button_pressed = AccessibilitySettings.mouse_inverted_y
    sensistivity_slider.value = AccessibilitySettings.mouse_sensitivity
    hide()

func _unhandled_input(event: InputEvent) -> void:
    if visible && event.is_action_pressed("crawl_pause") && Time.get_ticks_msec() > _show_time + 100:
        _on_resume_on_click(null)

func _show_menu() -> void:
    get_tree().paused = true
    _show_time = Time.get_ticks_msec()
    show()

func _on_sensitivity_slider_value_changed(value: float) -> void:
    AccessibilitySettings.mouse_sensitivity = value

func _on_invert_y_axis_toggled(toggled_on: bool) -> void:
    AccessibilitySettings.mouse_inverted_y = toggled_on

func _on_letters_btn_pressed() -> void:
    hide()
    menu_dialog.show_dialog(MenuDialog.Mode.RETURN_LETTERS, "Done", show)

func _on_spoiler_battle_pressed() -> void:
    hide()
    menu_dialog.show_dialog(MenuDialog.Mode.HINT_WORDS, "Done", show)

func _on_spoiler_health_pressed() -> void:
    hide()
    menu_dialog.show_dialog(MenuDialog.Mode.HINT_EXPLORATION, "Done", show)

func _on_spoiler_cat_pressed() -> void:
    hide()
    menu_dialog.show_dialog(MenuDialog.Mode.HINT_CAT, "Done", show)

func _on_spoiler_big_room_pressed() -> void:
    hide()
    menu_dialog.show_dialog(MenuDialog.Mode.HINT_ROOM, "Done", show)

func _on_resume_on_click(_button: ContainerButton) -> void:
    get_tree().paused = false
    print_debug("[Pause Menu] Resuming")
    hide()
    if _level != null:
        _level.paused = false
        _level = null

func _on_restart_on_click(_button: ContainerButton) -> void:
    hide()
    menu_dialog.show_dialog(
        MenuDialog.Mode.WARN_RESTART,
        "Restart",
        func () -> void:
            __AudioHub.clear_all_dialogues()
            PoemEvent.clear_played_poems()
            get_tree().paused = false
            get_tree().reload_current_scene()
            ,
        "Cancel",
        show,
    )

func _on_quit_on_click(_button: ContainerButton) -> void:
    hide()
    menu_dialog.show_dialog(
        MenuDialog.Mode.WARN_QUIT,
        "Quit",
        func () -> void:
            get_tree().quit()
            ,
        "Cancel",
        show,
    )
