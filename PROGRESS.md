# PAWN — Suivi de progression

> Fichier de reprise : l'état du projet, les décisions prises et la suite. Cahier des charges : `docs/SPECIFICATIONS.md`.
> **À tenir à jour à chaque étape terminée** (voir `CLAUDE.md`). Dernière mise à jour : 2026-11-11.

## Où on en est

- **Branche de travail** : `feature/decoupe-bois` (seule branche du dépôt `DisColow/claude-pawn` ; `main` n'existe pas encore — décision en attente, voir plus bas).
- **Fait** : §3.1 découpe de bois (validée par l'utilisateur) et §3.2 ramassage/portage des bûches (à valider en jeu par l'utilisateur).
- **Prochaine étape probable** : §3.3 dépôt au camp (zone de stockage, E pour décharger, stock global, pile du camp qui grandit).

## Fait

| Domaine | Contenu | Fichiers clés |
|---|---|---|
| Config | Toutes les valeurs d'équilibrage / game feel (autoload `GameConfig`) | `scripts/core/game_config.gd` |
| Arbre | 100 PV, 4 coups (25 dmg), petits éclats d'écorce éjectés à l'opposé du mouvement de la hache (direction transmise par `AxeController`), oscillation élastique (ressort amorti), son d'impact aléatoire, hit-stop. À 0 PV : **le tronc explose en 4 rondins** projetés à l'opposé du joueur + poussière/feuilles + fracas + secousse. La souche reste, **sans collision** (traversable). Charnière et collisions déduites des meshes. | `scripts/trees/choppable_tree.gd`, `scenes/trees/*.tscn` |
| Rondins | `WoodLog` (RigidBody3D, couche 4 « logs »), son au choc, groupe `wood_logs`. | `scripts/props/wood_log.gd`, `scenes/props/wood_log.tscn` |
| VFX | `WoodChipsVFX` (7 éclats d'écorce discrets), `DustImpactVFX` (GPUParticles3D one-shot, base `OneShotVFX`) | `scripts/vfx/`, `scenes/vfx/` |
| Joueur | Orc avec **oreilles pointues et défenses** (`OrcHeadParts`, modèles CC-BY greffés sur l'os Head ; visibles dans l'ombre, la tête étant masquée en vue subjective). CharacterBody3D : marche 5,2 / sprint 8,2 + endurance, saut, pas. Corps d'orc complet animé (AnimationTree : idle/walk/jog/sprint/jump + poing fermé), tête/cou masqués, **squelette d'ombre** (ombre complète), corps reculé quand on regarde en bas / court. Bras droit en **IK** (TwoBoneIK3D) tenant la hache ; coup **procédural** en espace caméra (élan, arc, hit-stop, retour), raycast d'impact. Camera shake par trauma. Z-clip (`z_clip_scale 0.1`) sur bras/hache/corps. `get_carry_speed_multiplier()` déjà câblé (-35 % à 10 rondins). | `scripts/player/*.gd`, `scenes/player/player.tscn` |
| Ramassage / portage | `LogCarrier` (enfant du joueur) : viser une bûche (rayon caméra, 2,3 m) → « [E] Ramasser ». Séquence de 2 s : la main droite **range la hache à la ceinture** (hanche droite, attache sur l'os pelvis), pas vers la bûche, accroupissement (`Crouch_Idle`), regard attiré vers elle, **la main droite empoigne la bûche** et la hisse en travers du corps jusqu'à l'épaule gauche (elle rapetisse jusqu'à sa taille « portée »), puis **reprend la hache** et revient en garde. **La main gauche (2e `TwoBoneIK3D`) tient la pile pendant toute la séquence** ; pour la 1re bûche, elle monte l'accueillir. Pile sur l'épaule gauche (4+4+2, bûches à 50 %), z-clip + copie d'ombre, main gauche qui la tient. Immobile et sans coup de hache pendant le ramassage ; hache utilisable ensuite. Capacité 10, « Charge pleine », pénalité -35 %. | `scripts/player/log_carrier.gd`, `first_person_body.gd` |
| HUD | Réticule, jauge d'endurance, invite de ramassage, compteur « Bois : n / 10 » | `scenes/ui/hud.tscn` |
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
- **Poignet réaliste** (2026-11-11, l'utilisateur avait vu un angle impossible) : hache glissée **à l'horizontale en travers de la ceinture** (manche à la hanche droite) ; l'orientation de la main droite pendant le ramassage est calculée à partir de l'avant-bras réel (poing tourné vers la bûche, torsion limitée à 60°). Contrôle automatique : `tests/wrist_test.gd` (angle avant-bras/main ≤ ~60° dans toutes les phases).
- **Après l'explosion, la souche n'a plus de collision** (demandé le 2026-11-07).
- **Tous les arbres sont coupables** (plus d'arbres de décor), demandé le 2026-11-07.
- Les arbres sont découpés hors-ligne (Blender) en souche + tronc ; les normales d'origine sont conservées (sinon anneau/traînées visibles à la jonction).

## Questions ouvertes (à poser à l'utilisateur)

1. Créer `main` à partir de la branche actuelle et travailler ensuite par branches de fonctionnalité + PR ?

## Problèmes connus / dette

- Le son n'a jamais été écouté (pas de carte son dans l'environnement cloud) → à valider par l'utilisateur.
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
