class_name GameData
extends RefCounted
## Tabelas centrais do jogo: minérios, gemas, terrenos, tiers e preços.

const ORE_ORDER := ["ferro", "cobre", "prata", "ouro", "platina", "mithril", "corium"]
const ORES := {
	"ferro": {"name": "Ferro", "value": 1, "color": Color(0.55, 0.55, 0.6)},
	"cobre": {"name": "Cobre", "value": 2, "color": Color(0.72, 0.45, 0.3)},
	"prata": {"name": "Prata", "value": 4, "color": Color(0.8, 0.82, 0.85)},
	"ouro": {"name": "Ouro", "value": 8, "color": Color(1.0, 0.78, 0.15)},
	"platina": {"name": "Platina", "value": 16, "color": Color(0.88, 0.92, 0.95)},
	"mithril": {"name": "Mithril", "value": 32, "color": Color(0.5, 0.85, 0.9)},
	"corium": {"name": "Corium", "value": 120, "color": Color(0.12, 0.06, 0.1)},
}

const GEM_ORDER := ["agata", "ametista", "esmeralda", "safira", "rubi", "diamante", "lagrima"]
const GEMS := {
	"agata": {"name": "Ágata", "value": 5, "color": Color(0.75, 0.65, 0.55)},
	"ametista": {"name": "Ametista", "value": 12, "color": Color(0.65, 0.4, 0.85)},
	"esmeralda": {"name": "Esmeralda", "value": 30, "color": Color(0.2, 0.8, 0.45)},
	"safira": {"name": "Safira", "value": 60, "color": Color(0.2, 0.4, 0.9)},
	"rubi": {"name": "Rubi", "value": 120, "color": Color(0.9, 0.15, 0.2)},
	"diamante": {"name": "Diamante", "value": 300, "color": Color(0.95, 0.98, 1.0)},
	"lagrima": {"name": "Lágrima Divina", "value": 2000, "color": Color(1.0, 0.95, 0.6)},
}

const ZONE_NAMES := [
	"Terras do seu Avô (T1)",
	"Terras do Prefeito (T2)",
	"Terras do Governador (T3)",
	"Terras do Rei (T4)",
	"Terra Sagrada (T5)",
]
const ZONE_X_BOUNDS := [-999.0, -30.0, 0.0, 30.0, 55.0]
const ZONE_BEDROCK := [-8.0, -14.0, -20.0, -28.0, -40.0]
const ORE_WEIGHTS := [
	[55, 30, 15, 0, 0, 0, 0],
	[35, 30, 22, 13, 0, 0, 0],
	[25, 30, 28, 17, 0, 0, 0],
	[0, 0, 20, 30, 30, 20, 0],
	[0, 0, 0, 20, 25, 30, 25],
]
const GEM_WEIGHTS := [
	[70, 30, 0, 0, 0, 0, 0],
	[45, 35, 20, 0, 0, 0, 0],
	[25, 30, 25, 20, 0, 0, 0],
	[10, 20, 25, 25, 20, 0, 0],
	[0, 10, 15, 20, 25, 25, 5],
]

