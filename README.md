# PAWN

> Vous n'êtes pas le commandant. Vous êtes un péon orc.

Simulation d'ouvrier en vue FPS au cœur d'un RTS asymétrique — **Godot 4.7 (Forward+)**, cible Windows.

## Le jeu

Tu es le péon d'un camp orc dirigé par une IA, le **Général**. Il décide quoi bâtir et te donne ses ordres
(en haut de l'écran) ; toi, tu coupes le bois, tu mines l'or, tu construis ses bâtiments et tu défends ta peau.
Des vagues de squelettes arrivent par la route du nord. **Victoire** si le camp repousse les 8 vagues,
**défaite** si le bastion tombe.

| Élément | Rôle |
|---|---|
| Bastion | Cœur du camp. On dépose le bois et l'or dans sa cour. S'il est détruit, c'est perdu. |
| Mine d'or (à l'est) | Maintenir E pour remplir un sac de 10 or, à rapporter au bastion. |
| Scierie | Premier bâtiment du plan ; second dépôt de bois. |
| Tours de guet | Tirent sur les squelettes à portée. |
| Caserne | Le Général y lève des grunts (25 or chacun, 6 au plus) qui défendent le camp. |

Le Général paie chaque bâtiment avec le stock du camp et pose le chantier ; le péon le construit en
maintenant E à côté. Un bâtiment détruit est recommandé par le Général (il faut le repayer et le rebâtir).
Le péon a 100 points de vie, se bat à la hache, et réapparaît au camp 6 secondes après sa mort en perdant sa charge.

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
| Déposer le bois (dans la zone du dépôt) | E |
| Miner l'or / construire un chantier | E (maintenir) |
| Rejouer (écran de fin) | R |
| *Test* : -300 PV au bâtiment le plus proche / lancer la vague suivante | K / N |
| Libérer / recapturer la souris | Échap / clic |

## Ce qui est implémenté

**Coupe** — 4 coups (`AXE_DAMAGE` 25 / `TREE_MAX_HEALTH` 100) : petits éclats d'écorce projetés à l'opposé du coup (`WoodChipsVFX`), oscillation élastique du tronc (ressort amorti), secousse d'écran, son d'impact, micro-pause à l'impact (*hit-stop*).

**Explosion en rondins** — à zéro point de vie, le tronc explose sur place : **4 rondins physiques** (`WoodLog`) sont projetés depuis le fût, surtout dans la direction du dernier coup, avec éclats, nuages de poussière et de feuilles (`DustImpactVFX`), fracas et secousse d'écran atténuée par la distance. La souche reste en place, sans collision.

**Ramassage** — viser une bûche affiche « [E] Ramasser ». La bûche disparaît dans un nuage de fumée façon ninja, avec le « clac » d'une bûche qui en cogne une autre, et apparaît aussitôt sur la pile de l'épaule gauche, tenue par la main gauche : la pile grossit de 1 à 10 (4 + 4 + 2) en périphérie gauche de l'écran, tenue par la main gauche. La hache reste utilisable, la charge ralentit (-35 % à 10), « Charge pleine » à 10/10.

**Bâtiments** — `CampBuilding` : points de vie, nom et barre de vie au-dessus, chantier par étapes sous échafaudage (les points de vie montent avec le travail du péon), ruines à zéro point de vie, reconstruction. Valeurs dans `GameConfig.BUILDINGS`.

**Général, vagues, unités** — `General` (plan de construction, recrutement), `GameDirector` (vagues, victoire, défaite), `Unit` (squelettes et grunts : choix de cible, déplacement, corps à corps), `WatchTower` (tir).

**Dépôt au camp** — la pile de bois (quatre piquets dans la cour du bastion et de la scierie) affiche « [E] Déposer le bois (n) » dès qu'on entre dans sa zone avec du bois. Les rondins quittent l'épaule un par un et volent jusqu'à la pile, qui grandit (3 tas en pyramide de 28 rondins, solides) ; le stock global du camp (`CampEconomy`) s'affiche en haut à gauche. `STOCKPILE_AUTO_DEPOSIT` permet de décharger sans appuyer sur E.

**Joueur** — corps d'orc complet animé (idle/marche/course/sprint/saut), visible en regardant vers le bas sans masquer le sol ; ombre portée complète (tête et hache comprises) ; bruits de pas cadencés ; endurance du sprint ; pénalité de charge déjà câblée (`get_carry_speed_multiplier`, -35 % à 10 rondins). Le bras droit tient la hache par IK, le coup est animé procéduralement en espace caméra. Bras, hache et corps utilisent le **Z-Clip Depth Scaling** (`use_z_clip_scale`, `z_clip_scale = 0.1`).

Toutes les valeurs d'équilibrage et de *game feel* sont dans `scripts/core/game_config.gd`.

## Structure

```
assets/        modèles, sons, textures (voir CREDITS.md)
scenes/        player/, trees/, props/, camp/, units/, vfx/, ui/, world/
scripts/
  core/        GameConfig et CampEconomy (autoloads), GameDirector, ZClip
  camp/        CampBuilding, Bastion, LumberMill, WatchTower, WoodStockpile
  units/       Unit (squelettes, grunts)
  ai/          General
  world/       GoldMine
  debug/       touches de test (K / N)
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
