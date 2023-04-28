extends Node
class_name GamesManager

const games_manager_file: String = "user://games.save"

var games: Dictionary = {}
var last_fetched_timestamp: float

class Game:
    var repo_name: String
    var settings: GameSettings
    var local_state: LocalGameState
    var update_info: UpdateInfo
    
    func _init(game_name: String) -> void:
        repo_name = game_name
        settings = GameSettings.new()
        local_state = LocalGameState.new()
        update_info = UpdateInfo.new()

class GameSettings:
    pass

class LocalGameState:
    var installed: bool
    var install_path: String
    var installed_version: String
    var exe_name: String
    var pck_name: String
    
    var config_commit_sha: String
    var icon_commit_sha: String

    var config: Dictionary
    var release_notes: String


class UpdateInfo:
    var latest_version: String
    var exe_download_url: String
    var pck_download_url: String
    var exe_name: String
    var pck_name: String
    var exe_size_in_bytes: int
    var pck_size_in_bytes: int
    var release_notes: String

func _ready() -> void:
    load_games_manager()

func get_game(game_name: String) -> Game:
    return games.get(game_name)

func add_game(game_name: String) -> void:
    if game_name not in games:
        games[game_name] = Game.new(game_name)

func load_games_manager() -> bool:
    var file_found: bool = FileAccess.file_exists(games_manager_file)
    if file_found:
        var file: FileAccess = FileAccess.open(games_manager_file, FileAccess.READ)
        var data: Dictionary = file.get_var()
        file.close()
        
        last_fetched_timestamp = data.get("last_fetched", 0)
        var games_data: Dictionary = data.get("games", {})
        for game_name in games_data:
            extract_game(game_name, games_data[game_name])
            
    return file_found

func extract_game(game_name: String, game_dict: Dictionary) -> void:
    var game: Game = Game.new(game_name)
    game.settings = extract_game_settings(game_dict.get("settings", {}))
    game.local_state = extract_local_game_state(game_dict.get("local_state", {}))
    game.update_info = extract_game_update_info(game_dict.get("update_info", {}))
    games[game_name] = game

func extract_game_settings(game_settings_dict: Dictionary) -> GameSettings:
    return GameSettings.new()

func extract_local_game_state(local_game_state_dict: Dictionary) -> LocalGameState:
    var local_game_state: LocalGameState = LocalGameState.new()
    local_game_state.installed = local_game_state_dict.get("installed", false)
    local_game_state.install_path = local_game_state_dict.get("install_path", "")
    local_game_state.installed_version = local_game_state_dict.get("installed_version", "")
    local_game_state.exe_name = local_game_state_dict.get("exe_name", "")
    local_game_state.pck_name = local_game_state_dict.get("pck_name", "")
    local_game_state.config_commit_sha = local_game_state_dict.get("config_commit_sha", "")
    local_game_state.icon_commit_sha = local_game_state_dict.get("icon_commit_sha", "")
    local_game_state.config = local_game_state_dict.get("config", {})
    local_game_state.release_notes = local_game_state_dict.get("release_notes", "")
    return local_game_state

func extract_game_update_info(game_update_info_dict: Dictionary) -> UpdateInfo:
    var update_info: UpdateInfo = UpdateInfo.new()
    update_info.latest_version = game_update_info_dict.get("latest_version", "")
    update_info.exe_download_url = game_update_info_dict.get("exe_download_url", "")
    update_info.pck_download_url = game_update_info_dict.get("pck_download_url", "")
    update_info.exe_name = game_update_info_dict.get("exe_name", "")
    update_info.pck_name = game_update_info_dict.get("pck_name", "")
    update_info.exe_size_in_bytes = game_update_info_dict.get("exe_size_in_bytes", 0)
    update_info.exe_size_in_bytes = game_update_info_dict.get("exe_size_in_bytes", 0)
    update_info.release_notes = game_update_info_dict.get("release_notes", "")
    return update_info

func save_games_manager() -> void:
    var games_data: Dictionary = {}
    for game_name in games:
        var game: Game = games[game_name]
        games_data[game_name] = {
            "settings": create_game_settings_dict(game.settings),
            "local_state": create_local_game_state_dict(game.local_state),
            "update_info": create_game_update_info_dict(game.update_info),
        }

    var data: Dictionary = {
        "last_fetched": last_fetched_timestamp,
        "games": games_data
    }

    var file: FileAccess = FileAccess.open(games_manager_file, FileAccess.WRITE)
    file.store_var(data)
    file.close()

func create_game_settings_dict(game_settings: GameSettings) -> Dictionary:
    return {}

func create_local_game_state_dict(local_game_state: LocalGameState) -> Dictionary:
    return {
        "installed": local_game_state.installed,
        "install_path": local_game_state.install_path,
        "installed_version": local_game_state.installed_version,
        "exe_name": local_game_state.exe_name,
        "pck_name": local_game_state.pck_name,
        "config_commit_sha": local_game_state.config_commit_sha,
        "icon_commit_sha": local_game_state.icon_commit_sha,
        "config": local_game_state.config,
        "release_notes": local_game_state.release_notes
    }
    
func create_game_update_info_dict(game_update_info: UpdateInfo) -> Dictionary:
    return {
        "latest_version": game_update_info.latest_version,
        "exe_download_url": game_update_info.exe_download_url,
        "pck_download_url": game_update_info.pck_download_url,
        "exe_name": game_update_info.exe_name,
        "pck_name": game_update_info.pck_name,
        "exe_size_in_bytes": game_update_info.exe_size_in_bytes,
        "pck_size_in_bytes": game_update_info.pck_size_in_bytes,
        "release_notes": game_update_info.release_notes,
    }
