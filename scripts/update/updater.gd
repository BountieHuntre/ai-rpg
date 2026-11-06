class_name Updater
extends Node
## Looks for a newer release of the game on GitHub and installs it: the
## releases' tags are "v<x.y.z>" with a "-windows.zip" asset holding an
## "AI RPG" folder (the exe and its pck). Installing downloads the zip,
## unpacks it under user://update/, and starts a small PowerShell script that
## waits for the game to close, copies the new files over the game's folder
## and starts it again. Only released Windows builds check (FrontEnd), unless
## the Check for Updates option is off.
##
## Developer builds can try it: `-- --check-updates` checks from the editor,
## `--pretend-version=0.5.0` plays an older game, `--update-dir=<dir>` installs
## into that folder (holding a copy of an exported game) instead of the
## running game's, and `--auto-update` answers Update for you.

signal found(version: String, size: int)
signal failed(message: String)
signal progress(fraction: float)
## The new files are ready and the install script is running: quit now.
signal ready_to_restart

const REPO := "BountieHuntre/ai-rpg"
const RELEASES_URL := "https://api.github.com/repos/%s/releases?per_page=20" % REPO
## The releases are pre-releases, which GitHub's "latest" link skips.
const PAGE_URL := "https://github.com/%s/releases" % REPO
const ASSET_SUFFIX := "-windows.zip"
const STAGE_DIR := "user://update/"
## Checked once a run (logging out back to the front end doesn't ask again).
static var checked := false

var latest_version := ""
var _asset_url := ""
var _asset_name := ""
var _http: HTTPRequest
var _downloading := false


## Whether this run should look for updates at all.
static func should_check() -> bool:
	if checked or not Settings.get_value("check_updates"):
		return false
	if "--check-updates" in _dev_args():
		return true
	return OS.has_feature("template") and not OS.is_debug_build()


## The running game's version, or the one pretended for a test.
static func current_version() -> String:
	for arg in _dev_args():
		if arg.begins_with("--pretend-version="):
			return arg.trim_prefix("--pretend-version=")
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func auto_accept() -> bool:
	return "--auto-update" in _dev_args()


## Test arguments, which release builds don't take.
static func _dev_args() -> PackedStringArray:
	return OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()


## -1, 0 or 1 as version a is older than, the same as or newer than b
## ("0.12.3" against "0.5.0"), part by part as numbers.
static func compare_versions(a: String, b: String) -> int:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.max_redirects = 10
	add_child(_http)


## Asks GitHub for the releases: emits found() for the newest one newer than
## this game, and nothing when there's none (or GitHub can't be reached; a
## failed check isn't worth troubling the player with).
func check() -> void:
	checked = true
	_http.request_completed.connect(_on_releases, CONNECT_ONE_SHOT)
	if _http.request(RELEASES_URL, _headers()) != OK:
		_http.request_completed.disconnect(_on_releases)


func _headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: AI-RPG-Updater", "Accept: application/vnd.github+json"])


