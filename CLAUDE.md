# PAWN — Instructions pour Claude

Jeu FPS « péon orc » dans un RTS, **Godot 4.7.2** (Forward+, Jolt). Cahier des charges : `docs/SPECIFICATIONS.md` (rédigé par l'utilisateur ; il prime, sauf décision contraire notée dans `PROGRESS.md`).

## À faire à chaque session

1. **Lire `PROGRESS.md` en premier** : état, décisions déjà prises, questions ouvertes.
2. **Mettre à jour `PROGRESS.md`** à chaque étape terminée ou décision prise (sections « Où on en est », « Fait », « Décisions », « Questions ouvertes », « Historique » avec le hash du commit), et le committer avec le travail.

## Façon de travailler avec l'utilisateur

- Échanges **en français**. L'utilisateur avance **étape par étape** : ne faire que l'étape demandée, poser les questions quand un choix lui revient.
- Il teste sous **Windows** en téléchargeant le ZIP de la branche :
  `https://github.com/DisColow/claude-pawn/archive/refs/heads/<branche>.zip` (dans un dossier neuf, pas par-dessus l'ancien).
- Branche actuelle : `feature/decoupe-bois`. Pousser après chaque étape validée par des tests.

## Code

- Valeurs d'équilibrage **uniquement** dans `scripts/core/game_config.gd` (constantes, commentées en français).
- Commentaires et docstrings en français, style `##` de GDScript. Typage statique partout (les avertissements GDScript doivent rester à zéro).
- Couches physiques : 1 world, 2 player, 3 trees (valeur 4), 4 logs (valeur 8).
- Éléments de la vue subjective : passer par `ZClip.apply()`.
- Les scènes sont écrites à la main en `.tscn` : vérifier qu'elles se chargent (test `load_all`).

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
- `play_test.gd` — scénario en jeu avec captures : `chop`, `look`, `tp`.
- `tree_test.gd` — un arbre isolé frappé 4 fois.
- `move_test.gd` — vitesses de marche/sprint, endurance, saut.
- `preview.gd` — aperçu de modèles/scènes.

Écrire les captures dans le scratchpad et **les regarder** (Read) avant de conclure. Ne jamais affirmer qu'un son est bon : il ne peut pas être écouté ici.

## Assets

- Sources et licences : `CREDITS.md`. Scripts de transformation : `tools/asset_pipeline/` (README).
- Les packs sources ne sont pas versionnés ; les retélécharger avec `tools/asset_pipeline/fetch/` (Kenney : `kenney.sh <slug> <dossier>` ; itch.io : `node itchpw.js <url> <dossier> [nom]`, nécessite Playwright) ou `gdown` (pip) pour les dossiers Google Drive de Quaternius.
