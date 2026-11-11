# Génère scenes/world/test_forest.tscn : le camp orc (bastion, emplacements du plan du Général) dans une
# clairière de terre battue, la route des squelettes au nord, la mine d'or à l'est, le tout entouré d'une forêt dense
# façon Warcraft 3 (sapins serrés aux couronnes jointives, quelques feuillus).
# usage : python3 tools/level_gen/gen_test_forest.py   (depuis la racine du projet)
# La scène est ensuite réenregistrée par l'éditeur Godot (tools/resave_with_editor.sh), sinon
# l'éditeur de l'utilisateur la réécrit à l'ouverture et ses `git pull` partent en conflit.
import math, random, shutil, subprocess

random.seed(7)
OUT = "scenes/world/test_forest.tscn"

SPACING = 2.6          # pas moyen de la grille d'arbres (m)
JITTER = 0.7           # décalage aléatoire autour de la grille (m)
FOREST_RADIUS = 42.0   # au-delà, le brouillard prend le relais
CLEARING = 17.0        # rayon moyen de la clairière (arbres exclus)
DIRT_SIZE = 38.0       # taille du décalque de terre battue
PLAYER_SPAWN = (0.0, 8.0)
BASTION = (0.0, -6.0, 0.0)     # bastion : x, z, lacet (rad) ; sa cour (dépôt de bois et d'or) est devant, vers le joueur
# Plan de construction du Général, dans l'ordre : (nom de l'emplacement, x, z, lacet).
BUILD_SLOTS = [
    ("lumber_mill_1", -12.5, 3.0, math.pi / 2),
    ("tower_1", 6.5, -13.5, 0.0),
    ("barracks_1", 12.0, 8.0, -math.pi / 2),
    ("tower_2", -6.5, -13.5, 0.0),
]
ROAD = (-3.5, 3.5, -43.0, -15.0)   # route du nord par où arrivent les squelettes : x min, x max, z min, z max
ENEMY_SPAWNS = [(-1.5, -38.0), (1.5, -38.0)]
MINE = (31.0, 2.0, 0.0)            # mine d'or à l'est : x, z, lacet
MINE_CLEARING = 8.0                # rayon dégagé autour de la mine
MINE_PATH = (15.0, 26.0, -1.5, 5.5)  # sentier entre la clairière et la mine

# (scène, poids, échelle min, échelle max) — majorité de sapins comme dans Lordaeron.
SPECIES = [
    ("tree_4_c", 85, 0.7, 0.95),
    ("tree_2_e", 5, 0.85, 1.1),
    ("tree_2_c", 4, 0.9, 1.2),
    ("tree_3_b", 3, 0.9, 1.1),
    ("tree_1_b", 3, 0.9, 1.1),
]
# Rochers solides et buissons qui froissent : scènes du projet ; herbe : modèles bruts (sans collision).
PROPS = {
    "Rock_1_A": "res://scenes/props/rock_1_a.tscn",
    "Rock_2_B": "res://scenes/props/rock_2_b.tscn",
    "Rock_3_C": "res://scenes/props/rock_3_c.tscn",
    "Bush_1_A": "res://scenes/props/bush_1_a.tscn",
    "Bush_2_B": "res://scenes/props/bush_2_b.tscn",
    "Grass_1_A": "res://assets/models/nature/Grass_1_A_Color1.gltf",
    "Grass_2_B": "res://assets/models/nature/Grass_2_B_Color1.gltf",
}


def clearing_edge(angle: float) -> float:
    return CLEARING + 0.9 * math.sin(3 * angle + 1.0) + 0.6 * math.sin(7 * angle + 2.0)


def in_clearing(x: float, z: float, margin: float = 0.0) -> bool:
    return math.hypot(x, z) < clearing_edge(math.atan2(z, x)) + margin


def in_rect(x: float, z: float, rect, margin: float = 0.0) -> bool:
    return rect[0] - margin < x < rect[1] + margin and rect[2] - margin < z < rect[3] + margin


def is_open(x: float, z: float, margin: float = 0.0) -> bool:
    """Zones sans arbres ni décor : clairière, route des ennemis, sentier et clairière de la mine."""
    return (in_clearing(x, z, margin) or in_rect(x, z, ROAD, margin) or in_rect(x, z, MINE_PATH, margin)
            or math.hypot(x - MINE[0], z - MINE[1]) < MINE_CLEARING + margin)


def tf(x, z, yaw, s=1.0, y=0.0):
    c, sn = math.cos(yaw) * s, math.sin(yaw) * s
    # Transform3D s'écrit ligne par ligne dans un .tscn (rotation autour de Y, échelle s).
    return "Transform3D(%.4f, 0, %.4f, 0, %.4f, 0, %.4f, 0, %.4f, %.3f, %.3f, %.3f)" % (c, sn, s, -sn, c, x, y, z)


