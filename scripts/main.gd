extends Node3D
## Núcleo do jogo: estado, economia, missões, interações, menus e save (v2).

const SAVE_PATH := "user://savegame.json"
const LOG_PATH := "user://error_log.txt"
const CADINHO_PRICE := 300
const MERCHANT_POS := Vector3(-6.0, 0.0, 66.0)
const BOARD_POS := Vector3(-12.0, 0.0, 64.0)
const STATUE_POS := Vector3(0.0, 0.0, 68.0)
const GATE_XS := [-30.0, 0.0, 30.0, 55.0]
const HOUSE_OFFSETS := [Vector3(-18, 0, 62), Vector3(-2, 0, 74), Vector3(8, 0, 62), Vector3(-16, 0, 74), Vector3(2, 0, 60), Vector3(11, 0, 70), Vector3(-8, 0, 76), Vector3(6, 0, 76)]
const HOUSE_LEVELS := [0, 0, 0, 1, 2, 2, 3, 4]

var terrain: Node3D
var player: Node3D
var hud: CanvasLayer
var machines: Node3D
var sound: Node

var money := 5000
var pa_tier := 0
var brush_tier := 0
var bucket_terra := 0
var bucket_water := 0.0
var pocket_dynamite := 0

var pocket_ores := {}
var pocket_bars := {}
var pocket_gems_raw := {}
var pocket_gems := {}
var joias: Array = []
var artefatos: Array = []

var quest_index := 0
var completed_orders := 0
var active_order := {}
var village_level := 1
var unlocked: Array = [true, false, false, false, false]

var stats_ores := 0
var stats_harvester := 0
var drills_watered := false
var met_merchant := false
var bars_heated := 0.0
var has_picareta := false
var has_rastelo := false
var has_detector := false
var map_open := false
var statue_level := 0
var playtime := 0.0
var world_hour := 8.0
var text_scale := 1.0
var has_truck := false
var driving := false
var truck: Node3D = null
var truck_yaw := 0.0
var truck_cargo := {}
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial
var _env: Environment
var _lamps: Array = []
var _lamp_lights: Array = []
var _player_light: OmniLight3D = null
var _lowfps_t: float = 0.0
var _lowfps_warned: bool = false
var _clouds: Array = []
var _fireflies: CPUParticles3D = null
var _stars: MultiMeshInstance3D = null
var _boat: Node3D = null
var _vignette: TextureRect = null
var _boat_base_y := 0.0
var _birds: Array = []
var _sun_vis: MeshInstance3D
var _moon_vis: MeshInstance3D
var _scatter: Array = []
var _scatter_timer := 0.0
var _sway_timer := 0.0
var _fx_timer := 0.0
var quality := 2
var debt := 0
var total_earned := 0
var _debt_timer := 0.0
var stress_level := 0
var showroom_open := false
var _showroom: Node3D
var _showroom_return := Vector3.ZERO

var placing := ""
var placing_tier := 0
var menu_open := false
var dig_cooldown := 0.0
var brush_progress := 0.0
var brush_needed := 4.0

var _aim := Vector3.ZERO
var _aim_valid := false
var _anvil_item := ""
var _anvil_base := ""
var _anvil_blade := ""
var _menu_machine := {}
var _esteira_prev := -1
var _esteira_yaw := 0.0
var _esteira_linked := false
var _esteira_on_pipe := false
var _placing_yaw := 0.0
var _trees: Array = []
var _rocks: Array = []
var _autosave := 0.0
var _quest_timer := 0.5
var _pickup_timer := 0.0
var _pickups: Array = []
var _rock_variants: Array = []
var _gem_variant: ArrayMesh = null
var _houses: Array = []
var _gate_labels: Array = []
var _gate_bars: Array = []
var _move_source := {}
var _blueprint: Array = []
var _event_timer := 180.0
var _lucky_time := 0.0
var _rain_time := 0.0
var _rain_tick := 0.0
var _boom_time := 0.0
var urgent_order := {}
var _urgent_deadline := 0.0
const BP_PATH := "user://blueprint.json"
const BP_CAP := 200


func _ready() -> void:
	randomize()
	_setup_input()
	_build_environment()
	terrain = preload("res://scripts/terrain.gd").new()
	terrain.game = self
	add_child(terrain)
	_build_sky_props()
	machines = preload("res://scripts/machines.gd").new()
	machines.game = self
	machines.terrain = terrain
	add_child(machines)
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)
	_build_village()
	_build_gates()
	_build_trees()
	_build_scatter()
	_build_pier()
	_build_reeds()
	_build_birds()
	_build_stars()
	player = preload("res://scripts/player.gd").new()
	player.terrain = terrain
	player.game = self
	add_child(player)
	player.global_position = Vector3(-40.0, terrain.height_at(-40.0, 0.0) + 1.0, 0.0)
	var pl := OmniLight3D.new()
	pl.position = Vector3(0, 2.3, 0)
	pl.omni_range = 11.0
	pl.light_color = Color(1.0, 0.8, 0.55)
	pl.light_energy = 0.0
	pl.shadow_enabled = false
	player.add_child(pl)
	_player_light = pl
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	add_child(hud)
	_build_vignette()
	var loaded := load_game()
	_load_blueprint()
	if not loaded:
		var bp := Vector3(-36.0, _ground_y(-36.0, 4.0), 4.0)
		machines.add_machine("bacia", 0, bp)
		_generate_veins()
		hud.flash("Bem-vindo às terras do seu avô!")
	_rebuild_village()
	_update_gate_labels()
	if loaded:
		hud.show_title(true)
	else:
		hud.show_intro()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _process(delta: float) -> void:
	playtime += delta
	world_hour = fmod(world_hour + delta * 24.0 / 720.0, 24.0)
	if Engine.get_frames_per_second() < 20:
		_lowfps_t += delta
		if _lowfps_t > 5.0 and not _lowfps_warned and quality >= 2:
			_lowfps_warned = true
			hud.flash("Desempenho baixo detectado \u2014 reduza a qualidade no menu de pausa (Esc)")
	else:
		_lowfps_t = 0.0
	_update_sky()
	_update_fx(delta)
	_update_truck(delta)
	dig_cooldown = maxf(0.0, dig_cooldown - delta)
	bars_heated = maxf(0.0, bars_heated - delta)
	_pickup_timer -= delta
	if _pickup_timer <= 0.0:
		_pickup_timer = 0.15
		_collect_pickups()
	_quest_timer -= delta
	if _quest_timer <= 0.0:
		_quest_timer = 0.5
		_check_quests()
	_scatter_timer -= delta
	if _scatter_timer <= 0.0:
		_scatter_timer = 0.5
		_settle_scatter()
	_autosave += delta
	if _autosave >= 30.0:
		_autosave = 0.0
		save_game()
	if debt > 0:
		_debt_timer += delta
		if _debt_timer >= 30.0:
			_debt_timer = 0.0
			var parcela := mini(debt, maxi(50, int(debt * 0.05)))
			if money >= parcela:
				money -= parcela
				debt -= parcela
				if debt <= 0:
					debt = 0
					hud.flash("Dívida quitada! O banco liberou seu nome.")
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = randf_range(150.0, 300.0)
		_random_event()
	_lucky_time = maxf(0.0, _lucky_time - delta)
	_boom_time = maxf(0.0, _boom_time - delta)
	_rain_time = maxf(0.0, _rain_time - delta)
	if _rain_time > 0.0:
		_rain_tick -= delta
		if _rain_tick <= 0.0:
			_rain_tick = 0.5
			for m in machines.list:
				if not bool(m.get("dead", false)) and String(m["type"]) == "bacia":
					m["water"] = minf(float(m["water"]) + 0.1, 2.0)
	if not urgent_order.is_empty():
		var now_s := Time.get_ticks_msec() / 1000.0
		if now_s > _urgent_deadline:
			urgent_order = {}
			hud.flash("O prazo da encomenda urgente acabou...")
			sound.play("water")
	hud.refresh_all()


func _random_event() -> void:
	var roll := randi() % 3
	if roll == 0:
		_lucky_time = 60.0
		hud.flash("VEIO RICO! A terra está generosa — cavar e escovar rende em dobro por 60s!")
	elif roll == 1:
		_rain_time = 60.0
		hud.flash("CHUVA! As bacias estão se enchendo de água sozinhas por 60s!")
	else:
		_boom_time = 90.0
		hud.flash("ALTA DO MERCADO! Vendas valem +25% por 90s!")
	sound.play("quest")


func _sell_mult() -> float:
	var mult := 1.0 + 0.05 * float(statue_level)
	if _boom_time > 0.0:
		mult *= 1.25
	return mult


func _unhandled_input(event: InputEvent) -> void:
	if hud.credits_visible():
		var pressed_c := (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed()
		if pressed_c:
			hud.hide_credits()
		return
	if hud.title_visible():
		return
	if hud.intro_visible():
		var pressed := (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed()
		if pressed:
			hud.hide_intro()
		return
	if hud.map_visible():
		if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
			hud.hide_map()
			map_open = false
		return
	if placing != "" and not menu_open:
		if event.is_action_pressed("rotate_cw"):
			_placing_yaw += PI * 0.25
			return
		if event.is_action_pressed("rotate_ccw"):
			_placing_yaw -= PI * 0.25
			return
		if event is InputEventMouseButton and event.is_pressed():
			var mb2 := event as InputEventMouseButton
			if mb2.button_index == MOUSE_BUTTON_WHEEL_UP:
				_placing_yaw += PI * 0.25
				return
			if mb2.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_placing_yaw -= PI * 0.25
				return
	if event.is_action_pressed("interact"):
		if menu_open:
			close_menu()
		else:
			interact()
	elif event.is_action_pressed("dump_bucket"):
		if not menu_open:
			_dump_bucket()
	elif event.is_action_pressed("build"):
		if menu_open:
			close_menu()
		else:
			open_build_menu()
	elif event.is_action_pressed("demolish"):
		demolish_nearby()
	elif event.is_action_pressed("move_obj"):
		_start_move()
	elif event.is_action_pressed("blueprint"):
		open_blueprint_menu()
	elif event.is_action_pressed("diagnose"):
		_diagnose()
	elif event.is_action_pressed("dinamite"):
		use_dynamite()
	elif event.is_action_pressed("cheat_money"):
		money += 100000
		hud.flash("Cheat de teste: +100 mil moedas (total: $%d)" % money)
		sound.play("coins")
	elif event.is_action_pressed("stress"):
		_stress_test()
	elif event.is_action_pressed("showroom"):
		toggle_showroom()
	elif event.is_action_pressed("save_game"):
		save_game()
		hud.flash("Jogo salvo!")
	elif event.is_action_pressed("reset_game"):
		reset_game()
	elif event.is_action_pressed("stats"):
		if not menu_open:
			hud.show_stats(_stats_text())
	elif event.is_action_pressed("ui_cancel"):
		if menu_open:
			close_menu()
		elif placing != "":
			cancel_placing()
			hud.flash("Construção cancelada.")
		else:
			open_pause_menu()


func open_pause_menu() -> void:
	var opts: Array = []
	opts.append({"label": "Continuar", "action": close_menu})
	opts.append({"label": "Salvar agora", "action": _pause_save})
	opts.append({"label": "Estatísticas da indústria (ou tecla J)", "action": _pause_stats})
	opts.append({"label": "Som: %s (alternar)" % ("LIGADO" if not AudioServer.is_bus_mute(0) else "DESLIGADO"), "action": _toggle_audio})
	opts.append({"label": "Volume da música: %s (alternar)" % _vol_name(sound.music_level), "action": _cycle_music})
	opts.append({"label": "Volume dos efeitos: %s (alternar)" % _vol_name(sound.sfx_level), "action": _cycle_sfx})
	opts.append({"label": "Tamanho do texto do HUD: %d%% (alternar)" % int(text_scale * 100), "action": _cycle_text_scale})
	opts.append({"label": "Qualidade gr\u00e1fica: %s (alternar)" % ["Baixa", "M\u00e9dia", "Alta", "Ultra"][quality], "action": _cycle_quality})
	opts.append({"label": "Créditos", "action": _show_credits})
	opts.append({"label": "REINICIAR o mundo do zero (apaga o save!)", "action": reset_game})
	opts.append({"label": "Sair do jogo", "action": _quit_game})
	_open_menu("PAUSA", opts)


func _vol_name(lvl: int) -> String:
	return ["Mudo", "Baixo", "Normal", "Alto"][clampi(lvl, 0, 3)]


func _cycle_music() -> void:
	sound.set_music_level((sound.music_level + 1) % 4)
	open_pause_menu()


func _cycle_sfx() -> void:
	sound.set_sfx_level((sound.sfx_level + 1) % 4)
	open_pause_menu()


func _cycle_text_scale() -> void:
	var steps: Array = [1.0, 1.25, 1.5]
	var idx := steps.find(text_scale)
	text_scale = steps[(idx + 1) % steps.size()]
	hud.set_text_scale(text_scale)
	open_pause_menu()


func _show_credits() -> void:
	close_menu()
	hud.show_credits()


func _toggle_audio() -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(idx, not AudioServer.is_bus_mute(idx))
	open_pause_menu()


func _pause_save() -> void:
	save_game()
	hud.flash("Jogo salvo!")
	close_menu()


func _pause_stats() -> void:
	close_menu()
	hud.show_stats(_stats_text())


func title_continue() -> void:
	hud.hide_title()
	hud.show_intro()


func title_new_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()


func title_quit() -> void:
	_quit_game()


func _quit_game() -> void:
	save_game()
	get_tree().quit()


func _stats_text() -> String:
	var lines: Array = []
	var by_type := {}
	var total_m := 0
	var sem_agua := 0
	var cheias := 0
	var sem_saida := 0
	for m in machines.list:
		if bool(m.get("dead", false)):
			continue
		var t: String = m["type"]
		by_type[t] = int(by_type.get(t, 0)) + 1
		total_m += 1
		if t == "drill" and not bool(m["active"]):
			sem_agua += 1
		if machines.is_belt(t) and machines.cargo_total(m["cargo"]) >= 8:
			cheias += 1
		if t == "harvester" and machines.find_belt_output(m["pos"], 2.6).is_empty() and machines.cargo_total(m["caixa"]) + machines.cargo_total(m["caixa_gems"]) >= 8:
			sem_saida += 1
	lines.append("=== ESTATÍSTICAS DA INDÚSTRIA ===")
	lines.append("Ganhos totais: $%d | Dívida no banco: $%d" % [total_earned, debt])
	@warning_ignore("integer_division")
	lines.append("Tempo de jogo: %dh %02dm | Bônus da estátua: +%d%%" % [int(playtime) / 3600, (int(playtime) % 3600) / 60, int(statue_level * 5)])
	lines.append("Minérios minerados: %d | Produzidos pelo harvester: %d" % [stats_ores, stats_harvester])
	lines.append("Peças construídas: %d" % total_m)
	var parts: Array = []
	for t in by_type:
		parts.append("%dx %s" % [int(by_type[t]), _machine_name(String(t), 0)])
	parts.sort()
	if not parts.is_empty():
		lines.append("Inventário: " + ", ".join(PackedStringArray(parts)))
	var ps: Dictionary = machines.power_stats()
	lines.append("Energia: %d fornecida / %d de consumo" % [int(ps["supply"]), int(ps["demand"])])
	lines.append("--- GARGALOS ---")
	if sem_agua > 0:
		lines.append("%d drill(s) SEM ÁGUA — ligue canos ao lago ou despeje balde" % sem_agua)
	if cheias > 0:
		lines.append("%d esteira(s) CHEIAS — o fluxo parou; esvazie com baú/filtro à frente" % cheias)
	if sem_saida > 0:
		lines.append("%d harvester(s) com a caixa cheia e sem esteira na saída" % sem_saida)
	if int(ps["supply"]) < int(ps["demand"]):
		lines.append("REDE ELÉTRICA SOBRECARREGADA — compre outro gerador")
	if sem_agua == 0 and cheias == 0 and sem_saida == 0 and int(ps["supply"]) >= int(ps["demand"]):
		lines.append("Nenhum gargalo detectado. Tudo rodando!")
	return "\n".join(PackedStringArray(lines))


func _generate_veins() -> void:
	var zone_ranges: Array = [[-78.0, -32.0], [-28.0, -2.0], [2.0, 28.0], [32.0, 53.0], [57.0, 78.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240915
	for zone in 5:
		for i in int(GameData.VEIN_COUNTS[zone]):
			var x: float = rng.randf_range(float(zone_ranges[zone][0]), float(zone_ranges[zone][1]))
			var z: float = rng.randf_range(-70.0, 50.0)
			if Vector2(x, z).distance_to(terrain.LAKE_POS) < 12.0:
				z = -70.0 + rng.randf_range(0.0, 30.0)
			var pos := Vector3(x, terrain.height_at(x, z), z)
			var idx: int = GameData.pick_weighted(GameData.ORE_WEIGHTS[zone])
			if idx < 0:
				continue
			var ore: String = String(GameData.ORE_ORDER[idx])
			var id: int = machines.add_machine("vein", zone, pos, rng.randf_range(0.0, TAU))
			if id >= 0:
				machines.vein_set_ore(id, ore)


func _build_sky_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in 14:
		var ang := float(i) / 14.0 * TAU
		var mx := cos(ang) * rng.randf_range(105.0, 125.0)
		var mz := sin(ang) * rng.randf_range(105.0, 125.0)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rng.randf_range(1.0, 5.0)
		cm.bottom_radius = rng.randf_range(14.0, 22.0)
		cm.height = rng.randf_range(22.0, 38.0)
		cm.radial_segments = 14
		cm.cap_top = false
		var noise := FastNoiseLite.new()
		noise.seed = 3300 + i * 17
		noise.frequency = 0.09
		var st := SurfaceTool.new()
		st.create_from(cm, 0)
		st.deindex()
		var arrays := st.commit_to_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vi in verts.size():
			var v := verts[vi]
			var k := 1.0 + 0.32 * noise.get_noise_2d(v.x * 1.5, v.z * 1.5)
			verts[vi] = Vector3(v.x * k, v.y, v.z * k)
		arrays[Mesh.ARRAY_VERTEX] = verts
		var st2 := SurfaceTool.new()
		st2.create_from_arrays(arrays)
		st2.deindex()
		st2.generate_normals()
		mi.mesh = st2.commit()
		mi.position = Vector3(mx, cm.height * 0.5 - 6.0, mz)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.46, 0.42)
		mat.roughness = 1.0
		mi.material_override = mat
		add_child(mi)
	for i in 7:
		var cluster := Node3D.new()
		cluster.position = Vector3(rng.randf_range(-100.0, 100.0), rng.randf_range(42.0, 58.0), rng.randf_range(-100.0, 100.0))
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.97, 0.98, 1.0)
		cmat.roughness = 1.0
		cmat.emission_enabled = true
		cmat.emission = Color(0.55, 0.6, 0.7)
		cmat.emission_energy_multiplier = 0.35
		for k in rng.randi_range(3, 5):
			var puff := MeshInstance3D.new()
			var pm4 := SphereMesh.new()
			var pr := rng.randf_range(2.6, 4.6)
			pm4.radius = pr
			pm4.height = pr * 1.1
			pm4.radial_segments = 12
			pm4.rings = 6
			puff.mesh = pm4
			puff.position = Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-1.5, 1.5), rng.randf_range(-5.0, 5.0))
			puff.scale = Vector3(1.0, 0.55, 1.0)
			puff.material_override = cmat
			cluster.add_child(puff)
		add_child(cluster)
		_clouds.append(cluster)
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 28
	_fireflies.lifetime = 5.0
	_fireflies.preprocess = 4.0
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(16.0, 2.0, 12.0)
	_fireflies.position = Vector3(terrain.LAKE_POS.x, terrain.height_at(terrain.LAKE_POS.x, terrain.LAKE_POS.y) + 2.0, terrain.LAKE_POS.y)
	_fireflies.direction = Vector3(0, 1, 0)
	_fireflies.spread = 180.0
	_fireflies.gravity = Vector3.ZERO
	_fireflies.initial_velocity_min = 0.2
	_fireflies.initial_velocity_max = 0.7
	_fireflies.scale_amount_min = 0.5
	_fireflies.scale_amount_max = 1.0
	var fmesh := QuadMesh.new()
	fmesh.size = Vector2(0.09, 0.09)
	_fireflies.mesh = fmesh
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.95, 0.9, 0.4)
	fmat.emission_enabled = true
	fmat.emission = Color(0.95, 0.85, 0.3)
	fmat.emission_energy_multiplier = 3.0
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fmesh.material = fmat
	_fireflies.visible = false
	add_child(_fireflies)
	_sun_vis = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 6.0
	sm.height = 12.0
	_sun_vis.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.9, 0.5)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.8, 0.4)
	smat.emission_energy_multiplier = 2.5
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sun_vis.material_override = smat
	add_child(_sun_vis)
	_moon_vis = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 4.0
	mm.height = 8.0
	_moon_vis.mesh = mm
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.85, 0.88, 0.95)
	mmat.emission_enabled = true
	mmat.emission = Color(0.6, 0.65, 0.8)
	mmat.emission_energy_multiplier = 1.2
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_moon_vis.material_override = mmat
	add_child(_moon_vis)


