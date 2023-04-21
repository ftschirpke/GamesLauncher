extends Control

const game_tab_scene: Resource = preload("res://scenes/subscenes/game_tab.tscn")

@onready var window: Window = get_viewport().get_window()
@onready var launcher_body: VBoxContainer = $VBoxContainer/BodyMargin/LauncherBody
@onready var game_body: MarginContainer = $VBoxContainer/BodyMargin/LauncherBody/GameBody
@onready var updating_label: Label = $VBoxContainer/BodyMargin/WhatIsGoingOnLabel

@onready var games_updater: GamesUpdater = $GamesUpdater
@onready var games_manager: GamesManager = $GamesUpdater/GamesManager

var game_tabs: Dictionary = {}

var drag_position = null

func _on_draggable_header_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == 1:
        if event.is_pressed():
            drag_position = get_global_mouse_position()
        else:
            drag_position = null
    if drag_position and event is InputEventMouseMotion:
        window.position += Vector2i(get_global_mouse_position() - drag_position)

func _ready() -> void:
    launcher_body.visible = false
    updating_label.visible = true
    
    if games_updater.is_done:
        _on_games_updater_fetched_all_game_versions()
    else:
        games_updater.fetched_all_game_versions.connect(_on_games_updater_fetched_all_game_versions)

func _on_installation_state_change_requested(game_name: String, install: bool) -> void:
    if install:
        games_updater.install_game(game_name)
    else:
        games_updater.uninstall_game(game_name)

func _on_games_updater_fetched_all_game_versions() -> void:
    for game_name in games_manager.games:
        var game: GamesManager.Game = games_manager.get_game(game_name)
        var new_tab = game_tab_scene.instantiate()
        game_body.add_child(new_tab)
        new_tab.visible = false
        new_tab.game_config = game
        new_tab.change_installation_state.connect(_on_installation_state_change_requested)
        new_tab.cancel_installation.connect(games_updater.cancel_installation)
        game_tabs[game_name] = new_tab
    launcher_body.create()
    updating_label.visible = false
    launcher_body.visible = true

func _on_installation_state_changed(game_name: String) -> void:
    games_manager.save_games_manager()

func _on_games_updater_game_installed(game_name: String) -> void:
    _on_installation_state_changed(game_name)
    game_tabs[game_name].installation_state_was_changed()

func _on_games_updater_game_uninstalled(game_name: String) -> void:
    _on_installation_state_changed(game_name)
    game_tabs[game_name].installation_state_was_changed()