func _on_releases(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var releases: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not releases is Array:
		return
	var best := current_version()
	var best_size := 0
	for release: Variant in releases:
		if not release is Dictionary or release.get("draft", false):
			continue
		var version := str(release.get("tag_name", "")).trim_prefix("v")
		if compare_versions(version, best) <= 0:
			continue
		for asset: Variant in release.get("assets", []):
			if asset is Dictionary and str(asset.get("name", "")).ends_with(ASSET_SUFFIX):
				best = version
				best_size = int(asset.get("size", 0))
				_asset_url = str(asset.get("browser_download_url", ""))
				_asset_name = str(asset.get("name", ""))
	if compare_versions(best, current_version()) > 0:
		latest_version = best
		found.emit(best, best_size)


## Whether the game can replace its own files: a Windows game in a folder it
## may write to (not, say, under Program Files).
func can_install() -> bool:
	if OS.get_name() != "Windows":
		return false
	var test_path := install_dir().path_join(".update_test")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	DirAccess.remove_absolute(test_path)
	return true


## The folder the game runs from (or the test's).
func install_dir() -> String:
	for arg in _dev_args():
		if arg.begins_with("--update-dir="):
			return arg.trim_prefix("--update-dir=")
	return OS.get_executable_path().get_base_dir()


## The exe the game runs as, in install_dir(): the new exe and pck take its
## name, in case the player renamed it.
func _exe_name() -> String:
	if install_dir() != OS.get_executable_path().get_base_dir():
		for file in DirAccess.get_files_at(install_dir()):
			if file.get_extension().to_lower() == "exe":
				return file
	return OS.get_executable_path().get_file()


## The release page, for when the game can't install itself.
func open_page() -> void:
	OS.shell_open(PAGE_URL + ("/tag/v" + latest_version if not latest_version.is_empty() else ""))


func download() -> void:
	if _downloading or _asset_url.is_empty():
		return
	_downloading = true
	var stage := ProjectSettings.globalize_path(STAGE_DIR)
	_clear_dir(stage)
	DirAccess.make_dir_recursive_absolute(stage)
	_http.download_file = stage.path_join(_asset_name)
	_http.timeout = 0.0
	_http.request_completed.connect(_on_downloaded, CONNECT_ONE_SHOT)
	if _http.request(_asset_url, PackedStringArray(["User-Agent: AI-RPG-Updater"])) != OK:
		_http.request_completed.disconnect(_on_downloaded)
		_downloading = false
		failed.emit("The download couldn't start.")


func cancel() -> void:
	if _downloading:
		_http.cancel_request()
		if _http.request_completed.is_connected(_on_downloaded):
			_http.request_completed.disconnect(_on_downloaded)
		_downloading = false
		_clear_dir(ProjectSettings.globalize_path(STAGE_DIR))


func _process(_delta: float) -> void:
	if _downloading and _http.get_body_size() > 0:
		progress.emit(clampf(float(_http.get_downloaded_bytes()) / _http.get_body_size(), 0.0, 1.0))


func _on_downloaded(result: int, code: int, _headers_in: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		failed.emit("The download failed (%s)." % (str(code) if result == HTTPRequest.RESULT_SUCCESS else "no connection"))
		return
	var message := _unpack(_http.download_file)
	if not message.is_empty():
		failed.emit(message)
		return
	message = _start_install()
	if not message.is_empty():
		failed.emit(message)
		return
	ready_to_restart.emit()


## Unpacks the zip into STAGE_DIR/new/, without its top folder, the exe and
## pck renamed to the running game's name. Returns an error, or "".
func _unpack(zip_path: String) -> String:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return "The download was damaged."
	var out := ProjectSettings.globalize_path(STAGE_DIR).path_join("new")
	var exe := _exe_name()
	var found_pck := false
	for entry in zip.get_files():
		# Windows' Compress-Archive puts backslashes between folders.
		var path := entry.replace("\\", "/")
		if path.ends_with("/"):
			continue
		# "AI RPG/AI RPG.exe" -> "AI RPG.exe".
		var parts := path.split("/")
		var relative := "/".join(parts.slice(1)) if parts.size() > 1 else path
		match relative.get_extension().to_lower():
			"exe":
				relative = relative.get_base_dir().path_join(exe) if relative.get_base_dir() else exe
			"pck":
				relative = exe.get_basename() + ".pck"
				found_pck = true
		var target := out.path_join(relative)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			zip.close()
			return "The update couldn't be unpacked."
		file.store_buffer(zip.read_file(entry))
		file.close()
	zip.close()
	DirAccess.remove_absolute(zip_path)
	return "" if found_pck else "The download didn't hold the game."


## Writes and starts the script that swaps the files in once the game quits.
func _start_install() -> String:
	var stage := ProjectSettings.globalize_path(STAGE_DIR)
	var script_path := stage.path_join("install.ps1")
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return "The update couldn't be installed."
	file.store_string(INSTALL_SCRIPT)
	file.close()
	var args := PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
		"-File", script_path,
		"-GamePid", str(OS.get_process_id()),
		"-Source", stage.path_join("new"),
		"-Dest", install_dir(),
		"-Exe", _exe_name()])
	if OS.create_process("powershell.exe", args) == -1:
		return "The update couldn't be installed."
	return ""


static func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(sub))
		DirAccess.remove_absolute(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))


## Waits for the game to close, copies the new files in (trying again while
## Windows still holds the old exe), clears the staging folder and starts the
## new game. Leaves install.log beside it.
const INSTALL_SCRIPT := """param([int]$GamePid, [string]$Source, [string]$Dest, [string]$Exe)
$log = Join-Path (Split-Path $Source) 'install.log'
"Installing from $Source to $Dest" | Out-File $log
try { Wait-Process -Id $GamePid -Timeout 60 -ErrorAction SilentlyContinue } catch {}
$done = $false
for ($i = 0; $i -lt 30 -and -not $done; $i++) {
	try {
		Copy-Item -Path (Join-Path $Source '*') -Destination $Dest -Recurse -Force -ErrorAction Stop
		$done = $true
	} catch {
		"Retry ${i}: $_" | Out-File $log -Append
		Start-Sleep -Milliseconds 500
	}
}
if ($done) {
	"Installed" | Out-File $log -Append
	Remove-Item -Path $Source -Recurse -Force -ErrorAction SilentlyContinue
} else {
	"Failed" | Out-File $log -Append
}
Start-Process -FilePath (Join-Path $Dest $Exe) -WorkingDirectory $Dest
"""
