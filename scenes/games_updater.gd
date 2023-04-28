extends HTTPRequestManager
class_name GamesUpdater
#@onready var window: Window = get_viewport().get_window()
#@onready var scene_tree: SceneTree = get_tree()
#@onready var label: Label = $VBoxContainer/BodyMargin/StarterBody/WhatIsGoingOnLabel

signal fetched_all_game_versions
signal game_installed(game_name: String)
signal game_uninstalled(game_name: String)

var installers: Dictionary = {}

@onready var games_manager: GamesManager = $GamesManager

const TWENTY_MINUTES: float = 1200
const GET_REPOS_URL: String = "https://api.github.com/users/ftschirpke/repos"

var fetching_game_completed: Dictionary = {}
var is_done: bool = false: set = _set_is_done

func _set_is_done(new_value: bool) -> void:
    is_done = new_value
    if is_done:
        fetching_game_completed.clear()
        finish_startup()

func _ready() -> void:    
    var start_timestamp: float = Time.get_unix_time_from_system()
    var look_for_updates: bool = start_timestamp - games_manager.last_fetched_timestamp >= TWENTY_MINUTES
#    look_for_updates = true # TODO - only testing

    if look_for_updates or games_manager.games.is_empty():
        create_directory_if_nonexistent("user://", "games")
        find_games()
        games_manager.last_fetched_timestamp = start_timestamp
    else:
        is_done = true

func finish_startup() -> void:
    games_manager.save_games_manager()
    emit_signal("fetched_all_game_versions")

func find_games() -> void:
    make_http_request(_on_find_games_request_completed, GET_REPOS_URL)

func _on_find_games_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    var games: Array[String] = []
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("HTTP Request to find games was not successful")
    var json: Array = JSON.parse_string(body.get_string_from_utf8())
    for repo_dict in json:
        var topics: Array = repo_dict["topics"]
        if "game" in topics and "godot" in topics:
            games.append(repo_dict["name"])
    for game_name in games:
        fetch_game_updates(game_name)
    if len(games) == 0:
        is_done = true

func fetch_game_updates(game_name: String) -> void:
    games_manager.add_game(game_name)
    var game_to_fetch: GamesManager.Game = games_manager.get_game(game_name)
    var game_updates_fetcher: GameUpdatesFetcher = GameUpdatesFetcher.new(game_to_fetch)
    game_updates_fetcher.game_updates_fetched.connect(_on_game_updates_fetched)
    add_child(game_updates_fetcher)
    fetching_game_completed[game_name] = false
    
func _on_game_updates_fetched(game_name: String) -> void:
    fetching_game_completed[game_name] = true
    for g_name in fetching_game_completed:
        if not fetching_game_completed[g_name]:
            return
    is_done = true

func install_game(game_name: String) -> void:
    var game_to_install: GamesManager.Game = games_manager.get_game(game_name)
    var game_installer: GameInstaller = GameInstaller.new(game_to_install)
    game_installer.install_done.connect(_game_install_done)
    add_child(game_installer)
    installers[game_name] = game_installer

func _game_install_done(game_name: String) -> void:
    installers.erase(game_name)
    emit_signal("game_installed", game_name)

func cancel_installation(game_name: String) -> void:
    var installer: GameInstaller = installers.get(game_name, null)
    if installer != null:
        installer.cancel_installation()
    
func uninstall_game(game_name: String) -> void:
    var game: GamesManager.Game = games_manager.get_game(game_name)
    
    delete_game_file(game_name, game.local_state.exe_name)
    delete_game_file(game_name, game.local_state.pck_name)
    
    game.local_state.installed = false
    game.local_state.install_path = ""
    game.local_state.installed_version = ""
    game.local_state.exe_name = ""
    game.local_state.pck_name = ""
    game.local_state.release_notes = ""
    
    emit_signal("game_uninstalled", game_name)