func _build_scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var tuft := BoxMesh.new()
	tuft.size = Vector3(0.07, 0.42, 0.07)
	mm.mesh = tuft
	var count := 320
	mm.instance_count = count
	var placed := 0
	var guard := 0
	while placed < count and guard < count * 10:
		guard += 1
		var gx := rng.randf_range(-78.0, 78.0)
		var gz := rng.randf_range(-78.0, 78.0)
		if gx > terrain.VILLAGE_MIN.x - 2.0 and gx < terrain.VILLAGE_MAX.x + 2.0 and gz > terrain.VILLAGE_MIN.y - 2.0 and gz < terrain.VILLAGE_MAX.y + 2.0:
			continue
		if Vector2(gx, gz).distance_to(terrain.LAKE_POS) < 12.0:
			continue
		var gy: float = terrain.height_at(gx, gz)
		if gy < 0.3:
			continue
		var trf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(gx, gy + 0.12, gz))
		mm.set_instance_transform(placed, trf)
		var g := rng.randf_range(0.75, 1.0)
		mm.set_instance_color(placed, Color(g * 0.5, g, g * 0.4))
		placed += 1
	mm.visible_instance_count = placed
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var gcode := """
shader_type spatial;
render_mode cull_disabled;
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.7;
void vertex() {
	float sway = sin(TIME * wind_speed + VERTEX.x * 2.2 + VERTEX.z * 1.8) * wind_strength * max(VERTEX.y, 0.0);
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""
	var gshader := Shader.new()
	gshader.code = gcode
	var gshader_mat := ShaderMaterial.new()
	gshader_mat.shader = gshader
	mmi.material_override = gshader_mat
	add_child(mmi)
	for i in 26:
		var fx := rng.randf_range(-78.0, 78.0)
		var fz := rng.randf_range(-78.0, 78.0)
		if fx > terrain.VILLAGE_MIN.x - 2.0 and fx < terrain.VILLAGE_MAX.x + 2.0 and fz > terrain.VILLAGE_MIN.y - 2.0 and fz < terrain.VILLAGE_MAX.y + 2.0:
			continue
		if Vector2(fx, fz).distance_to(terrain.LAKE_POS) < 12.0:
			continue
		var fy: float = terrain.height_at(fx, fz)
		if fy < 0.3:
			continue
		var froot := Node3D.new()
		froot.position = Vector3(fx, fy, fz)
		add_child(froot)
		_scatter.append(froot)
		_part(froot, Vector3(0.04, 0.3, 0.04), Color(0.4, 0.6, 0.3), Vector3(0, 0.15, 0))
		var cols: Array = [Color(0.95, 0.75, 0.3), Color(0.9, 0.4, 0.5), Color(0.85, 0.85, 0.95)]
		_part(froot, Vector3(0.14, 0.1, 0.14), cols[rng.randi() % 3], Vector3(0, 0.34, 0))
	for i in 22:
		var rx := rng.randf_range(-78.0, 78.0)
		var rz := rng.randf_range(-78.0, 78.0)
		if rx > terrain.VILLAGE_MIN.x - 2.0 and rx < terrain.VILLAGE_MAX.x + 2.0 and rz > terrain.VILLAGE_MIN.y - 2.0 and rz < terrain.VILLAGE_MAX.y + 2.0:
			continue
		if Vector2(rx, rz).distance_to(terrain.LAKE_POS) < 12.0:
			continue
		var ry: float = terrain.height_at(rx, rz)
		var rock := _part(self, Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0.2, 0.5), rng.randf_range(0.3, 0.8)), Color(0.5, 0.5, 0.48), Vector3(rx, ry + 0.05, rz))
		rock.rotation = Vector3(0, rng.randf_range(0.0, TAU), rng.randf_range(-0.15, 0.15))
		_scatter.append(rock)
	for i in 60:
		var bx := rng.randf_range(-78.0, 78.0)
		var bz := rng.randf_range(-78.0, 78.0)
		if bx > terrain.VILLAGE_MIN.x - 2.0 and bx < terrain.VILLAGE_MAX.x + 2.0 and bz > terrain.VILLAGE_MIN.y - 2.0 and bz < terrain.VILLAGE_MAX.y + 2.0:
			continue
		if Vector2(bx, bz).distance_to(terrain.LAKE_POS) < 12.0:
			continue
		var by: float = terrain.height_at(bx, bz)
		if by < 0.3:
			continue
		var bush := MeshInstance3D.new()
		var bsm := SphereMesh.new()
		var br := rng.randf_range(0.25, 0.55)
		bsm.radius = br
		bsm.height = br * 1.4
		bsm.radial_segments = 8
		bsm.rings = 4
		bush.mesh = bsm
		bush.position = Vector3(bx, by + br * 0.5, bz)
		bush.rotation.y = rng.randf_range(0.0, TAU)
		var g2 := rng.randf_range(0.7, 1.0)
		bush.material_override = _part_mat(Color(0.28 * g2, 0.5 * g2, 0.22 * g2))
		add_child(bush)
		_scatter.append(bush)


func _update_fx(delta: float) -> void:
	for c in _clouds:
		if is_instance_valid(c):
			c.position.x += delta * 2.0
			if c.position.x > 110.0:
				c.position.x = -110.0
	var tnow := Time.get_ticks_msec() / 1000.0
	if _boat != null and is_instance_valid(_boat):
		_boat.position.y = _boat_base_y + sin(tnow * 1.1) * 0.05
		_boat.rotation.z = sin(tnow * 0.8) * 0.03
		_boat.rotation.x = sin(tnow * 0.65 + 1.0) * 0.02
	var dfx := clampf(sin((world_hour - 6.0) / 24.0 * TAU), -1.0, 1.0)
	for bd in _birds:
		var bnode: Node3D = bd[0]
		if not is_instance_valid(bnode):
			continue
		bnode.visible = dfx > 0.15
		if not bnode.visible:
			continue
		var bang: float = float(bd[4]) + tnow * float(bd[3])
		var bcent: Vector3 = bd[1]
		var brad: float = bd[2]
		bnode.position = bcent + Vector3(cos(bang) * brad, sin(tnow * 0.7 + float(bd[5])) * 0.8, sin(bang) * brad)
		bnode.rotation.y = -bang + (PI * 0.5 if float(bd[3]) > 0.0 else -PI * 0.5)
		bnode.rotation.z = sin(tnow * 6.0 + float(bd[5])) * 0.25
	_fx_timer -= delta
	if _fx_timer <= 0.0:
		_fx_timer = 2.0
		for n in _scatter:
			if is_instance_valid(n):
				var g: float = terrain.height_at(n.position.x, n.position.z)
				n.visible = n.position.y < g + 0.6
	_sway_timer -= delta
	if _sway_timer <= 0.0:
		_sway_timer = 0.1
		var t := Time.get_ticks_msec() / 1000.0
		for tree in _trees:
			if is_instance_valid(tree):
				tree.rotation.z = sin(t * 1.3 + tree.position.x * 0.5) * 0.02


func _dust_burst(pos: Vector3, col: Color) -> void:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -4.5, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.28, 0.28)
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.position = pos + Vector3(0, 0.3, 0)
	add_child(p)
	p.emitting = true
	var c := CPUParticles3D.new()
	c.amount = 5
	c.lifetime = 0.9
	c.one_shot = true
	c.explosiveness = 1.0
	c.direction = Vector3(0, 1, 0)
	c.spread = 40.0
	c.initial_velocity_min = 1.0
	c.initial_velocity_max = 2.2
	c.gravity = Vector3(0, -7.5, 0)
	c.scale_amount_min = 0.7
	c.scale_amount_max = 1.3
	var cmesh := QuadMesh.new()
	cmesh.size = Vector2(0.16, 0.16)
	c.mesh = cmesh
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.95)
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmesh.material = cmat
	c.position = pos + Vector3(0, 0.35, 0)
	add_child(c)
	c.emitting = true
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
		if is_instance_valid(c):
			c.queue_free())


func _splash_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -8.0, 0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.14, 0.14)
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.82, 0.95, 0.75)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.position = pos + Vector3(0, 0.25, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


func _sparkle_burst(pos: Vector3, col: Color) -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -2.5, 0)
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.5
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.12, 0.12)
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r * 0.7 + 0.3, col.g * 0.7 + 0.3, col.b * 0.7 + 0.3, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6
	mesh.material = mat
	p.position = pos + Vector3(0, 0.2, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


func _apply_quality() -> void:
	if _env == null or _sun == null:
		return
	var shadows: Array = [false, true, true, true]
	var shadow_dist: Array = [40.0, 80.0, 120.0, 160.0]
	var glow_on: Array = [false, false, true, true]
	var ssao_on: Array = [false, false, true, true]
	var msaa: Array = [0, 0, 1, 1]
	_sun.shadow_enabled = shadows[quality]
	_sun.shadow_opacity = 0.72
	_sun.directional_shadow_max_distance = float(shadow_dist[quality])
	_env.glow_enabled = glow_on[quality]
	_env.ssao_enabled = ssao_on[quality]
	_env.volumetric_fog_enabled = quality >= 2
	_env.volumetric_fog_density = 0.009
	_env.volumetric_fog_anisotropy = 0.55
	_env.volumetric_fog_length = 90.0
	_env.volumetric_fog_ambient_inject = 0.8
	get_viewport().msaa_3d = msaa[quality]
	if _vignette != null and is_instance_valid(_vignette):
		_vignette.visible = quality >= 1


func _build_vignette() -> void:
	var tex := load("res://assets/textures/vignette.png") as Texture2D
	if tex == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = quality >= 1
	layer.add_child(_vignette)


func _cycle_quality() -> void:
	quality = (quality + 1) % 4
	_apply_quality()
	var names: Array = ["Baixa", "Média", "Alta", "Ultra"]
	hud.flash("Qualidade gráfica: %s (sombras, brilho, SSAO e suavização)" % names[quality])
	open_pause_menu()


func _update_sky() -> void:
	if _sun == null or _sky_mat == null or _env == null:
		return
	var day := clampf(sin((world_hour - 6.0) / 24.0 * TAU), -1.0, 1.0)
	var f := clampf(day, 0.0, 1.0)
	var glow := exp(-abs(day) * 5.0)
	_sky_mat.sky_top_color = Color(0.03, 0.04, 0.1).lerp(Color(0.22, 0.46, 0.82), f)
	_sky_mat.sky_horizon_color = Color(0.05, 0.06, 0.12).lerp(Color(0.83, 0.88, 0.94), f).lerp(Color(0.95, 0.55, 0.3), glow * 0.6)
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color.lerp(Color(0.3, 0.28, 0.25), 0.4)
	_sun.rotation_degrees = Vector3(-10.0 - 60.0 * f, -38.0 + world_hour * 15.0, 0.0)
	_sun.shadow_enabled = quality >= 1 and f > 0.15
	_sun.light_energy = maxf(f * 1.4, 0.14)
	_sun.light_color = Color(1.0, 0.55, 0.3).lerp(Color(1.0, 0.96, 0.88), f)
	_fill.light_energy = 0.32 + 0.18 * f
	_fill.light_color = Color(0.35, 0.42, 0.65).lerp(Color(0.6, 0.7, 0.95), f)
	_env.fog_light_color = _sky_mat.sky_horizon_color
	_env.ambient_light_energy = 0.8 + 0.45 * f
	var night := f < 0.25
	var pp := Vector3.ZERO
	if player != null and is_instance_valid(player):
		pp = player.global_position
	var sun_dir: Vector3 = _sun.global_transform.basis.z
	_sun_vis.global_position = pp + sun_dir * 140.0
	_moon_vis.global_position = pp - sun_dir * 140.0
	_sun_vis.visible = f > 0.03
	_moon_vis.visible = f < 0.45
	for lamp in _lamps:
		if is_instance_valid(lamp):
			var lm: StandardMaterial3D = lamp.material_override
			if night:
				lm.albedo_color = Color(1.0, 0.9, 0.6)
				lm.emission = Color(0.8, 0.6, 0.25)
			else:
				lm.albedo_color = Color(0.7, 0.7, 0.65)
				lm.emission = Color(0.05, 0.05, 0.04)
			lm.emission_energy_multiplier = 2.2 if night else 1.0
	for li in _lamp_lights:
		if is_instance_valid(li):
			li.light_energy = 1.8 if night else 0.0
	if _player_light != null and is_instance_valid(_player_light):
		_player_light.light_energy = 1.5 if night else 0.0
	if _fireflies != null and is_instance_valid(_fireflies):
		_fireflies.visible = night
	if _stars != null and is_instance_valid(_stars):
		_stars.visible = f < 0.2


func _build_lamps() -> void:
	for off in [Vector3(-38, 0, 3), Vector3(-14, 0, 58), Vector3(6, 0, 58), Vector3(-14, 0, 76), Vector3(6, 0, 76), Vector3(-4, 0, 66), Vector3(12, 0, 70)]:
		var wx: float = off.x
		var wz: float = off.z
		var ly: float = terrain.height_at(wx, wz)
		ly = minf(ly, minf(terrain.height_at(wx - 0.5, wz), terrain.height_at(wx + 0.5, wz)))
		ly = minf(ly, minf(terrain.height_at(wx, wz - 0.5), terrain.height_at(wx, wz + 0.5)))
		var root := Node3D.new()
		root.position = Vector3(wx, ly - 0.02, wz)
		add_child(root)
		_part(root, Vector3(0.14, 3.2, 0.14), Color(0.3, 0.24, 0.18), Vector3(0, 1.6, 0))
		_part(root, Vector3(0.5, 0.1, 0.5), Color(0.3, 0.24, 0.18), Vector3(0, 3.25, 0))
		var bulb := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.16
		bm.height = 0.32
		bulb.mesh = bm
		bulb.position = Vector3(0, 3.05, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.7, 0.65)
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.05, 0.04)
		bulb.material_override = mat
		root.add_child(bulb)
		_lamps.append(bulb)
		var li := OmniLight3D.new()
		li.position = Vector3(0, 3.0, 0)
		li.omni_range = 8.0
		li.light_color = Color(1.0, 0.78, 0.45)
		li.light_energy = 0.0
		li.shadow_enabled = false
		root.add_child(li)
		_lamp_lights.append(li)


func _build_pier() -> void:
	var lx: float = terrain.LAKE_POS.x
	var lz: float = terrain.LAKE_POS.y
	var shore_x: float = lx + float(terrain.LAKE_RADIUS) + 3.5
	var end_x: float = lx + 1.5
	var wood := Color(0.5, 0.36, 0.22)
	var wood_dark := Color(0.42, 0.3, 0.18)
	var y0 := 0.55
	for px in 2:
		var sx: float = shore_x + (end_x - shore_x) * 0.25 + float(px) * (end_x - shore_x) * 0.5
		_part(self, Vector3(end_x - shore_x + 1.0, 0.1, 0.12), wood_dark, Vector3(sx, y0 - 0.12, lz - 0.55))
		_part(self, Vector3(end_x - shore_x + 1.0, 0.1, 0.12), wood_dark, Vector3(sx, y0 - 0.12, lz + 0.55))
	var npl := 12
	for i in npl:
		var t := float(i) / float(npl - 1)
		var px2: float = shore_x + (end_x - shore_x) * t
		var plank := _part(self, Vector3(0.56, 0.06, 1.5), wood, Vector3(px2, y0, lz))
		plank.rotation.z = deg_to_rad(randf_range(-1.5, 1.5))
	for posts in 4:
		var t2 := float(posts % 2)
		var px3: float = shore_x - 1.0 - t2 * ((shore_x - end_x) - 2.0)
		for pz in [-0.55, 0.55]:
			_part(self, Vector3(0.16, 2.4, 0.16), wood_dark, Vector3(px3, y0 - 1.2, lz + pz))
	_part(self, Vector3(0.14, 1.0, 0.14), wood_dark, Vector3(end_x - 0.2, y0 + 0.5, lz - 0.6))
	_part(self, Vector3(0.55, 0.75, 0.55), Color(0.5, 0.36, 0.24), Vector3(end_x - 0.7, y0 + 0.42, lz + 0.4))
	_part(self, Vector3(0.6, 0.08, 0.6), Color(0.38, 0.27, 0.18), Vector3(end_x - 0.7, y0 + 0.83, lz + 0.4))
	_boat = Node3D.new()
	_boat.position = Vector3(lx + 3.0, 0.08, lz + 5.5)
	_boat.rotation.y = deg_to_rad(35.0)
	add_child(_boat)
	_boat_base_y = 0.08
	var hull_mat := _part_mat(Color(0.55, 0.4, 0.25))
	var hull := MeshInstance3D.new()
	var hm2 := BoxMesh.new()
	hm2.size = Vector3(2.0, 0.4, 0.9)
	hull.mesh = hm2
	hull.material_override = hull_mat
	hull.position = Vector3(0, 0.1, 0)
	_boat.add_child(hull)
	var bow := MeshInstance3D.new()
	var bwm := PrismMesh.new()
	bwm.size = Vector3(0.5, 0.4, 0.9)
	bow.mesh = bwm
	bow.rotation.y = PI * 0.5
	bow.position = Vector3(1.2, 0.1, 0)
	bow.material_override = hull_mat
	_boat.add_child(bow)
	var inner := MeshInstance3D.new()
	var im := BoxMesh.new()
	im.size = Vector3(1.7, 0.3, 0.6)
	inner.mesh = im
	var imat := StandardMaterial3D.new()
	imat.albedo_color = Color(0.16, 0.2, 0.28)
	inner.material_override = imat
	inner.position = Vector3(-0.05, 0.24, 0)
	_boat.add_child(inner)
	for bx in [-0.5, 0.4]:
		_part(_boat, Vector3(0.12, 0.05, 0.75), Color(0.48, 0.34, 0.2), Vector3(bx, 0.32, 0))
	for ox in [-0.7, 0.6]:
		var oar := _part(_boat, Vector3(0.9, 0.04, 0.07), Color(0.45, 0.32, 0.2), Vector3(ox, 0.3, 0.32))
		oar.rotation.y = deg_to_rad(12.0)


func _build_reeds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in 30:
		var ang := rng.randf() * TAU
		var rr := rng.randf_range(terrain.LAKE_RADIUS + 0.5, terrain.LAKE_RADIUS + 2.8)
		var cx: float = terrain.LAKE_POS.x + cos(ang) * rr
		var cz: float = terrain.LAKE_POS.y + sin(ang) * rr
		var cy: float = terrain.height_at(cx, cz)
		var cl := Node3D.new()
		cl.position = Vector3(cx, cy, cz)
		add_child(cl)
		_scatter.append(cl)
		for k in rng.randi_range(3, 5):
			var h := rng.randf_range(0.6, 1.15)
			var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			var stalk := _part(cl, Vector3(0.03, h, 0.03), Color(0.32, rng.randf_range(0.45, 0.58), 0.22), off + Vector3(0, h * 0.5, 0))
			stalk.rotation.z = rng.randf_range(-0.08, 0.08)
			if rng.randf() < 0.45:
				_part(cl, Vector3(0.05, 0.17, 0.05), Color(0.45, 0.3, 0.16), off + Vector3(0, h + 0.07, 0))


func _build_birds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	for f in 2:
		var center := Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(24.0, 34.0), rng.randf_range(-40.0, 40.0))
		var radius := rng.randf_range(18.0, 34.0)
		var speed := rng.randf_range(0.08, 0.14) * (1.0 if f == 0 else -1.0)
		var phase := rng.randf() * TAU
		for b in 4:
			var bird := Node3D.new()
			for wz in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var wm := BoxMesh.new()
				wm.size = Vector3(0.55, 0.02, 0.14)
				wing.mesh = wm
				wing.position = Vector3(wz * 0.28, 0.0, 0.0)
				wing.rotation.z = wz * deg_to_rad(18.0)
				var wmat := StandardMaterial3D.new()
				wmat.albedo_color = Color(0.25, 0.24, 0.26)
				wing.material_override = wmat
				bird.add_child(wing)
			add_child(bird)
			_birds.append([bird, center, radius, speed, phase + float(b) * 0.35, rng.randf_range(0.0, 2.0)])


func _build_stars() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	mm.mesh = sm
	var count := 140
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	for i in count:
		var ang := rng.randf() * TAU
		var el := rng.randf_range(0.12, 1.45)
		var r := 250.0
		var p := Vector3(cos(ang) * cos(el) * r, sin(el) * r, sin(ang) * cos(el) * r)
		var s := rng.randf_range(0.25, 0.8)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))
	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.98, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.92, 1.0)
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stars.material_override = mat
	_stars.visible = false
	add_child(_stars)


func _build_paths() -> void:
	var path_mat := _part_mat(Color(0.48, 0.38, 0.26))
	for off in HOUSE_OFFSETS:
		var sx: float = off.x
		var sz: float = off.z + 2.2
		var tx := -5.0
		var tz := 68.0
		var total := Vector2(tx - sx, tz - sz).length()
		if total < 3.0:
			continue
		var dirn := Vector2(tx - sx, tz - sz) / total
		for s in 4:
			var t0 := (float(s) + 0.5) / 4.0
			var mx := sx + dirn.x * total * t0
			var mz := sz + dirn.y * total * t0
			var seg := total / 4.0 + 0.4
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.15 + float(s % 2) * 0.25, seg)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = path_mat
			mi.position = Vector3(mx, terrain.height_at(mx, mz) + 0.04, mz)
			mi.rotation.y = atan2(dirn.x, dirn.y)
			add_child(mi)


func _build_fence() -> void:
	var wood := Color(0.5, 0.36, 0.22)
	var z := 80.5
	var spans: Array = [[-22.0, -3.0], [3.0, 12.0]]
	for sp in spans:
		var x0: float = sp[0]
		var x1: float = sp[1]
		var n := int((x1 - x0) / 2.4)
		for i in n + 1:
			var px := x0 + (x1 - x0) * float(i) / float(n)
			var py: float = terrain.height_at(px, z)
			_part(self, Vector3(0.14, 1.1, 0.14), wood, Vector3(px, py + 0.5, z))
			_part(self, Vector3(0.2, 0.1, 0.2), Color(0.42, 0.3, 0.18), Vector3(px, py + 1.12, z))
			if i < n:
				var nx: float = x0 + (x1 - x0) * float(i + 1) / float(n)
				var mid := (px + nx) * 0.5
				var seglen := absf(nx - px)
				for ry in [0.55, 0.95]:
					var rail := _part(self, Vector3(seglen, 0.09, 0.07), Color(0.55, 0.4, 0.25), Vector3(mid, 0.0, z))
					rail.position = Vector3(mid, terrain.height_at(mid, z) + ry, z)
					rail.rotation.y = 0.0
	for gx in [-3.0, 3.0]:
		var gy: float = terrain.height_at(gx, z)
		_part(self, Vector3(0.2, 1.4, 0.2), Color(0.45, 0.32, 0.2), Vector3(gx, gy + 0.65, z))
		_part(self, Vector3(0.26, 0.12, 0.26), Color(0.42, 0.3, 0.18), Vector3(gx, gy + 1.42, z))


func buy_truck() -> void:
	if has_truck or money < GameData.TRUCK_PRICE:
		return
	money -= GameData.TRUCK_PRICE
	has_truck = true
	_spawn_truck(Vector3(-4.0, 0.0, 56.0), PI)
	sound.play("coins")
	hud.flash("Caminhão entregue no vilarejo! E perto dele para dirigir; a caçamba coleta minérios no caminho.")
	open_merchant_menu()


func _spawn_truck(pos: Vector3, yaw: float) -> void:
	if truck != null and is_instance_valid(truck):
		truck.queue_free()
	var root := Node3D.new()
	root.position = Vector3(pos.x, terrain.height_at(pos.x, pos.z), pos.z)
	root.rotation = Vector3(0, yaw, 0)
	add_child(root)
	_part(root, Vector3(2.0, 0.5, 4.2), Color(0.55, 0.3, 0.2), Vector3(0, 0.85, 0))
	_part(root, Vector3(1.8, 1.0, 1.5), Color(0.45, 0.5, 0.55), Vector3(0, 1.6, -1.35))
	_part(root, Vector3(1.7, 0.5, 0.08), Color(0.7, 0.85, 0.95), Vector3(0, 1.75, -2.06))
	_part(root, Vector3(1.9, 0.1, 1.6), Color(0.4, 0.44, 0.48), Vector3(0, 2.15, -1.35))
	_part(root, Vector3(1.6, 0.4, 0.08), Color(0.3, 0.3, 0.32), Vector3(0, 1.1, -2.12))
	var bed := Node3D.new()
	bed.position = Vector3(0, 1.15, 0.9)
	bed.rotation.x = deg_to_rad(-4.0)
	root.add_child(bed)
	_part(bed, Vector3(1.9, 0.12, 2.5), Color(0.35, 0.3, 0.28), Vector3(0, 0, 0))
	_part(bed, Vector3(1.9, 0.5, 0.1), Color(0.35, 0.3, 0.28), Vector3(0, 0.28, 1.22))
	_part(bed, Vector3(1.9, 0.5, 0.1), Color(0.35, 0.3, 0.28), Vector3(0, 0.28, -1.22))
	_part(bed, Vector3(0.1, 0.5, 2.5), Color(0.35, 0.3, 0.28), Vector3(0.9, 0.28, 0))
	_part(bed, Vector3(0.1, 0.5, 2.5), Color(0.35, 0.3, 0.28), Vector3(-0.9, 0.28, 0))
	for wpos in [Vector3(1.0, 0.45, -1.4), Vector3(-1.0, 0.45, -1.4), Vector3(1.0, 0.45, 1.4), Vector3(-1.0, 0.45, 1.4)]:
		var tire := _cyl_root(root, 0.45, 0.32, Color(0.13, 0.13, 0.14), wpos)
		tire.rotation_degrees = Vector3(0, 0, 90)
		var rim := _cyl_root(root, 0.22, 0.34, Color(0.6, 0.6, 0.62), wpos)
		rim.rotation_degrees = Vector3(0, 0, 90)
	_part(root, Vector3(0.25, 0.15, 0.05), Color(1.0, 0.95, 0.6), Vector3(0.6, 1.0, -2.12))
	_part(root, Vector3(0.25, 0.15, 0.05), Color(1.0, 0.95, 0.6), Vector3(-0.6, 1.0, -2.12))
	truck = root
	truck_yaw = yaw


func _cyl_root(root: Node3D, radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = _part_mat(color)
	mi.position = pos
	root.add_child(mi)
	return mi


func _update_truck(delta: float) -> void:
	if not driving or truck == null or not is_instance_valid(truck):
		return
	if menu_open or hud.map_visible() or hud.title_visible() or hud.intro_visible():
		return
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	truck_yaw -= iv.x * delta * 1.8
	var spd := 16.0 if Input.is_action_pressed("sprint") else 9.0
	var fwd := -iv.y * spd * delta
	var dirv := Vector3(-sin(truck_yaw), 0.0, -cos(truck_yaw))
	var np: Vector3 = truck.position + dirv * fwd
	np.x = clampf(np.x, -terrain.HALF + 2.0, terrain.HALF - 2.0)
	np.z = clampf(np.z, -terrain.HALF + 2.0, terrain.HALF - 2.0)
	var prev_tx := np.x
	if np.z < 48.0 and not zone_unlocked(GameData.zone_at(np.x)) and not zone_unlocked(GameData.zone_at(truck.position.x)):
		np.x = truck.position.x
		if absf(np.x - prev_tx) > 0.001:
			np.z = truck.position.z
	np.y = terrain.height_at(np.x, np.z)
	truck.position = np
	truck.rotation = Vector3(0, truck_yaw, 0)
	player.global_position = np + Vector3(0, 1.3, 0)


func _toggle_truck() -> void:
	if truck == null or not is_instance_valid(truck):
		return
	if driving:
		driving = false
		var side := Vector3(cos(truck_yaw), 0.0, -sin(truck_yaw))
		player.global_position = truck.position + side * 2.2 + Vector3(0, 0.5, 0)
		hud.flash("Você saiu do caminhão.")
	else:
		driving = true
		sound.play("craft")
		hud.flash("Dirigindo! WASD move, Shift acelera, E desce. A caçamba recolhe minérios pelo caminho.")


func truck_cargo_value() -> int:
	var total := 0
	for k in truck_cargo:
		total += int(ceil(float(GameData.ORES[String(k)]["value"]) * _sell_mult())) * int(truck_cargo[k])
	return total


func sell_truck_cargo() -> void:
	var total := truck_cargo_value()
	if total <= 0:
		return
	var n := 0
	for k in truck_cargo:
		n += int(truck_cargo[k])
	money += total
	total_earned += total
	truck_cargo.clear()
	sound.play("coins")
	hud.flash("Carga do caminhão vendida: %d minérios por $%d!" % [n, total])
	open_merchant_menu()


func open_map() -> void:
	if menu_open or placing != "":
		return
	map_open = true
	hud.show_map()


func fast_travel(dest: String) -> void:
	var target := Vector3.ZERO
	match dest:
		"vila":
			target = Vector3(-5.0, 0.0, 60.0)
		"lago":
			var lp: Vector2 = terrain.LAKE_POS
			target = Vector3(lp.x + 12.0, 0.0, lp.y)
		"t2":
			target = Vector3(-28.0, 0.0, 0.0)
		"t3":
			target = Vector3(2.0, 0.0, 0.0)
		"t4":
			target = Vector3(32.0, 0.0, 0.0)
		"t5":
			target = Vector3(57.0, 0.0, 0.0)
		_:
			return
	hud.hide_map()
	map_open = false
	player.global_position = Vector3(target.x, terrain.height_at(target.x, target.z) + 1.0, target.z)
	sound.play("ding")
	hud.flash("Viagem rápida concluída!")


func open_statue_menu() -> void:
	var opts: Array = []
	opts.append({"label": "Bônus atual: +%d%% no preço de venda de TUDO" % int(statue_level * 5), "disabled": true, "action": _noop})
	if statue_level >= 10:
		opts.append({"label": "A estátua está completa! O vilarejo jamais esquecerá seu legado.", "disabled": true, "action": _noop})
	else:
		var cost := _statue_cost()
		opts.append({"label": "Doar para o nível %d (bônus +%d%%) — $%d" % [statue_level + 1, int((statue_level + 1) * 5), cost], "disabled": money < cost, "action": donate_statue})
	_open_menu("ESTÁTUA DO LEGADO — sua fama esculpida em pedra", opts)


func _statue_cost() -> int:
	return 2000 * (statue_level + 1) * (statue_level + 1)


func donate_statue() -> void:
	if statue_level >= 10:
		return
	var cost := _statue_cost()
	if money < cost:
		return
	money -= cost
	statue_level += 1
	sound.play("quest")
	hud.flash("A estátua cresceu! Todas as suas vendas agora valem +%d%%." % int(statue_level * 5))
	open_statue_menu()


func zone_unlocked(zone: int) -> bool:
	if zone < 0 or zone >= unlocked.size():
		return false
	return bool(unlocked[zone])


func roll_ore(zone: int) -> String:
	if zone < 0 or zone >= GameData.ORE_WEIGHTS.size():
		return ""
	var weights: Array = GameData.ORE_WEIGHTS[zone]
	var idx := GameData.pick_weighted(weights)
	if idx < 0:
		return ""
	return String(GameData.ORE_ORDER[idx])


func roll_gem(zone: int) -> String:
	if zone < 0 or zone >= GameData.GEM_WEIGHTS.size():
		return ""
	var weights: Array = GameData.GEM_WEIGHTS[zone]
	var idx := GameData.pick_weighted(weights)
	if idx < 0:
		return ""
	return String(GameData.GEM_ORDER[idx])


func on_drill_watered() -> void:
	drills_watered = true


func on_harvester_ore() -> void:
	stats_harvester += 1


func update_aim(hit: Vector3, valid: bool) -> void:
	_aim = hit
	_aim_valid = valid
	if placing == "":
		return
	if not valid:
		machines.hide_ghost()
		return
	if placing == "cano":
		var snap: Dictionary = machines.snap_pipe(hit)
		_aim = snap["pos"]
		machines.set_pipe_ghost(_aim, snap["from"], bool(snap["linked"]))
	elif placing == "registro":
		var snap_r: Dictionary = machines.snap_pipe(hit)
		_aim = snap_r["pos"]
		machines.set_pipe_ghost(_aim, snap_r["from"], bool(snap_r["linked"]))
	elif placing == "cabo":
		var snap_c: Dictionary = machines.snap_cabo(hit)
		_aim = snap_c["pos"]
		machines.set_wire_ghost(_aim, snap_c["from"], bool(snap_c["linked"]))
	elif placing == "esteira" or placing == "filtro" or placing == "esteira_v" or placing == "splitter":
		var se: Dictionary = machines.snap_esteira(hit)
		_aim = se["pos"]
		_esteira_prev = int(se["prev_id"])
		_esteira_yaw = float(se["yaw"])
		_esteira_linked = bool(se["linked"])
		_esteira_on_pipe = bool(se.get("on_pipe", false))
		machines.set_belt_ghost(_aim, _esteira_yaw, se["from"], bool(se["linked"]))
	elif placing == "drill":
		machines.set_drill_ghost(_aim, _placing_yaw)
	else:
		machines.set_ghost(_aim)


func on_click() -> void:
	if menu_open:
		return
	if placing != "":
		try_place()


func tool_hold(delta: float) -> void:
	if menu_open or not _aim_valid or placing != "":
		return
	var bacia: Dictionary = machines.nearest_of_type(_aim, "bacia", 4.0)
	if not bacia.is_empty() and float(bacia["dirt"]) > 0.0 and float(bacia["water"]) > 0.2:
		player.set_brushing(true)
		brush_needed = float(GameData.BRUSH_TIERS[brush_tier]["time"])
		brush_progress += delta
		if brush_progress >= brush_needed:
			brush_progress = 0.0
			_finish_brush(bacia)
	else:
		player.set_brushing(false)
		brush_progress = 0.0
		try_dig(_aim)


func end_tool() -> void:
	player.set_brushing(false)


func _dump_bucket() -> void:
	if truck != null and is_instance_valid(truck) and not driving and not truck_cargo.is_empty() and player.global_position.distance_to(truck.position) < 4.0:
		var n := 0
		for k in truck_cargo:
			pocket_ores[k] = int(pocket_ores.get(k, 0)) + int(truck_cargo[k])
			n += int(truck_cargo[k])
		truck_cargo.clear()
		hud.flash("Caçamba descarregada no bolso: %d minério(s)." % n)
		sound.play("ding")
		return
	if bucket_terra == 0 and bucket_water <= 0.0:
		hud.flash("O balde já está vazio.")
		return
	bucket_terra = 0
	bucket_water = 0.0
	sound.play("water")
	hud.flash("Balde esvaziado no chão.")


func _ground_y(x: float, z: float) -> float:
	var gy: float = terrain.height_at(x, z)
	var corners: Array[Vector2] = [Vector2(1.1, 0.8), Vector2(-1.1, 0.8), Vector2(1.1, -0.8), Vector2(-1.1, -0.8)]
	for off in corners:
		gy = maxf(gy, terrain.height_at(x + off.x, z + off.y))
	return gy - 0.05


func try_dig(hit: Vector3) -> void:
	if dig_cooldown > 0.0:
		return
	if hit.distance_to(player.global_position) > 9.0:
		return
	if hit.x > terrain.VILLAGE_MIN.x - 2.0 and hit.x < terrain.VILLAGE_MAX.x + 2.0 and hit.z > terrain.VILLAGE_MIN.y - 2.0 and hit.z < terrain.VILLAGE_MAX.y + 2.0:
		hud.flash("Não cave no vilarejo!")
		return
	var pa: Dictionary = GameData.PA_TIERS[pa_tier]
	if bucket_terra >= int(pa["bucket"]):
		hud.flash("Balde cheio de terra! Despeje numa bacia (E).")
		dig_cooldown = 0.5
		return
	dig_cooldown = float(pa["cooldown"])
	var removed: float = terrain.dig(hit, float(pa["radius"]), float(pa["power"]))
	if removed < 0.0:
		hud.flash("Terras trancadas! Progrida na história para abrir.")
		return
	if removed <= 0.0:
		return
	bucket_terra += 1
	sound.play("dig")
	_dust_burst(hit, Color(0.55, 0.42, 0.3))
	var dig_chance := 0.25
	if _lucky_time > 0.0:
		dig_chance = 0.5
	if has_picareta and player.global_position.y - hit.y > 1.5 and randf() < dig_chance:
		var oid: String = roll_ore(GameData.zone_at(hit.x))
		if oid != "":
			_spawn_pickup(hit, "ore", oid)
	if randf() < 0.005:
		_add_artefato(GameData.zone_at(hit.x))


func _finish_brush(bacia: Dictionary) -> void:
	sound.play("reveal")
	bacia["dirt"] = float(bacia["dirt"]) - 1.0
	var zone := GameData.zone_at(bacia["pos"].x)
	var count := 3 + (randi() % 4) + zone
	if has_rastelo:
		count += 1
	if _lucky_time > 0.0:
		count *= 2
	for i in count:
		var ore: String = roll_ore(zone)
		if ore != "":
			_spawn_pickup(bacia["pos"], "ore", ore)
	var gem_chance := 0.12 + 0.04 * float(zone)
	if has_rastelo:
		gem_chance += 0.08
	if randf() < gem_chance:
		var gem: String = roll_gem(zone)
		if gem != "":
			_spawn_pickup(bacia["pos"], "gem", gem)
	if randf() < 0.02:
		_add_artefato(zone)


func _add_artefato(zone: int) -> void:
	var nome: String = GameData.ARTEFACT_NAMES[randi() % GameData.ARTEFACT_NAMES.size()]
	var valor := (20 + randi() % 80) * (zone + 1)
	artefatos.append({"name": nome, "valor": valor})
	hud.flash("Você encontrou um artefato: %s! ($%d)" % [nome, valor])


func _rock_mesh(vi: int) -> ArrayMesh:
	while _rock_variants.size() <= vi:
		var seed_v := 5150 + _rock_variants.size() * 31
		var noise := FastNoiseLite.new()
		noise.seed = seed_v
		noise.frequency = 1.6
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		sm.radial_segments = 10
		sm.rings = 6
		var arrays := sm.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			var v := verts[i]
			var d := 1.0 + 0.3 * noise.get_noise_3d(v.x * 40.0, v.y * 40.0, v.z * 40.0)
			verts[i] = v * d
		arrays[Mesh.ARRAY_VERTEX] = verts
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		st.deindex()
		st.generate_normals()
		_rock_variants.append(st.commit())
	return _rock_variants[vi]


func _gem_mesh() -> ArrayMesh:
	if _gem_variant != null:
		return _gem_variant
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.11
	cm.height = 0.26
	cm.radial_segments = 6
	var st := SurfaceTool.new()
	st.create_from(cm, 0)
	_gem_variant = st.commit()
	return _gem_variant


func _spawn_pickup(pos: Vector3, kind: String, id: String) -> void:
	if _pickups.size() >= 80:
		var old: Node3D = _pickups[0]
		if is_instance_valid(old):
			old.queue_free()
		_pickups.remove_at(0)
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if kind == "ore":
		var ore: Dictionary = GameData.ORES[id]
		m.mesh = _rock_mesh(randi() % 4)
		m.rotation.y = randf() * TAU
		m.scale = Vector3.ONE * randf_range(0.9, 1.3)
		mat.albedo_color = ore["color"]
		mat.metallic = 0.7
		mat.roughness = 0.35
		if id == "sacradium":
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.95, 0.6)
			mat.emission_energy_multiplier = 1.8
			var aura := OmniLight3D.new()
			aura.omni_range = 3.0
			aura.light_energy = 0.9
			aura.light_color = Color(1.0, 0.95, 0.6)
			m.add_child(aura)
	else:
		var gem: Dictionary = GameData.GEMS[id]
		m.mesh = _gem_mesh()
		m.rotation.y = randf() * TAU
		m.scale = Vector3.ONE * randf_range(0.9, 1.2)
		mat.albedo_color = gem["color"]
		mat.emission_enabled = true
		mat.emission = gem["color"] * 0.4
		mat.roughness = 0.1
	m.material_override = mat
	var p := pos
	p.x += randf_range(-1.0, 1.0)
	p.z += randf_range(-1.0, 1.0)
	p.y = terrain.height_at(p.x, p.z) + 0.15
	m.position = p
	m.set_meta("kind", kind)
	m.set_meta("id", id)
	add_child(m)
	_pickups.append(m)


func _collect_pickups() -> void:
	var i := _pickups.size() - 1
	var got := false
	var reach := 3.5 if driving else 1.8
	while i >= 0:
		var n: Node3D = _pickups[i]
		if not is_instance_valid(n):
			_pickups.remove_at(i)
		elif n.global_position.distance_to(player.global_position) < reach:
			var kind: String = n.get_meta("kind")
			var id: String = n.get_meta("id")
			if kind == "ore":
				if driving:
					truck_cargo[id] = int(truck_cargo.get(id, 0)) + 1
				else:
					pocket_ores[id] = int(pocket_ores.get(id, 0)) + 1
				stats_ores += 1
			else:
				pocket_gems_raw[id] = int(pocket_gems_raw.get(id, 0)) + 1
			var pcol: Color = GameData.ORES[id]["color"] if kind == "ore" else GameData.GEMS[id]["color"]
			_sparkle_burst(n.global_position, pcol)
			n.queue_free()
			_pickups.remove_at(i)
			got = true
		i -= 1
	if got:
		sound.play("ding")


func interact() -> void:
	if menu_open:
		return
	var pp: Vector3 = player.global_position
	if Vector2(pp.x, pp.z).distance_to(terrain.LAKE_POS) < 11.0:
		bucket_water = 1.0
		sound.play("water")
		hud.flash("Balde cheio de água!")
		_splash_burst(pp)
		return
	var m: Dictionary = machines.nearest(pp, 3.5)
	if not m.is_empty():
		_interact_machine(m)
		return
	if pp.distance_to(MERCHANT_POS) < 4.0:
		met_merchant = true
		open_merchant_menu()
		return
	if pp.distance_to(BOARD_POS) < 4.0:
		open_board_menu()
		return
	if pp.distance_to(STATUE_POS) < 3.5:
		open_statue_menu()
		return
	if truck != null and is_instance_valid(truck) and pp.distance_to(truck.position) < 3.5:
		_toggle_truck()
		return
	hud.flash("Nada por perto para interagir.")


func _interact_machine(m: Dictionary) -> void:
	var type: String = m["type"]
	match type:
		"bacia":
			if bucket_terra > 0:
				m["dirt"] = float(m["dirt"]) + float(bucket_terra)
				hud.flash("Despejou %d carga(s) de terra na bacia." % bucket_terra)
				bucket_terra = 0
				sound.play("dig")
			elif bucket_water > 0.0:
				m["water"] = float(m["water"]) + 1.0
				bucket_water = 0.0
				sound.play("water")
				hud.flash("Água na bacia! Mire na bacia e segure o clique para escovar.")
			else:
				hud.flash("Bacia: traga terra (pá) ou água (balde no lago).")
		"drill":
			if bucket_water > 0.0:
				m["water_time"] = 30.0
				bucket_water = 0.0
				hud.flash("Drill com água por 30s! Ligue canos ao lago para água infinita.")
			else:
				hud.flash("Drill precisa de água: despeje um balde ou ligue canos ao lago.")
		"harvester":
			if bucket_terra > 0:
				var cap_h := 40 + 20 * int(m["tier"])
				var espaco := cap_h - int(float(m["dirt"]))
				if espaco <= 0:
					hud.flash("Harvester cheio de terra — ele consome rápido, aguarde.")
					return
				var deitou: int = mini(bucket_terra, espaco)
				m["dirt"] = float(m["dirt"]) + float(deitou)
				bucket_terra -= deitou
				sound.play("dig")
				hud.flash("Despejou %d carga(s) de terra no harvester (como jogar no topo)." % deitou)
				return
			var caixa: Dictionary = m["caixa"]
			var cg: Dictionary = m["caixa_gems"]
			var total := 0
			for k in caixa:
				pocket_ores[k] = int(pocket_ores.get(k, 0)) + int(caixa[k])
				total += int(caixa[k])
			for k in cg:
				pocket_gems_raw[k] = int(pocket_gems_raw.get(k, 0)) + int(cg[k])
				total += int(cg[k])
			caixa.clear()
			cg.clear()
			hud.flash("Coletou %d item(ns) da caixa!" % total)
		"cadinho":
			open_cadinho_menu(m)
		"forja":
			bars_heated = 60.0
			hud.flash("Barras aquecidas! Corra para a bigorna (60s).")
		"bigorna":
			open_anvil_menu()
		"esteira", "esteira_v":
			open_belt_menu(m)
		"splitter":
			open_splitter_menu(m)
		"filtro":
			open_filtro_menu(m)
		"bau":
			_collect_bau(m)
		"silo":
			hud.flash("Silo: %d/800 de terra. O harvester puxa dele se estiver a 3,5m." % int(float(m["dirt"])))
		"registro":
			_toggle_registro(m)
		"gerador":
			var pstats: Dictionary = machines.power_stats()
			hud.flash("Gerador ligado: fornece %d de energia | consumo da rede: %d" % [int(pstats["supply"]), int(pstats["demand"])])
		"sensor":
			m["count"] = 0
			m["last_total"] = 0
			hud.flash("Contagem do sensor zerada!")
			sound.play("ding")
		"alarme":
			open_alarme_menu(m)
		"vein":
			if String(m.get("ore", "")) == "":
				hud.flash("Este veio está esgotado.")
				return
			if float(m.get("cooldown", 0.0)) > 0.0:
				hud.flash("O veio precisa de %ds para se recompor." % int(ceil(float(m["cooldown"]))))
				return
			var n := 3 + randi() % 6
			for i in n:
				_spawn_pickup(m["pos"], "ore", String(m["ore"]))
			m["cooldown"] = GameData.VEIN_COOLDOWN
			sound.play("reveal")
			hud.flash("Você minerou %d minério(s) do veio! Ele se recompõe em %ds." % [n, int(GameData.VEIN_COOLDOWN)])
		"interruptor":
			m["open"] = not bool(m.get("open", true))
			machines.recompute_wires()
			sound.play("craft")
			if bool(m["open"]):
				hud.flash("Interruptor LIGADO — máquinas voltam a trabalhar.")
			else:
				hud.flash("Interruptor DESLIGADO — drills, esteiras e harvesters a 10m pararam.")
		"polidora":
			if not machines.is_power_connected_at(m["pos"]):
				hud.flash("SEM ENERGIA — ligue cabos da polidora a um gerador.")
			elif not machines.power_ok():
				hud.flash("REDE SOBRECARREGADA — a soma dos geradores não cobre todas as máquinas.")
			else:
				_polish_gems()
		"prensa":
			if not machines.is_power_connected_at(m["pos"]):
				hud.flash("SEM ENERGIA — ligue cabos da prensa a um gerador.")
			elif not machines.power_ok():
				hud.flash("REDE SOBRECARREGADA — a soma dos geradores não cobre todas as máquinas.")
			else:
				open_prensa_menu()
		_:
			hud.flash("Máquina: %s" % type)


func _open_menu(title: String, options: Array) -> void:
	menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.open_menu(title, options)


func close_menu() -> void:
	menu_open = false
	_menu_machine = {}
	hud.close_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _noop() -> void:
	pass


func _pocket_ores_value() -> int:
	var v := 0
	for k in pocket_ores:
		v += int(pocket_ores[k]) * int(GameData.ORES[String(k)]["value"])
	return v


func _pocket_bars_value() -> int:
	var v := 0
	for k in pocket_bars:
		v += int(floor(float(pocket_bars[k]) * float(GameData.bar_value(String(k)))))
	return v


func _pocket_gems_value(raw: bool) -> int:
	var v := 0
	var src: Dictionary = pocket_gems_raw if raw else pocket_gems
	for k in src:
		v += int(src[k]) * int(float(GameData.GEMS[String(k)]["value"]) * 2.2)
	return v


func _joias_value() -> int:
	var v := 0
	for j in joias:
		v += int(j["valor"])
	return v


func _artefatos_value() -> int:
	var v := 0
	for a in artefatos:
		v += int(a["valor"])
	return v


func sell_all_ores() -> void:
	var v := int(float(_pocket_ores_value()) * _sell_mult())
	if v <= 0:
		return
	pocket_ores.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu os minérios por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_bars() -> void:
	var v := int(float(_pocket_bars_value()) * _sell_mult())
	if v <= 0:
		return
	pocket_bars.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu as barras por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_gems_raw() -> void:
	var v := int(float(_pocket_gems_value(true)) * _sell_mult())
	if v <= 0:
		return
	pocket_gems_raw.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu as gemas brutas por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_gems_polished() -> void:
	var v := int(float(_pocket_gems_value(false)) * _sell_mult())
	if v <= 0:
		return
	pocket_gems.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu as gemas polidas por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_joias() -> void:
	var v := int(float(_joias_value()) * _sell_mult())
	if v <= 0:
		return
	joias.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu as jóias por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func sell_all_artefatos() -> void:
	var v := int(float(_artefatos_value()) * _sell_mult())
	if v <= 0:
		return
	artefatos.clear()
	money += v
	total_earned += v
	hud.flash("Vendeu os artefatos por $%d!" % v)
	sound.play("coins")
	open_merchant_menu()


func buy_pa() -> void:
	if pa_tier >= GameData.PA_TIERS.size() - 1:
		return
	var price := int(GameData.PA_TIERS[pa_tier + 1]["price"])
	if money < price:
		return
	money -= price
	pa_tier += 1
	hud.flash("Nova pá: %s!" % String(GameData.PA_TIERS[pa_tier]["name"]))
	sound.play("coins")
	open_merchant_menu()


func buy_brush() -> void:
	if brush_tier >= GameData.BRUSH_TIERS.size() - 1:
		return
	var price := int(GameData.BRUSH_TIERS[brush_tier + 1]["price"])
	if money < price:
		return
	money -= price
	brush_tier += 1
	hud.flash("Nova escova: %s!" % String(GameData.BRUSH_TIERS[brush_tier]["name"]))
	sound.play("coins")
	open_merchant_menu()


func open_merchant_menu() -> void:
	var opts: Array = []
	var v_ores := _pocket_ores_value()
	opts.append({"label": "Vender todos os minérios — $%d" % v_ores, "disabled": v_ores <= 0, "action": sell_all_ores})
	var v_bars := _pocket_bars_value()
	opts.append({"label": "Vender todas as barras — $%d" % v_bars, "disabled": v_bars <= 0, "action": sell_all_bars})
	var v_raw := _pocket_gems_value(true)
	opts.append({"label": "Vender gemas brutas — $%d" % v_raw, "disabled": v_raw <= 0, "action": sell_all_gems_raw})
	var v_pol := _pocket_gems_value(false)
	opts.append({"label": "Vender gemas polidas — $%d" % v_pol, "disabled": v_pol <= 0, "action": sell_all_gems_polished})
	var v_joias := _joias_value()
	opts.append({"label": "Vender jóias — $%d" % v_joias, "disabled": v_joias <= 0, "action": sell_all_joias})
	var v_art := _artefatos_value()
	opts.append({"label": "Vender artefatos — $%d" % v_art, "disabled": v_art <= 0, "action": sell_all_artefatos})
	if pa_tier < GameData.PA_TIERS.size() - 1:
		var nxt: Dictionary = GameData.PA_TIERS[pa_tier + 1]
		opts.append({"label": "Comprar %s — $%d" % [String(nxt["name"]), int(nxt["price"])], "disabled": money < int(nxt["price"]), "action": buy_pa})
	if brush_tier < GameData.BRUSH_TIERS.size() - 1:
		var nxtb: Dictionary = GameData.BRUSH_TIERS[brush_tier + 1]
		opts.append({"label": "Comprar %s — $%d" % [String(nxtb["name"]), int(nxtb["price"])], "disabled": money < int(nxtb["price"]), "action": buy_brush})
	if not has_picareta:
		opts.append({"label": "Comprar Picareta — $%d (cavar fundo rende minério extra)" % GameData.PICARETA_PRICE, "disabled": money < GameData.PICARETA_PRICE, "action": buy_picareta})
	if not has_rastelo:
		opts.append({"label": "Comprar Rastelo — $%d (escovar rende +1 minério e mais gemas)" % GameData.RASTELO_PRICE, "disabled": money < GameData.RASTELO_PRICE, "action": buy_rastelo})
	if not has_detector:
		opts.append({"label": "Comprar Detector de Metais — $%d (revela o tipo dos veios a distância)" % GameData.DETECTOR_PRICE, "disabled": money < GameData.DETECTOR_PRICE, "action": buy_detector})
	opts.append({"label": "Comprar Dinamite — $%d (aponte o chão e aperte V: abre uma cratera grande)" % GameData.DYNAMITE_PRICE, "disabled": money < GameData.DYNAMITE_PRICE, "action": buy_dynamite})
	if not has_truck:
		opts.append({"label": "Comprar Caminhão — $%d (dirigível; a caçamba coleta minérios no caminho)" % GameData.TRUCK_PRICE, "disabled": money < GameData.TRUCK_PRICE, "action": buy_truck})
	elif not truck_cargo.is_empty() and truck != null and is_instance_valid(truck) and truck.position.distance_to(MERCHANT_POS) < 15.0:
		opts.append({"label": "Descarregar e vender a carga do caminhão — $%d" % truck_cargo_value(), "action": sell_truck_cargo})
	elif not truck_cargo.is_empty():
		opts.append({"label": "— Estacione o caminhão a 15m do mercador para vender a carga (%d itens) —" % truck_cargo_value(), "disabled": true, "action": _noop})
	var limite := 2000 + int(total_earned * 0.5)
	if debt > 0:
		opts.append({"label": "— BANCO — dívida atual: $%d (juros de 1%%/min; desconto automático de $%d a cada 30s) —" % [debt, mini(debt, maxi(50, int(debt * 0.05)))], "disabled": true, "action": _noop})
		opts.append({"label": "Pagar a dívida inteira agora — $%d" % debt, "disabled": money < debt, "action": bank_repay})
	else:
		var max_emp := maxi(0, limite - debt)
		if max_emp >= 500:
			opts.append({"label": "— BANCO — pegar empréstimo de $%d (limite: $%d, conforme seus ganhos) —" % [max_emp, limite], "action": bank_borrow})
	_open_menu("MERCADOR — bem-vindo, herdeiro!", opts)


func bank_borrow() -> void:
	var emp := maxi(0, (2000 + int(total_earned * 0.5)) - debt)
	if emp < 500:
		return
	money += emp
	debt += emp
	hud.flash("Empréstimo de $%d aceito! Juros de 1%%/min; pague no mercador para evitar o desconto automático." % emp)
	sound.play("coins")
	open_merchant_menu()


func bank_repay() -> void:
	if debt <= 0 or money < debt:
		return
	money -= debt
	debt = 0
	_debt_timer = 0.0
	hud.flash("Dívida quitada! O banco liberou seu nome.")
	sound.play("coins")
	open_merchant_menu()


func open_build_menu() -> void:
	if placing != "":
		cancel_placing()
		hud.flash("Construção cancelada.")
		return
	var opts: Array = []
	opts.append({"label": "Bacia — $%d" % GameData.BACIA_PRICE, "disabled": money < GameData.BACIA_PRICE, "action": start_placing.bind("bacia", 0)})
	opts.append({"label": "Cano — $%d (aponte perto de outro cano ou da drill para encaixar)" % GameData.PIPE_PRICE, "disabled": money < GameData.PIPE_PRICE, "action": start_placing.bind("cano", 0)})
	opts.append({"label": "Esteira — $%d (monte SOBRE um cano p/ velocidade total; ou encaixe na drill/outra esteira)" % GameData.ESTEIRA_PRICE, "disabled": money < GameData.ESTEIRA_PRICE, "action": start_placing.bind("esteira", 0)})
	opts.append({"label": "Esteira Vertical — $%d (sobe/desce escavações; encaixa na linha ou sobre cano)" % GameData.ESTEIRA_V_PRICE, "disabled": money < GameData.ESTEIRA_V_PRICE, "action": start_placing.bind("esteira_v", 0)})
	opts.append({"label": "Divisor de Esteira — $%d (bandeja lateral: desvia o que você põe nela p/ cadinho/baú do lado)" % GameData.SPLITTER_PRICE, "disabled": money < GameData.SPLITTER_PRICE, "action": start_placing.bind("splitter", 0)})
	opts.append({"label": "Filtro — $%d (na linha de esteiras: o minério escolhido sai para o cadinho do lado)" % GameData.FILTRO_PRICE, "disabled": money < GameData.FILTRO_PRICE, "action": start_placing.bind("filtro", 0)})
	opts.append({"label": "Registro — $%d (na linha de canos: E nele abre/fecha a água)" % GameData.REGISTRO_PRICE, "disabled": money < GameData.REGISTRO_PRICE, "action": start_placing.bind("registro", 0)})
	opts.append({"label": "Baú — $%d (guarda os minérios que chegam pela esteira)" % GameData.BAU_PRICE, "disabled": money < GameData.BAU_PRICE, "action": start_placing.bind("bau", 0)})
	opts.append({"label": "Silo — $%d (armazena terra da linha; o harvester puxa dele)" % GameData.SILO_PRICE, "disabled": money < GameData.SILO_PRICE, "action": start_placing.bind("silo", 0)})
	opts.append({"label": "— ENERGIA — a polidora e a prensa precisam de eletricidade —", "disabled": true, "action": _noop})
	opts.append({"label": "Cabo — $%d (encaixa no gerador ou em outro cabo; ligue até a máquina)" % GameData.CABO_PRICE, "disabled": money < GameData.CABO_PRICE, "action": start_placing.bind("cabo", 0)})
	for t in 5:
		var gt: Dictionary = GameData.GERADOR_TIERS[t]
		var glabel := "%s — $%d %s (fornece %d de energia)" % [String(gt["name"]), int(gt["money"]), _bars_cost_text(gt["bars"]), int(gt["power"])]
		opts.append({"label": glabel, "disabled": not can_afford(int(gt["money"]), gt["bars"]), "action": start_placing.bind("gerador", t)})
	opts.append({"label": "— LÓGICA E CONTROLE —", "disabled": true, "action": _noop})
	opts.append({"label": "Sensor — $%d (encoste numa esteira: conta os minérios que passam)" % GameData.SENSOR_PRICE, "disabled": money < GameData.SENSOR_PRICE, "action": start_placing.bind("sensor", 0)})
	opts.append({"label": "Alarme — $%d (a 6m de um sensor: avisa quando a contagem chega na meta)" % GameData.ALARME_PRICE, "disabled": money < GameData.ALARME_PRICE, "action": start_placing.bind("alarme", 0)})
	opts.append({"label": "Interruptor — $%d (E nele liga/desliga as máquinas num raio de 10m)" % GameData.INTERRUPTOR_PRICE, "disabled": money < GameData.INTERRUPTOR_PRICE, "action": start_placing.bind("interruptor", 0)})
	opts.append({"label": "— ESTRUTURAS —", "disabled": true, "action": _noop})
	for st_key in ["fundacao", "piso", "parede", "escada", "cerca"]:
		var st_price: int = int(GameData.STRUCT_PRICES[st_key])
		var st_label := "%s — $%d (Q/E ou roda gira a peça)" % [_machine_name(st_key, 0), st_price]
		opts.append({"label": st_label, "disabled": money < st_price, "action": start_placing.bind(st_key, 0)})
	opts.append({"label": "Cadinho — $%d (funde 10 minérios em 1 barra)" % CADINHO_PRICE, "disabled": money < CADINHO_PRICE, "action": start_placing.bind("cadinho", 0)})
	opts.append({"label": "Forja — $%d (aquece barras para a bigorna)" % GameData.FORJA_PRICE, "disabled": money < GameData.FORJA_PRICE, "action": start_placing.bind("forja", 0)})
	opts.append({"label": "Bigorna — $%d (forja anéis, adagas, espadas)" % GameData.BIGORNA_PRICE, "disabled": money < GameData.BIGORNA_PRICE, "action": start_placing.bind("bigorna", 0)})
	opts.append({"label": "Polidora — $%d (polidor de gemas brutas)" % GameData.POLIDORA_PRICE, "disabled": money < GameData.POLIDORA_PRICE, "action": start_placing.bind("polidora", 0)})
	opts.append({"label": "Prensa — $%d (combina gemas em jóias)" % GameData.PRENSA_PRICE, "disabled": money < GameData.PRENSA_PRICE, "action": start_placing.bind("prensa", 0)})
	for t in 5:
		var d: Dictionary = GameData.DRILL_TIERS[t]
		var label := "%s — $%d %s" % [String(d["name"]), int(d["money"]), _bars_cost_text(d["bars"])]
		opts.append({"label": label, "disabled": not can_afford(int(d["money"]), d["bars"]), "action": start_placing.bind("drill", t)})
	for t in 5:
		var hv: Dictionary = GameData.HARVESTER_TIERS[t]
		var label2 := "%s — $%d %s (movido a água por canos; rende mais com boa pressão)" % [String(hv["name"]), int(hv["money"]), _bars_cost_text(hv["bars"])]
		opts.append({"label": label2, "disabled": not can_afford(int(hv["money"]), hv["bars"]), "action": start_placing.bind("harvester", t)})
	_open_menu("CONSTRUÍR — escolha e posicione com o clique esquerdo", opts)


func start_placing(type: String, tier: int) -> void:
	placing = type
	placing_tier = tier
	close_menu()
	if type == "cano":
		hud.flash("Modo cano: aproxime da drill ou de outro cano e ele ENCAIXA sozinho. T para sair.")
	elif type == "esteira":
		hud.flash("Modo esteira: monte SOBRE um cano (velocidade total) ou encaixe na drill/outra esteira. T para sair.")
	elif type == "esteira_v":
		hud.flash("Modo esteira vertical: sobe/desce escavações — encaixa na linha ou sobre um cano. T para sair.")
	elif type == "splitter":
		hud.flash("Modo divisor: bandeja lateral desvia o que você põe nela para um cadinho/baú do lado. T para sair.")
	elif type == "filtro":
		hud.flash("Modo filtro: encaixe na linha de esteiras com um cadinho do lado. Aperte E no filtro para escolher o minério. T para sair.")
	elif type == "registro":
		hud.flash("Modo registro: encaixa na linha de canos. E nele abre/fecha a água. T para sair.")
	elif type == "cabo":
		hud.flash("Modo cabo: comece no gerador e vá encaixando até a polidora/prensa. T para sair.")
	elif type == "gerador":
		hud.flash("Modo gerador: posicione perto das máquinas elétricas e ligue cabos. T para sair.")
	elif type == "sensor":
		hud.flash("Modo sensor: encoste numa esteira/filtro (3m) para contar o minério. T para sair.")
	elif type == "alarme":
		hud.flash("Modo alarme: coloque a 6m de um sensor e aperte E nele para escolher a meta. T para sair.")
	elif type == "interruptor":
		hud.flash("Modo interruptor: E nele liga/desliga drills, esteiras e harvesters a 10m. T para sair.")
	elif type == "bau":
		hud.flash("Modo baú: encoste numa esteira com minério (até 3m) e ele guarda tudo. T para sair.")
	elif type == "silo":
		hud.flash("Modo silo: encoste numa esteira ou drill; o harvester puxa terra dele (3,5m). T para sair.")
	elif type == "fundacao" or type == "piso" or type == "parede" or type == "escada" or type == "cerca":
		hud.flash("Q/E ou roda do mouse giram a peça. Clique para posicionar. T para sair.")
	elif type == "drill":
		hud.flash("Modo drill: Q/E ou roda do mouse GIRA — a seta mostra para onde ela cospe a terra. T para sair.")
	else:
		hud.flash("Clique esquerdo para posicionar. T para cancelar.")


func cancel_placing() -> void:
	if placing == "mover" and not _move_source.is_empty():
		var back: Vector3 = _move_source["pos"]
		var nid0: int = machines.add_machine(String(_move_source["type"]), int(_move_source["tier"]), back, float(_move_source["yaw"]))
		if nid0 >= 0:
			_restore_machine(machines.list[nid0], _move_source)
		_move_source = {}
		machines.recompute_wires()
		placing = ""
		machines.hide_ghost()
		return
	placing = ""
	machines.hide_ghost()


func _snapshot_machine(m: Dictionary) -> Dictionary:
	return {"type": String(m["type"]), "tier": int(m["tier"]), "yaw": float(m.get("yaw", 0.0)), "pos": m["pos"], "dirt": float(m["dirt"]), "water": float(m["water"]), "water_time": float(m["water_time"]), "caixa": m["caixa"], "caixa_gems": m["caixa_gems"], "cargo": m["cargo"], "filter": String(m.get("filter", "")), "orebox": m.get("orebox", {}), "open": bool(m.get("open", true)), "store": m.get("store", {}), "count": int(m.get("count", 0)), "meta": int(m.get("meta", 50)), "dir": int(m.get("dir", 1)), "tray": m.get("tray", {})}


func _restore_machine(m: Dictionary, src: Dictionary) -> void:
	m["dirt"] = float(src["dirt"])
	m["water"] = float(src["water"])
	m["water_time"] = float(src["water_time"])
	m["caixa"] = src["caixa"]
	m["caixa_gems"] = src["caixa_gems"]
	m["cargo"] = src["cargo"]
	m["filter"] = String(src["filter"])
	m["orebox"] = src["orebox"]
	m["open"] = bool(src["open"])
	m["store"] = src["store"]
	m["count"] = int(src["count"])
	m["meta"] = int(src["meta"])
	m["dir"] = int(src.get("dir", 1))
	m["tray"] = src.get("tray", {})


func _start_move() -> void:
	if menu_open or placing != "":
		return
	var m: Dictionary = machines.nearest(player.global_position, 3.5)
	if m.is_empty():
		hud.flash("Nada por perto para mover (G).")
		return
	if bool(m.get("stress", false)):
		hud.flash("Máquinas de teste não podem ser movidas.")
		return
	if String(m["type"]) == "vein":
		hud.flash("Veios de minério fazem parte do terreno e não podem ser movidos.")
		return
	_move_source = _snapshot_machine(m)
	machines.remove_machine(int(m["id"]))
	machines.recompute_wires()
	placing = "mover"
	machines.hide_ghost()
	hud.flash("Peça na mão! Mire no novo lugar e clique para posicionar (G/Esc devolve ao lugar original).")


func open_blueprint_menu() -> void:
	if menu_open or placing != "":
		return
	var opts: Array = []
	opts.append({"label": "Capturar blueprint — todas as peças num raio de 8m (sem o conteúdo)", "action": _bp_capture})
	if not _blueprint.is_empty():
		var cost := _bp_total_cost()
		opts.append({"label": "Carimbar blueprint (%d peças) — $%d %s" % [_blueprint.size(), cost, _bars_cost_text(_bp_bars())], "disabled": not can_afford(cost, _bp_bars()), "action": _bp_stamp_start})
		opts.append({"label": "Descartar o blueprint salvo", "action": _bp_clear})
	_open_menu("BLUEPRINT — copie uma instalação e carimbe em outro lugar (B)", opts)


func _bp_capture() -> void:
	_blueprint.clear()
	var origin: Vector3 = player.global_position
	for m in machines.list:
		if bool(m.get("dead", false)) or bool(m.get("stress", false)):
			continue
		if String(m["type"]) == "vein":
			continue
		if m["pos"].distance_to(origin) > 8.0:
			continue
		if _blueprint.size() >= BP_CAP:
			break
		_blueprint.append({"type": String(m["type"]), "tier": int(m["tier"]), "dx": m["pos"].x - origin.x, "dy": m["pos"].y - origin.y, "dz": m["pos"].z - origin.z, "yaw": float(m.get("yaw", 0.0)), "filter": String(m.get("filter", ""))})
	if _blueprint.is_empty():
		hud.flash("Nenhuma peça num raio de 8m para capturar.")
		return
	var f := FileAccess.open(BP_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"pieces": _blueprint}))
		f.close()
	sound.play("craft")
	hud.flash("Blueprint capturado com %d peça(s)! Ele sobrevive ao save." % _blueprint.size())
	open_blueprint_menu()


func _bp_clear() -> void:
	_blueprint.clear()
	if FileAccess.file_exists(BP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BP_PATH))
	hud.flash("Blueprint descartado.")
	close_menu()


func _bp_total_cost() -> int:
	var total := 0
	for e in _blueprint:
		total += _machine_cost(String(e["type"]), int(e["tier"]))
	return total


func _bp_bars() -> Dictionary:
	var bars := {}
	for e in _blueprint:
		var eb: Dictionary = _machine_bars(String(e["type"]), int(e["tier"]))
		for k in eb:
			bars[k] = float(bars.get(k, 0.0)) + float(eb[k])
	return bars


func _bp_stamp_start() -> void:
	close_menu()
	placing = "blueprint"
	hud.flash("Blueprint pronto: mire no chão onde fica a ORIGEM e clique para carimbar. Esc cancela.")


func _load_blueprint() -> void:
	if not FileAccess.file_exists(BP_PATH):
		return
	var f := FileAccess.open(BP_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var pieces = parsed.get("pieces", [])
	if typeof(pieces) == TYPE_ARRAY:
		_blueprint = pieces


func can_afford(cost: int, bars: Dictionary) -> bool:
	if money < cost:
		return false
	for k in bars:
		if float(pocket_bars.get(k, 0.0)) < float(bars[k]):
			return false
	return true


func _pay(cost: int, bars: Dictionary) -> void:
	money -= cost
	for k in bars:
		pocket_bars[k] = float(pocket_bars.get(k, 0.0)) - float(bars[k])


func _machine_cost(type: String, tier: int) -> int:
	match type:
		"drill":
			return int(GameData.DRILL_TIERS[tier]["money"])
		"harvester":
			return int(GameData.HARVESTER_TIERS[tier]["money"])
		"bacia":
			return GameData.BACIA_PRICE
		"cano":
			return GameData.PIPE_PRICE
		"forja":
			return GameData.FORJA_PRICE
		"bigorna":
			return GameData.BIGORNA_PRICE
		"polidora":
			return GameData.POLIDORA_PRICE
		"prensa":
			return GameData.PRENSA_PRICE
		"cadinho":
			return CADINHO_PRICE
		"esteira":
			return GameData.ESTEIRA_PRICE
		"esteira_v":
			return GameData.ESTEIRA_V_PRICE
		"splitter":
			return GameData.SPLITTER_PRICE
		"filtro":
			return GameData.FILTRO_PRICE
		"bau":
			return GameData.BAU_PRICE
		"silo":
			return GameData.SILO_PRICE
		"registro":
			return GameData.REGISTRO_PRICE
		"cabo":
			return GameData.CABO_PRICE
		"gerador":
			return int(GameData.GERADOR_TIERS[tier]["money"])
		"sensor":
			return GameData.SENSOR_PRICE
		"alarme":
			return GameData.ALARME_PRICE
		"interruptor":
			return GameData.INTERRUPTOR_PRICE
		"fundacao", "piso", "parede", "escada", "cerca":
			return int(GameData.STRUCT_PRICES[type])
	return 0


func _machine_bars(type: String, tier: int) -> Dictionary:
	if type == "drill":
		return GameData.DRILL_TIERS[tier]["bars"]
	if type == "harvester":
		return GameData.HARVESTER_TIERS[tier]["bars"]
	if type == "gerador":
		return GameData.GERADOR_TIERS[tier]["bars"]
	return {}


func _machine_name(type: String, tier: int) -> String:
	match type:
		"drill":
			return String(GameData.DRILL_TIERS[tier]["name"])
		"harvester":
			return String(GameData.HARVESTER_TIERS[tier]["name"])
		"bacia":
			return "Bacia"
		"cadinho":
			return "Cadinho"
		"forja":
			return "Forja"
		"bigorna":
			return "Bigorna"
		"polidora":
			return "Polidora"
		"prensa":
			return "Prensa"
		"cano":
			return "Cano"
		"esteira":
			return "Esteira"
		"esteira_v":
			return "Esteira Vertical"
		"splitter":
			return "Divisor de Esteira"
		"filtro":
			return "Filtro"
		"bau":
			return "Baú"
		"silo":
			return "Silo"
		"registro":
			return "Registro"
		"cabo":
			return "Cabo"
		"gerador":
			return String(GameData.GERADOR_TIERS[tier]["name"])
		"sensor":
			return "Sensor"
		"alarme":
			return "Alarme"
		"interruptor":
			return "Interruptor"
		"fundacao":
			return "Fundação"
		"piso":
			return "Piso"
		"parede":
			return "Parede"
		"escada":
			return "Escada"
		"cerca":
			return "Cerca"
	return type


func _bars_cost_text(bars: Dictionary) -> String:
	if bars.is_empty():
		return ""
	var parts: Array = []
	for k in bars:
		parts.append("%d barra(s) de %s" % [int(bars[k]), String(GameData.ORES[String(k)]["name"])])
	return "(" + " + ".join(PackedStringArray(parts)) + ")"


func try_place() -> void:
	if placing == "" or not _aim_valid:
		return
	var pos: Vector3 = _aim
	var zone := GameData.zone_at(pos.x)
	if not zone_unlocked(zone):
		hud.flash("Terreno trancado!")
		return
	if pos.x > terrain.VILLAGE_MIN.x - 2.0 and pos.x < terrain.VILLAGE_MAX.x + 2.0 and pos.z > terrain.VILLAGE_MIN.y - 2.0 and pos.z < terrain.VILLAGE_MAX.y + 2.0:
		hud.flash("Não dá para construir no vilarejo!")
		return
	var pos3 := Vector3(pos.x, _ground_y(pos.x, pos.z), pos.z)
	if placing == "cano":
		if money < GameData.PIPE_PRICE:
			hud.flash("Dinheiro insuficiente!")
			return
		money -= GameData.PIPE_PRICE
		machines.add_pipe(pos3 + Vector3(0.0, 0.4, 0.0))
		hud.flash("Cano instalado! (%d canos) T para sair." % machines.pipes.size())
		return
	if placing == "registro":
		if money < GameData.REGISTRO_PRICE:
			hud.flash("Dinheiro insuficiente!")
			return
		money -= GameData.REGISTRO_PRICE
		machines.add_machine("registro", 0, _aim)
		hud.flash("Registro instalado! E nele para abrir/fechar. T para sair.")
		return
	if placing == "cabo":
		if money < GameData.CABO_PRICE:
			hud.flash("Dinheiro insuficiente!")
			return
		money -= GameData.CABO_PRICE
		machines.add_wire(_aim)
		hud.flash("Cabo instalado! (%d cabos) T para sair." % machines.wires.size())
		return
	if placing == "mover":
		if not machines.nearest(pos, 1.6, false).is_empty():
			hud.flash("Espaço ocupado!")
			return
		var nid_m: int = machines.add_machine(String(_move_source["type"]), int(_move_source["tier"]), pos3, _placing_yaw)
		if nid_m >= 0:
			_restore_machine(machines.list[nid_m], _move_source)
		_move_source = {}
		machines.recompute_wires()
		hud.flash("Peça movida! (os links de esteira dela precisam ser refeitos)")
		cancel_placing()
		return
	if placing == "blueprint":
		var cost_b := _bp_total_cost()
		var bars_b := _bp_bars()
		if not can_afford(cost_b, bars_b):
			hud.flash("Recursos insuficientes para o carimbo!")
			return
		for e in _blueprint:
			var px: float = pos.x + float(e["dx"])
			var pz: float = pos.z + float(e["dz"])
			var ppos := Vector3(px, _ground_y(px, pz), pz)
			if not machines.nearest(ppos, 1.2, false).is_empty():
				hud.flash("Espaço ocupado — carimbo abortado (nada foi cobrado).")
				return
		_pay(cost_b, bars_b)
		var placed_n := 0
		for e in _blueprint:
			var px2: float = pos.x + float(e["dx"])
			var pz2: float = pos.z + float(e["dz"])
			var ppos2 := Vector3(px2, _ground_y(px2, pz2), pz2)
			var nid_b: int = machines.add_machine(String(e["type"]), int(e["tier"]), ppos2, float(e["yaw"]))
			if nid_b >= 0:
				machines.list[nid_b]["filter"] = String(e["filter"])
				placed_n += 1
		machines.recompute_wires()
		hud.flash("Blueprint carimbado: %d peça(s)!" % placed_n)
		cancel_placing()
		return
	if placing == "esteira" or placing == "filtro" or placing == "esteira_v" or placing == "splitter":
		var price: int = GameData.ESTEIRA_PRICE if placing == "esteira" else GameData.FILTRO_PRICE
		if placing == "esteira_v":
			price = GameData.ESTEIRA_V_PRICE
		elif placing == "splitter":
			price = GameData.SPLITTER_PRICE
		if money < price:
			hud.flash("Dinheiro insuficiente!")
			return
		if placing != "filtro" and not _esteira_linked and not _esteira_on_pipe:
			hud.flash("Monte a esteira SOBRE um cano ou encaixe na drill/outra esteira!")
			return
		money -= price
		var place_pos := pos3
		if _esteira_on_pipe:
			place_pos = _aim
		var eid: int = machines.add_machine(placing, 0, place_pos, _esteira_yaw)
		if eid >= 0 and _esteira_prev >= 0:
			machines.set_prev(eid, _esteira_prev)
		var msg_link := ""
		var dr_near: Dictionary = machines.nearest_of_type(place_pos, "drill", 2.6)
		var hv_near: Dictionary = machines.nearest_of_type(place_pos, "harvester", 3.5)
		if _esteira_prev < 0 and not dr_near.is_empty():
			msg_link = " Esteira ligada à drill — a terra entra por aqui."
		elif not hv_near.is_empty():
			var dh: float = Vector2(place_pos.x - float(hv_near["pos"].x), place_pos.z - float(hv_near["pos"].z)).length()
			if _esteira_prev < 0 and dh <= 2.6:
				msg_link = " Esteira de SAÍDA ligada ao harvester — os minérios saem por aqui."
			else:
				msg_link = " Esteira de ENTRADA ligada ao harvester — a terra entra por aqui."
		if placing != "filtro" and not _esteira_on_pipe:
			hud.flash("%s instalado! SEM cano embaixo — 60%% de velocidade (H mostra o diagnóstico). T para sair.%s" % [_machine_name(placing, 0), msg_link])
		else:
			hud.flash("%s instalado! T para sair.%s" % [_machine_name(placing, 0), msg_link])
		return
	if placing == "fundacao" or placing == "piso" or placing == "parede" or placing == "escada" or placing == "cerca":
		var st_price: int = int(GameData.STRUCT_PRICES[placing])
		if money < st_price:
			hud.flash("Dinheiro insuficiente!")
			return
		if not machines.nearest_of_type(pos3, placing, 1.0).is_empty():
			hud.flash("Já tem uma peça igual aqui!")
			return
		money -= st_price
		machines.add_machine(placing, 0, pos3, _placing_yaw)
		return
	if not machines.nearest(pos, 1.6, false).is_empty():
		hud.flash("Espaço ocupado!")
		return
	var cost := _machine_cost(placing, placing_tier)
	var bars := _machine_bars(placing, placing_tier)
	if not can_afford(cost, bars):
		hud.flash("Recursos insuficientes!")
		return
	_pay(cost, bars)
	machines.add_machine(placing, placing_tier, pos3, _placing_yaw)
	if placing == "gerador":
		machines.recompute_wires()
	hud.flash("%s construída!" % _machine_name(placing, placing_tier))
	cancel_placing()


func demolish_nearby() -> void:
	var m: Dictionary = machines.nearest(player.global_position, 3.5)
	if m.is_empty():
		hud.flash("Nenhuma máquina por perto para desmontar (X).")
		return
	if String(m["type"]) == "vein":
		hud.flash("Veios fazem parte do terreno e não podem ser desmontados.")
		return
	var refund := int(float(_machine_cost(String(m["type"]), int(m["tier"]))) * 0.5)
	machines.remove_machine(int(m["id"]))
	money += refund
	machines.recompute_wires()
	hud.flash("Máquina desmontada: +$%d" % refund)


func open_cadinho_menu(m: Dictionary) -> void:
	_menu_machine = m
	var box: Dictionary = m.get("orebox", {})
	var opts: Array = []
	for ore_id in GameData.ORE_ORDER:
		var in_bolso := int(pocket_ores.get(ore_id, 0))
		var in_cadinho := int(box.get(ore_id, 0))
		var have := in_bolso + in_cadinho
		if have >= 10:
			var ore: Dictionary = GameData.ORES[ore_id]
			var label := "Fundir 10 %s (bolso %d + cadinho %d) → 1 barra (vale $%d)" % [String(ore["name"]), in_bolso, in_cadinho, GameData.bar_value(ore_id)]
			opts.append({"label": label, "action": _melt.bind(ore_id)})
	if opts.is_empty():
		opts.append({"label": "Junte 10 minérios iguais (no bolso ou mandados pelo filtro) para fundir", "disabled": true, "action": _noop})
	_open_menu("CADINHO — fundir minérios em barras", opts)


func _melt(ore_id: String) -> void:
	var need := 10
	var box: Dictionary = {}
	if not _menu_machine.is_empty():
		box = _menu_machine.get("orebox", {})
	var from_box: int = mini(int(box.get(ore_id, 0)), need)
	if from_box > 0:
		box[ore_id] = int(box[ore_id]) - from_box
		if int(box[ore_id]) <= 0:
			box.erase(ore_id)
		need -= from_box
	if need > 0:
		if int(pocket_ores.get(ore_id, 0)) < need:
			return
		pocket_ores[ore_id] = int(pocket_ores[ore_id]) - need
	pocket_bars[ore_id] = float(pocket_bars.get(ore_id, 0.0)) + 1.0
	sound.play("craft")
	hud.flash("1 barra de %s pronta!" % String(GameData.ORES[ore_id]["name"]))
	if not _menu_machine.is_empty():
		open_cadinho_menu(_menu_machine)


func open_anvil_menu() -> void:
	_anvil_item = ""
	_anvil_base = ""
	_anvil_blade = ""
	if bars_heated <= 0.0:
		_open_menu("BIGORNA", [{"label": "As barras estão frias! Aqueça na forja primeiro (E na forja).", "disabled": true, "action": _noop}])
		return
	var opts: Array = []
	for item in GameData.ANVIL_ITEMS:
		var label := "%s (%d barra(s)) — bônus +%d%%" % [String(item["name"]), int(item["bars"]), int(float(item["bonus"]) * 100.0)]
		opts.append({"label": label, "action": _anvil_select_item.bind(String(item["id"]))})
	_open_menu("BIGORNA — escolha o item (barras precisam estar aquecidas!)", opts)


func _anvil_bars_needed() -> int:
	for item in GameData.ANVIL_ITEMS:
		if String(item["id"]) == _anvil_item:
			return int(item["bars"])
	return 1


func _anvil_select_item(id: String) -> void:
	_anvil_item = id
	_anvil_base = ""
	_anvil_blade = ""
	_anvil_pick_base()


func _anvil_pick_base() -> void:
	var opts: Array = []
	for ore_id in GameData.ORE_ORDER:
		if float(pocket_bars.get(ore_id, 0.0)) >= 1.0:
			var label := "Punho/base: barra de %s ($%d)" % [String(GameData.ORES[ore_id]["name"]), GameData.bar_value(ore_id)]
			opts.append({"label": label, "action": _anvil_set_base.bind(ore_id)})
	if opts.is_empty():
		opts.append({"label": "Você não tem barras! Funda minérios no cadinho.", "disabled": true, "action": _noop})
	_open_menu("BIGORNA — %s: escolha a barra do punho/base" % String(_anvil_item), opts)


func _anvil_set_base(ore_id: String) -> void:
	_anvil_base = ore_id
	if _anvil_bars_needed() >= 2:
		_anvil_pick_blade()
	else:
		_anvil_gem_step()


func _anvil_pick_blade() -> void:
	var opts: Array = []
	for ore_id in GameData.ORE_ORDER:
		var disponivel := float(pocket_bars.get(ore_id, 0.0))
		if ore_id == _anvil_base:
			disponivel -= 1.0
		if disponivel >= 1.0:
			var label := "Lâmina/topo: barra de %s ($%d)" % [String(GameData.ORES[ore_id]["name"]), GameData.bar_value(ore_id)]
			opts.append({"label": label, "action": _anvil_set_blade.bind(ore_id)})
	if opts.is_empty():
		opts.append({"label": "Faltam barras para a lâmina (precisa de 2 no total).", "disabled": true, "action": _noop})
	_open_menu("BIGORNA — %s: escolha a barra da lâmina/topo" % String(_anvil_item), opts)


func _anvil_set_blade(ore_id: String) -> void:
	_anvil_blade = ore_id
	_anvil_gem_step()


func _anvil_gem_step() -> void:
	var best_gem := ""
	var best_val := 0
	for g in GameData.GEM_ORDER:
		if int(pocket_gems.get(g, 0)) > 0:
			var val := int(float(GameData.GEMS[g]["value"]) * 2.2)
			if val > best_val:
				best_val = val
				best_gem = g
	var opts: Array = []
	if best_gem != "":
		var label := "Encrubar %s polida (valor final ×1.2)" % String(GameData.GEMS[best_gem]["name"])
		opts.append({"label": label, "action": _anvil_craft.bind(true)})
	opts.append({"label": "Forjar sem gema", "action": _anvil_craft.bind(false)})
	_open_menu("BIGORNA — gema opcional", opts)


func _anvil_craft(encrust: bool) -> void:
	var need := _anvil_bars_needed()
	var bars_used: Array = [_anvil_base]
	if need >= 2:
		bars_used.append(_anvil_blade)
	for b in bars_used:
		if float(pocket_bars.get(b, 0.0)) < 1.0:
			hud.flash("Barras insuficientes!")
			return
	var total := 0
	for b in bars_used:
		pocket_bars[b] = float(pocket_bars[b]) - 1.0
		total += GameData.bar_value(String(b))
	var item: Dictionary = {}
	for it in GameData.ANVIL_ITEMS:
		if String(it["id"]) == _anvil_item:
			item = it
	var value := int(float(total) * (1.0 + float(item["bonus"])))
	if encrust:
		var bg := ""
		var bv := 0
		for g in GameData.GEM_ORDER:
			if int(pocket_gems.get(g, 0)) > 0:
				var val := int(float(GameData.GEMS[g]["value"]) * 2.2)
				if val > bv:
					bv = val
					bg = g
		if bg != "":
			pocket_gems[bg] = int(pocket_gems[bg]) - 1
			value = int(float(value) * 1.2)
	joias.append({"valor": value, "lagrima": false})
	hud.flash("Forjou %s no valor de $%d!" % [String(item["name"]), value])
	sound.play("craft")
	close_menu()


func _polish_gems() -> void:
	var total := 0
	for g in GameData.GEM_ORDER:
		var n := int(pocket_gems_raw.get(g, 0))
		if n > 0:
			pocket_gems_raw[g] = 0
			pocket_gems[g] = int(pocket_gems.get(g, 0)) + n
			total += n
	if total > 0:
		sound.play("craft")
		hud.flash("A polidora lapidou %d gema(s)! Leve à prensa." % total)
	else:
		hud.flash("Sem gemas brutas para polir.")


func open_prensa_menu() -> void:
	var opts: Array = []
	for g in GameData.GEM_ORDER:
		var n := int(pocket_gems.get(g, 0))
		var min_n := 1
		if g != "lagrima":
			min_n = 2
		if n >= min_n:
			var total := 0
			for i in n:
				total += int(float(GameData.GEMS[g]["value"]) * 2.2)
			var jv := int(float(total) * 1.3)
			var label := "Fundir %d %s polida(s) → 1 JÓIA ($%d)" % [n, String(GameData.GEMS[g]["name"]), jv]
			opts.append({"label": label, "action": _press.bind(g)})
	if opts.is_empty():
		opts.append({"label": "Passe as gemas brutas na polidora; depois junte 2 polidas iguais (a Lágrima Divina vale sozinha).", "disabled": true, "action": _noop})
	_open_menu("PRENSA — combinar gemas em jóias", opts)


func _press(g: String) -> void:
	var n := int(pocket_gems.get(g, 0))
	if n <= 0:
		return
	var total := 0
	for i in n:
		total += int(float(GameData.GEMS[g]["value"]) * 2.2)
	pocket_gems[g] = 0
	var jv := int(float(total) * 1.3)
	joias.append({"valor": jv, "lagrima": g == "lagrima"})
	hud.flash("Jóia criada no valor de $%d!" % jv)
	sound.play("craft")
	open_prensa_menu()


func on_alarm_fired(meta: int) -> void:
	hud.flash("🔔 ALARME: a contagem chegou na meta de %d!" % meta)
	sound.play("ding")


func open_alarme_menu(m: Dictionary) -> void:
	var opts: Array = []
	for meta in [10, 50, 100, 500, 1000]:
		var mark := ""
		if int(m.get("meta", 50)) == meta:
			mark = "  <"
		opts.append({"label": "Meta: %d itens%s" % [meta, mark], "action": _set_meta.bind(m, meta)})
	_open_menu("ALARME — avisa quando o sensor (a 6m) atingir a contagem", opts)


func _set_meta(m: Dictionary, meta: int) -> void:
	m["meta"] = meta
	m["fired"] = false
	hud.flash("Meta do alarme ajustada para %d!" % meta)
	close_menu()


func open_belt_menu(m: Dictionary) -> void:
	_menu_machine = m
	var opts: Array = []
	var dir_txt := "inverter (a seta verde vai apontar para trás)"
	if int(m.get("dir", 1)) < 0:
		dir_txt = "voltar ao sentido original"
	opts.append({"label": "Inverter sentido da esteira", "action": _invert_belt_action.bind(m)})
	opts.append({"label": "Sentido atual: %s" % dir_txt, "disabled": true, "action": _noop})
	_open_menu("ESTEIRA — direção do fluxo", opts)


func _invert_belt_action(m: Dictionary) -> void:
	var err: String = machines.invert_belt(int(m["id"]))
	if err == "":
		hud.flash("Sentido da esteira invertido!")
		sound.play("craft")
	else:
		hud.flash(err)
	close_menu()


func open_splitter_menu(m: Dictionary) -> void:
	_menu_machine = m
	var opts: Array = []
	opts.append({"label": "Inverter sentido (troca também o lado da bandeja)", "action": _invert_belt_action.bind(m)})
	var tray: Dictionary = m.get("tray", {})
	if not tray.is_empty():
		opts.append({"label": "Bandeja: %d item(ns) aguardando do lado da saída" % machines.cargo_total(tray), "disabled": true, "action": _noop})
	var side := 1.0 if int(m.get("dir", 1)) > 0 else -1.0
	var drop: Vector3 = m["pos"] + Vector3(0.0, 0.0, 1.1 * side).rotated(Vector3.UP, float(m["yaw"]))
	var has_dest: bool = not machines.nearest_of_type(drop, "cadinho", 2.2).is_empty() or not machines.nearest_of_type(drop, "bau", 2.2).is_empty()
	if not has_dest:
		opts.append({"label": "SEM cadinho/baú do lado da bandeja — coloque um a até 2m da saída", "disabled": true, "action": _noop})
	for ore_id in GameData.ORE_ORDER:
		var n_p: int = int(pocket_ores.get(ore_id, 0))
		if n_p <= 0:
			continue
		var ore: Dictionary = GameData.ORES[ore_id]
		opts.append({"label": "Pôr %d %s na bandeja (caem para o lado)" % [n_p, String(ore["name"])], "disabled": not has_dest, "action": _tray_put.bind(m, ore_id, n_p)})
	_open_menu("DIVISOR DE ESTEIRA — o que você põe na bandeja cai para o lado", opts)


func _tray_put(m: Dictionary, ore_id: String, n: int) -> void:
	var tray: Dictionary = m["tray"]
	tray[ore_id] = int(tray.get(ore_id, 0)) + n
	pocket_ores[ore_id] = int(pocket_ores.get(ore_id, 0)) - n
	if int(pocket_ores[ore_id]) <= 0:
		pocket_ores.erase(ore_id)
	hud.flash("%d %s na bandeja — vão cair para o lado da saída." % [n, String(GameData.ORES[ore_id]["name"])])
	sound.play("craft")
	close_menu()


func open_filtro_menu(m: Dictionary) -> void:
	_menu_machine = m
	var opts: Array = []
	var sel: String = String(m.get("filter", ""))
	for ore_id in GameData.ORE_ORDER:
		var ore: Dictionary = GameData.ORES[ore_id]
		var mark := ""
		if sel == ore_id:
			mark = "  <"
		opts.append({"label": "Desviar: %s%s" % [String(ore["name"]), mark], "action": _set_filter.bind(m, ore_id)})
	opts.append({"label": "Desativar filtro (tudo passa reto)", "action": _set_filter.bind(m, "")})
	_open_menu("FILTRO — o minério escolhido sai da linha para o cadinho do lado", opts)


func _set_filter(m: Dictionary, ore_id: String) -> void:
	m["filter"] = ore_id
	var lamp: MeshInstance3D = m.get("lamp", null)
	if lamp != null and is_instance_valid(lamp):
		var lmat: StandardMaterial3D = lamp.material_override
		if ore_id != "":
			var oc: Color = GameData.ORES[ore_id]["color"]
			lmat.albedo_color = oc
			lmat.emission = oc * 0.5
		else:
			lmat.albedo_color = Color(0.6, 0.6, 0.6)
			lmat.emission = Color(0.15, 0.15, 0.15)
	hud.flash("Filtro ajustado!")
	close_menu()


func buy_picareta() -> void:
	if has_picareta or money < GameData.PICARETA_PRICE:
		return
	money -= GameData.PICARETA_PRICE
	has_picareta = true
	hud.flash("Picareta comprada! Cavar mirando mais de 1,5m abaixo dos pés pode soltar minério extra.")
	sound.play("coins")
	open_merchant_menu()


func buy_rastelo() -> void:
	if has_rastelo or money < GameData.RASTELO_PRICE:
		return
	money -= GameData.RASTELO_PRICE
	has_rastelo = true
	hud.flash("Rastelo comprado! A escovação na bacia rende +1 minério e mais gemas.")
	sound.play("coins")
	open_merchant_menu()


func buy_detector() -> void:
	if has_detector or money < GameData.DETECTOR_PRICE:
		return
	money -= GameData.DETECTOR_PRICE
	has_detector = true
	hud.flash("Detector de Metais comprado! Os veios revelam seu minério a até 12m (mire neles).")
	sound.play("coins")
	open_merchant_menu()


func buy_dynamite() -> void:
	if money < GameData.DYNAMITE_PRICE:
		return
	money -= GameData.DYNAMITE_PRICE
	pocket_dynamite += 1
	sound.play("coins")
	hud.flash("Dinamite comprada (%d no bolso)! Aponte o chão e aperte V." % pocket_dynamite)
	open_merchant_menu()


func use_dynamite() -> void:
	if menu_open or hud.intro_visible() or hud.title_visible():
		return
	if pocket_dynamite <= 0:
		hud.flash("Sem dinamite! Compre no mercador ($%d)." % GameData.DYNAMITE_PRICE)
		return
	if not _aim_valid:
		hud.flash("Aponte para o chão para plantar a dinamite.")
		return
	var zone := GameData.zone_at(_aim.x)
	if not zone_unlocked(zone):
		hud.flash("Terreno trancado!")
		return
	pocket_dynamite -= 1
	var pos := Vector3(_aim.x, _ground_y(_aim.x, _aim.z), _aim.z)
	terrain.dig(pos, 3.6, 2.4)
	for i in 3:
		_dust_burst(pos + Vector3(randf_range(-1.6, 1.6), 0.5, randf_range(-1.6, 1.6)), Color(0.42, 0.34, 0.26))
	sound.play("boom")
	hud.flash("BUUM! Cratera aberta (%d de dinamite restantes)." % pocket_dynamite)


func _collect_bau(m: Dictionary) -> void:
	var store: Dictionary = m["store"]
	var total := 0
	for k in store:
		pocket_ores[k] = int(pocket_ores.get(k, 0)) + int(store[k])
		total += int(store[k])
	store.clear()
	if total > 0:
		hud.flash("Pegou %d minério(s) do baú!" % total)
		sound.play("ding")
	else:
		hud.flash("Baú vazio — encoste numa esteira com minério (até 3m).")


func _toggle_registro(m: Dictionary) -> void:
	m["open"] = not bool(m.get("open", true))
	machines.recompute_water()
	if bool(m["open"]):
		hud.flash("Registro ABERTO — a água volta a passar.")
	else:
		hud.flash("Registro FECHADO — a água parou nesta linha.")
	sound.play("craft")


func _diagnose() -> void:
	if menu_open:
		return
	var target: Dictionary = {}
	if _aim_valid:
		target = machines.nearest(_aim, 5.0)
	if target.is_empty():
		target = machines.nearest(player.global_position, 3.5)
	if target.is_empty():
		hud.show_diag("Nada por perto para diagnosticar.")
		return
	hud.show_diag(_diagnose_text(target))


func _diagnose_text(m: Dictionary) -> String:
	var type: String = m["type"]
	var lines: Array = []
	match type:
		"drill":
			if float(m["water_time"]) > 0.0 or machines.is_pipe_connected_at(m["pos"]):
				lines.append("Água: OK")
			else:
				lines.append("SEM ÁGUA — despeje um balde (E) ou ligue canos até o lago")
			var cap := int(40.0 + 20.0 * float(m["tier"]))
			lines.append("Pilha de terra: %d/%d" % [int(float(m["dirt"])), cap])
			if float(m["dirt"]) >= float(cap) - 1.0:
				lines.append("Pilha cheia! Encoste uma esteira na frente da seta de saída.")
		"esteira", "esteira_v", "splitter", "filtro":
			if int(m["prev"]) >= 0:
				lines.append("Recebe carga da peça anterior (link OK)")
			else:
				lines.append("Cabeça de linha: puxa terra da drill encostada na frente dela")
			var carg: Dictionary = m["cargo"]
			lines.append("Terra: %d | Minério: %d" % [int(float(m["dirt"])), machines.cargo_total(carg)])
			if type != "filtro":
				var f: float = machines.pipe_factor_at(m["pos"])
				if f >= 1.0:
					lines.append("Cano: montada sobre cano com água — velocidade total")
				elif f > 0.05:
					lines.append("SEM cano embaixo — 60% de velocidade (coloque canos ao longo da linha)")
				else:
					lines.append("Cano SEM ÁGUA — registro fechado ou linha desconectada: esteira PARADA")
				var d_txt := "frente"
				if int(m.get("dir", 1)) < 0:
					d_txt = "invertido"
				lines.append("Sentido: %s (E na esteira para inverter)" % d_txt)
				if type == "splitter":
					var tray_d: Dictionary = m.get("tray", {})
					if tray_d.is_empty():
						lines.append("Bandeja vazia — E no divisor para pôr minérios nela")
					else:
						lines.append("Bandeja: %d item(ns) aguardando cadinho/baú do lado" % machines.cargo_total(tray_d))
			if float(m["dirt"]) <= 0.05 and machines.cargo_total(carg) == 0:
				lines.append("Parada: nada está chegando — verifique a drill ou a peça anterior")
			if type == "filtro":
				var sel: String = String(m.get("filter", ""))
				if sel == "":
					lines.append("Filtro desativado — aperte E nele para escolher o minério")
				else:
					var tem_cad: bool = not machines.nearest_of_type(m["pos"], "cadinho", 3.0).is_empty()
					lines.append("Desviando: %s | cadinho do lado: %s" % [String(GameData.ORES[sel]["name"]), "sim" if tem_cad else "NÃO — coloque um a até 3m"])
		"harvester":
			var caixa: Dictionary = m["caixa"]
			var cg: Dictionary = m["caixa_gems"]
			var total := 0
			for k in caixa:
				total += int(caixa[k])
			for k in cg:
				total += int(cg[k])
			lines.append("Caixa: %d item(ns) (E coleta)" % total)
			var fac: float = machines.pipe_factor_at(m["pos"])
			if fac <= 0.05:
				lines.append("Água: SEM ÁGUA — ligue canos ao lago (atrás ou lateral)")
			elif fac < 0.9:
				lines.append("Água: %d%% — sem cano encostado (60% de rendimento)" % int(round(fac * 100.0)))
			else:
				lines.append("Água: conectada (100%)")
			if bool(m["active"]):
				lines.append("Recebendo terra: OK")
			else:
				lines.append("Recebendo terra: PARADO")
			var in_dr: Dictionary = machines.find_dirt_source(m["pos"], "drill", 2.6)
			var in_be: Dictionary = machines.find_dirt_source(m["pos"], "esteira", 3.5)
			var in_si: Dictionary = machines.find_dirt_source(m["pos"], "silo", 3.5)
			if not in_dr.is_empty():
				lines.append("Entrada: drill encostada")
			elif not in_be.is_empty():
				lines.append("Entrada: esteira a %.1fm" % m["pos"].distance_to(in_be["pos"]))
			elif not in_si.is_empty():
				lines.append("Entrada: silo a %.1fm" % m["pos"].distance_to(in_si["pos"]))
			else:
				lines.append("Entrada: NENHUMA — encoste drill/esteira/silo ou use E com balde de terra")
			var out_b: Dictionary = machines.find_belt_output(m["pos"], 2.6)
			if out_b.is_empty():
				lines.append("Saída: NENHUMA esteira nova por perto — o minério vai para a caixa")
			else:
				lines.append("Saída: esteira conectada")
		"bacia":
			var water_txt := "sim"
			if float(m["water"]) <= 0.2:
				water_txt = "não — despeje um balde (E)"
			lines.append("Terra: %d | Água: %s" % [int(float(m["dirt"])), water_txt])
		"cadinho":
			var box: Dictionary = m.get("orebox", {})
			var parts: Array = []
			for k in box:
				parts.append("%dx %s" % [int(box[k]), String(GameData.ORES[String(k)]["name"])])
			if parts.is_empty():
				lines.append("Cadinho vazio — o filtro manda minério se estiver a 3m")
			else:
				lines.append("No cadinho: " + ", ".join(PackedStringArray(parts)))
		"bau":
			var store: Dictionary = m["store"]
			lines.append("Minério guardado: %d/150 (E para pegar)" % machines.cargo_total(store))
		"silo":
			lines.append("Terra: %d/800" % int(float(m["dirt"])))
		"registro":
			if bool(m.get("open", true)):
				lines.append("ABERTO — água passando (E para fechar)")
			else:
				lines.append("FECHADO — água bloqueada (E para abrir)")
			if machines.is_pipe_connected_at(m["pos"]):
				lines.append("Linha com água até aqui: sim")
			else:
				lines.append("Linha com água até aqui: NÃO — verifique os canos até o lago")
		"gerador":
			var pstats_d: Dictionary = machines.power_stats()
			lines.append("Energia fornecida: %d | Consumo da rede: %d" % [int(pstats_d["supply"]), int(pstats_d["demand"])])
			if machines.is_power_connected_at(m["pos"]):
				lines.append("Cabos ligados neste gerador: sim")
			else:
				lines.append("Cabos ligados neste gerador: NÃO — nenhum cabo a até 2,5m")
			if int(pstats_d["supply"]) < int(pstats_d["demand"]):
				lines.append("REDE SOBRECARREGADA — compre outro gerador e ligue na mesma rede")
		"polidora", "prensa":
			if not machines.is_power_connected_at(m["pos"]):
				lines.append("SEM ENERGIA — leve um cabo do gerador até 2,5m desta máquina")
			elif not machines.power_ok():
				lines.append("REDE SOBRECARREGADA — a soma dos geradores não cobre todas as máquinas elétricas")
			else:
				lines.append("Energia: OK")
		"sensor":
			lines.append("Contagem acumulada: %d (E zera)" % int(m.get("count", 0)))
			if machines.nearest_of_type(m["pos"], "esteira", 3.0).is_empty() and machines.nearest_of_type(m["pos"], "filtro", 3.0).is_empty() and machines.nearest_of_type(m["pos"], "esteira_v", 3.0).is_empty() and machines.nearest_of_type(m["pos"], "splitter", 3.0).is_empty():
				lines.append("NENHUMA esteira/filtro a 3m — encoste o sensor na linha")
			else:
				lines.append("Esteira monitorada: OK")
		"alarme":
			lines.append("Meta atual: %d (E muda)" % int(m.get("meta", 50)))
			var sen_d: Dictionary = machines.nearest_of_type(m["pos"], "sensor", 6.0)
			if sen_d.is_empty():
				lines.append("NENHUM sensor a 6m — encoste um sensor numa esteira e traga o alarme para perto")
			else:
				lines.append("Sensor: %d/%d itens" % [int(sen_d.get("count", 0)), int(m.get("meta", 50))])
			if bool(m.get("fired", false)):
				lines.append("META ATINGIDA — zere o sensor (E nele) para rearmar")
		"interruptor":
			if bool(m.get("open", true)):
				lines.append("Estado: LIGADO (E desliga)")
			else:
				lines.append("Estado: DESLIGADO — drills, esteiras e harvesters a 10m estão parados (E liga)")
		_:
			lines.append("Sem diagnóstico detalhado para esta peça.")
	var titulo := _machine_name(type, int(m["tier"]))
	return "%s\n%s" % [titulo, "\n".join(PackedStringArray(lines))]


func toggle_showroom() -> void:
	if _showroom == null:
		_build_showroom()
	if not showroom_open:
		_showroom_return = player.global_position
		player.global_position = Vector3(0.0, 29.6, -65.5)
		_showroom.visible = true
		showroom_open = true
		hud.flash("Showroom visual: todas as máquinas, minérios, gemas e materiais. F11 para voltar.")
	else:
		_showroom.visible = false
		showroom_open = false
		player.global_position = _showroom_return
		hud.flash("Showroom fechado.")


func _showroom_label(parent: Node3D, txt: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = txt
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.01
	l.outline_size = 10
	l.position = pos
	parent.add_child(l)


func _build_showroom() -> void:
	_showroom = Node3D.new()
	_showroom.position = Vector3(0.0, 28.0, -68.0)
	add_child(_showroom)
	_part(_showroom, Vector3(44.0, 0.4, 20.0), Color(0.35, 0.3, 0.26), Vector3(0, 0, 0))
	_part(_showroom, Vector3(44.0, 0.1, 20.0), Color(0.45, 0.38, 0.3), Vector3(0, 0.25, 0))
	for pz in [9.7, -9.7]:
		for px in range(-5, 6):
			var rx := float(px) * 4.0
			_part(_showroom, Vector3(0.1, 0.55, 0.1), Color(0.36, 0.26, 0.16), Vector3(rx, 0.55, pz))
		_part(_showroom, Vector3(44.0, 0.05, 0.05), Color(0.42, 0.3, 0.18), Vector3(0, 0.82, pz))
	for corner in [Vector3(-20.5, 0, 8.8), Vector3(20.5, 0, 8.8), Vector3(-20.5, 0, -8.8), Vector3(20.5, 0, -8.8)]:
		_part(_showroom, Vector3(0.14, 2.6, 0.14), Color(0.3, 0.24, 0.18), corner + Vector3(0, 1.3, 0))
		_part(_showroom, Vector3(0.4, 0.08, 0.4), Color(0.3, 0.24, 0.18), corner + Vector3(0, 2.65, 0))
		var bulb2 := _part(_showroom, Vector3(0.2, 0.26, 0.2), Color(1.0, 0.9, 0.65), corner + Vector3(0, 2.4, 0))
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(1.0, 0.9, 0.65)
		bmat.emission_enabled = true
		bmat.emission = Color(1.0, 0.8, 0.5)
		bmat.emission_energy_multiplier = 1.6
		bulb2.material_override = bmat
		var sl := OmniLight3D.new()
		sl.omni_range = 14.0
		sl.light_energy = 1.1
		sl.light_color = Color(1.0, 0.88, 0.65)
		sl.position = corner + Vector3(0, 2.4, 0)
		_showroom.add_child(sl)
	_part(_showroom, Vector3(1.7, 0.04, 18.6), Color(0.42, 0.13, 0.11), Vector3(0, 0.32, 0.5))
	_part(_showroom, Vector3(1.4, 0.04, 17.6), Color(0.55, 0.2, 0.16), Vector3(0, 0.35, 0.5))
	for px2 in [-1.6, 1.6]:
		_part(_showroom, Vector3(0.16, 3.2, 0.16), Color(0.36, 0.26, 0.16), Vector3(px2, 1.6, 9.6))
	_part(_showroom, Vector3(3.6, 0.14, 0.14), Color(0.36, 0.26, 0.16), Vector3(0, 3.25, 9.6))
	_part(_showroom, Vector3(2.0, 0.6, 0.08), Color(0.5, 0.36, 0.22), Vector3(0, 2.75, 9.55))
	var types: Array = ["bacia", "cadinho", "forja", "bigorna", "polidora", "prensa", "bau", "silo", "sensor", "alarme", "interruptor", "gerador", "drill", "harvester", "esteira", "esteira_v", "splitter", "filtro", "registro", "fundacao", "piso", "parede", "escada", "cerca"]
	for i in types.size():
		var row := int(i / 10.0)
		var col := i % 10
		var wx := -18.0 + float(col) * 4.0
		var wz := -8.5 + float(row) * 3.5
		var tier := 2 if types[i] in ["gerador", "drill", "harvester"] else 0
		var v: Dictionary = machines._build_visual(String(types[i]), tier, Vector3(wx, 0.0, wz), 0.0)
		var node: Node3D = v["node"]
		machines.remove_child(node)
		_showroom.add_child(node)
		node.position = Vector3(wx, 0.2, wz)
		node.rotation = Vector3.ZERO
	for i in GameData.ORE_ORDER.size():
		var ok: String = GameData.ORE_ORDER[i]
		var ox := -18.0 + float(i) * 5.0
		var ped := MeshInstance3D.new()
		var pmesh := CylinderMesh.new()
		pmesh.top_radius = 0.55
		pmesh.bottom_radius = 0.65
		pmesh.height = 0.6
		ped.mesh = pmesh
		ped.position = Vector3(ox, 0.6, 8.5)
		ped.material_override = _part_mat(Color(0.5, 0.48, 0.45))
		_showroom.add_child(ped)
		var sw := _part(_showroom, Vector3(0.9, 0.9, 0.9), GameData.ORES[ok]["color"], Vector3(ox, 1.2, 8.5))
		sw.rotation.y = deg_to_rad(45.0)
		_showroom_label(_showroom, String(GameData.ORES[ok]["name"]), Vector3(ox, 2.4, 8.5))
	for i in GameData.GEM_ORDER.size():
		var gk: String = GameData.GEM_ORDER[i]
		var gx := -18.0 + float(i) * 5.0
		var ped2 := MeshInstance3D.new()
		var pmesh2 := CylinderMesh.new()
		pmesh2.top_radius = 0.45
		pmesh2.bottom_radius = 0.55
		pmesh2.height = 0.6
		ped2.mesh = pmesh2
		ped2.position = Vector3(gx, 0.6, 4.5)
		ped2.material_override = _part_mat(Color(0.5, 0.48, 0.45))
		_showroom.add_child(ped2)
		var gem := _part(_showroom, Vector3(0.7, 0.7, 0.7), GameData.GEMS[gk]["color"], Vector3(gx, 1.2, 4.5))
		gem.rotation = Vector3(deg_to_rad(30.0), deg_to_rad(45.0), 0.0)
		var gm: StandardMaterial3D = gem.material_override
		gm.emission_enabled = true
		gm.emission = GameData.GEMS[gk]["color"] * 0.4
		_showroom_label(_showroom, String(GameData.GEMS[gk]["name"]), Vector3(gx, 2.3, 4.5))
	var mats: Array = [["Terra", Color(0.45, 0.32, 0.2)], ["Areia", Color(0.85, 0.75, 0.5)], ["Pedra", Color(0.5, 0.5, 0.48)], ["Madeira", Color(0.45, 0.3, 0.18)], ["Ferro", Color(0.55, 0.55, 0.6)], ["Aço", Color(0.62, 0.64, 0.68)], ["Cobre", Color(0.72, 0.45, 0.3)], ["Água", Color(0.1, 0.5, 0.75, 0.6)]]
	for i in mats.size():
		var mx := -17.5 + float(i) * 5.0
		var sw2 := _part(_showroom, Vector3(1.4, 0.5, 1.4), mats[i][1], Vector3(mx, 0.55, 0.5))
		if i == 7:
			var wm: StandardMaterial3D = sw2.material_override
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wm.roughness = 0.05
		_showroom_label(_showroom, String(mats[i][0]), Vector3(mx, 1.6, 0.5))
	_showroom_label(_showroom, "SHOWROOM VISUAL", Vector3(0.0, 3.7, 0.0))
	var sign2 := Label3D.new()
	sign2.text = "SHOWROOM"
	sign2.font_size = 72
	sign2.pixel_size = 0.01
	sign2.outline_size = 12
	sign2.position = Vector3(0, 2.75, 9.62)
	sign2.rotation.y = PI
	_showroom.add_child(sign2)


func _stress_test() -> void:
	for m in machines.list:
		if bool(m.get("stress", false)) and not bool(m.get("dead", false)):
			machines.remove_machine(int(m["id"]))
	stress_level = (stress_level + 1) % 6
	if stress_level == 0:
		hud.flash("Teste de estresse: máquinas de teste removidas.")
		return
	var n: int = [100, 500, 1000, 100, 500][stress_level - 1]
	var kind: String = "drill"
	if stress_level >= 4:
		kind = "esteira"
	var cols := 18
	var spacing := 2.6
	var placed := 0
	var last_in_row := -1
	for i in n:
		var cx: int = i % cols
		var cz: int = int(float(i) / float(cols))
		var sx: float = -76.0 + float(cx) * spacing
		var sz: float = -70.0 + float(cz) * spacing
		var gy: float = terrain.height_at(sx, sz)
		if gy < -2.0:
			continue
		var sid: int = machines.add_machine(kind, 0, Vector3(sx, gy - 0.05, sz), 0.0)
		if sid < 0:
			break
		machines.list[sid]["stress"] = true
		if kind == "drill":
			machines.list[sid]["water_time"] = 1.0e9
		else:
			if cx > 0 and last_in_row >= 0:
				machines.set_prev(sid, last_in_row)
			last_in_row = sid
		placed += 1
	var kind_txt := "%d drills" % placed
	if kind == "esteira":
		kind_txt = "%d esteiras em linha" % placed
	hud.flash("TESTE DE ESTRESSE: %s (F10 avança: drills 100→500→1000 → esteiras 100→500 → limpar)" % kind_txt)
	log_error("Teste de estresse: %d máquinas de teste criadas." % placed)


func open_board_menu() -> void:
	var opts: Array = []
	if active_order.is_empty():
		var order := _make_order()
		var label := "Aceitar encomenda: %d barra(s) de %s — $%d" % [int(order["bars"]), String(GameData.ORES[String(order["ore"])]["name"]), int(order["reward"])]
		opts.append({"label": label, "action": _accept_order.bind(order)})
	else:
		var have := float(pocket_bars.get(String(active_order["ore"]), 0.0))
		var need := int(float(active_order["bars"]))
		var label2 := "Entregar encomenda: %d/%d barra(s) de %s" % [int(minf(have, float(need))), need, String(GameData.ORES[String(active_order["ore"])]["name"])]
		opts.append({"label": label2, "disabled": have < float(need), "action": _deliver_order})
		opts.append({"label": "Cancelar encomenda", "action": _cancel_order})
	if urgent_order.is_empty():
		var uo := _make_urgent_order()
		opts.append({"label": "URGENTE: %d minério(s) de %s em 120s — $%d (sem barras, direto do bolso)" % [int(uo["n"]), String(GameData.ORES[String(uo["ore"])]["name"]), int(uo["reward"])], "action": _accept_urgent.bind(uo)})
	else:
		var rem := int(_urgent_deadline - Time.get_ticks_msec() / 1000.0)
		var have_u := int(pocket_ores.get(String(urgent_order["ore"]), 0))
		var need_u := int(urgent_order["n"])
		opts.append({"label": "URGENTE: entregar %d/%d %s — $%d (faltam %ds)" % [mini(have_u, need_u), need_u, String(GameData.ORES[String(urgent_order["ore"])]["name"]), int(urgent_order["reward"]), rem], "disabled": have_u < need_u, "action": _deliver_urgent})
	_open_menu("QUADRO DE ENCOMENDAS DO VILAREJO", opts)


func _make_urgent_order() -> Dictionary:
	var pool: Array = []
	for z in 5:
		if not zone_unlocked(z):
			continue
		for oi in 7:
			if float(GameData.ORE_WEIGHTS[z][oi]) > 0.0:
				pool.append(String(GameData.ORE_ORDER[oi]))
	var ore_id: String = pool[randi() % pool.size()]
	var n := 8 + (randi() % 10)
	var reward := int(float(n) * float(GameData.ORES[ore_id]["value"]) * 2.2)
	return {"ore": ore_id, "n": n, "reward": reward}


func _accept_urgent(uo: Dictionary) -> void:
	urgent_order = uo
	_urgent_deadline = Time.get_ticks_msec() / 1000.0 + 120.0
	hud.flash("Encomenda URGENTE aceita! Você tem 120s!")
	sound.play("quest")
	close_menu()


func _deliver_urgent() -> void:
	if urgent_order.is_empty():
		return
	var ore_id: String = String(urgent_order["ore"])
	var need: int = int(urgent_order["n"])
	if int(pocket_ores.get(ore_id, 0)) < need:
		return
	pocket_ores[ore_id] = int(pocket_ores[ore_id]) - need
	if int(pocket_ores[ore_id]) <= 0:
		pocket_ores.erase(ore_id)
	var reward: int = int(urgent_order["reward"])
	money += reward
	total_earned += reward
	completed_orders += 1
	urgent_order = {}
	hud.flash("Encomenda urgente entregue a tempo! +$%d" % reward)
	sound.play("coins")
	open_board_menu()


func _make_order() -> Dictionary:
	var pool: Array = []
	for z in 5:
		if not zone_unlocked(z):
			continue
		for oi in 7:
			if float(GameData.ORE_WEIGHTS[z][oi]) > 0.0:
				pool.append(String(GameData.ORE_ORDER[oi]))
	var ore_id: String = pool[randi() % pool.size()]
	var n := 3 + (randi() % 6)
	var reward := int(float(n) * float(GameData.bar_value(ore_id)) * 1.6)
	return {"ore": ore_id, "bars": n, "reward": reward}


func _accept_order(order: Dictionary) -> void:
	active_order = order
	hud.flash("Encomenda aceita! Veja no canto superior esquerdo.")
	close_menu()


func _deliver_order() -> void:
	if active_order.is_empty():
		return
	var ore_id: String = String(active_order["ore"])
	var need := int(float(active_order["bars"]))
	if float(pocket_bars.get(ore_id, 0.0)) < float(need):
		return
	pocket_bars[ore_id] = float(pocket_bars[ore_id]) - float(need)
	var reward := int(float(active_order["reward"]))
	money += reward
	completed_orders += 1
	active_order = {}
	hud.flash("Encomenda entregue! +$%d" % reward)
	open_board_menu()


func _cancel_order() -> void:
	active_order = {}
	hud.flash("Encomenda cancelada.")
	close_menu()


func _check_quests() -> void:
	while quest_index < GameData.MAIN_QUESTS.size() and _quest_done(quest_index):
		var q: Dictionary = GameData.MAIN_QUESTS[quest_index]
		_consume_quest(quest_index)
		if q.has("reward"):
			money += int(q["reward"])
		if q.has("village"):
			village_level = int(q["village"])
			_rebuild_village()
		if q.has("unlock"):
			var zi := int(q["unlock"])
			unlocked[zi] = true
			_update_gate_labels()
		quest_index += 1
		sound.play("quest")
		hud.flash("Missão concluída! (%s)" % String(q["text"]))
		save_game()


func _quest_done(i: int) -> bool:
	match i:
		0:
			return met_merchant
		1:
			return stats_ores >= 10
		2:
			return float(pocket_bars.get("ferro", 0.0)) >= 5.0
		3:
			return drills_watered
		4:
			return stats_harvester >= 50
		5:
			return money >= 10000
		6:
			return float(pocket_bars.get("ouro", 0.0)) >= 10.0
		7:
			return money >= 50000 and float(pocket_bars.get("mithril", 0.0)) >= 15.0
		8:
			return completed_orders >= 10
		9:
			return _has_lagrima_jewel()
	return true


func _consume_quest(i: int) -> void:
	match i:
		2:
			pocket_bars["ferro"] = float(pocket_bars.get("ferro", 0.0)) - 5.0
		5:
			money -= 10000
		6:
			pocket_bars["ouro"] = float(pocket_bars.get("ouro", 0.0)) - 10.0
		7:
			money -= 50000
			pocket_bars["mithril"] = float(pocket_bars.get("mithril", 0.0)) - 15.0


func _has_lagrima_jewel() -> bool:
	for j in joias:
		if bool(j["lagrima"]):
			return true
	return false


func get_prompt() -> String:
	if menu_open:
		return ""
	if placing != "":
		if placing == "drill":
			return "Clique: posicionar drill | Q/E ou roda do mouse: girar | T: cancelar"
		return "Clique esquerdo: posicionar %s | T: cancelar" % _machine_name(placing, placing_tier)
	var pp: Vector3 = player.global_position
	if Vector2(pp.x, pp.z).distance_to(terrain.LAKE_POS) < 11.0:
		return "E: encher o balde de água no lago"
	if _aim_valid:
		var b: Dictionary = machines.nearest_of_type(_aim, "bacia", 4.0)
		if not b.is_empty() and float(b["dirt"]) > 0.0 and float(b["water"]) > 0.2:
			return "Segure o clique esquerdo para ESCOVAR a terra"
		if has_detector:
			var vein: Dictionary = machines.nearest_of_type(_aim, "vein", 12.0)
			if not vein.is_empty():
				return "Veio detectado a %dm! Aproxime-se e aperte E para minerar" % int(player.global_position.distance_to(vein["pos"]))
	var m: Dictionary = machines.nearest(pp, 3.5)
	if not m.is_empty():
		return "E: usar %s | X: desmontar" % _machine_name(String(m["type"]), int(m["tier"]))
	if pp.distance_to(MERCHANT_POS) < 4.0:
		return "E: falar com o Mercador"
	if pp.distance_to(BOARD_POS) < 4.0:
		return "E: ver o quadro de encomendas"
	if pp.distance_to(STATUE_POS) < 3.5:
		return "E: contemplar a Estátua do Legado (+%d%% de bônus nas vendas)" % int(statue_level * 5)
	if truck != null and is_instance_valid(truck) and pp.distance_to(truck.position) < 3.5:
		if driving:
			return "E: sair do caminhão | a caçamba recolhe minérios automaticamente"
		return "E: dirigir | R: descarregar caçamba no bolso (%d minérios)" % truck_cargo_value()
	return ""


func _build_village() -> void:
	var roof_pal: Array = [Color(0.68, 0.28, 0.2), Color(0.55, 0.32, 0.22), Color(0.46, 0.4, 0.37), Color(0.6, 0.42, 0.25)]
	var body_pal: Array = [Color(0.82, 0.72, 0.56), Color(0.76, 0.66, 0.5), Color(0.85, 0.76, 0.62)]
	for i in HOUSE_OFFSETS.size():
		var off: Vector3 = HOUSE_OFFSETS[i]
		var wx: float = off.x
		var wz: float = off.z
		var bw := 3.0 + float(i % 2) * 0.5
		var bh := 2.2 + float(i % 3) * 0.15
		var bd := 3.0 + float((i + 1) % 2) * 0.4
		var h00: float = terrain.height_at(wx - bw * 0.5, wz - bd * 0.5)
		var h10: float = terrain.height_at(wx + bw * 0.5, wz - bd * 0.5)
		var h01: float = terrain.height_at(wx - bw * 0.5, wz + bd * 0.5)
		var h11: float = terrain.height_at(wx + bw * 0.5, wz + bd * 0.5)
		var y: float = min(minf(h00, h10), minf(h01, h11))
		var hdrop: float = max(maxf(h00, h10), maxf(h01, h11)) - y
		var root := Node3D.new()
		root.position = Vector3(wx, y, wz)
		add_child(root)
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(bw, bh, bd)
		body.mesh = bm
		body.position = Vector3(0, bh * 0.5, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = body_pal[i % body_pal.size()]
		body.material_override = mat
		root.add_child(body)
		_part(root, Vector3(bw + 0.5, 0.45 + hdrop, bd + 0.5), Color(0.45, 0.43, 0.4), Vector3(0, 0.175 - (hdrop + 0.1) * 0.5, 0))
		_gable_roof(root, bw, bd, bh, roof_pal[i % roof_pal.size()])
		var fz := bd * 0.5
		_part(root, Vector3(0.98, 1.5, 0.07), Color(0.32, 0.22, 0.13), Vector3(0, 0.75, fz + 0.01))
		_part(root, Vector3(0.74, 1.3, 0.09), Color(0.5, 0.34, 0.2), Vector3(0, 0.65, fz + 0.04))
		_part(root, Vector3(0.07, 0.07, 0.1), Color(0.8, 0.7, 0.3), Vector3(0.26, 0.68, fz + 0.09))
		for sx2 in [-1.0, 1.0]:
			var wxx: float = sx2 * bw * 0.3
			_part(root, Vector3(0.7, 0.7, 0.07), Color(0.32, 0.22, 0.13), Vector3(wxx, 1.4, fz + 0.01))
			_part(root, Vector3(0.54, 0.54, 0.06), Color(0.65, 0.8, 0.9), Vector3(wxx, 1.4, fz + 0.045))
			_part(root, Vector3(0.54, 0.06, 0.05), Color(0.32, 0.22, 0.13), Vector3(wxx, 1.4, fz + 0.08))
			_part(root, Vector3(0.06, 0.54, 0.05), Color(0.32, 0.22, 0.13), Vector3(wxx, 1.4, fz + 0.08))
			_part(root, Vector3(0.86, 0.1, 0.14), Color(0.4, 0.28, 0.18), Vector3(wxx, 1.0, fz + 0.05))
		var chim_x := 0.85 if bw > 3.2 else 0.7
		_part(root, Vector3(0.4, 1.6, 0.4), Color(0.48, 0.4, 0.36), Vector3(chim_x, bh + 0.7, -0.5))
		_part(root, Vector3(0.52, 0.14, 0.52), Color(0.4, 0.33, 0.3), Vector3(chim_x, bh + 1.55, -0.5))
		if i % 2 == 0:
			var smoke := CPUParticles3D.new()
			smoke.amount = 7
			smoke.lifetime = 3.2
			smoke.preprocess = 3.0
			smoke.position = Vector3(chim_x, bh + 1.85, -0.5)
			smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			smoke.emission_sphere_radius = 0.08
			smoke.direction = Vector3(0.2, 1.0, 0.1)
			smoke.spread = 12.0
			smoke.gravity = Vector3(0.15, 0.35, 0.05)
			smoke.initial_velocity_min = 0.3
			smoke.initial_velocity_max = 0.6
			smoke.scale_amount_min = 0.5
			smoke.scale_amount_max = 1.0
			var smesh := QuadMesh.new()
			smesh.size = Vector2(0.3, 0.3)
			smoke.mesh = smesh
			var smat3 := StandardMaterial3D.new()
			smat3.albedo_color = Color(0.82, 0.82, 0.85, 0.4)
			smat3.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smat3.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			smat3.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smesh.material = smat3
			root.add_child(smoke)
		_part(root, Vector3(0.42, 0.6, 0.42), Color(0.5, 0.34, 0.2), Vector3(bw * 0.5 + 0.4, 0.62, bd * 0.5 - 0.2))
		_part(root, Vector3(0.42, 0.6, 0.42), Color(0.45, 0.3, 0.18), Vector3(bw * 0.5 + 0.6, 0.62, bd * 0.5 - 0.6))
		_part(root, Vector3(0.55, 0.5, 0.55), Color(0.55, 0.4, 0.24), Vector3(-bw * 0.5 - 0.45, 0.57, bd * 0.5 - 0.15))
		_houses.append(root)
	_merchant_node()
	_board_node()
	_statue_node()
	_build_lamps()
	_build_paths()
	_build_fence()
	_rebuild_village()


func _gable_roof(root: Node3D, bw: float, bd: float, bh: float, col: Color) -> void:
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = col
	rmat.roughness = 0.85
	rmat.albedo_texture = Textures.roof_tiles()
	rmat.normal_enabled = true
	rmat.normal_texture = Textures.roof_normal()
	rmat.normal_scale = 0.9
	rmat.uv1_triplanar = true
	rmat.uv1_scale = Vector3(0.8, 0.8, 0.8)
	var ridge_y := bh + 0.9
	var eave_y := bh + 0.1
	var half := bd * 0.5 + 0.55
	var drop := ridge_y - eave_y
	var slope := atan2(drop, half)
	var plen := sqrt(half * half + drop * drop) + 0.1
	for s in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(bw + 0.5, 0.12, plen)
		panel.mesh = pm
		panel.position = Vector3(0, (ridge_y + eave_y) * 0.5, s * half * 0.5)
		panel.rotation.x = s * slope
		panel.material_override = rmat
		root.add_child(panel)
	var ridge := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(bw + 0.55, 0.13, 0.36)
	ridge.mesh = rm
	ridge.position = Vector3(0, ridge_y + 0.03, 0)
	ridge.material_override = rmat
	root.add_child(ridge)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.78, 0.68, 0.52)
	gmat.roughness = 0.95
	for s2 in [-1.0, 1.0]:
		var gab := MeshInstance3D.new()
		var gm := PrismMesh.new()
		gm.size = Vector3(bd, ridge_y - bh, 0.16)
		gab.mesh = gm
		gab.position = Vector3(s2 * (bw * 0.5 - 0.02), bh + (ridge_y - bh) * 0.5, 0)
		gab.rotation.y = PI * 0.5
		gab.material_override = gmat
		root.add_child(gab)


func _merchant_node() -> void:
	var root := Node3D.new()
	var my: float = terrain.height_at(MERCHANT_POS.x, MERCHANT_POS.z)
	for off2 in [Vector2(-1.7, -2.2), Vector2(1.7, -2.2), Vector2(-1.7, 2.2), Vector2(1.7, 2.2)]:
		my = minf(my, terrain.height_at(MERCHANT_POS.x + off2.x, MERCHANT_POS.z + off2.y))
	root.position = Vector3(MERCHANT_POS.x, my - 0.03, MERCHANT_POS.z)
	root.rotation.y = PI
	add_child(root)
	var wood_dark := Color(0.36, 0.24, 0.14)
	for px in [-1.5, 1.5]:
		_part(root, Vector3(0.1, 2.5, 0.1), wood_dark, Vector3(px, 1.25, -1.0))
		_part(root, Vector3(0.1, 2.1, 0.1), wood_dark, Vector3(px, 1.05, 1.0))
	_part(root, Vector3(3.2, 0.09, 0.09), wood_dark, Vector3(0, 2.52, -1.0))
	_part(root, Vector3(3.2, 0.09, 0.09), wood_dark, Vector3(0, 2.12, 1.0))
	var awn := Node3D.new()
	awn.position = Vector3(0, 2.3, 0)
	awn.rotation.x = deg_to_rad(14.0)
	root.add_child(awn)
	for i in 7:
		var col := Color(0.72, 0.22, 0.18) if i % 2 == 0 else Color(0.93, 0.9, 0.82)
		_part(awn, Vector3(3.3, 0.06, 0.34), col, Vector3(0, 0.0, 1.06 - 0.33 * float(i)))
	for s in 9:
		var scol := Color(0.72, 0.22, 0.18) if s % 2 == 0 else Color(0.93, 0.9, 0.82)
		_part(awn, Vector3(0.34, 0.16, 0.06), scol, Vector3(-1.48 + 0.37 * float(s), -0.09, 1.24))
	var lantern := _part(root, Vector3(0.16, 0.22, 0.16), Color(0.9, 0.75, 0.4), Vector3(1.2, 2.0, 0.75))
	_part(root, Vector3(0.03, 0.3, 0.03), Color(0.2, 0.16, 0.12), Vector3(1.2, 2.26, 0.75))
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.7, 0.7, 0.65)
	lmat.emission_enabled = true
	lmat.emission = Color(0.05, 0.05, 0.04)
	lantern.material_override = lmat
	var llight := OmniLight3D.new()
	llight.omni_range = 6.0
	llight.light_energy = 0.0
	llight.light_color = Color(1.0, 0.85, 0.55)
	llight.position = Vector3(1.2, 1.95, 0.75)
	root.add_child(llight)
	_lamp_lights.append(llight)
	_part(root, Vector3(2.2, 0.03, 1.2), Color(0.5, 0.18, 0.15), Vector3(0, 0.04, 2.1))
	_part(root, Vector3(2.0, 0.03, 1.0), Color(0.62, 0.28, 0.22), Vector3(0, 0.06, 2.1))
	_part(root, Vector3(0.55, 0.4, 0.55), Color(0.55, 0.4, 0.24), Vector3(-2.0, 0.2, 0.4))
	_part(root, Vector3(0.45, 0.34, 0.45), Color(0.48, 0.34, 0.2), Vector3(-2.0, 0.57, 0.42))
	_part(root, Vector3(0.5, 0.5, 0.5), Color(0.56, 0.42, 0.26), Vector3(2.05, 0.25, -0.3))
	_part(root, Vector3(3.0, 0.14, 0.7), Color(0.58, 0.42, 0.26), Vector3(0, 1.0, 0.9))
	_part(root, Vector3(3.0, 0.9, 0.1), Color(0.5, 0.36, 0.22), Vector3(0, 0.5, 1.22))
	_part(root, Vector3(0.14, 1.0, 0.7), Color(0.45, 0.32, 0.2), Vector3(-1.45, 0.5, 0.9))
	_part(root, Vector3(0.14, 1.0, 0.7), Color(0.45, 0.32, 0.2), Vector3(1.45, 0.5, 0.9))
	_part(root, Vector3(2.8, 0.1, 0.5), Color(0.5, 0.36, 0.22), Vector3(0, 1.6, -1.0))
	_part(root, Vector3(2.8, 0.1, 0.5), Color(0.5, 0.36, 0.22), Vector3(0, 1.1, -1.0))
	_part(root, Vector3(0.45, 0.3, 0.45), Color(0.6, 0.44, 0.26), Vector3(-1.0, 1.8, -1.0))
	_part(root, Vector3(0.4, 0.26, 0.4), Color(0.6, 0.44, 0.26), Vector3(-0.3, 1.78, -1.0))
	_part(root, Vector3(0.28, 0.2, 0.28), Color(0.72, 0.45, 0.3), Vector3(0.4, 1.75, -1.0))
	_part(root, Vector3(0.5, 0.35, 0.5), Color(0.6, 0.44, 0.26), Vector3(-1.0, 1.22, -1.0))
	_part(root, Vector3(0.34, 0.24, 0.34), Color(0.5, 0.55, 0.6), Vector3(0.3, 1.17, -1.0))
	_part(root, Vector3(0.36, 0.22, 0.36), Color(0.8, 0.6, 0.2), Vector3(1.0, 1.17, -1.0))
	_part(root, Vector3(0.4, 0.25, 0.4), Color(0.72, 0.45, 0.3), Vector3(-0.9, 1.18, 0.9))
	_part(root, Vector3(0.3, 0.2, 0.3), Color(0.85, 0.7, 0.2), Vector3(0.9, 1.16, 0.9))
	_part(root, Vector3(0.06, 0.5, 0.06), Color(0.2, 0.16, 0.12), Vector3(1.5, 1.9, 0.2))
	_part(root, Vector3(0.7, 0.45, 0.05), Color(0.5, 0.36, 0.22), Vector3(1.5, 1.55, 0.2))
	var skin := Color(0.85, 0.65, 0.5)
	var shirt := Color(0.32, 0.48, 0.72)
	_part(root, Vector3(0.18, 0.75, 0.18), Color(0.22, 0.2, 0.25), Vector3(-0.14, 0.38, -0.25))
	_part(root, Vector3(0.18, 0.75, 0.18), Color(0.22, 0.2, 0.25), Vector3(0.14, 0.38, -0.25))
	_part(root, Vector3(0.54, 0.72, 0.34), shirt, Vector3(0, 1.12, -0.25))
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.18
	hm.height = 0.36
	head.mesh = hm
	head.position = Vector3(0, 1.7, -0.25)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = skin
	head.material_override = hmat
	root.add_child(head)
	_part(root, Vector3(0.05, 0.06, 0.03), Color(0.12, 0.1, 0.1), Vector3(-0.07, 1.74, -0.08))
	_part(root, Vector3(0.05, 0.06, 0.03), Color(0.12, 0.1, 0.1), Vector3(0.07, 1.74, -0.08))
	_part(root, Vector3(0.52, 0.04, 0.52), Color(0.92, 0.75, 0.15), Vector3(0, 1.87, -0.25))
	_part(root, Vector3(0.34, 0.2, 0.34), Color(0.95, 0.78, 0.18), Vector3(0, 1.95, -0.25))
	var label := Label3D.new()
	label.text = "MERCADOR — E para falar"
	label.font_size = 96
	label.pixel_size = 0.01
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.2, 0)
	root.add_child(label)


func _board_node() -> void:
	var root := Node3D.new()
	root.position = Vector3(BOARD_POS.x, terrain.height_at(BOARD_POS.x, BOARD_POS.z), BOARD_POS.z)
	add_child(root)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(2.2, 1.4, 0.15)
	panel.mesh = pm
	panel.position = Vector3(0, 1.6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.35, 0.2)
	panel.material_override = mat
	root.add_child(panel)
	_part(root, Vector3(0.12, 1.7, 0.12), Color(0.36, 0.24, 0.14), Vector3(-0.85, 0.85, 0.04))
	_part(root, Vector3(0.12, 1.7, 0.12), Color(0.36, 0.24, 0.14), Vector3(0.85, 0.85, 0.04))
	var label := Label3D.new()
	label.text = "QUADRO DE ENCOMENDAS — E"
	label.font_size = 72
	label.pixel_size = 0.01
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.9, 0)
	root.add_child(label)


func _statue_node() -> void:
	var root := Node3D.new()
	var sy: float = terrain.height_at(STATUE_POS.x, STATUE_POS.z)
	for off3 in [Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(-1.2, 1.2), Vector2(1.2, 1.2)]:
		sy = minf(sy, terrain.height_at(STATUE_POS.x + off3.x, STATUE_POS.z + off3.y))
	root.position = Vector3(STATUE_POS.x, sy - 0.03, STATUE_POS.z)
	add_child(root)
	var stone := Color(0.58, 0.56, 0.52)
	var gold := Color(0.82, 0.68, 0.3)
	_part(root, Vector3(2.0, 0.4, 2.0), Color(0.5, 0.48, 0.45), Vector3(0, 0.2, 0))
	_part(root, Vector3(1.5, 0.5, 1.5), stone, Vector3(0, 0.65, 0))
	_part(root, Vector3(1.0, 0.5, 1.0), stone, Vector3(0, 1.15, 0))
	_part(root, Vector3(0.16, 0.7, 0.16), gold, Vector3(-0.12, 1.75, 0))
	_part(root, Vector3(0.16, 0.7, 0.16), gold, Vector3(0.12, 1.75, 0))
	_part(root, Vector3(0.44, 0.6, 0.26), gold, Vector3(0, 2.4, 0))
	var arm_l := _part(root, Vector3(0.12, 0.55, 0.12), gold, Vector3(-0.3, 2.5, 0.05))
	arm_l.rotation.z = deg_to_rad(25.0)
	var arm_r := _part(root, Vector3(0.12, 0.6, 0.12), gold, Vector3(0.32, 2.62, -0.05))
	arm_r.rotation.z = deg_to_rad(-140.0)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.34
	head.mesh = hm
	head.position = Vector3(0, 2.88, 0)
	head.material_override = _gold_mat()
	root.add_child(head)
	var pick_handle := _part(root, Vector3(0.05, 1.0, 0.05), Color(0.4, 0.28, 0.16), Vector3(0.42, 2.75, -0.05))
	pick_handle.rotation.z = deg_to_rad(-20.0)
	_part(root, Vector3(0.5, 0.08, 0.08), gold, Vector3(0.55, 3.2, -0.05))
	var label := Label3D.new()
	label.text = "ESTÁTUA DO LEGADO — E"
	label.font_size = 72
	label.pixel_size = 0.01
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 4.1, 0)
	root.add_child(label)


func _rebuild_village() -> void:
	for i in _houses.size():
		var h: Node3D = _houses[i]
		var threshold := 0
		if i < HOUSE_LEVELS.size():
			threshold = HOUSE_LEVELS[i]
		h.visible = village_level > threshold
		var s := 1.0 + 0.06 * minf(float(village_level), 10.0)
		h.scale = Vector3(s, s, s)


func _build_gates() -> void:
	var wood := Color(0.44, 0.32, 0.19)
	var wood_dark := Color(0.34, 0.24, 0.14)
	for gx in GATE_XS:
		var x := float(gx)
		var z: float = terrain.height_at(x, 20.0)
		var pz := -78.0
		while pz < 47.5:
			var zn := pz + 4.2
			var in_gate := pz < 25.0 and zn > 15.0
			if not in_gate:
				var h0: float = terrain.height_at(x, pz)
				var h1: float = terrain.height_at(x, zn)
				var hm := (h0 + h1) * 0.5
				_part(self, Vector3(0.15, 1.6, 0.15), wood, Vector3(x, h0 + 0.8, pz))
				_part(self, Vector3(0.09, 0.09, 4.3), wood_dark, Vector3(x, hm + 0.55, pz + 2.1))
				_part(self, Vector3(0.09, 0.09, 4.3), wood_dark, Vector3(x, hm + 1.15, pz + 2.1))
			pz = zn
		_part(self, Vector3(0.3, 3.0, 0.3), wood, Vector3(x, z + 1.5, 16.0))
		_part(self, Vector3(0.3, 3.0, 0.3), wood, Vector3(x, z + 1.5, 24.0))
		_part(self, Vector3(0.12, 0.18, 8.0), wood, Vector3(x, z + 1.0, 20.0))
		_part(self, Vector3(0.12, 0.18, 8.0), wood, Vector3(x, z + 2.2, 20.0))
		var bars := Node3D.new()
		bars.position = Vector3.ZERO
		add_child(bars)
		for bz in [17.0, 18.5, 20.0, 21.5, 23.0]:
			var bh: float = terrain.height_at(x, bz)
			_part(bars, Vector3(0.1, 2.5, 0.1), wood_dark, Vector3(x, bh + 1.25, bz))
		_gate_bars.append(bars)
		var lab := Label3D.new()
		lab.font_size = 96
		lab.pixel_size = 0.01
		lab.outline_size = 16
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = Vector3(x, z + 3.6, 20.0)
		add_child(lab)
		_gate_labels.append(lab)


func _update_gate_labels() -> void:
	for i in GATE_XS.size():
		var zone := GameData.zone_at(float(GATE_XS[i]) + 1.0)
		var lab: Label3D = _gate_labels[i]
		if zone_unlocked(zone):
			lab.text = "ABERTO — %s" % String(GameData.ZONE_NAMES[zone])
			lab.modulate = Color(0.4, 1.0, 0.4)
		else:
			lab.text = "TRANCADO — %s" % String(GameData.ZONE_NAMES[zone])
			lab.modulate = Color(1.0, 0.4, 0.4)
		var bars: Node3D = _gate_bars[i]
		if is_instance_valid(bars):
			bars.visible = not zone_unlocked(zone)


var _part_mats: Dictionary = {}


func _part_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _part_mats.has(key):
		return _part_mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.albedo_texture = Textures.pick(color, 0.0)
	mat.normal_enabled = true
	mat.normal_texture = Textures.normal_for(color, 0.0)
	mat.normal_scale = 0.7
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	_part_mats[key] = mat
	return mat


func _part(root: Node3D, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _part_mat(color)
	mi.position = pos
	root.add_child(mi)
	return mi


func _gold_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.68, 0.3)
	mat.metallic = 0.8
	mat.roughness = 0.3
	return mat


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for i in 40:
		var tx := rng.randf_range(-78.0, 78.0)
		var tz := rng.randf_range(-78.0, 78.0)
		if tx > terrain.VILLAGE_MIN.x - 4.0 and tx < terrain.VILLAGE_MAX.x + 4.0 and tz > terrain.VILLAGE_MIN.y - 4.0 and tz < terrain.VILLAGE_MAX.y + 4.0:
			continue
		if Vector2(tx, tz).distance_to(terrain.LAKE_POS) < 13.0:
			continue
		if Vector2(tx, tz).distance_to(Vector2(-40.0, 0.0)) < 8.0:
			continue
		var y: float = terrain.height_at(tx, tz)
		if y < 0.2:
			continue
		var root := Node3D.new()
		root.position = Vector3(tx, y, tz)
		add_child(root)
		_trees.append(root)
		var style := i % 3
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.4, 0.28, 0.18)
		tmat.roughness = 1.0
		tmat.albedo_texture = Textures.wood()
		tmat.normal_enabled = true
		tmat.normal_texture = Textures.wood_normal()
		tmat.normal_scale = 0.7
		tmat.uv1_triplanar = true
		tmat.uv1_scale = Vector3(0.6, 0.6, 0.6)
		if style == 1:
			var trunk := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.12
			tm.bottom_radius = 0.24
			tm.height = 2.6
			trunk.mesh = tm
			trunk.position = Vector3(0, 1.3, 0)
			trunk.material_override = tmat
			root.add_child(trunk)
			for k in 2:
				var cone := MeshInstance3D.new()
				var pm3 := CylinderMesh.new()
				pm3.top_radius = 0.05
				pm3.bottom_radius = 1.1 - 0.45 * float(k)
				pm3.height = 1.6
				cone.mesh = pm3
				cone.position = Vector3(0, 2.6 + 0.9 * float(k), 0)
				var cmat := StandardMaterial3D.new()
				cmat.albedo_color = Color(0.16, rng.randf_range(0.34, 0.46), 0.16)
				cmat.roughness = 1.0
				cone.material_override = cmat
				root.add_child(cone)
		else:
			var lean := rng.randf_range(-0.12, 0.12)
			var trunk := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.15
			tm.bottom_radius = 0.22
			tm.height = 2.2
			trunk.mesh = tm
			trunk.position = Vector3(0, 1.1, 0)
			trunk.rotation.z = lean
			trunk.material_override = tmat
			root.add_child(trunk)
			var trunk2 := MeshInstance3D.new()
			var tm2 := CylinderMesh.new()
			tm2.top_radius = 0.1
			tm2.bottom_radius = 0.15
			tm2.height = 1.4
			trunk2.mesh = tm2
			trunk2.position = Vector3(lean * -2.4, 2.6, 0)
			trunk2.rotation.z = lean * 2.0
			trunk2.material_override = tmat
			root.add_child(trunk2)
			var autumn := rng.randf() < 0.25
			var crown_col: Color
			if autumn:
				var apal: Array = [Color(0.75, 0.42, 0.14), Color(0.8, 0.55, 0.16), Color(0.68, 0.3, 0.12)]
				crown_col = apal[rng.randi() % apal.size()]
			else:
				crown_col = Color(0.22, rng.randf_range(0.38, 0.58), 0.18)
			if style == 2:
				var crown := MeshInstance3D.new()
				var cm := SphereMesh.new()
				var r := rng.randf_range(1.1, 1.4)
				cm.radius = r
				cm.height = r * 2.4
				crown.mesh = cm
				crown.position = Vector3(lean * -4.0, 3.9, 0)
				var cmat := StandardMaterial3D.new()
				cmat.albedo_color = crown_col
				cmat.roughness = 1.0
				crown.material_override = cmat
				root.add_child(crown)
			else:
				for k in 3:
					var crown := MeshInstance3D.new()
					var cm := SphereMesh.new()
					var r := rng.randf_range(0.85, 1.25)
					cm.radius = r
					cm.height = r * 2.0
					crown.mesh = cm
					crown.position = Vector3(lean * -3.0 + rng.randf_range(-0.6, 0.6), 2.6 + rng.randf_range(0.0, 1.0), rng.randf_range(-0.6, 0.6))
					var cmat := StandardMaterial3D.new()
					var cg := rng.randf_range(0.85, 1.1)
					cmat.albedo_color = Color(crown_col.r * cg, crown_col.g * cg, crown_col.b * cg)
					cmat.roughness = 1.0
					crown.material_override = cmat
					root.add_child(crown)
	for i in 25:
		var rx := rng.randf_range(-78.0, 78.0)
		var rz := rng.randf_range(-78.0, 78.0)
		if rx > terrain.VILLAGE_MIN.x - 3.0 and rx < terrain.VILLAGE_MAX.x + 3.0 and rz > terrain.VILLAGE_MIN.y - 3.0 and rz < terrain.VILLAGE_MAX.y + 3.0:
			continue
		if Vector2(rx, rz).distance_to(terrain.LAKE_POS) < 11.0:
			continue
		var ry: float = terrain.height_at(rx, rz)
		if ry < -1.0:
			continue
		var rock := MeshInstance3D.new()
		var kr := rng.randf_range(0.25, 0.7)
		rock.mesh = _rock_mesh(i % 4)
		rock.position = Vector3(rx, ry + kr * 0.3, rz)
		var ks := kr / 0.12
		rock.scale = Vector3(ks, ks * 0.6, ks * rng.randf_range(0.8, 1.2))
		rock.rotation.y = rng.randf() * TAU
		_rocks.append([rock, kr * 0.3])
		var kmat := StandardMaterial3D.new()
		var kg := rng.randf_range(0.35, 0.55)
		kmat.albedo_color = Color(kg, kg, kg * 1.05)
		kmat.roughness = 0.95
		kmat.albedo_texture = Textures.stone()
		kmat.normal_enabled = true
		kmat.normal_texture = Textures.stone_normal()
		kmat.normal_scale = 0.8
		kmat.uv1_triplanar = true
		rock.material_override = kmat
		add_child(rock)


func _settle_scatter() -> void:
	if terrain == null:
		return
	for t in _trees:
		var n: Node3D = t
		if is_instance_valid(n):
			var g: float = terrain.height_at(n.position.x, n.position.z)
			if n.position.y > g + 0.02:
				n.position.y = g
	for r in _rocks:
		var pair: Array = r
		var n2: Node3D = pair[0]
		if is_instance_valid(n2):
			n2.position.y = terrain.height_at(n2.position.x, n2.position.z) + float(pair[1])


func log_error(msg: String) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("[%s] %s" % [Time.get_datetime_string_from_system(), msg])
	f.close()


func save_game() -> void:
	var mach: Array = []
	for m in machines.list:
		if bool(m.get("dead", false)):
			continue
		var prev_pos := Vector2(1.0e30, 1.0e30)
		if int(m.get("prev", -1)) >= 0:
			var pm: Dictionary = machines.list[int(m["prev"])]
			prev_pos = Vector2(pm["pos"].x, pm["pos"].z)
		if bool(m.get("stress", false)):
			continue
		mach.append([String(m["type"]), int(m["tier"]), m["pos"].x, m["pos"].y, m["pos"].z, float(m["dirt"]), float(m["water"]), float(m["water_time"]), m["caixa"], m["caixa_gems"], float(m.get("yaw", 0.0)), prev_pos.x, prev_pos.y, m.get("cargo", {}), String(m.get("filter", "")), m.get("orebox", {}), bool(m.get("open", true)), m.get("store", {}), int(m.get("count", 0)), int(m.get("meta", 50)), String(m.get("ore", "")), int(m.get("dir", 1)), m.get("tray", {})])
	var pipe_arr: Array = []
	for p in machines.pipes:
		pipe_arr.append([p.x, p.y, p.z])
	var wire_arr: Array = []
	for p in machines.wires:
		wire_arr.append([p.x, p.y, p.z])
	var data := {
		"v": 2,
		"money": money,
		"pa_tier": pa_tier,
		"brush_tier": brush_tier,
		"bucket_terra": bucket_terra,
		"bucket_water": bucket_water,
		"pocket_dynamite": pocket_dynamite,
		"pocket_ores": pocket_ores,
		"pocket_bars": pocket_bars,
		"pocket_gems_raw": pocket_gems_raw,
		"pocket_gems": pocket_gems,
		"joias": joias,
		"artefatos": artefatos,
		"quest_index": quest_index,
		"completed_orders": completed_orders,
		"active_order": active_order,
		"village_level": village_level,
		"unlocked": unlocked,
		"stats_ores": stats_ores,
		"stats_harvester": stats_harvester,
		"drills_watered": drills_watered,
		"met_merchant": met_merchant,
		"has_picareta": has_picareta,
		"has_rastelo": has_rastelo,
		"has_detector": has_detector,
		"statue_level": statue_level,
		"playtime": playtime,
		"world_hour": world_hour,
		"text_scale": text_scale,
		"quality": quality,
		"music_level": sound.music_level,
		"sfx_level": sound.sfx_level,
		"has_truck": has_truck,
		"truck_cargo": truck_cargo,
		"debt": debt,
		"total_earned": total_earned,
		"player": [player.global_position.x, player.global_position.y, player.global_position.z],
		"machines": mach,
		"pipes": pipe_arr,
		"wires": wire_arr,
		"heights": Array(terrain.heights),
		"water": Array(terrain.water),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		log_error("Falha ao salvar: não foi possível abrir o arquivo de save.")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		log_error("Save corrompido ou ilegível (JSON inválido).")
		return false
	if int(parsed.get("v", 0)) < 2:
		return false
	money = int(parsed.get("money", money))
	pa_tier = int(parsed.get("pa_tier", 0))
	brush_tier = int(parsed.get("brush_tier", 0))
	bucket_terra = int(parsed.get("bucket_terra", 0))
	bucket_water = float(parsed.get("bucket_water", 0.0))
	pocket_dynamite = int(parsed.get("pocket_dynamite", 0))
	var po = parsed.get("pocket_ores", {})
	if typeof(po) == TYPE_DICTIONARY:
		pocket_ores = po
	var pb = parsed.get("pocket_bars", {})
	if typeof(pb) == TYPE_DICTIONARY:
		pocket_bars = pb
	var pgr = parsed.get("pocket_gems_raw", {})
	if typeof(pgr) == TYPE_DICTIONARY:
		pocket_gems_raw = pgr
	var pg = parsed.get("pocket_gems", {})
	if typeof(pg) == TYPE_DICTIONARY:
		pocket_gems = pg
	var jz = parsed.get("joias", [])
	if typeof(jz) == TYPE_ARRAY:
		joias = jz
	var ar = parsed.get("artefatos", [])
	if typeof(ar) == TYPE_ARRAY:
		artefatos = ar
	quest_index = int(parsed.get("quest_index", 0))
	completed_orders = int(parsed.get("completed_orders", 0))
	var ao = parsed.get("active_order", {})
	if typeof(ao) == TYPE_DICTIONARY:
		active_order = ao
	village_level = int(parsed.get("village_level", 1))
	var ul = parsed.get("unlocked", [])
	if typeof(ul) == TYPE_ARRAY and ul.size() == 5:
		unlocked = ul
	stats_ores = int(parsed.get("stats_ores", 0))
	stats_harvester = int(parsed.get("stats_harvester", 0))
	drills_watered = bool(parsed.get("drills_watered", false))
	met_merchant = bool(parsed.get("met_merchant", false))
	has_picareta = bool(parsed.get("has_picareta", false))
	has_rastelo = bool(parsed.get("has_rastelo", false))
	has_detector = bool(parsed.get("has_detector", false))
	statue_level = int(parsed.get("statue_level", 0))
	playtime = float(parsed.get("playtime", 0.0))
	world_hour = float(parsed.get("world_hour", 8.0))
	text_scale = float(parsed.get("text_scale", 1.0))
	quality = clampi(int(parsed.get("quality", 2)), 0, 3)
	_apply_quality()
	hud.set_text_scale(text_scale)
	sound.set_music_level(int(parsed.get("music_level", 2)))
	sound.set_sfx_level(int(parsed.get("sfx_level", 2)))
	has_truck = bool(parsed.get("has_truck", false))
	var tc = parsed.get("truck_cargo", {})
	if typeof(tc) == TYPE_DICTIONARY:
		truck_cargo = tc
	if has_truck and truck == null:
		_spawn_truck(Vector3(-4.0, 0.0, 56.0), PI)
	debt = int(parsed.get("debt", 0))
	total_earned = int(parsed.get("total_earned", 0))
	var h = parsed.get("heights", [])
	if typeof(h) == TYPE_ARRAY and h.size() == terrain.heights.size():
		terrain.heights = PackedFloat32Array(h)
		terrain.rebuild_all()
	var w = parsed.get("water", [])
	if typeof(w) == TYPE_ARRAY and w.size() == terrain.water.size():
		terrain.water = PackedFloat32Array(w)
		terrain.rebuild_water_mesh()
	var mach = parsed.get("machines", [])
	if typeof(mach) == TYPE_ARRAY:
		var prev_links: Array = []
		for e in mach:
			if typeof(e) == TYPE_ARRAY and e.size() >= 10:
				var pos := Vector3(float(e[2]), float(e[3]), float(e[4]))
				var yaw := 0.0
				if e.size() >= 11:
					yaw = float(e[10])
				var id: int = machines.add_machine(String(e[0]), int(e[1]), pos, yaw)
				if id >= 0:
					var m: Dictionary = machines.list[id]
					m["dirt"] = float(e[5])
					m["water"] = float(e[6])
					m["water_time"] = float(e[7])
					if typeof(e[8]) == TYPE_DICTIONARY:
						m["caixa"] = e[8]
					if typeof(e[9]) == TYPE_DICTIONARY:
						m["caixa_gems"] = e[9]
					if e.size() >= 14 and typeof(e[13]) == TYPE_DICTIONARY:
						m["cargo"] = e[13]
					if e.size() >= 15:
						m["filter"] = String(e[14])
					if e.size() >= 16 and typeof(e[15]) == TYPE_DICTIONARY:
						m["orebox"] = e[15]
					if e.size() >= 17:
						m["open"] = bool(e[16])
					if e.size() >= 18 and typeof(e[17]) == TYPE_DICTIONARY:
						m["store"] = e[17]
					if e.size() >= 19:
						m["count"] = int(e[18])
					if e.size() >= 20:
						m["meta"] = int(e[19])
					if e.size() >= 21 and String(e[0]) == "vein" and String(e[20]) != "":
						machines.vein_set_ore(id, String(e[20]))
					if e.size() >= 22:
						m["dir"] = 1 if int(e[21]) >= 0 else -1
					if e.size() >= 23 and typeof(e[22]) == TYPE_DICTIONARY:
						m["tray"] = e[22]
					if e.size() >= 13 and float(e[11]) < 1.0e30:
						prev_links.append([id, float(e[11]), float(e[12])])
		for link in prev_links:
			var lpos := Vector3(float(link[1]), 0.0, float(link[2]))
			var target: Dictionary = machines.find_machine_2d(lpos, "esteira", 0.3)
			if target.is_empty():
				target = machines.find_machine_2d(lpos, "filtro", 0.3)
			if target.is_empty():
				target = machines.find_machine_2d(lpos, "esteira_v", 0.3)
			if target.is_empty():
				target = machines.find_machine_2d(lpos, "splitter", 0.3)
			if not target.is_empty():
				machines.set_prev(int(link[0]), int(target["id"]))
		for m_lp in machines.list:
			if machines.is_belt(String(m_lp["type"])):
				machines.update_belt_pitch(int(m_lp["id"]))
	var pipe_arr = parsed.get("pipes", [])
	if typeof(pipe_arr) == TYPE_ARRAY:
		for p in pipe_arr:
			if typeof(p) == TYPE_ARRAY and p.size() == 3:
				machines.add_pipe(Vector3(float(p[0]), float(p[1]), float(p[2])))
	var wire_arr = parsed.get("wires", [])
	if typeof(wire_arr) == TYPE_ARRAY:
		for p in wire_arr:
			if typeof(p) == TYPE_ARRAY and p.size() == 3:
				machines.add_wire(Vector3(float(p[0]), float(p[1]), float(p[2])))
	var pp = parsed.get("player", [])
	if typeof(pp) == TYPE_ARRAY and pp.size() == 3:
		player.global_position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
	return true


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("interact", KEY_E)
	_add_key("build", KEY_T)
	_add_key("demolish", KEY_X)
	_add_key("move_obj", KEY_G)
	_add_key("dinamite", KEY_V)
	_add_key("cheat_money", KEY_F7)
	_add_key("blueprint", KEY_B)
	_add_key("map", KEY_M)
	_add_key("dump_bucket", KEY_R)
	_add_key("rotate_ccw", KEY_Q)
	_add_key("rotate_cw", KEY_E)
	_add_key("diagnose", KEY_H)
	_add_key("stats", KEY_J)
	_add_key("stress", KEY_F10)
	_add_key("showroom", KEY_F11)
	_add_key("save_game", KEY_F5)
	_add_key("reset_game", KEY_F9)
	if not InputMap.has_action("dig"):
		InputMap.add_action("dig")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("dig", mb)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.46, 0.82)
	sky_mat.sky_horizon_color = Color(0.83, 0.88, 0.94)
	sky_mat.ground_bottom_color = Color(0.35, 0.32, 0.28)
	sky_mat.ground_horizon_color = Color(0.78, 0.84, 0.9)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_sky_mat = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.84, 0.93)
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.12
	env.fog_aerial_perspective = 0.25
	_env = env
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_blur = 1.6
	sun.shadow_opacity = 0.82
	add_child(sun)
	_sun = sun
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 142, 0)
	fill.light_color = Color(0.6, 0.7, 0.95)
	fill.light_energy = 0.3
	add_child(fill)
	_fill = fill
	_apply_quality()
