class_name CampEconomy
extends Node
## Économie du camp : stock global des ressources déposées par les travailleurs, dépensé par le Général.
## Chargé en autoload (nœud `Camp`) ; on y accède par `CampEconomy.instance` plutôt que par le nom
## de l'autoload, qui n'existe pas encore quand Godot compile un script lancé avec `-s` (tests).

signal wood_changed(total: int)
signal gold_changed(total: int)

static var instance: CampEconomy

## Bois en stock au camp (en rondins).
var wood := 0
## Or en stock au camp.
var gold := 0


func _enter_tree() -> void:
	instance = self


## Ajoute `amount` rondins au stock global.
func add_wood(amount: int) -> void:
	if amount <= 0:
		return
	wood += amount
	wood_changed.emit(wood)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func can_afford(wood_cost: int, gold_cost: int) -> bool:
	return wood >= wood_cost and gold >= gold_cost


## Dépense les ressources si le stock suffit. Renvoie false (et ne dépense rien) sinon.
func spend(wood_cost: int, gold_cost: int) -> bool:
	if not can_afford(wood_cost, gold_cost):
		return false
	wood -= wood_cost
	gold -= gold_cost
	wood_changed.emit(wood)
	gold_changed.emit(gold)
	return true


## Remet le stock à zéro (nouvelle partie).
func reset() -> void:
	wood = 0
	gold = 0
	wood_changed.emit(wood)
	gold_changed.emit(gold)
