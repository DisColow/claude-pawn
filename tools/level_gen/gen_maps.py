# Génère les cartes de partie (scenes/world/map_<nom>.tscn) : deux camps face à face (§10.7 du
# cahier des charges). Chaque camp a son hôtel de ville, ses emplacements de construction, sa mine
# d'or et ses points de coupe ; une route relie les deux bases, et deux mines à coloniser la bordent.
# Forêt dense façon Warcraft 3 autour des bases et des mines, prairie ouverte ailleurs.
# usage : python3 tools/level_gen/gen_maps.py   (depuis la racine du projet)
# Les scènes sont ensuite réenregistrées par l'éditeur Godot (tools/resave_with_editor.sh), sinon
# l'éditeur de l'utilisateur les réécrit à l'ouverture et ses `git pull` partent en conflit.
import math, random, shutil, subprocess

SPACING = 3.0          # pas moyen de la grille d'arbres (m)
JITTER = 0.8           # décalage aléatoire autour de la grille (m)
BASE_RADIUS = 33.0     # rayon de la clairière d'une base
BASE_FOREST = 47.0     # la forêt d'une base s'étend jusqu'à ce rayon
MINE_CLEARING = 16.0   # rayon dégagé autour d'une mine
MINE_FOREST = 27.0     # la forêt d'une mine à coloniser s'étend jusqu'à ce rayon
ROAD_HALF = 5.0        # demi-largeur des routes et sentiers
MINE_MOUTH = 13.5      # distance du centre d'une mine à la sortie de sa galerie

# Emplacements de construction d'une base, dans l'ordre du plan du Général (voir
# GameConfig.GENERAL_BUILD_ORDER), puis emplacements de réserve. Repère de la base :
# x = à droite, f = vers l'ennemi. La mine est à droite (x > 0), le dépôt et le joueur côté f < 0.
SLOTS = [(-13, 8), (13, 9), (-15, -5), (-6, 20), (15, -8), (-23, 11), (-25, -5), (22, 15), (-11, -17),
         (11, -18), (-20, 21), (20, -19), (6, 22), (-27, -16), (27, -13), (-3, -27)]
MINE_LOCAL = (58.0, 0.0)                    # mine principale, dans le repère de la base
WOOD_LOCAL = [(-30.0, -4.0), (-26.0, -19.0), (-27.0, 14.0)]  # points de coupe des péons du Général
RALLY_LOCAL = (0.0, 24.0)
SPAWN_LOCAL = (0.0, -18.0)

# (scène, poids, échelle min, échelle max) — majorité de sapins comme dans Lordaeron.
SPECIES = [("tree_4_c", 85, 0.7, 0.95), ("tree_2_e", 5, 0.85, 1.1), ("tree_2_c", 4, 0.9, 1.2),
           ("tree_3_b", 3, 0.9, 1.1), ("tree_1_b", 3, 0.9, 1.1)]
PROPS = {
    "Rock_1_A": "res://scenes/props/rock_1_a.tscn", "Rock_2_B": "res://scenes/props/rock_2_b.tscn",
    "Rock_3_C": "res://scenes/props/rock_3_c.tscn", "Bush_1_A": "res://scenes/props/bush_1_a.tscn",
    "Bush_2_B": "res://scenes/props/bush_2_b.tscn", "Grass_1_A": "res://assets/models/nature/Grass_1_A_Color1.gltf",
    "Grass_2_B": "res://assets/models/nature/Grass_2_B_Color1.gltf",
}

# Cartes : bases (centre, direction vers l'ennemi), route entre les bases (ligne brisée), mines à
# coloniser (centre, point de la route où part leur sentier).
MAPS = {
    "valley": {"seed": 7, "bases": [((0.0, 0.0), (0.0, -1.0)), ((0.0, -200.0), (0.0, 1.0))],
               "road": [(0.0, -24.0), (0.0, -100.0), (0.0, -176.0)],
               "expansions": [((-66.0, -100.0), (0.0, -100.0)), ((66.0, -100.0), (0.0, -100.0))]},
    "crossing": {"seed": 19, "bases": [((0.0, 0.0), (0.0, -1.0)), ((150.0, -150.0), (-1.0, 0.0))],
                 "road": [(0.0, -24.0), (0.0, -150.0), (126.0, -150.0)],
                 "expansions": [((-62.0, -85.0), (0.0, -85.0)), ((75.0, -88.0), (75.0, -150.0))]},
}


