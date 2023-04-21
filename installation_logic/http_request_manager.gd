extends Node
class_name HTTPRequestManager

const GET_GAME_FILE_URL: String = "https://api.github.com/repos/ftschirpke/%s/contents/%s"

const GAME_DIR_PATH: String = "user://games/%s"
const GAME_FILE_PATH: String = "user://games/%s/%s"

func create_directory_if_nonexistent(parent_dir_path: String, dir_name: String) -> void:
    if not DirAccess.dir_exists_absolute(parent_dir_path + dir_name):
        var user_dir: DirAccess = DirAccess.open(parent_dir_path)
        user_dir.make_dir(dir_name)

func delete_game_file(game_name: String, file_name: String) -> void:
    var dir: DirAccess = DirAccess.open(GAME_DIR_PATH % game_name)
    dir.remove(file_name)

func make_http_request(function_on_completion: Callable, request_url: String) -> HTTPRequest:
    var http_request: HTTPRequest = HTTPRequest.new()
    add_child(http_request)
    http_request.set_tls_options(TLSOptions.client())
    http_request.request_completed.connect(function_on_completion)
    http_request.request(request_url, ["Accept: application/vnd.github+json"])
    return http_request

func download_file(url: String, game_name: String, file_name: String, _on_download_finished: Callable) -> void:
    var file_path: String = GAME_FILE_PATH % [game_name, file_name]
    if not FileAccess.file_exists(file_path):
        var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
        if not file:
            push_error("Error while trying to open file %s: %s" % [file_path, FileAccess.get_open_error()])
        else:
            file.close()

    var http_request: HTTPRequest = HTTPRequest.new()
    add_child(http_request)
    http_request.set_tls_options(TLSOptions.client())
    http_request.download_file = file_path
    http_request.request_completed.connect(_on_download_finished)
    http_request.request(url, ["Accept: application/octet-stream"])
