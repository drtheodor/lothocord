extends Node

@export var idle_sleep_msec: int = 500000
@export var idle_max_fps: int = 2

var _low_processor_sleep: int
var _max_fps: int

func _ready() -> void:
	self._low_processor_sleep = OS.low_processor_usage_mode_sleep_usec
	self._max_fps = Engine.max_fps
	
	PhysicsServer2D.set_active(false)
	PhysicsServer3D.set_active(false)
	NavigationServer2D.set_active(false)
	NavigationServer3D.set_active(false)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			self._idle()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			self._unidle()

func _idle() -> void:
	RenderingServer.render_loop_enabled = false
	OS.low_processor_usage_mode_sleep_usec = idle_sleep_msec
	Engine.max_fps = idle_max_fps

func _unidle() -> void:
	RenderingServer.render_loop_enabled = true
	OS.low_processor_usage_mode_sleep_usec = self._low_processor_sleep
	Engine.max_fps = self._max_fps