def tf(x, z, yaw, s=1.0, y=0.0):
    c, sn = math.cos(yaw) * s, math.sin(yaw) * s
    # Transform3D s'écrit ligne par ligne dans un .tscn (rotation autour de Y, échelle s).
    return "Transform3D(%.4f, 0, %.4f, 0, %.4f, 0, %.4f, 0, %.4f, %.3f, %.3f, %.3f)" % (c, sn, s, -sn, c, x, y, z)


def facing(dx, dz):
    """Lacet qui tourne le +Z local (façade des bâtiments, entrée des mines) vers (dx, dz)."""
    return math.atan2(dx, dz)


def seg_dist(p, a, b):
    """Distance du point p au segment [a, b]."""
    ax, az, bx, bz = a[0], a[1], b[0], b[1]
    length2 = (bx - ax) ** 2 + (bz - az) ** 2
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((p[0] - ax) * (bx - ax) + (p[1] - az) * (bz - az)) / length2))
    return math.hypot(p[0] - ax - t * (bx - ax), p[1] - az - t * (bz - az))


def generate(name, spec):
    random.seed(spec["seed"])
    out_path = "scenes/world/map_%s.tscn" % name
    bases = spec["bases"]

    def world(base, x, f):
        (cx, cz), (fx, fz) = bases[base]
        # droite = direction vers l'ennemi tournée de -90° (pour (0, -1) : (1, 0)).
        return (cx + x * -fz + f * fx, cz + x * fx + f * fz)

    mines = [world(b, *MINE_LOCAL) for b in range(2)]
    expansions = [e[0] for e in spec["expansions"]]
    # Segments dégagés : route, sentiers des mines principales et des mines à coloniser.
    paths = list(zip(spec["road"], spec["road"][1:]))
    paths += [(bases[b][0], mines[b]) for b in range(2)]
    paths += [(junction, center) for center, junction in spec["expansions"]]

    def is_open(x, z, margin=0.0):
        """Zones sans arbres : clairières des bases et des mines, routes et sentiers."""
        if any(math.hypot(x - c[0], z - c[1]) < BASE_RADIUS + 1.5 * math.sin(3 * math.atan2(z - c[1], x - c[0])) + margin for c, _ in bases):
            return True
        if any(math.hypot(x - m[0], z - m[1]) < MINE_CLEARING + margin for m in mines + expansions):
            return True
        return any(seg_dist((x, z), a, b) < ROAD_HALF + margin for a, b in paths)

    def forested(x, z):
        """La forêt entoure les bases et les mines ; ailleurs, prairie avec quelques bosquets."""
        if any(math.hypot(x - c[0], z - c[1]) < BASE_FOREST + random.uniform(-2, 2) for c, _ in bases):
            return True
        if any(math.hypot(x - m[0], z - m[1]) < MINE_FOREST + random.uniform(-2, 2) for m in mines + expansions):
            return True
        # Lisières clairsemées le long des routes.
        return any(seg_dist((x, z), a, b) < ROAD_HALF + 14 for a, b in paths) and random.random() < 0.22

    xs = [c[0] for c, _ in bases] + [m[0] for m in mines + expansions]
    zs = [c[1] for c, _ in bases] + [m[1] for m in mines + expansions]
    min_x, max_x, min_z, max_z = min(xs) - 60, max(xs) + 60, min(zs) - 60, max(zs) + 60
    center = ((min_x + max_x) / 2, (min_z + max_z) / 2)
    ground = max(max_x - min_x, max_z - min_z) + 160

    # --- Arbres sur une grille perturbée -------------------------------------------------
    trees = []
    for i in range(int((max_x - min_x) / SPACING) + 1):
        for j in range(int((max_z - min_z) / (SPACING * 0.87)) + 1):
            x = min_x + i * SPACING + (j % 2) * SPACING * 0.5 + random.uniform(-JITTER, JITTER)
            z = min_z + j * SPACING * 0.87 + random.uniform(-JITTER, JITTER)
            if is_open(x, z) or not forested(x, z):
                continue
            species = random.choices(SPECIES, weights=[s[1] for s in SPECIES])[0]
            trees.append((species[0], x, z, random.uniform(0, math.tau), random.uniform(species[2], species[3])))
    # Tree001 = un arbre de lisière à l'ouest de la base du joueur (utilisé par tests/play_test.gd).
    west = world(0, -BASE_RADIUS, 0.0)
    trees.sort(key=lambda t: math.hypot(t[1] - west[0], t[2] - west[1]))

    ext = [("PackedScene", "res://scenes/player/player.tscn", "player"), ("PackedScene", "res://scenes/ui/hud.tscn", "hud"),
           ("PackedScene", "res://scenes/camp/building.tscn", "building"), ("PackedScene", "res://scenes/world/gold_mine.tscn", "mine"),
           ("Script", "res://scripts/ai/general.gd", "general"), ("Script", "res://scripts/core/game_director.gd", "director"),
           ("Script", "res://scripts/core/nav_graph.gd", "nav"), ("Script", "res://scripts/debug/camp_debug_keys.gd", "debug_keys"),
           ("Texture2D", "res://assets/textures/dirt_clearing.png", "dirt")]
    ext += [("PackedScene", "res://scenes/trees/%s.tscn" % s[0], s[0]) for s in SPECIES]
    ext += [("PackedScene", path, key) for key, path in PROPS.items()]
    ids = {key: "%d_%s" % (k + 1, key) for k, (_, _, key) in enumerate(ext)}
    out = ["[gd_scene format=3]\n"]
    out += ['[ext_resource type="%s" path="%s" id="%s"]' % (t, p, ids[key]) for t, p, key in ext]
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
fog_density = 0.004
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
uv1_scale = Vector3(%d, %d, %d)

