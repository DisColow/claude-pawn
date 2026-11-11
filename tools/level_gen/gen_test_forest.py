# Génère scenes/world/test_forest.tscn : une clairière de terre battue entourée d'une forêt dense
# façon Warcraft 3 (sapins serrés aux couronnes jointives, quelques feuillus).
# usage : python3 tools/level_gen/gen_test_forest.py   (depuis la racine du projet)
# La scène est ensuite réenregistrée par l'éditeur Godot (tools/resave_with_editor.sh), sinon
# l'éditeur de l'utilisateur la réécrit à l'ouverture et ses `git pull` partent en conflit.
import math, random, shutil, subprocess

random.seed(7)
OUT = "scenes/world/test_forest.tscn"

SPACING = 2.6          # pas moyen de la grille d'arbres (m)
JITTER = 0.7           # décalage aléatoire autour de la grille (m)
FOREST_RADIUS = 32.0   # au-delà, le brouillard prend le relais
CLEARING = 8.5         # rayon moyen de la clairière (arbres exclus)
DIRT_SIZE = 19.0       # taille du décalque de terre battue
STOCKPILE = (4.6, -1.5, 1.05)  # dépôt de bois du camp dans la clairière : x, z, lacet (rad)

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
        if r > FOREST_RADIUS + random.uniform(-2, 2) or in_clearing(x, z):
            continue
        name, _, smin, smax = random.choices(SPECIES, weights=[s[1] for s in SPECIES])[0]
        trees.append((name, x, z, random.uniform(0, math.tau), random.uniform(smin, smax)))

# Tree01 = l'arbre de lisière face au point d'apparition (utilisé par tests/play_test.gd).
trees.sort(key=lambda t: math.hypot(t[1] - 0.0, t[2] + CLEARING))

ext = [("PackedScene", "res://scenes/player/player.tscn", "player"),
       ("PackedScene", "res://scenes/ui/hud.tscn", "hud"),
       ("PackedScene", "res://scenes/camp/wood_stockpile.tscn", "stockpile"),
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

[node name="Player" parent="." instance=ExtResource("%s")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 3)

[node name="HUD" parent="." instance=ExtResource("%s")]

[node name="WoodStockpile" parent="." instance=ExtResource("%s")]
transform = %s

[node name="Trees" type="Node3D" parent="."]
''' % (DIRT_SIZE, DIRT_SIZE, ids["dirt"], ids["player"], ids["hud"], ids["stockpile"], tf(*STOCKPILE)))

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
        if in_clearing(x, z, -1.0):
            continue
        count += 1; placed += 1
        out.append('[node name="%s%03d" parent="Scenery" instance=ExtResource("%s")]\ntransform = %s\n'
                   % (kind.replace("_", ""), count, ids[kind], tf(x, z, random.uniform(0, math.tau), random.uniform(smin, smax))))


scatter("Rock_1_A", 3, 0, 0, 0.6, 1.1, near_edge=True)
scatter("Rock_2_B", 3, 10, 28, 0.6, 1.0)
scatter("Rock_3_C", 2, 10, 28, 0.5, 0.9)
scatter("Bush_1_A", 8, 0, 0, 0.8, 1.3, near_edge=True)
scatter("Bush_2_B", 8, 10, 28, 0.8, 1.3)
scatter("Grass_1_A", 45, 0, 0, 0.8, 1.4, near_edge=True)
scatter("Grass_2_B", 45, 9, 28, 0.8, 1.4)

open(OUT, "w").write("\n".join(out))
print("%d arbres, %d éléments de décor -> %s" % (len(trees), count, OUT))
if shutil.which("godot") and shutil.which("xvfb-run"):
    subprocess.run(["tools/resave_with_editor.sh"], check=True)
else:
    print("ATTENTION : lancer tools/resave_with_editor.sh avant de committer.")