# --- Arbres sur une grille perturbée ------------------------------------------------------
trees = []
n = int(FOREST_RADIUS / SPACING) + 1
for i in range(-n, n + 1):
    for j in range(-n, n + 1):
        x = i * SPACING + (j % 2) * SPACING * 0.5 + random.uniform(-JITTER, JITTER)
        z = j * SPACING * 0.87 + random.uniform(-JITTER, JITTER)
        r = math.hypot(x, z)
        if r > FOREST_RADIUS + random.uniform(-2, 2) or is_open(x, z):
            continue
        name, _, smin, smax = random.choices(SPECIES, weights=[s[1] for s in SPECIES])[0]
        trees.append((name, x, z, random.uniform(0, math.tau), random.uniform(smin, smax)))

# Tree01 = un arbre de lisière au nord-ouest de la clairière (utilisé par tests/play_test.gd).
trees.sort(key=lambda t: math.hypot(t[1] + CLEARING * 0.71, t[2] + CLEARING * 0.71))

ext = [("PackedScene", "res://scenes/player/player.tscn", "player"),
       ("PackedScene", "res://scenes/ui/hud.tscn", "hud"),
       ("PackedScene", "res://scenes/camp/bastion.tscn", "bastion"),
       ("PackedScene", "res://scenes/world/gold_mine.tscn", "mine"),
       ("Script", "res://scripts/ai/general.gd", "general"),
       ("Script", "res://scripts/core/game_director.gd", "director"),
       ("Script", "res://scripts/debug/camp_debug_keys.gd", "debug_keys"),
       ("Texture2D", "res://assets/textures/dirt_clearing.png", "dirt")]
ext += [("PackedScene", "res://scenes/trees/%s.tscn" % s[0], s[0]) for s in SPECIES]
ext += [("PackedScene", path, key) for key, path in PROPS.items()]
ids = {key: "%d_%s" % (k + 1, key) for k, (_, _, key) in enumerate(ext)}

out = ["[gd_scene load_steps=%d format=3]\n" % (len(ext) + 10)]
out += ['[ext_resource type="%s" path="%s" id="%s"]' % (t, p, ids[key]) for t, p, key in ext]
# Soleil haut (70°) dans le dos du point d'apparition : clairière ensoleillée, ombre du joueur devant lui.
out.append('''
[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]
sky_top_color = Color(0.36, 0.55, 0.82, 1)
sky_horizon_color = Color(0.72, 0.8, 0.86, 1)
ground_bottom_color = Color(0.22, 0.27, 0.2, 1)
ground_horizon_color = Color(0.72, 0.8, 0.86, 1)
sun_angle_max = 20.0

[sub_resource type="Sky" id="Sky_res"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Env"]
background_mode = 2
sky = SubResource("Sky_res")
ambient_light_source = 3
ambient_light_sky_contribution = 0.85
tonemap_mode = 3
ssao_enabled = true
ssao_intensity = 1.6
glow_enabled = true
glow_intensity = 0.35
fog_enabled = true
fog_light_color = Color(0.62, 0.72, 0.7, 1)
fog_density = 0.008
fog_sky_affect = 0.2

[sub_resource type="Gradient" id="Grad_grass"]
offsets = PackedFloat32Array(0, 0.5, 1)
colors = PackedColorArray(0.22, 0.42, 0.12, 1, 0.3, 0.52, 0.15, 1, 0.4, 0.6, 0.2, 1)

[sub_resource type="FastNoiseLite" id="Noise_grass"]
frequency = 0.02

[sub_resource type="NoiseTexture2D" id="NoiseTex_grass"]
width = 256
height = 256
seamless = true
color_ramp = SubResource("Grad_grass")
noise = SubResource("Noise_grass")

[sub_resource type="StandardMaterial3D" id="Mat_ground"]
albedo_texture = SubResource("NoiseTex_grass")
roughness = 0.95
uv1_scale = Vector3(30, 30, 30)

[sub_resource type="PlaneMesh" id="Plane_ground"]
material = SubResource("Mat_ground")
size = Vector2(200, 200)

[sub_resource type="BoxShape3D" id="Box_ground"]
size = Vector3(200, 2, 200)

[node name="TestForest" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.940, -0.321, 0.117, 0.000, 0.342, 0.940, -0.342, -0.883, 0.321, 0, 20, 0)
light_color = Color(1, 0.95, 0.86, 1)
light_energy = 1.25
shadow_enabled = true
directional_shadow_max_distance = 60.0

[node name="Ground" type="StaticBody3D" parent="."]
collision_layer = 1
collision_mask = 0

[node name="Mesh" type="MeshInstance3D" parent="Ground"]
mesh = SubResource("Plane_ground")

[node name="Collision" type="CollisionShape3D" parent="Ground"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -1, 0)
shape = SubResource("Box_ground")

[node name="DirtClearing" type="Decal" parent="."]
size = Vector3(%.1f, 2, %.1f)
texture_albedo = ExtResource("%s")
upper_fade = 0.2
lower_fade = 0.2

[node name="DirtRoad" type="Decal" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.1f, 0, %.1f)
size = Vector3(%.1f, 2, %.1f)
texture_albedo = ExtResource("%s")
upper_fade = 0.2
lower_fade = 0.2

[node name="DirtMine" type="Decal" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.1f, 0, %.1f)
size = Vector3(%.1f, 2, %.1f)
texture_albedo = ExtResource("%s")
upper_fade = 0.2
lower_fade = 0.2

[node name="DirtMinePath" type="Decal" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.1f, 0, %.1f)
size = Vector3(%.1f, 2, %.1f)
texture_albedo = ExtResource("%s")
upper_fade = 0.2
lower_fade = 0.2

[node name="Player" parent="." instance=ExtResource("%s")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.1f, 0, %.1f)

[node name="HUD" parent="." instance=ExtResource("%s")]

[node name="Bastion" parent="." instance=ExtResource("%s")]
transform = %s

[node name="GoldMine" parent="." instance=ExtResource("%s")]
transform = %s

[node name="BuildSlots" type="Node3D" parent="."]
%s
[node name="EnemySpawns" type="Node3D" parent="."]
%s
[node name="General" type="Node" parent="."]
script = ExtResource("%s")

[node name="GameDirector" type="Node" parent="."]
script = ExtResource("%s")

[node name="CampDebugKeys" type="Node" parent="."]
script = ExtResource("%s")

[node name="Trees" type="Node3D" parent="."]
''' % (DIRT_SIZE, DIRT_SIZE, ids["dirt"],
       (ROAD[0] + ROAD[1]) / 2, (ROAD[2] + ROAD[3]) / 2 + 2, ROAD[1] - ROAD[0] + 5, ROAD[3] - ROAD[2] + 10, ids["dirt"],
       MINE[0], MINE[1], MINE_CLEARING * 2.6, MINE_CLEARING * 2.6, ids["dirt"],
       (MINE_PATH[0] + MINE_PATH[1]) / 2, (MINE_PATH[2] + MINE_PATH[3]) / 2, MINE_PATH[1] - MINE_PATH[0] + 12, MINE_PATH[3] - MINE_PATH[2] + 5, ids["dirt"],
       ids["player"], PLAYER_SPAWN[0], PLAYER_SPAWN[1], ids["hud"], ids["bastion"], tf(*BASTION), ids["mine"], tf(*MINE),
       "".join('\n[node name="%s" type="Marker3D" parent="BuildSlots"]\ntransform = %s\n' % (n, tf(x, z, yaw)) for n, x, z, yaw in BUILD_SLOTS),
       "".join('\n[node name="Spawn%d" type="Marker3D" parent="EnemySpawns" groups=["enemy_spawns"]]\ntransform = %s\n' % (k + 1, tf(x, z, math.pi)) for k, (x, z) in enumerate(ENEMY_SPAWNS)),
       ids["general"], ids["director"], ids["debug_keys"]))

