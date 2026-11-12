# PAWN — Suivi de progression

> Fichier de reprise : l'état du projet, les décisions prises et la suite. Cahier des charges : `docs/PAWN_Specification_1.pdf` (référence), `docs/SPECIFICATIONS.md` (ancien extrait bois, amendé).
> **À tenir à jour à chaque étape terminée** (voir `CLAUDE.md`). Dernière mise à jour : 2026-11-11.

## Où on en est

- **Branche de travail** : `feature/decoupe-bois` (seule branche du dépôt `DisColow/claude-pawn`).
- **Référence** : `docs/PAWN_Specification_1.pdf`, fourni le 2026-11-12. L'utilisateur a validé le plan de réalignement, confirmé Godot, puis demandé de **tout faire d'une traite** (« je vois ensuite »).
- **Fait le 2026-11-12** : les cinq tranches du plan, en une première version jouable de bout en bout (menu → partie → Renom). Les tests automatiques passent ; **l'utilisateur n'a encore rien joué de cette version**.
- **Ses remarques du 2026-11-12, intégrées** : chantiers en fantôme vert jusqu'au premier coup, marteau, dépôt direct dans le bâtiment, autres unités de l'IA, mine « toute buguée » (cause trouvée : voir Mine).
- **Prochaine étape** : ses retours après essai. Les manques connus sont listés dans « Écarts restants avec le PDF ».

## Fait

