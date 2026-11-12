class_name WorkerProgress
extends Node
## Progression du péon PENDANT la partie (§8) : XP, niveaux (30 au plus), un point de talent par
## niveau, trois arbres (Récolte, Construction, Combat). Tout est remis à zéro à la mort ; seules
## les améliorations permanentes (`MetaProgress`) survivent.

signal xp_changed(xp: int, needed: int, level: int)
signal leveled_up(level: int)
signal talents_changed

var level := 1
var xp := 0
## Points de talent à dépenser.
var points := 0
## Rangs investis : id du talent → rang.
var ranks: Dictionary = {}
var respec_cooldown := 0.0


func _physics_process(delta: float) -> void:
	respec_cooldown = maxf(respec_cooldown - delta, 0.0)


## XP nécessaire pour passer du niveau courant au suivant.
func xp_needed() -> int:
	return GameConfig.XP_BASE + GameConfig.XP_PER_LEVEL * (level - 1)


func add_xp(amount: float) -> void:
	if level >= GameConfig.LEVEL_CAP:
		return
	xp += roundi(amount * (1.0 + 0.1 * MetaProgress.level_of("learning")))
	while level < GameConfig.LEVEL_CAP and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		points += 1
		leveled_up.emit(level)
	if level >= GameConfig.LEVEL_CAP:
		xp = 0
	xp_changed.emit(xp, xp_needed(), level)


func rank(talent: String) -> int:
	return int(ranks.get(talent, 0))


## Points investis dans un arbre.
func spent_in(tree: String) -> int:
	var total := 0
	for talent: String in ranks:
		if GameConfig.TALENTS[talent]["tree"] == tree:
			total += int(ranks[talent])
	return total


## Peut-on investir un point dans ce talent ? (point disponible, rang max, palier débloqué)
func can_spend(talent: String) -> bool:
	var config: Dictionary = GameConfig.TALENTS[talent]
	return points > 0 and rank(talent) < int(config["ranks"]) \
		and spent_in(config["tree"]) >= (int(config["tier"]) - 1) * GameConfig.TALENT_TIER_COST


func spend(talent: String) -> bool:
	if not can_spend(talent):
		return false
	ranks[talent] = rank(talent) + 1
	points -= 1
	talents_changed.emit()
	return true


## Redistribution : rend tous les points (avec un délai avant la prochaine).
func respec() -> bool:
	if respec_cooldown > 0.0 or ranks.is_empty():
		return false
	for talent: String in ranks:
		points += int(ranks[talent])
	ranks.clear()
	respec_cooldown = GameConfig.RESPEC_COOLDOWN
	talents_changed.emit()
	return true


## Mort du péon : niveau, XP et talents repartent de zéro.
func reset() -> void:
	level = 1
	xp = 0
	points = 0
	ranks.clear()
	respec_cooldown = 0.0
	talents_changed.emit()
	xp_changed.emit(xp, xp_needed(), level)
