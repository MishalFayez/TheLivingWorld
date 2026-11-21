class_name PlaceholderSfx
extends RefCounted
## TEMPORARY TEST AUDIO (REAVER-FREEFLOW-001). The project has no audio assets yet; these are short
## synthesized tones so playtesters can hear the Free Flow Precision Opportunity. They are not an art /
## audio direction decision: replace `_stream()` with real assets, or set `enabled = false` to mute.
## Everything audio-related for Free Flow goes through `play()`, so this file is the only thing to swap.

static var enabled: bool = true
static var _cache: Dictionary = {}

## kind -> [frequency Hz, seconds, peak volume dB, decay]
const CUES := {
	"opportunity": [1320.0, 0.12, -16.0, 9.0],   # restrained high chime: an opportunity is ready
	"consume": [180.0, 0.2, -10.0, 6.0],          # low thump: a prepared strike was spent
	"rhythm": [880.0, 0.05, -24.0, 10.0],         # REAVER-FREEFLOW-002: very soft tick, In Rhythm
	# LEVEL10-FOUNDATION-005 (temporary tones, same rule: placeholders until real audio exists)
	"bd_full_charge": [990.0, 0.14, -14.0, 8.0],  # Committed Cut reached its 0.75s maximum (once per charge)
	"bd_whirl_hit": [150.0, 0.07, -15.0, 12.0],   # weight of each Whirling Assault hit
	"augment": [660.0, 0.08, -20.0, 10.0],        # an augment effect activated (restrained)
	"poise_break": [95.0, 0.28, -9.0, 5.0],       # Poise Break opening starts
}


static func play(at: Node3D, kind: String) -> void:
	if not enabled or at == null or not is_instance_valid(at) or not at.is_inside_tree() or not CUES.has(kind):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(kind)
	p.volume_db = float(CUES[kind][2])
	p.unit_size = 12.0
	p.bus = &"Master"
	at.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func _stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var cue: Array = CUES[kind]
	var freq: float = cue[0]
	var secs: float = cue[1]
	var decay: float = cue[3]
	var rate := 22050
	var n := int(rate * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := exp(-decay * t / secs) * minf(1.0, t * 400.0)
		var s := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.15
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	_cache[kind] = w
	return w
