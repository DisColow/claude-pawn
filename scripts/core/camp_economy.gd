class_name CampEconomy
extends Node
## Économie du camp : stock global des ressources déposées par les travailleurs.
## Chargé en autoload (nœud `Camp`) ; on y accède par `CampEconomy.instance` plutôt que par le nom
## de l'autoload, qui n'existe pas encore quand Godot compile un script lancé avec `-s` (tests).

signal wood_changed(total: int)

static var instance: CampEconomy

## Bois en stock au camp (en rondins).
var wood := 0


func _enter_tree() -> void:
	instance = self


## Ajoute `amount` rondins au stock global.
func add_wood(amount: int) -> void:
	if amount <= 0:
		return
	wood += amount
	wood_changed.emit(wood)
