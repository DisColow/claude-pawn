#!/bin/bash
# Fait passer le vrai éditeur Godot sur le projet : réimport (détection 3D des textures),
# réécriture de project.godot et réenregistrement de toutes les scènes au format de l'éditeur.
# À lancer avant chaque commit qui touche des scènes ou des assets : sinon l'éditeur de
# l'utilisateur modifie ces fichiers à l'ouverture et ses `git pull` suivants partent en conflit.
# Nécessite Xvfb (voir CLAUDE.md). Usage : tools/resave_with_editor.sh  (depuis n'importe où)
set -euo pipefail
cd "$(dirname "$0")/.."

PLUGIN='res://addons/pawn_resave/plugin.cfg'
toggle_plugin() {  # $1 = on|off : active le plugin le temps du passage, sans le laisser dans le dépôt
	python3 - "$1" "$PLUGIN" <<'PY'
import re, sys
state, plugin = sys.argv[1], sys.argv[2]
text = open("project.godot").read()
text = re.sub(r'\n\[editor_plugins\]\n\nenabled=PackedStringArray\([^)]*\)\n', '\n', text)
if state == "on":
    text = text.rstrip("\n") + '\n\n[editor_plugins]\n\nenabled=PackedStringArray("%s")\n' % plugin
open("project.godot", "w").write(text)
PY
}
toggle_plugin on
trap 'toggle_plugin off' EXIT
godot --headless --import --path . >/dev/null 2>&1 || true
timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot -e --path . 2>&1 | grep -E '^\[resave\]' || true
