extends Node
## Sons procedurais gerados em tempo de execução (sem arquivos externos).

var _players: Dictionary = {}


func _ready() -> void:
	_add_sound("dig", _make_dig(), -8.0)
	_add_sound("ding", _make_ding(), -10.0)
	_add_sound("water", _make_water(), -8.0)
	_add_sound("coins", _make_coins(), -10.0)
	_add_sound("reveal", _make_reveal(), -8.0)
	_add_sound("craft", _make_craft(), -8.0)
	_add_sound("quest", _make_quest(), -8.0)
	_start_ambient()
	_start_music()


func play(id: String) -> void:
	if not _players.has(id):
		return
	var p: AudioStreamPlayer = _players[id]
	if p.playing:
		return
	p.play()


func _add_sound(id: String, stream: AudioStreamWAV, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	_players[id] = p


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.data = bytes
	return wav


func _make_dig() -> AudioStreamWAV:
	var n := int(0.14 * 22050)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / float(n)
		prev = prev * 0.7 + (randf() * 2.0 - 1.0) * 0.5
		s[i] = prev * (1.0 - t) * 0.8
	return _wav(s)


func _make_ding() -> AudioStreamWAV:
	var n := int(0.22 * 22050)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / 22050.0
		var env := 1.0 - float(i) / float(n)
		s[i] = (sin(TAU * 880.0 * t) * 0.5 + sin(TAU * 1318.5 * t) * 0.3) * env * 0.6
	return _wav(s)


func _make_water() -> AudioStreamWAV:
	var n := int(0.5 * 22050)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / float(n)
		prev = prev * 0.85 + (randf() * 2.0 - 1.0) * 0.4
		s[i] = prev * sin(t * PI) * 0.8
	return _wav(s)


func _make_coins() -> AudioStreamWAV:
	var n := int(0.45 * 22050)
	var s := PackedFloat32Array()
	s.resize(n)
	var freqs: Array[float] = [988.0, 1318.5, 1760.0]
	for j in 3:
		var start := int(0.12 * float(j) * 22050.0)
		for i in range(start, n):
			var t := float(i) / 22050.0
			var env := 1.0 - float(i - start) / float(n - start)
			s[i] += sin(TAU * freqs[j] * t) * env * 0.25
	return _wav(s)


func _make_reveal() -> AudioStreamWAV:
	var n := int(0.3 * 22050)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / 22050.0
		var f := 400.0 + 500.0 * float(i) / float(n)
		var env := sin(float(i) / float(n) * PI)
		s[i] = sin(TAU * f * t) * env * 0.5
	return _wav(s)


func _make_craft() -> AudioStreamWAV:
	var n := int(0.3 * 22050)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / 22050.0
		var env := 1.0 - float(i) / float(n)
		prev = prev * 0.6 + (randf() * 2.0 - 1.0) * 0.4
		s[i] = (prev * 0.5 + sin(TAU * 220.0 * t) * 0.4) * env * 0.7
	return _wav(s)


func _make_quest() -> AudioStreamWAV:
	var n := int(0.6 * 22050)
	var s := PackedFloat32Array()
	s.resize(n)
	var notes: Array[float] = [523.25, 659.25, 783.99]
	for j in 3:
		var start := int(0.15 * float(j) * 22050.0)
		for i in range(start, n):
			var t := float(i) / 22050.0
			var env := 1.0 - float(i - start) / float(n - start)
			s[i] += sin(TAU * notes[j] * t) * env * 0.3
	return _wav(s)


func _start_ambient() -> void:
	var n := 4 * 22050
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		prev = prev * 0.995 + (randf() * 2.0 - 1.0) * 0.02
		s[i] = prev * 2.0
	var wav := _wav(s)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	var p := AudioStreamPlayer.new()
	p.stream = wav
	p.volume_db = -20.0
	p.autoplay = true
	add_child(p)


func _start_music() -> void:
	var rate := 22050
	var chord_dur := 4.0
	var chords: Array = [
		[261.63, 329.63, 392.0, 523.25],
		[220.0, 261.63, 329.63, 440.0],
		[174.61, 220.0, 261.63, 349.23],
		[196.0, 246.94, 293.66, 392.0],
	]
	var n := int(chord_dur * 4.0 * float(rate))
	var s := PackedFloat32Array()
	s.resize(n)
	for ci in 4:
		var base := int(float(ci) * chord_dur * float(rate))
		var chord: Array = chords[ci]
		for i in int(chord_dur * float(rate)):
			var t := float(i) / float(rate)
			var idx := base + i
			var pad_env := sin(clampf(t / 1.2, 0.0, 1.0) * PI * 0.5) * sin(clampf((chord_dur - t) / 1.2, 0.0, 1.0) * PI * 0.5)
			var pad := 0.0
			for f in chord:
				pad += sin(TAU * float(f) * t) * 0.06 + sin(TAU * float(f) * 2.0 * t) * 0.015
			s[idx] += pad * pad_env
			var step := int(0.5 * float(rate))
			if i % step == 0:
				var beat := int(floor(float(i) / float(step)))
				var note_f: float = chord[beat % chord.size()]
				if beat % 4 == 3:
					note_f *= 2.0
				var dur := int(0.9 * float(rate))
				for j in dur:
					var t2 := float(j) / float(rate)
					var env := exp(-t2 * 3.5) * clampf(t2 * 80.0, 0.0, 1.0)
					var k := idx + j
					if k < n:
						s[k] += (sin(TAU * note_f * t2) + 0.35 * sin(TAU * note_f * 2.0 * t2)) * env * 0.12
	var wav := _wav(s)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	var p := AudioStreamPlayer.new()
	p.stream = wav
	p.volume_db = -13.0
	p.autoplay = true
	add_child(p)
