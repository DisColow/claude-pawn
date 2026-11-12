# PAWN — Instructions pour Claude

Jeu FPS « péon orc » dans un RTS, **Godot 4.7.2** (Forward+, Jolt). Cahier des charges complet : **`docs/PAWN_Specification_1.pdf`** (38 pages, en anglais, fourni par l'utilisateur le 2026-11-12 : c'est la référence, il faut le suivre). `docs/SPECIFICATIONS.md` est l'ancien extrait sur la coupe de bois, avec des amendements de l'utilisateur. Les écarts décidés par l'utilisateur sont notés dans `PROGRESS.md`.

## À faire à chaque session

1. **Lire `PROGRESS.md` en premier** : état, décisions déjà prises, questions ouvertes.
2. **Mettre à jour `PROGRESS.md`** à chaque étape terminée ou décision prise (sections « Où on en est », « Fait », « Décisions », « Questions ouvertes », « Historique » avec le hash du commit), et le committer avec le travail.

## Façon de travailler avec l'utilisateur

- Échanges **en français**. L'utilisateur avance **étape par étape** : ne faire que l'étape demandée, poser les questions quand un choix lui revient.
- Il teste sous **Windows** en téléchargeant le ZIP de la branche :
  `https://github.com/DisColow/claude-pawn/archive/refs/heads/<branche>.zip` (dans un dossier neuf, pas par-dessus l'ancien).
- Remarques de l'utilisateur à respecter (2026-11-12) : chantier en **fantôme vert** intangible jusqu'au premier coup ; on construit **au marteau** ; on dépose **directement dans le bâtiment**, de n'importe quel côté (pas de zone devant).
- Branche actuelle : `feature/decoupe-bois`. Pousser après chaque étape validée par des tests.

## Code

- Valeurs d'équilibrage **uniquement** dans `scripts/core/game_config.gd` (constantes, commentées en français).
- Commentaires et docstrings en français, style `##` de GDScript. Typage statique partout (les avertissements GDScript doivent rester à zéro).
- Autoloads à état (ex. `CampEconomy`) : y accéder par `Classe.instance`, jamais par le nom de l'autoload (introuvable à la compilation des tests lancés avec `-s`).
- Couches physiques : 1 world, 2 player, 3 trees (valeur 4), 4 logs (valeur 8), 5 units (valeur 16 : unités des deux camps).
- Éléments de la vue subjective : passer par `ZClip.apply()`.
- **Avant chaque commit qui touche des scènes, des assets ou `project.godot` : lancer `tools/resave_with_editor.sh`.**
  Il fait passer le vrai éditeur Godot (réimport, détection 3D des textures, scènes réenregistrées avec
  `uid`/`unique_id`). Sans ça, l'éditeur de l'utilisateur réécrit ces fichiers à l'ouverture et ses
  `git pull` suivants partent en conflit (problème rencontré le 2026-11-07). Le script est idempotent.
- Scènes écrites ou modifiées par script : vérifier qu'elles se chargent (test `load_all`), puis outil ci-dessus.
- Les cartes (`scenes/world/map_*.tscn`) se régénèrent avec `tools/level_gen/gen_maps.py` (qui lance l'outil tout seul) ; ne pas les éditer à la main.
- Bâtiments, unités, talents, améliorations, Général : tout est décrit par les dictionnaires de `GameConfig` ; une scène générique par famille (`scenes/camp/building.tscn`, `scenes/units/unit.tscn`), `kind` et `team` réglés avant `add_child`.
- Ne jamais envelopper un volume où l'on entre avec les montagnes KayKit : ce sont des blocs imbriqués dont les faces internes remplissent l'intérieur (bug de la mine du 2026-11-12).

## Environnement cloud (à réinstaller dans un conteneur neuf)

```bash
# Godot 4.7.2 (GitHub est bloqué par le proxy, utiliser le miroir officiel)
mkdir -p /opt/godot && cd /opt/godot && curl -sSL -o g.zip "https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=linux.x86_64.zip&platform=linux.64" && unzip -q g.zip && ln -sf /opt/godot/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
# Rendu headless (captures d'écran) + Blender (pipeline d'assets)
apt-get install -y xvfb mesa-vulkan-drivers libvulkan1 libgl1 libegl1 libxkbcommon0 libsm6 libxi6 libxrender1 libxxf86vm1 libxfixes3
mkdir -p /opt/blender && cd /opt/blender && curl -sS -o b.tar.xz https://download.blender.org/release/Blender5.2/blender-5.2.3-linux-x64.tar.xz && tar xf b.tar.xz && ln -sf /opt/blender/blender-5.2.3-linux-x64/blender /usr/local/bin/blender
```

Puis, dans le projet : `godot --headless --import` (ré-import ; nécessaire aussi après ajout d'un `class_name`).

## Vérifier son travail (pas de carte son ni de GPU : Vulkan llvmpipe sous Xvfb)

Scripts dans `tests/` (en-tête de chaque fichier = usage) :
- `load_all.gd` — charge toutes les scènes (headless, sans Xvfb).
- `play_test.gd` — scénario sur la carte avec captures : `chop`, `look`, `tp`.
- `tree_test.gd` — un arbre isolé frappé 4 fois.
- `move_test.gd` — vitesses de marche/sprint, endurance, saut.
- `pickup_test.gd` — ramassage des bûches (E) : disparition en fumée, pile 1→10, ralentissement, charge pleine.
- `mine_test.gd` — mine d'or : entrer, pioche en main, 1 or par coup jusqu'à 10, veine qui s'épuise, bois et or exclusifs, charge lâchée à la mort puis ramassée, sac à dos.
- `building_test.gd` — bâtiment : fantôme vert jusqu'au premier coup, étapes, points de vie, réparation, ruines, tour qui tire, palier de l'hôtel de ville, dépôt des quatre côtés.
- `match_test.gd` — partie jouée par script sur « La Vallée » : chantier au marteau, dépôt, ordres et loyauté, roue et confiance, talents, traître, appel aux armes, mort et nouveau péon, victoire et Renom. Long (~4 min).
- `sim_test.gd` — **sans rendu** (headless) : les deux Généraux jouent seuls en accéléré, état des camps toutes les 30 s. À lancer après tout changement d'équilibrage ou d'IA.
- `props_test.gd` — rocher bloquant, buisson traversable qui froisse.
- `preview.gd` — aperçu de modèles/scènes.

Écrire les captures dans le scratchpad et **les regarder** (Read) avant de conclure. Ne jamais affirmer qu'un son est bon : il ne peut pas être écouté ici.

> Dans les tests, la souris n'est pas capturée : déclencher les coups avec `player.axe.request_swing()`, pas avec l'action `attack`.

## Assets

- Sources et licences : `CREDITS.md`. Scripts de transformation : `tools/asset_pipeline/` (README).
- Les packs sources ne sont pas versionnés ; les retélécharger avec `tools/asset_pipeline/fetch/` (Kenney : `kenney.sh <slug> <dossier>` ; itch.io : `node itchpw.js <url> <dossier> [nom]`, nécessite Playwright) ou `gdown` (pip) pour les dossiers Google Drive de Quaternius.