const PA_TIERS := [
	{"name": "Pá de Madeira", "radius": 1.3, "power": 0.35, "cooldown": 0.5, "bucket": 8, "price": 0},
	{"name": "Pá de Ferro", "radius": 1.8, "power": 0.45, "cooldown": 0.45, "bucket": 12, "price": 300},
	{"name": "Pá de Aço", "radius": 2.2, "power": 0.55, "cooldown": 0.4, "bucket": 16, "price": 1200},
	{"name": "Pá de Platina", "radius": 2.6, "power": 0.65, "cooldown": 0.35, "bucket": 20, "price": 5000},
	{"name": "Pá Divina", "radius": 3.2, "power": 0.8, "cooldown": 0.3, "bucket": 30, "price": 20000},
]
const BRUSH_TIERS := [
	{"name": "Escova Simples", "time": 4.0, "price": 0},
	{"name": "Escova de Cerda Fina", "time": 3.0, "price": 250},
	{"name": "Escova de Aço", "time": 2.4, "price": 900},
	{"name": "Escova Precisa", "time": 1.8, "price": 3500},
	{"name": "Escova Arcana", "time": 1.2, "price": 14000},
]
const DRILL_TIERS := [
	{"name": "Drill T1", "rate": 0.4, "money": 200, "bars": {}},
	{"name": "Drill T2", "rate": 0.8, "money": 800, "bars": {"ferro": 5}},
	{"name": "Drill T3", "rate": 1.6, "money": 3000, "bars": {"ferro": 10, "cobre": 5}},
	{"name": "Drill T4", "rate": 3.2, "money": 12000, "bars": {"ouro": 10, "platina": 5}},
	{"name": "Drill T5", "rate": 6.4, "money": 45000, "bars": {"mithril": 15, "corium": 3}},
]
const HARVESTER_TIERS := [
	{"name": "Harvester T1", "rate": 0.8, "money": 350, "bars": {}},
	{"name": "Harvester T2", "rate": 1.6, "money": 1200, "bars": {"ferro": 8}},
	{"name": "Harvester T3", "rate": 3.2, "money": 4500, "bars": {"cobre": 10, "prata": 5}},
	{"name": "Harvester T4", "rate": 6.4, "money": 15000, "bars": {"ouro": 12, "platina": 8}},
	{"name": "Harvester T5", "rate": 12.8, "money": 60000, "bars": {"mithril": 20, "corium": 5}},
]
const PIPE_PRICE := 10
const POLIDORA_PRICE := 600
const PRENSA_PRICE := 1500
const FORJA_PRICE := 400
const BIGORNA_PRICE := 700
const BACIA_PRICE := 150
const ESTEIRA_PRICE := 60
const FILTRO_PRICE := 250
const BAU_PRICE := 400
const SILO_PRICE := 600
const REGISTRO_PRICE := 150
const PICARETA_PRICE := 350
const RASTELO_PRICE := 500
const CABO_PRICE := 25
const SENSOR_PRICE := 200
const DETECTOR_PRICE := 1200
const VEIN_COUNTS := [4, 5, 6, 7, 8]
const VEIN_COOLDOWN := 20.0
const ALARME_PRICE := 150
const INTERRUPTOR_PRICE := 100
const STRUCT_PRICES := {"fundacao": 20, "piso": 15, "parede": 25, "escada": 30, "cerca": 10}
const GERADOR_TIERS := [
	{"name": "Gerador T1", "power": 3, "money": 500, "bars": {}},
	{"name": "Gerador T2", "power": 8, "money": 2000, "bars": {"ferro": 5}},
	{"name": "Gerador T3", "power": 20, "money": 6000, "bars": {"cobre": 10, "ferro": 5}},
	{"name": "Gerador T4", "power": 50, "money": 18000, "bars": {"ouro": 10, "platina": 5}},
	{"name": "Gerador T5", "power": 120, "money": 55000, "bars": {"mithril": 15, "corium": 3}},
]
const TIER_COLORS := [Color(0.55, 0.4, 0.25), Color(0.6, 0.6, 0.65), Color(0.3, 0.5, 0.85), Color(0.9, 0.75, 0.2), Color(0.95, 0.95, 1.0)]

const ANVIL_ITEMS := [
	{"id": "anel", "name": "Anel", "bars": 1, "bonus": 0.15},
	{"id": "adaga", "name": "Adaga", "bars": 2, "bonus": 0.25},
	{"id": "espada", "name": "Espada", "bars": 2, "bonus": 0.4},
]

const MAIN_QUESTS := [
	{"text": "Fale com o Mercador do vilarejo", "reward": 50},
	{"text": "Colete 10 minérios (balde + bacia + escova)", "reward": 100, "village": 2},
	{"text": "Entregue 5 barras de ferro ao Mercador", "reward": 300, "village": 3},
	{"text": "Ligue uma Drill T1 à água", "reward": 500, "village": 4},
	{"text": "Produza 50 minérios com o Harvester", "reward": 1000, "village": 5},
	{"text": "Acumule $10.000 para comprar as terras do Prefeito", "unlock": 1},
	{"text": "Entregue 10 barras de ouro ao Governador", "unlock": 2},
	{"text": "Acumule $50.000 e 15 barras de mithril para o Rei", "unlock": 3},
	{"text": "Complete 10 encomendas do vilarejo", "unlock": 4},
	{"text": "Forje uma joia com a Lágrima Divina", "reward": 100000},
]

const ARTEFACT_NAMES := [
	"Moeda Antiga", "Amuleto Rústico", "Fragmento de Espada", "Ídolo de Barro",
	"Chave Enferrujada", "Anel de Signet", "Placa de Bronze", "Relicário Aberto",
]


static func zone_at(wx: float) -> int:
	for i in range(ZONE_X_BOUNDS.size() - 1, -1, -1):
		if wx >= ZONE_X_BOUNDS[i]:
			return i
	return 0


static func pick_weighted(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return -1
	var r := randi() % total
	for i in weights.size():
		r -= int(weights[i])
		if r < 0:
			return i
	return 0


static func bar_value(ore_id: String) -> int:
	var ore: Dictionary = ORES[ore_id]
	return int(ceil(10.0 * float(ore["value"]) * 1.1))
