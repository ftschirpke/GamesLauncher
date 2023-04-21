extends VBoxContainer

@onready var game_select_button: Button = $GameSelectButton
@onready var game_body: MarginContainer = $GameBody

var games: Dictionary = {}

var visible_game_id: int

func create() -> void:
    var counter = 0
    for child in game_body.get_children():
        games[counter] = child
        game_select_button.add_item(child.name, counter)
        counter += 1
    game_select_button.selected = -1
    game_select_button.text = "Select Game"

func _on_game_select_button_item_selected(index: int) -> void:
    games[visible_game_id].visible = false
    games[index].visible = true
    visible_game_id = index
