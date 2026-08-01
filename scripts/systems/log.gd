class_name Log
extends RefCounted
## Gated developer logging.
##
## `Log.d()` replaces bare `print()` for diagnostics: it is silent in exported
## release builds so shipped .exe output stays clean. `push_error` and
## `push_warning` are unaffected and should still be used for real problems.
##
## The gate follows `OS.is_debug_build()` unless the project setting
## `application/config/verbose_logging` overrides it.

const VERBOSE_SETTING := "application/config/verbose_logging"

static var _enabled: bool = _resolve_enabled()


## True when diagnostics should be printed.
static func is_enabled() -> bool:
	return _enabled


## Force verbose logging on or off at runtime (dev consoles, test scenes).
static func set_enabled(value: bool) -> void:
	_enabled = value


## Print a developer diagnostic. No-op in release builds.
static func d(message: String) -> void:
	if _enabled:
		print(message)


static func _resolve_enabled() -> bool:
	if ProjectSettings.has_setting(VERBOSE_SETTING):
		return bool(ProjectSettings.get_setting(VERBOSE_SETTING))
	return OS.is_debug_build()
