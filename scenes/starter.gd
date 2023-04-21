extends Control

@onready var window: Window = get_viewport().get_window()
@onready var scene_tree: SceneTree = get_tree()
@onready var label: Label = $VBoxContainer/BodyMargin/WhatIsGoingOnLabel

const GET_LAUNCHER_LAST_RELEASE_URL: String = "https://api.github.com/repos/ftschirpke/GamesLauncher/releases?page=1&per_page=1"

const launcher_scene_path: String = "res://scenes/launcher.tscn"
const launcher_pck_path: String = "user://mg_launcher.pck"

# VERSION
const VERSION_DEFAULT: String = "v0.2.0"

const version_file: String = "user://version.save"
var release: String = ""
var last_fetched_timestamp: float

const TWENTY_MINUTES: float = 1200

# WINDOW DRAGGING
var drag_position = null

# MORE INFORMATION
var release_notes: String = ""
var asset_name: String = ""
var asset_url: String = ""
var asset_size: int = 0

func _on_draggable_header_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == 1:
        if event.is_pressed():
            drag_position = get_global_mouse_position()
        else:
            drag_position = null
    if drag_position and event is InputEventMouseMotion:
        window.position += Vector2i(get_global_mouse_position() - drag_position)

func _init() -> void:
    load_version()

func load_version() -> bool:
    var file_found: bool = FileAccess.file_exists(version_file)
    if file_found:
        var file: FileAccess = FileAccess.open(version_file, FileAccess.READ)
        var data: Dictionary = file.get_var()
        file.close()
    
        release = data.get("release", VERSION_DEFAULT)
        last_fetched_timestamp = data.get("last_fetched", 0)
            
    return file_found

func save_version() -> void:
    var data: Dictionary = {
        "release": release,
        "last_fetched": last_fetched_timestamp,
    }

    var file: FileAccess = FileAccess.open(version_file, FileAccess.WRITE)
    file.store_var(data)
    file.close()

func _ready() -> void:
    var start_timestamp: float = Time.get_unix_time_from_system()
    var look_for_updates: bool = start_timestamp - last_fetched_timestamp >= TWENTY_MINUTES
    if look_for_updates:
        look_for_launcher_updates()
        last_fetched_timestamp = start_timestamp
    else:
        start_launcher()

func make_http_request(function_on_completion: Callable, request_url: String) -> HTTPRequest:
    var http_request: HTTPRequest = HTTPRequest.new()
    add_child(http_request)
    http_request.set_tls_options(TLSOptions.client())
    http_request.request_completed.connect(function_on_completion)
    http_request.request(request_url, ["Accept: application/vnd.github+json"])
    return http_request

func download_file(url: String, file_path: String, _on_download_finished: Callable) -> void:
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

func look_for_launcher_updates() -> void:
    label.text = "Looking for launcher updates..."
    make_http_request(_on_launcher_update_request_completed, GET_LAUNCHER_LAST_RELEASE_URL)

func _on_launcher_update_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("HTTP request to get launcher update was not successful")
        return
    var json: Array = JSON.parse_string(body.get_string_from_utf8())
    if len(json) == 0:
        push_error("Could not find any Launcher releases.")
        return
    var last_release: Dictionary = json[0]
    
    var new_release: String = last_release.get("name", "")
    if new_release == "" or new_release == release:
        start_launcher()
        return

    release_notes = last_release.get("body", "")
    
    var release_assets: Array = last_release.get("assets", [])
    for asset_dict in release_assets:
        asset_name = asset_dict.get("name", "")
        if asset_name.ends_with(".pck"):
            asset_url = asset_dict.get("url", "")
            asset_size = asset_dict.get("size", -1)
            download_launcher_pck(asset_url)
            break

func download_launcher_pck(download_url: String) -> void:
    label.text = "Downloading launcher updates..."
    if not FileAccess.file_exists(launcher_pck_path):
        var file: FileAccess = FileAccess.open(launcher_pck_path, FileAccess.WRITE)
        if not file:
            push_error(FileAccess.get_open_error())
        else:
            file.close()
    download_file(download_url, launcher_pck_path, _on_launcher_pck_downloaded)

func _on_launcher_pck_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    label.text = "Loading changes..."
    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("HTTP Request to download file was not successful")
    save_version()
    start_launcher()

func start_launcher() -> void:
    if FileAccess.file_exists(launcher_pck_path):
        var successful = ProjectSettings.load_resource_pack(launcher_pck_path)
        if not successful:
            push_error("Failed to load the launcher update. Continuing with the base version...")
    label.text = "Launching..."
    scene_tree.change_scene_to_file(launcher_scene_path)