[sub_resource type="PlaneMesh" id="Plane_ground"]
material = SubResource("Mat_ground")
size = Vector2(%d, %d)

[sub_resource type="BoxShape3D" id="Box_ground"]
size = Vector3(%d, 2, %d)

[node name="Map" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.940, -0.321, 0.117, 0.000, 0.342, 0.940, -0.342, -0.883, 0.321, 0, 20, 0)
light_color = Color(1, 0.95, 0.86, 1)
light_energy = 1.25
shadow_enabled = true
directional_shadow_max_distance = 70.0

[node name="Ground" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.1f, 0, %.1f)
collision_layer = 1
collision_mask = 0

[node name="Mesh" type="MeshInstance3D" parent="Ground"]
mesh = SubResource("Plane_ground")

[node name="Collision" type="CollisionShape3D" parent="Ground"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -1, 0)
shape = SubResource("Box_ground")
''' % (ground / 7, ground / 7, ground / 7, ground, ground, ground, ground, center[0], center[1]))

    # --- Terre battue : bases, mines, routes ----------------------------------------------
    def decal(label, x, z, size):
        out.append('[node name="%s" type="Decal" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.1f, 0, %.1f)\n'
                   'size = Vector3(%.1f, 2, %.1f)\ntexture_albedo = ExtResource("%s")\nupper_fade = 0.2\nlower_fade = 0.2\n'
                   % (label, x, z, size, size, ids["dirt"]))

    for b, (c, _) in enumerate(bases):
        decal("DirtBase%d" % b, c[0], c[1], BASE_RADIUS * 2.3)
    for k, m in enumerate(mines + expansions):
        decal("DirtMine%d" % k, m[0], m[1], MINE_CLEARING * 2.7)
    count = 0
    for a, b in paths:
        steps = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 9))
        for s in range(steps + 1):
            count += 1
            decal("DirtRoad%03d" % count, a[0] + (b[0] - a[0]) * s / steps, a[1] + (b[1] - a[1]) * s / steps, ROAD_HALF * 3.4)

    # --- Jeu : directeur (avant les Généraux), graphe de chemins, joueur, HUD ----------------
    nav_points = [world(0, *RALLY_LOCAL)] + spec["road"] + [world(1, *RALLY_LOCAL)]
    nav_edges = [(k, k + 1) for k in range(len(nav_points) - 1)]
    mouths = []
    for b in range(2):
        c = bases[b][0]
        d = math.hypot(c[0] - mines[b][0], c[1] - mines[b][1])
        mouths.append((mines[b][0] + (c[0] - mines[b][0]) / d * MINE_MOUTH, mines[b][1] + (c[1] - mines[b][1]) / d * MINE_MOUTH))
    exp_markers = []
    for center_e, junction in spec["expansions"]:
        d = math.hypot(junction[0] - center_e[0], junction[1] - center_e[1])
        ux, uz = (junction[0] - center_e[0]) / d, (junction[1] - center_e[1]) / d
        mouth = (center_e[0] + ux * MINE_MOUTH, center_e[1] + uz * MINE_MOUTH)
        # Entrepôt de colonisation : sur le sentier, à 14 m de l'entrée, décalé sur le côté.
        slot = (mouth[0] + ux * 9 - uz * 7, mouth[1] + uz * 9 + ux * 7)
        exp_markers.append((slot, mouth, (ux, uz)))
        # Le sentier rejoint la route au point de jonction : nouveau nœud relié au nœud de route le plus proche.
        nav_points.append(junction)
        j_index = len(nav_points) - 1
        nearest = min(range(len(spec["road"]) + 2), key=lambda k: math.hypot(nav_points[k][0] - junction[0], nav_points[k][1] - junction[1]))
        nav_edges.append((nearest, j_index))
        nav_points.append(mouth)
        nav_edges.append((j_index, len(nav_points) - 1))
    spawn = world(0, *SPAWN_LOCAL)
    f0 = bases[0][1]
    out.append('''[node name="GameDirector" type="Node" parent="."]
