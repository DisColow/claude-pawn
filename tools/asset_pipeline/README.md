# Pipeline d'assets

Scripts utilisés pour produire les fichiers de `assets/` à partir des packs sources (non versionnés).
Testés avec Blender 5.2 et Python 3 + Pillow/NumPy/soundfile.

| Script | Rôle | Exemple |
|---|---|---|
| `split_tree.py` | Coupe un arbre KayKit en **souche** + **tronc** à une hauteur donnée, bouche la coupe avec la texture de cernes, place l'origine du tronc sur la charnière de chute. | `blender -b -P split_tree.py -- Tree_2_C_Color1.gltf assets/models/trees tree_2_c 0.45 1.1 assets/textures/wood_rings.png` |
| `make_log.py` | Génère le rondin (`wood_log.glb`) : écorce de l'atlas KayKit + cernes aux extrémités. | `blender -b -P make_log.py -- forest_texture.png wood_rings.png assets/models/props/wood_log.glb` |
| `orc_recolor.py` | Recolore la texture du personnage de base Quaternius (peau verte orc, short en cuir). | `python3 orc_recolor.py T_Superhero_Male_Dark.png T_Orc_BaseColor.png` |
| `build_orc.py` | Assemble `orc_worker.glb` : personnage Quaternius + textures orc + animations de la Universal Animation Library (même squelette). | `blender -b -P build_orc.py -- Superhero_Male_FullBody.gltf UAL1_Standard.glb <dossier_textures> assets/models/characters/orc_worker.glb` |
| `fbx2glb.py` | Convertit un FBX Quaternius en GLB (matériaux opaques, mise à l'échelle). | `blender -b -P fbx2glb.py -- Axe.fbx assets/models/props/axe.glb 0.24` |

La texture `assets/textures/wood_rings.png` est générée procéduralement (Pillow).
Les sons d'arbre (`tree_creak.ogg`, `tree_crash.ogg`, `tree_fall_thud.ogg`) sont des extraits découpés des fichiers OpenGameArt listés dans `CREDITS.md`.
