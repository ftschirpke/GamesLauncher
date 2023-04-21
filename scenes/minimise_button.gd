extends Button

@onready var window: Window = get_viewport().get_window()

func _on_pressed() -> void:
    window.mode = Window.MODE_MINIMIZED
