# PAWN

> Vous n'êtes pas le commandant. Vous êtes un péon orc.

Simulation d'ouvrier en vue FPS au cœur d'un RTS asymétrique — **Godot 4.7 (Forward+)**, cible Windows.

## État du MVP

| Étape | Statut |
|---|---|
| Découpe de bois (§3.1 de la spec) + joueur FPS minimal | ✅ |
| Ramassage (E) et portage des bûches sur l'épaule (§3.2) | ✅ |
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
| Ramasser une bûche (en la visant) | E |
| Libérer / recapturer la souris | Échap / clic |

## Ce qui est implémenté

**Coupe** — 4 coups (`AXE_DAMAGE` 25 / `TREE_MAX_HEALTH` 100) : petits éclats d'écorce projetés à l'opposé du coup (`WoodChipsVFX`), oscillation élastique du tronc (ressort amorti), secousse d'écran, son d'impact, micro-pause à l'impact (*hit-stop*).

**Explosion en rondins** — à zéro point de vie, le tronc explose sur place : **4 rondins physiques** (`WoodLog`) sont projetés depuis le fût, surtout dans la direction du dernier coup, avec éclats, nuages de poussière et de feuilles (`DustImpactVFX`), fracas et secousse d'écran atténuée par la distance. La souche reste en place, sans collision.

**Ramassage** — viser une bûche affiche « [E] Ramasser ». L'orc range sa hache à la ceinture, fait un pas vers la bûche, s'accroupit en baissant le regard, l'empoigne de la main droite et la hisse jusqu'à son épaule gauche (la main gauche ne lâche jamais la pile), puis reprend sa hache : la pile grossit de 1 à 10 (4 + 4 + 2) en périphérie gauche de l'écran, tenue par la main gauche. La hache reste utilisable, la charge ralentit (-35 % à 10), « Charge pleine » à 10/10.

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
tests/         scénarios automatiques avec captures (voir CLAUDE.md)
tools/asset_pipeline/   scripts Blender/Python ayant produit les assets
tools/level_gen/        générateur de la forêt de test (+ texture de terre battue)
docs/          cahier des charges
PROGRESS.md    état du projet et suite (reprise de session)
```

### Ajouter un arbre

Découper un modèle avec `tools/asset_pipeline/split_tree.py`, puis créer une scène héritée de
`scenes/trees/choppable_tree.tscn` avec le GLB de souche sous `Stump` et celui du tronc sous `TrunkPivot`
(voir `tree_2_c.tscn`). La charnière et les collisions sont déduites automatiquement des meshes.
