extends Button

@onready var scene_tree: SceneTree = get_tree()

signal exiting_program

func _on_pressed() -> void:
    emit_signal("exiting_program")
    scene_tree.quit()