script = ExtResource("%s")

[node name="NavGraph" type="Node" parent="."]
script = ExtResource("%s")
points = PackedVector3Array(%s)
edges = PackedInt32Array(%s)

[node name="Player" parent="." instance=ExtResource("%s")]
transform = %s

[node name="HUD" parent="." instance=ExtResource("%s")]
''' % (ids["director"], ids["nav"], ", ".join("%.1f, 0, %.1f" % p for p in nav_points),
       ", ".join("%d, %d" % e for e in nav_edges), ids["player"], tf(spawn[0], spawn[1], facing(-f0[0], -f0[1])), ids["hud"]))

    # --- Camps : hôtel de ville, emplacements, points de récolte, ralliement, mine ---------------
    for b in range(2):
        (cx, cz), (fx, fz) = bases[b]
        out.append('[node name="WarLodge%d" parent="." instance=ExtResource("%s")]\ntransform = %s\nkind = "war_lodge"\nteam = %d\n'
                   % (b, ids["building"], tf(cx, cz, facing(-fx, -fz)), b))
        out.append('[node name="Slots%d" type="Node3D" parent="."]\n' % b)
        for k, (x, f) in enumerate(SLOTS):
            wx, wz = world(b, x, f)
            out.append('[node name="Slot%02d" type="Marker3D" parent="Slots%d"]\ntransform = %s\n' % (k + 1, b, tf(wx, wz, facing(cx - wx, cz - wz))))
        out.append('[node name="MinePoint%d" type="Marker3D" parent="." groups=["mine_point_%d"]]\ntransform = %s\n' % (b, b, tf(mouths[b][0], mouths[b][1], 0.0)))
        for k, (x, f) in enumerate(WOOD_LOCAL):
            wx, wz = world(b, x, f)
            out.append('[node name="WoodPoint%d_%d" type="Marker3D" parent="." groups=["wood_point_%d"]]\ntransform = %s\n' % (b, k + 1, b, tf(wx, wz, 0.0)))
        rx, rz = world(b, *RALLY_LOCAL)
        out.append('[node name="Rally%d" type="Marker3D" parent="." groups=["rally_%d"]]\ntransform = %s\n' % (b, b, tf(rx, rz, 0.0)))
        out.append('[node name="GoldMine%d" parent="." instance=ExtResource("%s")]\ntransform = %s\n'
                   % (b, ids["mine"], tf(mines[b][0], mines[b][1], facing(cx - mines[b][0], cz - mines[b][1]))))
    for k, (center_e, _) in enumerate(spec["expansions"]):
        slot, mouth, (ux, uz) = exp_markers[k]
        out.append('[node name="ExpansionMine%d" parent="." instance=ExtResource("%s")]\ntransform = %s\n'
                   % (k + 1, ids["mine"], tf(center_e[0], center_e[1], facing(ux, uz))))
        out.append('[node name="Expansion%d" type="Marker3D" parent="." groups=["expansion_points"]]\ntransform = %s\nmetadata/mine_point = Vector3(%.1f, 0, %.1f)\n'
                   % (k + 1, tf(slot[0], slot[1], facing(mouth[0] - slot[0], mouth[1] - slot[1])), mouth[0], mouth[1]))
    out.append('''[node name="General0" type="Node" parent="."]