| Domaine | Contenu | Fichiers clés |
|---|---|---|
| Données | Tout l'équilibrage et tout le contenu : bâtiments, unités, apparences par camp, héros, triangle des types, Général, ordres / loyauté / confiance, influence, XP, talents, Renom, améliorations, campagne, cartes. | `scripts/core/game_config.gd` |
| Péon (§4) | Vue subjective avec corps complet (IK, ombre, z-clip), marche / sprint / saut / endurance, roulade (à débloquer), vie, régénération, mort. Statistiques = base + talents + améliorations permanentes (`max_health()`, `wood_capacity()`, `swing_speed()`…). Manette et souris. | `scripts/player/player.gd`, `first_person_body.gd`, `axe_controller.gd` |
| Bois (§5.2) | Arbre : 4 coups, éclats, oscillation, hit-stop, puis **explosion en 4 rondins** (décision de l'utilisateur, à la place de la chute physique). Ramassage « ninja » en fumée, pile sur l'épaule gauche, hache toujours active. | `scripts/trees/choppable_tree.gd`, `scripts/player/log_carrier.gd` |
| Or (§5.1) | `GoldMine` : galerie où l'on entre (salle 11 × 13 m étayée de poutres, lanternes, éboulis), huit `GoldVein` ; la pioche sort toute seule dedans ; 1 or par coup, étincelles ; veines qui s'épuisent et se reconstituent ; sac à dos visible. **Les montagnes entourent la coque sans la recouper** (leurs blocs imbriqués remplissaient la salle : c'était le bug). | `scripts/world/gold_mine.gd`, `gold_vein.gd` |
| Portage (§4.4) | Bois OU or. Dépôt avec E **contre** l'hôtel de ville ou un entrepôt, de n'importe quel côté ; les rondins volent dans le bâtiment. À la mort, la charge tombe au sol (bûches, `GoldSack`) et se ramasse. | `scripts/player/log_carrier.gd` |
| Bâtiments (§10.2) | `CampBuilding` générique : 12 bâtiments en données (Loge de guerre → Bastion → Forteresse, Terrier, Caserne, Forge, Tour de guet, Entrepôt, Loge de chasse, Enclos des bêtes, Hutte des esprits, Autel des ancêtres, Aire céleste, Atelier), rouges pour nous, bleus pour l'ennemi. **Fantôme vert intangible** tant que personne n'a frappé, puis étapes sous échafaudage, ruines, reconstruction. Nourriture, tour qui tire, paliers. | `scripts/camp/camp_building.gd`, `scenes/camp/building.tscn` |
| Construction | Maintenir E devant un chantier ou un bâtiment abîmé : le **marteau** sort, le travail commence au premier coup porté, étincelles. Talents : vitesse, Renforcé, Architecte (F), Barricade (B). | `scripts/player/log_carrier.gd`, `assets/models/props/hammer.glb` |
| Unités (§10.3-10.5) | `Unit` générique : péon du Général (récolte, chantier, milice), Cogneur, Tirailleur, Chevaucheur, Mastodonte, Mande-tempête, Parle-sang (soigne), Pillard céleste et Saboteur (volants), Démolisseur (siège), 4 héros à niveaux. Triangle mêlée > distance > volant > mêlée. Ordres GUARD / ASSAULT, trajets par `NavGraph`. Orcs = modèle du péon teinté et armé ; ennemis = squelettes KayKit (faction de remplacement). | `scripts/units/unit.gd`, `scripts/core/nav_graph.gd` |
| Général (§6, §10) | Un par camp : péons, plan de construction, paliers, forge, composition d'armée, héros (recrute, renvoie se soigner), colonise une mine, défend, sonne l'appel aux armes, lance et rappelle les assauts. **Erreurs volontaires** du catalogue §6.3 (8 erreurs), plus ou moins fréquentes selon la difficulté. | `scripts/ai/general.gd` |
| Ordres, loyauté, confiance (§6.2-6.6) | Jusqu'à 3 ordres (récolter, bâtir, coloniser, réparer, défendre, attaquer), jamais obligatoires ; faisceau lumineux et ping sur la minimap. Loyauté : à 0, escouade d'exécuteurs, sursis si on se rachète. Confiance : exploits et bons conseils. | `scripts/ai/worker_orders.gd` |
| Influence (§7) | Roue de communication (Q) : 8 suggestions, acceptation selon confiance + justesse + hasard, délai entre deux, XP si acceptée, bonus si elle corrigeait une vraie erreur. | `scripts/ui/comm_wheel.gd`, `scripts/ai/worker_orders.gd`, `General.evaluate()` |
| Talents (§8) | XP (dépôts, chantier, ennemis tués, ordres, conseils), 30 niveaux, 3 arbres × 5 paliers (21 talents), redistribution avec délai, remise à zéro à la mort. | `scripts/progress/worker_progress.gd`, `scripts/ui/talent_screen.gd` |
| Renom (§9) | Calculé en fin de partie (victoire, dépôts du joueur, ennemis tués, bons conseils, survie), dépensé au menu en 11 améliorations permanentes ; sauvegarde `user://pawn_save.json` (Renom, améliorations, campagne, options, touches). | `scripts/progress/meta_progress.gd` |
| Partie (§10.8) | `GameDirector` : victoire = loge ennemie détruite, défaite = la nôtre ; réapparition = nouveau péon payé par le Général après le combat ; écran de fin avec détail du Renom. | `scripts/core/game_director.gd` |
| Modes (§2) | Menu : Partie libre (2 cartes, 3 difficultés), Campagne « L'Ascension » (3 missions à dialogues, débloquées en chaîne), Progression, Options (sensibilité, volume, touches). | `scripts/ui/main_menu.gd` |
| HUD (§4.7) | Réticule, panneau d'ordres, message du Général (avec signal sonore), minimap (mines, bases, unités, pings), loyauté et confiance, vie et endurance, charge, niveau et XP, stock et nourriture du camp. | `scripts/ui/hud.gd`, `minimap.gd`, `ui_kit.gd` |
| Cartes (§10.7) | « La Vallée » et « Le Carrefour » : deux bases, 16 emplacements chacune, mine principale, deux mines à coloniser, route, graphe de chemins, ~1600 arbres coupables. | `tools/level_gen/gen_maps.py`, `scenes/world/map_*.tscn` |
| Décor, VFX, assets | Rochers solides, buissons qui froissent ; éclats, poussière, fumée, étincelles, traits de tir. Packs KayKit, Quaternius, Kenney, OpenGameArt. | `scripts/props/`, `scripts/vfx/`, `CREDITS.md` |

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
- **Son de ramassage gratifiant** (2026-11-11) : le « poof » de bruit filtré était désagréable ; remplacé d'abord par des notes de marimba synthétisées (rejetées aussi : « pas du tout »), puis par un **choc bûche contre bûche** tiré de vrais enregistrements. Ne plus proposer de son synthétisé ou musical.
- **Le dépôt de bois est un bâtiment** (2026-11-11, demandé par l'utilisateur, référence : bastion / scierie de Warcraft 3) : constructible par le Général, destructible par les ennemis, avec points de vie. Choix de Claude à confirmer : scierie plutôt que bastion, modèle KayKit Medieval Hexagon rouge, construction automatique dans le temps (le péon ne construit pas encore), stock conservé à la destruction, clairière agrandie (rayon 11 m).
- **Remarques du 2026-11-12** : chantier en fantôme vert jusqu'au premier coup ; construction au marteau ; dépôt directement dans le bâtiment, de tous les côtés ; il faut d'autres unités de l'IA ; la mine était buguée.
- **Camp ennemi = squelettes** (faction de remplacement prévue par le PDF, §19), mêmes bâtiments en bleu.
- **« Développe tout le jeu »** (2026-11-11, remplacé depuis par le PDF) : l'utilisateur a laissé carte blanche. Choix de Claude, tous à confirmer : ennemis = squelettes (pack KayKit animé, CC0) ; défense par vagues plutôt que camp ennemi à détruire ; le péon construit en maintenant E ; le Général suit un plan fixe ; l'or se mine en maintenant E (pas de pioche) ; grunts = modèle du péon avec hache ; pas de sauvegarde.
- **Après l'explosion, la souche n'a plus de collision** (demandé le 2026-11-07).
- **Tous les arbres sont coupables** (plus d'arbres de décor), demandé le 2026-11-07.
- Les arbres sont découpés hors-ligne (Blender) en souche + tronc ; les normales d'origine sont conservées (sinon anneau/traînées visibles à la jonction).

## Questions ouvertes (à poser à l'utilisateur)

1. Chute physique de l'arbre et bois dans les deux bras (PDF) ou explosion en rondins et épaule (ses décisions précédentes) ?
2. Équilibrage : une partie IA contre IA dure ~20 min ; le rythme lui convient-il ?
3. Musique et sons : il a rejeté deux sons synthétisés ; il faut des fichiers ou des références de sa part.
4. Créer `main` et passer aux branches de fonctionnalité + PR ?

## Écarts restants avec le PDF (à dire franchement à l'utilisateur)

Par décision de l'utilisateur : **Godot** au lieu d'Unity ; **explosion en rondins** au lieu de la chute physique (§5.2, critère §20.1) ; **bois sur l'épaule, hache active** au lieu des deux bras et outils rangés (§4.4). Les deux derniers n'ont pas été re-tranchés depuis le PDF.

Simplifié :
- Héros : niveaux et soins, mais pas de capacités actives ; le Maître des bêtes n'invoque rien.
- Volants : mêmes modèles que les unités à pied, en lévitation (pas de monture ailée).
- Orcs : toutes les unités partagent le modèle du péon (teinte, taille, arme) ; attaque à distance jouée avec l'animation d'épée.
- Ordres : pas d'ordre « éclaireur » ni « transporter une pile ».
- « Construire X » de la roue : propose le prochain bâtiment utile, sans choix dans une liste.
- Unités : contournement d'obstacle au jugé + graphe de routes, pas de vraie recherche de chemin.
- Péons de l'IA : récolte abstraite (ils n'abattent pas d'arbre et n'entrent pas dans la mine).

Absent : magie du joueur (§4.6), vol de monture, ragdolls (§12.3), **musique** et sons dédiés (§13.2 : tout réutilise les sons de bois existants), voix, unité de transport, cinématiques.

Non vérifiable ici : 60 images/s sur PC (§20.5), tout ce qui est sonore, la manette (commandes déclarées, jamais essayées).

## Problèmes connus / dette

- Le son n'a jamais été écouté (pas de carte son dans l'environnement cloud) → à valider par l'utilisateur.
- Unités sans vraie recherche de chemin (elles longent les obstacles au jugé) : peuvent se coincer contre les arbres si elles poursuivent le joueur en forêt.
- Les sons de combat, de tour et de chantier réutilisent les sons de bois existants.
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
| 2026-11-11 | `3fc2410` | Son de ramassage : choc de bois (bûche contre bûche) à la place des notes de marimba |
| 2026-11-11 | `6d4fe0d` | Scierie : le dépôt devient un bâtiment à points de vie, constructible et destructible (`CampBuilding`, `LumberMill`), test `building_test` |
| 2026-11-11 | `4303cbb` | Boucle de jeu complète : or, bastion, Général, construction par le péon, squelettes, grunts, tours, vie du joueur, victoire / défaite, test `game_test` |
| 2026-11-12 | `8771da5` | Ajout du cahier des charges complet (`docs/PAWN_Specification_1.pdf`) et relevé des écarts |
| 2026-11-12 | `b7cba73` | Tranche 1 du réalignement : mine dans laquelle on entre, veines à la pioche, sac à dos, bois et or exclusifs, charge lâchée à la mort, test `mine_test` |
| 2026-11-12 | `a41beb2` | Réalignement complet sur le PDF : deux camps et leurs Généraux, 12 bâtiments, 14 unités, ordres / loyauté / confiance, roue d'influence, talents, Renom sauvegardé, menu et campagne, minimap ; chantier fantôme, marteau, dépôt direct, mine refaite |
