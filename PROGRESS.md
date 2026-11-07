# PAWN — Suivi de progression

> Fichier de reprise : l'état du projet, les décisions prises et la suite. Cahier des charges : `docs/SPECIFICATIONS.md`.
> **À tenir à jour à chaque étape terminée** (voir `CLAUDE.md`). Dernière mise à jour : 2026-11-07.

## Où on en est

- **Branche de travail** : `feature/decoupe-bois` (seule branche du dépôt `DisColow/claude-pawn` ; `main` n'existe pas encore — décision en attente, voir plus bas).
- **Étape en cours** : MVP « découpe de bois » (§3.1 de la spec) **terminée et validée par l'utilisateur** en jeu (il teste sous Windows via le ZIP de la branche).
- **Prochaine étape probable** : §3.2 portage des rondins sur l'épaule (ramassage, pile sur l'épaule gauche 1→10, coupe continue, pénalité de vitesse).

## Fait

| Domaine | Contenu | Fichiers clés |
|---|---|---|
| Config | Toutes les valeurs d'équilibrage / game feel (autoload `GameConfig`) | `scripts/core/game_config.gd` |
| Arbre | 100 PV, 4 coups (25 dmg), éclats + sciure, oscillation élastique (ressort amorti), son d'impact aléatoire, hit-stop. À 0 PV : **le tronc explose en 4 rondins** projetés à l'opposé du joueur + poussière/feuilles + fracas + secousse. La souche reste, **sans collision** (traversable). Charnière et collisions déduites des meshes. | `scripts/trees/choppable_tree.gd`, `scenes/trees/*.tscn` |
| Rondins | `WoodLog` (RigidBody3D, couche 4 « logs »), son au choc, groupe `wood_logs`. Pas encore ramassables. | `scripts/props/wood_log.gd`, `scenes/props/wood_log.tscn` |
| VFX | `WoodChipsVFX`, `DustImpactVFX` (GPUParticles3D one-shot, base `OneShotVFX`) | `scripts/vfx/`, `scenes/vfx/` |
| Joueur | CharacterBody3D : marche 5,2 / sprint 8,2 + endurance, saut, pas. Corps d'orc complet animé (AnimationTree : idle/walk/jog/sprint/jump + poing fermé), tête/cou masqués, **squelette d'ombre** (ombre complète), corps reculé quand on regarde en bas / court. Bras droit en **IK** (TwoBoneIK3D) tenant la hache ; coup **procédural** en espace caméra (élan, arc, hit-stop, retour), raycast d'impact. Camera shake par trauma. Z-clip (`z_clip_scale 0.1`) sur bras/hache/corps. `get_carry_speed_multiplier()` déjà câblé (-35 % à 10 rondins). | `scripts/player/*.gd`, `scenes/player/player.tscn` |
| HUD | Réticule + jauge d'endurance | `scenes/ui/hud.tscn` |
| Monde | Clairière de test : **44 arbres, tous coupables** (5 espèces KayKit : `tree_1_b`, `tree_2_c`, `tree_3_b`, `tree_2_e`, `tree_4_c`, échelle 1 à 1,4) + rochers, buissons, herbe (décor sans collision) | `scenes/world/test_forest.tscn` |
| Assets | KayKit, Quaternius, Kenney, OpenGameArt (CC0 sauf `tree_crash.ogg` CC-BY 3.0) | `CREDITS.md`, `tools/asset_pipeline/` |

## Décisions prises (ne pas re-discuter sans l'utilisateur)

- **Godot 4.7.2**, Forward+, Jolt Physics. Cible Windows.
- **Assets** : CC0 de préférence (Sketchfab écarté : CC-BY). Style low-poly KayKit/Quaternius.
- **Plus de chute d'arbre** : l'utilisateur a essayé la chute scriptée puis la chute physique (le penchant naturel l'emportait sur la direction du coup) et a choisi **l'explosion en rondins à 0 PV**.
- **Vue FPS « true first person »** : vrai corps animé + IK pour le bras, plutôt qu'un viewmodel séparé.
- Touches **physiques** (ZQSD sur AZERTY = WASD).
- **Après l'explosion, la souche n'a plus de collision** (demandé le 2026-11-07).
- **Tous les arbres sont coupables** (plus d'arbres de décor), demandé le 2026-11-07.
- Les arbres sont découpés hors-ligne (Blender) en souche + tronc ; les normales d'origine sont conservées (sinon anneau/traînées visibles à la jonction).

## Questions ouvertes (à poser à l'utilisateur)

1. Créer `main` à partir de la branche actuelle et travailler ensuite par branches de fonctionnalité + PR ?
2. Rochers (15) et buissons (20) : **sans collision** aujourd'hui (on les traverse). Les rendre solides ?
3. Ramassage des rondins : automatique en marchant dessus, ou touche `E` ?
4. Style de l'orc (base humaine recolorée, sans crocs/oreilles) : OK ?

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
| 2026-11-07 | (ce commit) | Souche sans collision après l'explosion en bûches |