for k, (name, x, z, yaw, s) in enumerate(trees):
    out.append('[node name="Tree%03d" parent="Trees" instance=ExtResource("%s")]\ntransform = %s\n' % (k + 1, ids[name], tf(x, z, yaw, s)))

# --- Rochers (solides), buissons (froissent) et herbe -----------------------------------
out.append('[node name="Scenery" type="Node3D" parent="."]\n')
count = 0


def scatter(kind, n, rmin, rmax, smin, smax, near_edge=False):
    global count
    placed = 0
    while placed < n:
        a = random.uniform(0, math.tau)
        r = clearing_edge(a) + random.uniform(-0.5, 2.5) if near_edge else random.uniform(rmin, rmax)
        x, z = math.cos(a) * r, math.sin(a) * r
        if is_open(x, z, -1.0) or any(math.hypot(x - sx, z - sz) < 6.0 for _, sx, sz, _ in BUILD_SLOTS):
            continue
        count += 1; placed += 1
        out.append('[node name="%s%03d" parent="Scenery" instance=ExtResource("%s")]\ntransform = %s\n'
                   % (kind.replace("_", ""), count, ids[kind], tf(x, z, random.uniform(0, math.tau), random.uniform(smin, smax))))


scatter("Rock_1_A", 3, 0, 0, 0.6, 1.1, near_edge=True)
scatter("Rock_2_B", 4, 19, 38, 0.6, 1.0)
scatter("Rock_3_C", 3, 19, 38, 0.5, 0.9)
scatter("Bush_1_A", 8, 0, 0, 0.8, 1.3, near_edge=True)
scatter("Bush_2_B", 12, 19, 38, 0.8, 1.3)
scatter("Grass_1_A", 45, 0, 0, 0.8, 1.4, near_edge=True)
scatter("Grass_2_B", 60, 18, 38, 0.8, 1.4)

open(OUT, "w").write("\n".join(out))
print("%d arbres, %d éléments de décor -> %s" % (len(trees), count, OUT))
if shutil.which("godot") and shutil.which("xvfb-run"):
    subprocess.run(["tools/resave_with_editor.sh"], check=True)
else:
    print("ATTENTION : lancer tools/resave_with_editor.sh avant de committer.")
