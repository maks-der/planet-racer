class_name Sfx
extends RefCounted

static func beep(parent: Node, freq: float, duration: float, volume_db: float = -8.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _tone(freq, duration)
	player.volume_db = volume_db
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _tone(freq: float, duration: float) -> AudioStreamWAV:
	var mix := 22050
	var count := maxi(int(float(mix) * duration), 1)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(mix)
		var env := 1.0 - (t / duration)
		env = env * env
		var sample := sin(TAU * freq * t) * env
		var v := int(clampf(sample, -1.0, 1.0) * 28000.0)
		data[i * 2] = v & 255
		data[i * 2 + 1] = (v >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix
	wav.stereo = false
	wav.data = data
	return wav
