class_name EncounterZone
extends Node3D
## An encounter objective: triggers when the player comes close, spawns its waves in order and
## awards objective EXP when every wave is cleared.

signal completed(zone: EncounterZone)

var zone_name: String = "Pack"
var area_key: String = "outskirts"
var trigger_radius: float = 14.0
var spawn_radius: float = 5.0
var waves: Array = []           # Array of Array of [type, elite]
var wave_index: int = -1
var alive: Array = []
var started: bool = false
var done: bool = false
var objective_exp: int = 30
var repeatable: bool = false


func setup(p_name: String, p_area: String, p_waves: Array, p_trigger: float = 14.0) -> EncounterZone:
	zone_name = p_name
	area_key = p_area
	waves = p_waves
	trigger_radius = p_trigger
	return self


func _physics_process(_delta: float) -> void:
	if done:
		return
	if not started:
		var p := Game.player
		if is_instance_valid(p) and p.visible and p.global_position.distance_to(global_position) < trigger_radius:
			start()
		return
	for i in range(alive.size() - 1, -1, -1):
		if not is_instance_valid(alive[i]) or alive[i].dead:
			alive.remove_at(i)
	if alive.is_empty():
		_next_wave()


func start() -> void:
	if started:
		return
	started = true
	Events.log_message.emit("Encounter: %s" % zone_name, "system")
	_next_wave()


func _next_wave() -> void:
	wave_index += 1
	if wave_index >= waves.size():
		_complete()
		return
	var wave: Array = waves[wave_index]
	var n := wave.size()
	for i in n:
		var entry: Array = wave[i]
		var ang := TAU * float(i) / float(maxi(n, 1)) + randf() * 0.5
		var pos := global_position + Vector3(cos(ang), 0, sin(ang)) * spawn_radius
		pos.y = 0.2
		var e := Game.spawn_enemy(entry[0], pos, area_key, entry.size() > 1 and entry[1])
		if e:
			alive.append(e)
			e.update_target(0.0)
	if wave_index > 0:
		Events.notify.emit("%s - wave %d" % [zone_name, wave_index + 1])


func _complete() -> void:
	done = true
	if objective_exp > 0:
		Events.objective_completed.emit(zone_name, objective_exp)
		Game.gain_exp(objective_exp, "Objective: " + zone_name)
	completed.emit(self)
	if repeatable:
		done = false
		started = false
		wave_index = -1


func reset_zone() -> void:
	for e in alive:
		if is_instance_valid(e):
			e.queue_free()
	alive.clear()
	started = false
	done = false
	wave_index = -1