script = ExtResource("%s")

[node name="General1" type="Node" parent="."]
script = ExtResource("%s")
team = 1
difficulty = "normal"

[node name="CampDebugKeys" type="Node" parent="."]
script = ExtResource("%s")

[node name="Trees" type="Node3D" parent="."]
''' % (ids["general"], ids["general"], ids["debug_keys"]))
    for k, (species, x, z, yaw, s) in enumerate(trees):
        out.append('[node name="Tree%04d" parent="Trees" instance=ExtResource("%s")]\ntransform = %s\n' % (k + 1, ids[species], tf(x, z, yaw, s)))

    # --- Rochers (solides), buissons (froissent) et herbe ---------------------------------------
    out.append('[node name="Scenery" type="Node3D" parent="."]\n')
    slots_world = [world(b, x, f) for b in range(2) for x, f in SLOTS]
    placed_total = 0
    for kind, amount, smin, smax in [("Rock_1_A", 10, 0.6, 1.1), ("Rock_2_B", 12, 0.6, 1.0), ("Rock_3_C", 10, 0.5, 0.9),
                                     ("Bush_1_A", 30, 0.8, 1.3), ("Bush_2_B", 30, 0.8, 1.3), ("Grass_1_A", 130, 0.8, 1.4), ("Grass_2_B", 130, 0.8, 1.4)]:
        placed = 0
        while placed < amount:
            x, z = random.uniform(min_x, max_x), random.uniform(min_z, max_z)
            # Pas de décor au milieu des clairières et des routes, ni sur un emplacement de construction.
            if is_open(x, z, -1.5) or any(math.hypot(x - sx, z - sz) < 7.0 for sx, sz in slots_world):
                continue
            placed += 1
            placed_total += 1
            out.append('[node name="%s%03d" parent="Scenery" instance=ExtResource("%s")]\ntransform = %s\n'
                       % (kind.replace("_", ""), placed_total, ids[kind], tf(x, z, random.uniform(0, math.tau), random.uniform(smin, smax))))

    open(out_path, "w").write("\n".join(out))
    print("%s : %d arbres, %d éléments de décor -> %s" % (name, len(trees), placed_total, out_path))


for map_name, map_spec in MAPS.items():
    generate(map_name, map_spec)
if shutil.which("godot") and shutil.which("xvfb-run"):
    subprocess.run(["tools/resave_with_editor.sh"], check=True)
else:
    print("ATTENTION : lancer tools/resave_with_editor.sh avant de committer.")
