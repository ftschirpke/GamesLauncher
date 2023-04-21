extends HTTPRequestManager
class_name GameInstaller

var game: GamesManager.Game

signal install_done(game_name: String)
var got_exe: bool = false: set = _set_got_exe
var got_pck: bool = false: set = _set_got_pck

func _init(game_to_install: GamesManager.Game) -> void:
    game = game_to_install

func _set_got_exe(new_value: bool) -> void:
    got_exe = new_value
    if new_value:
        _check_done()

func _set_got_pck(new_value: bool) -> void:
    got_pck = new_value
    if new_value:
        _check_done()

func _ready() -> void:
    install_game()

func install_game() -> void:
    var url: String = game.update_info.exe_download_url
    download_file(url, game.repo_name, game.update_info.exe_name + ".tmp", _on_exe_downloaded)
    # PCK
    url = game.update_info.pck_download_url
    download_file(url, game.repo_name, game.update_info.pck_name + ".tmp", _on_pck_downloaded)

func _on_exe_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("Error occured while downloading .exe")
    else:
        delete_game_file(game.repo_name, game.local_state.exe_name)
        var game_dir: DirAccess = DirAccess.open(GAME_DIR_PATH % game.repo_name)
        game_dir.rename(game.update_info.exe_name + ".tmp", game.update_info.exe_name)
    got_exe = true

func _on_pck_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("Error occured while downloading .pck")
    else:
        delete_game_file(game.repo_name, game.local_state.pck_name)
        var game_dir: DirAccess = DirAccess.open(GAME_DIR_PATH % game.repo_name)
        game_dir.rename(game.update_info.pck_name + ".tmp", game.update_info.pck_name)
    got_pck = true

func cancel_installation() -> void:
    for http_request_child in get_children():
        (http_request_child as HTTPRequest).cancel_request()
    delete_game_file(game.repo_name, game.update_info.exe_name + ".tmp")
    delete_game_file(game.repo_name, game.update_info.pck_name + ".tmp")

func update_game_values() -> void:
    game.local_state.installed = true
    game.local_state.installed_version = game.update_info.latest_version
    game.local_state.exe_name = game.update_info.exe_name
    game.local_state.pck_name = game.update_info.pck_name
    game.local_state.release_notes = game.update_info.release_notes
    
    game.local_state.install_path = (GAME_FILE_PATH % [game.repo_name, game.local_state.exe_name]).replace("user:/", OS.get_user_data_dir())

func _check_done() -> void:
    if is_done():
        update_game_values()

        emit_signal("install_done", game.repo_name)
        
        for child in get_children():
            child.queue_free()
        queue_free()

func is_done() -> bool:
    return got_exe and got_pck
