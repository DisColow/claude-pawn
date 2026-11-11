# PAWN — Suivi de progression

> Fichier de reprise : l'état du projet, les décisions prises et la suite. Cahier des charges : `docs/SPECIFICATIONS.md`.
> **À tenir à jour à chaque étape terminée** (voir `CLAUDE.md`). Dernière mise à jour : 2026-11-11.

## Où on en est

- **Branche de travail** : `feature/decoupe-bois` (seule branche du dépôt `DisColow/claude-pawn` ; `main` n'existe pas encore — décision en attente, voir plus bas).
- **Fait** : tout le MVP du cahier des charges — §3.1 découpe de bois (validée par l'utilisateur), §3.2 ramassage/portage (ramassage « ninja ») et §3.3 dépôt au camp (**à valider en jeu par l'utilisateur**).
- **Prochaine étape** : retours de l'utilisateur sur le dépôt ; ensuite, la suite de la vision (§1 : or, construction, défense, Général) n'est pas encore spécifiée.

## Fait

| Domaine | Contenu | Fichiers clés |
|---|---|---|
| Config | Toutes les valeurs d'équilibrage / game feel (autoload `GameConfig`) | `scripts/core/game_config.gd` |
| Arbre | 100 PV, 4 coups (25 dmg), petits éclats d'écorce éjectés à l'opposé du mouvement de la hache (direction transmise par `AxeController`), oscillation élastique (ressort amorti), son d'impact aléatoire, hit-stop. À 0 PV : **le tronc explose en 4 rondins** projetés à l'opposé du joueur + poussière/feuilles + fracas + secousse. La souche reste, **sans collision** (traversable). Charnière et collisions déduites des meshes. | `scripts/trees/choppable_tree.gd`, `scenes/trees/*.tscn` |
| Rondins | `WoodLog` (RigidBody3D, couche 4 « logs »), son au choc, groupe `wood_logs`. | `scripts/props/wood_log.gd`, `scenes/props/wood_log.tscn` |
| VFX | `WoodChipsVFX` (7 éclats d'écorce discrets), `DustImpactVFX` (GPUParticles3D one-shot, base `OneShotVFX`), `poof_vfx.tscn` (disparition en fumée, muette) | `scripts/vfx/`, `scenes/vfx/` |
| Joueur | Orc avec **oreilles pointues et défenses** (`OrcHeadParts`, modèles CC-BY greffés sur l'os Head ; visibles dans l'ombre, la tête étant masquée en vue subjective). CharacterBody3D : marche 5,2 / sprint 8,2 + endurance, saut, pas. Corps d'orc complet animé (AnimationTree : idle/walk/jog/sprint/jump + poing fermé), tête/cou masqués, **squelette d'ombre** (ombre complète), corps reculé quand on regarde en bas / court. Bras droit en **IK** (TwoBoneIK3D) tenant la hache ; coup **procédural** en espace caméra (élan, arc, hit-stop, retour), raycast d'impact. Camera shake par trauma. Z-clip (`z_clip_scale 0.1`) sur bras/hache/corps. `get_carry_speed_multiplier()` déjà câblé (-35 % à 10 rondins). | `scripts/player/*.gd`, `scenes/player/player.tscn` |
| Ramassage / portage | `LogCarrier` (enfant du joueur) : viser une bûche (rayon caméra, 2,3 m) → « [E] Ramasser ». **Ramassage « ninja »** : la bûche disparaît instantanément dans un nuage de fumée blanche (`PoofVFX` : bouffées opaques qui gonflent d'un coup + anneau de petites bouffées) et **une note douce façon marimba est jouée** (non spatialisée ; dix notes synthétisées qui montent une gamme pentatonique avec la pile, arpège à la 10e) et apparaît sur la pile avec un petit rebond. Aucun temps mort : on peut bouger et frapper pendant. Pile sur l'épaule gauche (4+4+2, bûches à 50 %), z-clip + copie d'ombre, **main gauche (2e `TwoBoneIK3D`) qui la tient**. Capacité 10, « Charge pleine », pénalité -35 %. | `scripts/player/log_carrier.gd`, `scenes/vfx/poof_vfx.tscn` |
| Dépôt au camp | `WoodStockpile` dans la clairière (4 piquets, étiquette 3D « Dépôt de bois n »). Dans sa zone (Area3D, 7 × 5,4 m) avec du bois : « [E] Déposer le bois (n) ». Les rondins partent de l'épaule un par un (0,09 s) et **volent en cloche jusqu'à la pile**, qui grandit : 3 tas en pyramide de 28 (MultiMesh, 84 visibles ; au-delà seul le compteur monte), une boîte de collision par tas. Sortir de la zone interrompt le déchargement (le reste est gardé). Stock global : autoload `Camp` (`CampEconomy.instance.wood`, signal `wood_changed`), crédité quand le rondin quitte l'épaule. | `scripts/camp/wood_stockpile.gd`, `scenes/camp/wood_stockpile.tscn`, `scripts/core/camp_economy.gd` |
| HUD | Réticule, jauge d'endurance, invite (ramassage / dépôt), compteur « Bois : n / 10 », stock « Camp — Bois : n » | `scenes/ui/hud.tscn` |
| Décor | **Rochers solides** (`SolidProp` : collision convexe calculée depuis le mesh, en cache) ; **buissons traversables qui froissent** (`RustlingBush` : son de feuilles + frémissement, répété tant qu'on s'y déplace). | `scripts/props/`, `scenes/props/` |
| Monde | Forêt de test **façon Warcraft 3** générée par `tools/level_gen/gen_test_forest.py` : clairière de terre battue (décalque) au centre, **504 arbres coupables** serrés (grille perturbée, pas 2,6 m ; 85 % de sapins `tree_4_c`), rochers solides, buissons qui froissent, herbe ; soleil haut (70°) dans le dos du joueur, clairière ensoleillée. Rayons de tronc mis en cache par modèle, oscillation calculée seulement quand un arbre bouge. | `scenes/world/test_forest.tscn`, `tools/level_gen/` |
| Assets | KayKit, Quaternius, Kenney, OpenGameArt (CC0 sauf `tree_crash.ogg` CC-BY 3.0) | `CREDITS.md`, `tools/asset_pipeline/` |

## Décisions prises (ne pas re-discuter sans l'utilisateur)

- **Godot 4.7.2**, Forward+, Jolt Physics. Cible Windows.
- **Assets** : CC0 de préférence (Sketchfab écarté : CC-BY). Style low-poly KayKit/Quaternius.
- **Plus de chute d'arbre** : l'utilisateur a essayé la chute scriptée puis la chute physique (le penchant naturel l'emportait sur la direction du coup) et a choisi **l'explosion en rondins à 0 PV**.
- **Vue FPS « true first person »** : vrai corps animé + IK pour le bras, plutôt qu'un viewmodel séparé.
- Touches **physiques** (ZQSD sur AZERTY = WASD).
- **Effet d'impact discret** : quelques éclats d'écorce, projetés à l'opposé du coup (demandé le 2026-11-07, l'ancien effet était jugé raté).
- **Le dépôt est toujours dans l'état où l'éditeur Godot le laisse** : `tools/resave_with_editor.sh` avant chaque commit (sinon conflits au `git pull` chez l'utilisateur).
- Rochers solides, buissons traversables avec bruit ; **arbres (sapins KayKit) gardés tels quels** ; ramassage des bûches **avec E** et animation en body awareness ; orc avec crocs et oreilles pointues (2026-11-07).
- **Forêt dense façon Warcraft 3** (référence : captures de WC3 Reforged fournies le 2026-11-07) : la scène de test se régénère avec le script, ne pas l'éditer à la main.
- **Ramassage de la main droite** (2026-11-08) : la main gauche, qui tient la pile sur l'épaule, ne doit jamais la lâcher (sinon les bûches tomberaient) ; l'orc range donc sa hache à la ceinture pour ramasser.
- **Ramassage « ninja » en fumée** (2026-11-11) : l'utilisateur a abandonné l'animation de ramassage (main droite, hache à la ceinture, accroupissement) au profit d'une disparition en fumée façon Naruto ; la bûche apparaît directement sur la pile. L'ancienne animation reste consultable dans l'historique git (commit `4dbd985`).
- **Dépôt avec E dans la zone** (2026-11-11, choix de Claude, à confirmer) : la spec dit « approcher du dépôt ou appuyer sur E » ; E a été retenu par cohérence avec le ramassage. `STOCKPILE_AUTO_DEPOSIT = true` dans `GameConfig` décharge dès l'entrée dans la zone.
- **`CampEconomy.instance`** plutôt que le nom de l'autoload : celui-ci n'existe pas quand Godot compile un script lancé avec `-s`, ce qui cassait tous les tests.
- **Son de ramassage gratifiant** (2026-11-11) : le « poof » de bruit filtré était désagréable ; remplacé par des notes qui montent avec la pile (`tools/asset_pipeline/make_pickup_sounds.py`).
- **Après l'explosion, la souche n'a plus de collision** (demandé le 2026-11-07).
- **Tous les arbres sont coupables** (plus d'arbres de décor), demandé le 2026-11-07.
- Les arbres sont découpés hors-ligne (Blender) en souche + tronc ; les normales d'origine sont conservées (sinon anneau/traînées visibles à la jonction).

## Questions ouvertes (à poser à l'utilisateur)

1. Dépôt : garder E, ou décharger automatiquement en approchant (`STOCKPILE_AUTO_DEPOSIT`) ?
2. Créer `main` à partir de la branche actuelle et travailler ensuite par branches de fonctionnalité + PR ?

## Problèmes connus / dette

- Le son n'a jamais été écouté (pas de carte son dans l'environnement cloud) → à valider par l'utilisateur.
- Le stock du camp n'est pas sauvegardé (remis à zéro à chaque lancement).
- Performances non mesurées (rendu logiciel llvmpipe ici).
- Ligne de pointillés d'1 pixel possible à la coupe souche/tronc sous certains angles.
- En marche arrière, les épaules peuvent remonter dans le champ de vision.
- Animation de locomotion : pas de strafe dédié (marche avant utilisée), léger glissement des pieds.

## Historique

| Date | Commit | Résumé |
|---|---|---|
| 2026-10-28 | `a7e0993` | MVP découpe de bois + joueur FPS minimal |
| 2026-11-04 | `449d680` | Chute physique du tronc (abandonnée ensuite) |
| 2026-11-05 | `f613912` | L'arbre explose en rondins à 0 PV |
| 2026-11-06 | `9771656` | Arbres découpés : normales d'origine conservées (anneau / traînées corrigés) |
| 2026-11-06 | `2a289bf` | Ajout de `PROGRESS.md`, `CLAUDE.md`, `docs/SPECIFICATIONS.md`, tests dans `tests/`, scripts de téléchargement d'assets |
| 2026-11-07 | `4d82171` | Tous les arbres sont coupables : 2 espèces de plus découpées, 32 arbres de décor remplacés |
| 2026-11-07 | `5d6faaa` | Souche sans collision après l'explosion en bûches |
| 2026-11-07 | `5f4d16a` | Effet d'impact refait : éclats d'écorce discrets, à l'opposé du coup |
| 2026-11-07 | `29cf561` | Forêt dense façon Warcraft 3 (504 arbres, clairière de terre battue), générateur de niveau |
| 2026-11-07 | `9ac9724` | `git pull` réparé : scènes, imports et `project.godot` au format de l'éditeur, `.gitattributes`, outil `tools/resave_with_editor.sh` |
| 2026-11-07 | `c7de86d` | Rochers solides, buissons qui froissent, orc avec oreilles pointues et défenses, soleil corrigé |
| 2026-11-07 | `0f0b5da` | Ramassage des bûches (E) avec animation en body awareness, pile sur l'épaule gauche (§3.2) |
| 2026-11-08 | `656bf58` | Ramassage de la main droite : hache rangée à la ceinture, main gauche qui ne lâche jamais la pile |
| 2026-11-11 | `4dbd985` | Poignet corrigé pendant le ramassage (max 58° au lieu de ~100°), hache en travers de la ceinture, test `wrist_test` |
| 2026-11-11 | `e38bee7` | Ramassage « ninja » : la bûche disparaît en fumée et apparaît sur la pile (animation de ramassage retirée) |
| 2026-11-11 | `572fac3` | Dépôt au camp (§3.3) : zone de stockage, E pour décharger, rondins qui volent jusqu'à la pile, stock global, HUD, test `deposit_test` |
| 2026-11-11 | `8ce15bc` | Son de ramassage refait : notes douces qui montent la gamme avec la pile (le « poof » est retiré) |
