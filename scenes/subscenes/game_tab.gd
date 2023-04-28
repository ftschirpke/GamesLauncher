extends HBoxContainer
class_name GameTab

signal change_installation_state(game_name: String, install: bool)
signal cancel_installation(game_name: String)

@onready var description_label: Label = $RightSide/UpperControl/Description
@onready var icon_texture_rect: TextureRect = $LeftSide/TextureRect

# managing release notes
@onready var installed_version_label: Label = $RightSide/LowerControl/VersionsBox/InstalledVersion
@onready var latest_version_label: Label = $RightSide/LowerControl/VersionsBox/LatestVersion
@onready var release_notes_header: Label = $RightSide/LowerControl/MarginContainer/VBoxContainer/ReleaseNotesHeader
@onready var release_notes: Label = $RightSide/LowerControl/MarginContainer/VBoxContainer/ReleaseNotes
@onready var choose_version_button: CheckButton = $RightSide/LowerControl/VersionsBox/ChooseVersionButton

# buttons
@onready var game_settings_button: Button = $LeftSide/Buttons/SmallButtons/GameSettingsButton
@onready var update_button: Button = $LeftSide/Buttons/SmallButtons/UpdateButton
@onready var uninstall_button: Button = $LeftSide/Buttons/SmallButtons/UninstallButton
@onready var play_button: Button = $LeftSide/Buttons/PlayButton
@onready var install_button: Button = $LeftSide/Buttons/InstallButton

# installation dialog
@onready var installation_bar: HBoxContainer = $RightSide/InstallationBarContainer
@onready var installation_progress_bar: ProgressBar = $RightSide/InstallationBarContainer/InstallationProgressBar
var installing: bool = false
var exe_progress: int = 0
var pck_progress: int = 0
var total_size: float
var time_since_last_update: float = 0

# constant strings
const INSTALLED_VERSION_TEXT: String = "%s (installed)"
const LATEST_VERSION_TEXT: String = "%s (latest)"

const DEFAULT_DESCRIPTION: String = "Couldn't find a description for this game..."
const DEFAULT_RELEASE_NOTES_HEADER: String = "Empty Release Notes"
const DEFAULT_RELEASE_NOTES: String = "No release notes found"

const icon_file_path: String = "user://games/%s/launcher_icon.png"

var started: bool = false
var game_config: GamesManager.Game = null: set = _set_game_config

var show_latest_release_notes: bool: set = _set_show_latest_release_notes


func _set_game_config(new_config: GamesManager.Game) -> void:
    game_config = new_config
    if started:
        configure()

func configure() -> void:
    configure_display_name()
    configure_description()
    configure_icon()
    configure_release_notes()
    configure_buttons()
        
func configure_display_name() -> void:
    var alias = game_config.local_state.config.get("alias", "")
    if alias != "":
        name = alias
    else:
        name = game_config.repo_name

func configure_description() -> void:
    description_label.text = game_config.local_state.config.get("description", DEFAULT_DESCRIPTION)

func configure_icon() -> void:
    var icon_path: String = icon_file_path % game_config.repo_name
    if FileAccess.file_exists(icon_path):
        var icon_image: Image = Image.load_from_file(icon_path)
        icon_texture_rect.texture = ImageTexture.create_from_image(icon_image)

func configure_release_notes() -> void:        
    installed_version_label.text = INSTALLED_VERSION_TEXT % game_config.local_state.installed_version
    latest_version_label.text = LATEST_VERSION_TEXT % game_config.update_info.latest_version
    
    show_latest_release_notes = true

    if not game_config.local_state.installed:
        installed_version_label.text = "no version installed"
        choose_version_button.disabled = true

func _set_show_latest_release_notes(show_latest: bool) -> void:
    show_latest_release_notes = show_latest
    var release_notes_version: String = ""
    var release_notes_header_text: String
    var release_notes_text: String
    if show_latest:
        release_notes_version = game_config.update_info.latest_version
        release_notes_header_text = LATEST_VERSION_TEXT % release_notes_version
        release_notes_text = game_config.update_info.release_notes
    else:
        release_notes_version = game_config.local_state.installed_version
        release_notes_header_text = INSTALLED_VERSION_TEXT % release_notes_version
        release_notes_text = game_config.local_state.release_notes

    release_notes_header.text = release_notes_header_text if release_notes_version != "" else DEFAULT_RELEASE_NOTES_HEADER
    release_notes.text = release_notes_text if release_notes_text != "" else DEFAULT_RELEASE_NOTES

func configure_buttons() -> void:
    var installed: bool = game_config.local_state.installed
    game_settings_button.visible = installed
    game_settings_button.disabled = true # TODO: not implemented yet
    update_button.visible = installed
    update_button.disabled = game_config.update_info.latest_version == game_config.local_state.installed_version
    uninstall_button.visible = installed
    play_button.visible = installed
    install_button.visible = not installed

func _ready() -> void:
    started = true
    installation_bar.visible = false
    if game_config:
        configure()

func get_download_progress() -> float:
    var exe_file: FileAccess = FileAccess.open("user://games/%s/%s.tmp" % [game_config.repo_name, game_config.update_info.exe_name], FileAccess.READ)
    if exe_file:
        exe_progress = exe_file.get_length()
        exe_file.close()
    var pck_file: FileAccess = FileAccess.open("user://games/%s/%s.tmp" % [game_config.repo_name, game_config.update_info.pck_name], FileAccess.READ)
    if pck_file:
        pck_progress = pck_file.get_length()
        pck_file.close()
    return exe_progress + pck_progress

func _process(delta: float) -> void:
    if installing:
        if time_since_last_update < 0.5:
            time_since_last_update += delta
        else:
            installation_progress_bar.value = get_download_progress() / total_size * 100
            time_since_last_update = 0

func start_installation_bar() -> void:
    installation_bar.visible = true
    total_size = game_config.update_info.exe_size_in_bytes + game_config.update_info.pck_size_in_bytes
    exe_progress = 0
    pck_progress = 0
    installing = true

func stop_installation_bar() -> void:
    installation_bar.visible = false
    installing = false

func installation_state_was_changed() -> void:
    configure()
    installing = false
    stop_installation_bar()

func _on_install_button_pressed() -> void:
    emit_signal("change_installation_state", game_config.repo_name, true)
    start_installation_bar()

func _on_uninstall_button_pressed() -> void:
    emit_signal("change_installation_state", game_config.repo_name, false)

func _on_play_button_pressed() -> void:
    OS.execute(game_config.local_state.install_path, [])

func _on_update_button_pressed() -> void:
    emit_signal("change_installation_state", game_config.repo_name, true)
    start_installation_bar()

func _on_cancel_installation_button_pressed() -> void:
    stop_installation_bar()
    emit_signal("cancel_installation", game_config.repo_name)
