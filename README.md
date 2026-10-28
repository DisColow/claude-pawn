# PAWN

> Vous n'êtes pas le commandant. Vous êtes un péon orc.

Simulation d'ouvrier en vue FPS au cœur d'un RTS asymétrique — **Godot 4.7 (Forward+)**, cible Windows.

## État du MVP

| Étape | Statut |
|---|---|
| Découpe de bois (§3.1 de la spec) + joueur FPS minimal | ✅ |
| Portage des rondins sur l'épaule (§3.2) | à venir |
| Dépôt au camp (§3.3) | à venir |

## Lancer

1. Ouvrir le dossier dans **Godot 4.7** (`project.godot`), laisser l'import se terminer.
2. `F5` — la scène principale est `scenes/world/test_forest.tscn`.

| Action | Touche |
|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) — touches *physiques* |
| Sprint (consomme l'endurance) | Maj |
| Sauter | Espace |
| Coup de hache | Clic gauche (maintenir = coups enchaînés) |
| Libérer / recapturer la souris | Échap / clic |

## Ce qui est implémenté

**Coupe** — 4 coups (`AXE_DAMAGE` 25 / `TREE_MAX_HEALTH` 100) : éclats de bois et sciure (`WoodChipsVFX`), oscillation élastique du tronc (ressort amorti), secousse d'écran, son d'impact, micro-pause à l'impact (*hit-stop*).

**Chute physique** — à zéro point de vie, le tronc devient un corps rigide (collisions convexes fût + feuillage calculées depuis le mesh), retenu à la souche par une rotule qui cède en cours de chute. Le dernier coup lui donne un élan dans sa direction, que la gravité amplifie *avec* le penchant naturel de l'arbre (feuillage décentré) : la chute suit le coup avec une déviation propre à chaque arbre (`TREE_FELL_KICK` règle le mélange). Craquement (`tree_creak`) pendant la bascule ; un tronc peut heurter un autre arbre avant de toucher le sol. **Au contact du sol**, il éclate en **4 rondins physiques** (`WoodLog`) projetés le long de son axe, avec éclats, poussière, feuilles (`DustImpactVFX`), fracas et secousse atténuée par la distance. La souche reste en place.

**Joueur** — corps d'orc complet animé (idle/marche/course/sprint/saut), visible en regardant vers le bas sans masquer le sol ; ombre portée complète (tête et hache comprises) ; bruits de pas cadencés ; endurance du sprint ; pénalité de charge déjà câblée (`get_carry_speed_multiplier`, -35 % à 10 rondins). Le bras droit tient la hache par IK, le coup est animé procéduralement en espace caméra. Bras, hache et corps utilisent le **Z-Clip Depth Scaling** (`use_z_clip_scale`, `z_clip_scale = 0.1`).

Toutes les valeurs d'équilibrage et de *game feel* sont dans `scripts/core/game_config.gd`.

## Structure

```
assets/        modèles, sons, textures (voir CREDITS.md)
scenes/        player/, trees/, props/, vfx/, ui/, world/
scripts/
  core/        GameConfig (autoload), ZClip
  player/      Player, FirstPersonBody (+ modificateurs de squelette), AxeController, CameraShake
  trees/       ChoppableTree
  props/       WoodLog
  vfx/         OneShotVFX, WoodChipsVFX, DustImpactVFX
  ui/          HUD
tools/asset_pipeline/   scripts Blender/Python ayant produit les assets
```

### Ajouter un arbre

Découper un modèle avec `tools/asset_pipeline/split_tree.py`, puis créer une scène héritée de
`scenes/trees/choppable_tree.tscn` avec le GLB de souche sous `Stump` et celui du tronc sous `TrunkPivot`
(voir `tree_2_c.tscn`). La charnière et les collisions sont déduites automatiquement des meshes.
