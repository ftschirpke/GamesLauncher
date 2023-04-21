extends HTTPRequestManager
class_name GameUpdatesFetcher

const GET_LAST_GAME_RELEASE_URL: String = "https://api.github.com/repos/ftschirpke/%s/releases?page=1&per_page=1"
const GET_LAST_COMMIT_URL: String = "https://api.github.com/repos/ftschirpke/%s/commits?path=%s&page=1&per_page=1"

const GAME_CONFIG_FILE_NAME: String = "launcher_config.json"
const GAME_ICON_FILE_NAME: String = "launcher_icon.png"

var last_config_commit_sha: String = ""
var last_icon_commit_sha: String = ""

signal game_updates_fetched(game_name: String)

var game: GamesManager.Game

var got_release: bool = false: set = _set_got_release
var got_last_config_commit: bool = false: set = _set_got_last_config_commit
var got_last_icon_commit: bool = false: set = _set_got_last_icon_commit
var got_config: bool = false: set = _set_got_config
var got_icon: bool = false: set = _set_got_icon

func _init(game_to_fetch: GamesManager.Game) -> void:
    game = game_to_fetch
    
func _ready() -> void:
    fetch()

func _set_got_release(new_value: bool) -> void:
    got_release = new_value
    if new_value:
        _check_done()

func _set_got_last_config_commit(new_value: bool) -> void:
    got_last_config_commit = new_value
    if new_value:
        _check_done()

func _set_got_last_icon_commit(new_value: bool) -> void:
    got_last_icon_commit = new_value
    if new_value:
        _check_done()

func _set_got_config(new_value: bool) -> void:
    got_config = new_value
    if new_value:
        _check_done()

func _set_got_icon(new_value: bool) -> void:
    got_icon = new_value
    if new_value:
        _check_done()

func _check_done() -> void:
    if is_done():
        emit_signal("game_updates_fetched", game.repo_name)
        for child in get_children():
            child.queue_free()
        queue_free()

func is_done() -> bool:
    return got_release and got_last_config_commit and got_last_icon_commit and got_config and got_icon

func fetch() -> void:
    create_directory_if_nonexistent("user://games/", game.repo_name)

    make_http_request(_on_get_last_release, GET_LAST_GAME_RELEASE_URL % game.repo_name)
    
    make_http_request(_on_get_last_config_commit, GET_LAST_COMMIT_URL % [game.repo_name, GAME_CONFIG_FILE_NAME])
    make_http_request(_on_get_last_icon_commit, GET_LAST_COMMIT_URL % [game.repo_name, GAME_ICON_FILE_NAME])

func _on_get_last_release(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("HTTP Request to get game was not successful")
        got_release = true
        return
    var json: Array = JSON.parse_string(body.get_string_from_utf8())
    if len(json) == 0:
        got_release = true
        return

    var last_release: Dictionary = json[0]
    
#    var game: GamesManager.Game = games_manager.get_game(game_name)
    game.update_info.latest_version = last_release.get("name", "")
    game.update_info.release_notes = last_release.get("body", "")
    
    var pck_found: bool = false
    var exe_found: bool = false
    var release_assets: Array = last_release.get("assets", [])
    for asset_dict in release_assets:
        var asset_name: String = asset_dict.get("name", "")
        var asset_url: String = asset_dict.get("url", "")
        var asset_size: int = asset_dict.get("size", -1)
        if asset_name.ends_with(".exe"):
            if exe_found:
                push_error("Release %s has multiple .exe files, only the first will be considered.")
                continue
            else:
                exe_found = true
                game.update_info.exe_name = asset_name
                game.update_info.exe_download_url = asset_url
                game.update_info.exe_size_in_bytes = asset_size
        elif asset_name.ends_with(".pck"):
            if pck_found:
                push_error("Release %s has multiple .pck files, only the first will be considered.")
                continue
            else:
                pck_found = true
                game.update_info.pck_name = asset_name
                game.update_info.pck_download_url = asset_url
                game.update_info.pck_size_in_bytes = asset_size
    
    got_release = true

func _on_get_last_commit(file_name: String, result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> String:
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("HTTP Request to get last commit of %s/%s was not successful" % [game.repo_name, file_name])
        return ""
    var json: Array = JSON.parse_string(body.get_string_from_utf8())
    var hash: String = ""
    if len(json) > 0:
        hash = json[0].get("sha", "")
    return hash

func _on_get_last_config_commit(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    last_config_commit_sha = _on_get_last_commit(GAME_CONFIG_FILE_NAME, result, response_code, headers, body)
    got_last_config_commit = true
    if last_config_commit_sha == "" or last_config_commit_sha == game.local_state.config_commit_sha:
        got_config = true
    else:
        make_http_request(_on_config_received, GET_GAME_FILE_URL % [game.repo_name, GAME_CONFIG_FILE_NAME])
    
func _on_get_last_icon_commit(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    var last_icon_commit_sha: String = _on_get_last_commit(GAME_ICON_FILE_NAME, result, response_code, headers, body)
    got_last_icon_commit = true
    if last_icon_commit_sha == "" or last_icon_commit_sha == game.local_state.icon_commit_sha:
        got_icon = true
    else:
        make_http_request(_on_icon_received, GET_GAME_FILE_URL % [game.repo_name, GAME_ICON_FILE_NAME])

func _on_config_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("HTTP Request to get game launcher config for %s was not successful" % game.repo_name)
        got_config = true
        return
    var json: Dictionary = JSON.parse_string(body.get_string_from_utf8())
    var encoding: String = json.get("encoding", "")
    var content: String = json.get("content", "")
    var decoded_content_str: String
    if encoding == "base64":
        decoded_content_str = Marshalls.base64_to_utf8(content)
    else:
        push_error("Encoding %s not supported." % encoding)
        got_config = true
        return
    var decoded_config: Dictionary = JSON.parse_string(decoded_content_str)
    if decoded_config != null:
        game.local_state.config = decoded_config
        game.local_state.config_commit_sha = last_config_commit_sha
    got_config = true

func _on_icon_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("HTTP Request to get game launcher icon was not successful")
        got_icon = true
        return
    var json: Dictionary = JSON.parse_string(body.get_string_from_utf8())
    var encoding: String = json.get("encoding", "")
    var content: String = json.get("content", "")
    var decoded_content: PackedByteArray
    if encoding == "base64":
        decoded_content = Marshalls.base64_to_raw(content)
    else:
        push_error("Encoding %s not supported." % encoding)
        got_icon = true
        return

    var image = Image.new()
    image.load_png_from_buffer(decoded_content)
    image.save_png(GAME_FILE_PATH % [game.repo_name, GAME_ICON_FILE_NAME])
    game.local_state.icon_commit_sha = last_icon_commit_sha
    got_icon = true
