# PAWN

> Vous n'êtes pas le commandant. Vous êtes un péon orc.

Simulation d'ouvrier en vue FPS au cœur d'un RTS asymétrique — **Godot 4.7 (Forward+)**, cible Windows.

## Le jeu

Tu n'es pas le commandant : tu es **un péon** au milieu d'une vraie partie de stratégie que joue une IA, le
**Général**. Il bâtit la base, gère l'économie, lève l'armée et attaque le camp d'en face, tenu par un autre
Général. Toi, en vue subjective, tu coupes le bois, tu mines l'or, tu construis au marteau et, en dernier
recours, tu te bats. **On gagne en rasant la loge de guerre ennemie ; on perd si la nôtre tombe.**

Cahier des charges : `docs/PAWN_Specification_1.pdf`. Avancement et écarts : `PROGRESS.md`.

| Système | En jeu |
|---|---|
| Ordres | Panneau en haut à gauche. Les suivre fait monter la **loyauté**, les ignorer la fait baisser. À zéro, le Général te déclare traître et envoie une escouade. |
| Influence | Maintenir **Q** : roue de 8 suggestions. Le Général se trompe exprès (il oublie l'or, n'entraîne pas de guerriers…) ; un bon conseil accepté rapporte XP et **confiance**, qui décide s'il t'écoute. |
| Récolte | Bois : abattre un arbre, ramasser les bûches (E). Or : entrer dans la mine, frapper les veines à la pioche. On porte l'un ou l'autre. Dépôt avec E contre la loge ou un entrepôt, de n'importe quel côté. |
| Construction | Le Général pose un chantier en **fantôme vert** ; maintenir E devant : le marteau sort, le bâtiment devient tangible au premier coup. E répare aussi les bâtiments abîmés. |
| Talents | XP en récoltant, bâtissant, tuant, conseillant. Un point par niveau (30 max), trois arbres (**Tab**). Tout est perdu à la mort. |
| Renom | Gagné en fin de partie, dépensé au menu en améliorations **permanentes** (sauvegardées). |
| Mort | La charge tombe au sol ; le Général entraîne un nouveau péon (prix d'un péon, après le combat). |

## Lancer

1. Ouvrir le dossier dans **Godot 4.7** (`project.godot`), laisser l'import se terminer.
2. `F5` — menu principal : Partie libre (2 cartes, 3 difficultés), Campagne (3 missions), Progression, Options.

| Action | Clavier | Manette |
|---|---|---|
| Se déplacer | ZQSD / WASD (touches physiques) | stick gauche |
| Regarder | souris | stick droit |
| Sprint / saut / roulade (à débloquer) | Maj / Espace / Ctrl | L3 / A / B |
| Coup d'outil (hache, pioche dans la mine) | clic gauche (maintenir) | RT |
| Ramasser, déposer ; construire et réparer (maintenir) | E | X |
| Roue de communication (maintenir, viser, relâcher) | Q (touche physique : « A » sur AZERTY) | LB |
| Talents | Tab | Start |
| Barricade / achever un chantier (talents) | B / F | — |
| Libérer la souris | Échap | — |
| *Test* : -300 PV au bâtiment allié proche / +100 bois et or / assaut ennemi immédiat / +1 niveau | K / L / N / X | — |

Les touches du clavier se reconfigurent dans Options.

## Structure

```
assets/        modèles, sons, textures (voir CREDITS.md)
scenes/        player/, trees/, props/, camp/ (building.tscn), units/ (unit.tscn), vfx/, ui/, world/ (cartes, mine)
scripts/
  core/        GameConfig (toutes les données), CampEconomy (un par camp), GameDirector, NavGraph, ZClip
  ai/          General (IA d'un camp), WorkerOrders (ordres, loyauté, confiance, influence)
  camp/        CampBuilding (tous les bâtiments)
  units/       Unit (péons du Général, soldats, lanceurs, volants, siège, héros)
  player/      Player, LogCarrier (portage et actions E), FirstPersonBody, AxeController, CameraShake
  progress/    WorkerProgress (XP, talents), MetaProgress (Renom, sauvegarde, options)
  world/       GoldMine, GoldVein
  props/       WoodLog, GoldSack, WeaponPickup, Barricade, rochers, buissons
  ui/          HUD, Minimap, CommWheel, TalentScreen, MainMenu, UiKit
  vfx/, trees/, debug/
tests/         scénarios automatiques (voir CLAUDE.md)
tools/         asset_pipeline/ (Blender, Python), level_gen/gen_maps.py (cartes)
docs/          cahier des charges (PDF) et ancien extrait
PROGRESS.md    état du projet, décisions, écarts avec le cahier des charges
```

### Ajouter un arbre

Découper un modèle avec `tools/asset_pipeline/split_tree.py`, puis créer une scène héritée de
`scenes/trees/choppable_tree.tscn` avec le GLB de souche sous `Stump` et celui du tronc sous `TrunkPivot`
(voir `tree_2_c.tscn`). La charnière et les collisions sont déduites automatiquement des meshes.
