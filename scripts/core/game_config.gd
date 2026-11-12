extends Node
## Valeurs d'équilibrage centralisées (data-driven).
## Toute valeur de gameplay doit être lue ici plutôt que codée en dur dans les scripts.

# --- Locomotion -------------------------------------------------------------
const WALK_SPEED := 5.2
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 5.0
const GROUND_ACCELERATION := 14.0
const AIR_ACCELERATION := 3.0
const MOUSE_SENSITIVITY := 0.0022
const GAMEPAD_LOOK_SPEED := 2.6         # vitesse de rotation au stick droit (rad/s)

# --- Endurance (sprint) -----------------------------------------------------
const MAX_STAMINA := 100.0
const STAMINA_SPRINT_DRAIN := 22.0      # points / seconde
const STAMINA_REGEN := 16.0             # points / seconde
const STAMINA_REGEN_DELAY := 0.8        # secondes avant régénération
const STAMINA_SPRINT_MIN := 15.0        # endurance minimale pour relancer un sprint

# --- Décor ------------------------------------------------------------------
const BUSH_RUSTLE_INTERVAL := 0.45      # délai minimal entre deux froissements d'un buisson (s)
const BUSH_RUSTLE_MIN_SPEED := 1.0      # vitesse à partir de laquelle on froisse en continu (m/s)
const BUSH_SHAKE_ANGLE := 0.09          # inclinaison du frémissement (rad)

# --- Transport de bois ------------------------------------------------------
const BASE_WOOD_CAPACITY := 10
const MAX_CARRY_SPEED_PENALTY := 0.35
const PICKUP_RANGE := 2.3               # distance max (depuis la caméra) pour ramasser une bûche (m)
# Ramassage « ninja » : la bûche disparaît en fumée et réapparaît sur la pile de l'épaule gauche.
const PICKUP_POP_TIME := 0.18           # apparition (avec rebond) de la bûche sur la pile (s)
const PICKUP_SOUND_VOLUME_DB := -4.0     # volume du choc de bois joué à chaque ramassage (dB)
const PICKUP_SOUND_PITCH := 1.3         # hauteur du choc (1 = son d'origine, plus = plus sec et aigu)
const PICKUP_SOUND_PITCH_PER_LOG := 0.02  # montée de hauteur par bûche déjà portée
const PICKUP_SOUND_PITCH_JITTER := 0.05 # variation aléatoire de hauteur (±)
const CARRIED_LOG_SCALE := 0.5          # taille des bûches portées sur l'épaule (lisibilité de la vue)

# --- Dépôt au camp (directement dans l'hôtel de ville ou un entrepôt) -----------
const DEPOSIT_RANGE := 3.5              # distance max au bord du bâtiment pour y déposer (m), de n'importe quel côté
const DEPOSIT_UNLOAD_INTERVAL := 0.09   # délai entre deux rondins déchargés (s)
const DEPOSIT_FLY_TIME := 0.32          # durée du vol d'un rondin de l'épaule au bâtiment (s)
const DEPOSIT_FLY_ARC := 0.5            # hauteur de la cloche du vol (m)

# --- Or ------------------------------------------------------------------------
const BASE_GOLD_CAPACITY := 10          # or que contient le sac à dos
const GOLD_PER_SWING := 1               # or tiré d'une veine par coup de pioche
const MAX_GOLD_CARRY_SPEED_PENALTY := 0.15  # ralentissement à sac plein
const VEIN_GOLD := 40                   # or d'une veine pleine
const VEIN_REGEN_INTERVAL := 6.0        # secondes pour qu'une veine entamée regagne 1 or

# =============================================================================================
# Couche stratégique (§10 du cahier des charges). Camp 0 = celui du joueur (orcs, rouge),
# camp 1 = l'ennemi (morts-vivants, faction de remplacement, bleu). Mêmes bâtiments et unités des
# deux côtés ; seuls les modèles changent (`UNIT_VISUALS`).
# =============================================================================================

# --- Départ et économie -------------------------------------------------------------------
const START_WOOD := 40
const START_GOLD := 40
const START_PEONS := 4                  # péons contrôlés par le Général au début (en plus du joueur dans le camp 0)
const FOOD_CAP := 60                    # plafond absolu de nourriture
const PEON_TRIP_GOLD := 10               # or rapporté par voyage d'un péon du Général
const PEON_TRIP_WOOD := 10               # bois rapporté par voyage d'un péon du Général
const PEON_WORK_TIME := 6.0             # temps passé à miner / couper avant de repartir (s)
const PEON_BUILD_RATE := 0.6            # vitesse de construction d'un péon du Général (1 = celle du joueur)

# --- Bâtiments ----------------------------------------------------------------------------
# name : nom affiché ; tier : palier d'hôtel de ville requis ; health ; build_time : secondes de
# travail d'un péon ; wood / gold : coût ; food : nourriture fournie ; scale : agrandissement du
# modèle (miniatures KayKit) ; model : modèle (building_<model>_<couleur>.gltf) ;
# dropoff : on peut y déposer bois et or ; trains : unités produites ; tower : tire sur les ennemis.
const BUILDINGS := {
	"war_lodge": {"name": "Loge de guerre", "tier": 1, "health": 2500.0, "build_time": 40.0, "wood": 0, "gold": 0,
		"food": 10, "scale": 3.2, "model": "castle", "dropoff": true, "trains": ["peon"]},
	"burrow": {"name": "Terrier", "tier": 1, "health": 600.0, "build_time": 9.0, "wood": 20, "gold": 0,
		"food": 8, "scale": 4.2, "model": "home_A"},
	"barracks": {"name": "Caserne", "tier": 1, "health": 1200.0, "build_time": 14.0, "wood": 40, "gold": 20,
		"scale": 4.5, "model": "barracks", "trains": ["bruiser"]},
	"forge": {"name": "Forge", "tier": 1, "health": 900.0, "build_time": 12.0, "wood": 40, "gold": 30,
		"scale": 4.5, "model": "blacksmith"},
	"watch_tower": {"name": "Tour de guet", "tier": 2, "health": 700.0, "build_time": 9.0, "wood": 30, "gold": 20,
		"scale": 4.0, "model": "tower_A", "tower": true},
	"stockpile": {"name": "Entrepôt", "tier": 2, "health": 900.0, "build_time": 11.0, "wood": 40, "gold": 0,
		"food": 4, "scale": 4.5, "model": "lumbermill", "dropoff": true},
	"hunt_lodge": {"name": "Loge de chasse", "tier": 2, "health": 1000.0, "build_time": 13.0, "wood": 50, "gold": 30,
		"scale": 4.5, "model": "archeryrange", "trains": ["skirmisher"]},
	"beast_pen": {"name": "Enclos des bêtes", "tier": 2, "health": 1100.0, "build_time": 14.0, "wood": 60, "gold": 50,
		"scale": 4.5, "model": "tavern", "trains": ["outrider", "juggernaut"]},
	"spirit_hut": {"name": "Hutte des esprits", "tier": 2, "health": 800.0, "build_time": 13.0, "wood": 50, "gold": 60,
		"scale": 4.2, "model": "home_B", "trains": ["stormcaller", "bloodspeaker"]},
	"ancestor_shrine": {"name": "Autel des ancêtres", "tier": 2, "health": 1000.0, "build_time": 14.0, "wood": 60, "gold": 60,
		"scale": 4.2, "model": "church"},
	"sky_roost": {"name": "Aire céleste", "tier": 3, "health": 1000.0, "build_time": 14.0, "wood": 70, "gold": 80,
		"scale": 4.2, "model": "windmill", "trains": ["sky_raider", "saboteur"]},
	"workshop": {"name": "Atelier", "tier": 3, "health": 1200.0, "build_time": 14.0, "wood": 80, "gold": 60,
		"scale": 4.2, "model": "tower_catapult", "trains": ["demolisher"]},
}
# Paliers de l'hôtel de ville (index 0 = palier 1) : nom, coût et durée de l'amélioration, vie, nourriture.
const TOWN_HALL_TIERS := [
	{"name": "Loge de guerre", "wood": 0, "gold": 0, "time": 0.0, "health": 2500.0, "food": 10},
	{"name": "Bastion", "wood": 90, "gold": 70, "time": 25.0, "health": 3200.0, "food": 14},
	{"name": "Forteresse", "wood": 140, "gold": 140, "time": 30.0, "health": 4000.0, "food": 18},
]
const BUILDING_START_HEALTH_RATIO := 0.1  # part des points de vie au début du chantier (le reste monte avec la construction)
const BUILD_RANGE := 3.0                # distance max au chantier pour y travailler (m, depuis son bord)
const REPAIR_RATE := 60.0               # points de vie rendus par seconde de réparation (E maintenu)
const LUMBER_MILL_SAW_SPEED := 5.0      # rotation de la scie de l'entrepôt (rad/s)
const SHAKE_BUILDING_COLLAPSE := 0.8    # "trauma" à proximité d'un bâtiment qui s'effondre
const SHAKE_BUILDING_COLLAPSE_RADIUS := 30.0
const DEBUG_BUILDING_DAMAGE := 300.0    # dégâts infligés par la touche de test K

# --- Tour de guet -------------------------------------------------------------
const TOWER_RANGE := 16.0               # portée de tir (m)
const TOWER_DAMAGE := 14.0              # dégâts par flèche
const TOWER_FIRE_INTERVAL := 1.1        # délai entre deux tirs (s)

# --- Forge : améliorations d'armée (2 niveaux chacune) ---------------------------------------
const FORGE_UPGRADE_COST := {"wood": 40, "gold": 50}
const FORGE_UPGRADE_TIME := 20.0
const FORGE_MAX_LEVEL := 2
const FORGE_DAMAGE_BONUS := 0.15        # dégâts en plus par niveau d'armes
const FORGE_ARMOR_BONUS := 0.12         # dégâts subis en moins par niveau d'armures

# --- Unités -------------------------------------------------------------------
# name ; type (worker, melee, ranged, flying, siege, caster, hero) ; health ; speed (m/s) ;
# damage (par coup) ; attack_interval (s) ; attack_range (m) ; aggro (m) ; food ; wood / gold : coût ;
# train_time (s) ; flying : survole le sol, seuls tireurs et lanceurs l'atteignent ;
# heal : soigne ses alliés au lieu d'attaquer (points de vie par incantation).
const UNITS := {
	"peon": {"name": "Péon", "type": "worker", "health": 90.0, "speed": 4.2, "damage": 6.0, "attack_interval": 1.4,
		"attack_range": 1.7, "aggro": 0.0, "food": 1, "wood": 0, "gold": 30, "train_time": 12.0},
	"bruiser": {"name": "Cogneur", "type": "melee", "health": 170.0, "speed": 4.4, "damage": 16.0, "attack_interval": 1.2,
		"attack_range": 1.9, "aggro": 14.0, "food": 2, "wood": 0, "gold": 35, "train_time": 14.0},
	"skirmisher": {"name": "Tirailleur", "type": "ranged", "health": 110.0, "speed": 4.4, "damage": 13.0, "attack_interval": 1.5,
		"attack_range": 11.0, "aggro": 15.0, "food": 2, "wood": 15, "gold": 35, "train_time": 15.0},
	"outrider": {"name": "Chevaucheur", "type": "melee", "health": 140.0, "speed": 6.6, "damage": 14.0, "attack_interval": 1.0,
		"attack_range": 1.9, "aggro": 16.0, "food": 2, "wood": 10, "gold": 45, "train_time": 16.0},
	"juggernaut": {"name": "Mastodonte", "type": "melee", "health": 420.0, "speed": 3.3, "damage": 30.0, "attack_interval": 1.7,
		"attack_range": 2.2, "aggro": 13.0, "food": 4, "wood": 20, "gold": 80, "train_time": 24.0},
	"stormcaller": {"name": "Mande-tempête", "type": "caster", "health": 100.0, "speed": 4.0, "damage": 22.0, "attack_interval": 2.2,
		"attack_range": 12.0, "aggro": 15.0, "food": 3, "wood": 0, "gold": 70, "train_time": 20.0},
	"bloodspeaker": {"name": "Parle-sang", "type": "caster", "health": 100.0, "speed": 4.0, "damage": 6.0, "attack_interval": 2.0,
		"attack_range": 10.0, "aggro": 14.0, "food": 2, "wood": 0, "gold": 60, "train_time": 20.0, "heal": 28.0},
	"sky_raider": {"name": "Pillard céleste", "type": "flying", "health": 150.0, "speed": 6.0, "damage": 18.0, "attack_interval": 1.4,
		"attack_range": 3.0, "aggro": 18.0, "food": 3, "wood": 20, "gold": 70, "train_time": 22.0, "flying": true},
	"saboteur": {"name": "Saboteur", "type": "flying", "health": 120.0, "speed": 6.0, "damage": 12.0, "attack_interval": 1.4,
		"attack_range": 3.0, "aggro": 18.0, "food": 3, "wood": 30, "gold": 60, "train_time": 22.0, "flying": true,
		"building_bonus": 3.0},
	"demolisher": {"name": "Démolisseur", "type": "siege", "health": 260.0, "speed": 2.8, "damage": 20.0, "attack_interval": 2.4,
		"attack_range": 13.0, "aggro": 16.0, "food": 4, "wood": 60, "gold": 60, "train_time": 28.0, "building_bonus": 4.0},
	# Héros (§10.5) : recrutés à l'autel, ils gagnent des niveaux au combat.
	"warlord": {"name": "Seigneur de guerre", "type": "hero", "health": 520.0, "speed": 4.6, "damage": 34.0, "attack_interval": 1.3,
		"attack_range": 2.2, "aggro": 16.0, "food": 5, "wood": 0, "gold": 120, "train_time": 30.0},
	"storm_shaman": {"name": "Chaman des tempêtes", "type": "hero", "health": 380.0, "speed": 4.4, "damage": 30.0, "attack_interval": 1.8,
		"attack_range": 12.0, "aggro": 16.0, "food": 5, "wood": 0, "gold": 120, "train_time": 30.0},
	"beastmaster": {"name": "Maître des bêtes", "type": "hero", "health": 620.0, "speed": 4.4, "damage": 26.0, "attack_interval": 1.4,
		"attack_range": 2.2, "aggro": 16.0, "food": 5, "wood": 0, "gold": 120, "train_time": 30.0},
	"shadowblade": {"name": "Lame d'ombre", "type": "hero", "health": 400.0, "speed": 6.0, "damage": 42.0, "attack_interval": 1.0,
		"attack_range": 2.0, "aggro": 16.0, "food": 5, "wood": 0, "gold": 120, "train_time": 30.0},
}
const HEROES := ["warlord", "storm_shaman", "beastmaster", "shadowblade"]
const HERO_MAX_LEVEL := 5
const HERO_XP_PER_LEVEL := 3            # ennemis tués par niveau
const HERO_LEVEL_BONUS := 0.18          # vie et dégâts en plus par niveau
const HERO_HEAL_THRESHOLD := 0.4        # sous cette part de vie, le Général rappelle le héros à l'autel
const HERO_HEAL_RATE := 30.0            # points de vie par seconde près de l'autel
# Triangle des types (§10.4) : multiplicateur de dégâts de l'attaquant (clé) contre la cible.
const TYPE_BONUS := {
	"melee": {"ranged": 1.5, "caster": 1.5},
	"ranged": {"flying": 1.6},
	"flying": {"melee": 1.5, "siege": 1.5},
	"siege": {},
	"caster": {},
	"hero": {},
	"worker": {},
}
const UNIT_KNOCKBACK := 3.5             # recul d'une unité touchée (m/s)
const UNIT_CORPSE_TIME := 4.0           # durée d'affichage d'un cadavre (s)
const FLY_HEIGHT := 3.2                 # altitude des unités volantes (m)
const MILITIA_DURATION := 30.0          # durée de l'appel aux armes (s)
const MILITIA_DAMAGE_BONUS := 1.6       # dégâts des péons en milice (multiplicateur)
const MILITIA_ARMOR := 0.4              # part des dégâts ignorée en milice

# Apparence des unités par camp. model : scène ; weapon : scène tenue en main ("" = rien) ;
# scale ; tint : teinte du modèle ; anims : [repos, course, attaque, mort ("" = bascule)] ; hit : instant du coup (s).
const ORC_ANIMS := ["Idle", "Jog_Fwd", "Sword_Attack", ""]
const SKEL_MELEE := ["Idle", "Running_A", "1H_Melee_Attack_Chop", "Death_A"]
const SKEL_RANGED := ["Idle", "Running_A", "2H_Ranged_Shoot", "Death_A"]
const SKEL_CAST := ["Idle", "Running_A", "Spellcast_Shoot", "Death_A"]
const ORC_MODEL := "res://assets/models/characters/orc_worker.glb"
const W := "res://assets/models/weapons/"
const E := "res://assets/models/enemies/"
const UNIT_VISUALS := [
	{  # camp 0 : orcs
		"peon": {"model": ORC_MODEL, "weapon": "res://assets/models/props/axe.glb", "scale": 1.0, "tint": Color(1, 1, 1), "anims": ORC_ANIMS, "hit": 0.4},
		"bruiser": {"model": ORC_MODEL, "weapon": W + "axe_2handed.gltf", "scale": 1.12, "tint": Color(0.9, 1.0, 0.85), "anims": ORC_ANIMS, "hit": 0.4},
		"skirmisher": {"model": ORC_MODEL, "weapon": W + "crossbow_2handed.gltf", "scale": 1.0, "tint": Color(1.0, 0.95, 0.7), "anims": ORC_ANIMS, "hit": 0.4},
		"outrider": {"model": ORC_MODEL, "weapon": W + "sword_1handed.gltf", "scale": 0.98, "tint": Color(1.0, 0.8, 0.7), "anims": ORC_ANIMS, "hit": 0.4},
		"juggernaut": {"model": ORC_MODEL, "weapon": W + "sword_2handed.gltf", "scale": 1.45, "tint": Color(0.75, 0.75, 0.65), "anims": ORC_ANIMS, "hit": 0.4},
		"stormcaller": {"model": ORC_MODEL, "weapon": W + "staff.gltf", "scale": 1.0, "tint": Color(0.7, 0.85, 1.2), "anims": ORC_ANIMS, "hit": 0.4},
		"bloodspeaker": {"model": ORC_MODEL, "weapon": W + "staff.gltf", "scale": 1.0, "tint": Color(1.25, 0.7, 0.7), "anims": ORC_ANIMS, "hit": 0.4},
		"sky_raider": {"model": ORC_MODEL, "weapon": W + "sword_1handed.gltf", "scale": 0.95, "tint": Color(0.85, 0.85, 1.1), "anims": ORC_ANIMS, "hit": 0.4},
		"saboteur": {"model": ORC_MODEL, "weapon": W + "dagger.gltf", "scale": 0.9, "tint": Color(0.6, 0.6, 0.6), "anims": ORC_ANIMS, "hit": 0.4},
		"demolisher": {"model": ORC_MODEL, "weapon": W + "axe_2handed.gltf", "scale": 1.3, "tint": Color(1.0, 0.85, 0.55), "anims": ORC_ANIMS, "hit": 0.4},
		"warlord": {"model": ORC_MODEL, "weapon": W + "sword_2handed.gltf", "scale": 1.6, "tint": Color(1.2, 0.9, 0.5), "anims": ORC_ANIMS, "hit": 0.4},
		"storm_shaman": {"model": ORC_MODEL, "weapon": W + "staff.gltf", "scale": 1.5, "tint": Color(0.6, 0.9, 1.4), "anims": ORC_ANIMS, "hit": 0.4},
		"beastmaster": {"model": ORC_MODEL, "weapon": W + "axe_2handed.gltf", "scale": 1.65, "tint": Color(1.0, 0.75, 0.5), "anims": ORC_ANIMS, "hit": 0.4},
		"shadowblade": {"model": ORC_MODEL, "weapon": W + "dagger.gltf", "scale": 1.45, "tint": Color(0.5, 0.45, 0.7), "anims": ORC_ANIMS, "hit": 0.4},
	},
	{  # camp 1 : morts-vivants (faction de remplacement)
		"peon": {"model": E + "Skeleton_Minion.glb", "weapon": "", "scale": 0.9, "tint": Color(1, 1, 1), "anims": SKEL_MELEE, "hit": 0.45},
		"bruiser": {"model": E + "Skeleton_Warrior.glb", "weapon": E + "Skeleton_Blade.gltf", "scale": 1.05, "tint": Color(1, 1, 1), "anims": SKEL_MELEE, "hit": 0.45},
		"skirmisher": {"model": E + "Skeleton_Rogue.glb", "weapon": E + "Skeleton_Crossbow.gltf", "scale": 1.0, "tint": Color(1, 1, 1), "anims": SKEL_RANGED, "hit": 0.5},
		"outrider": {"model": E + "Skeleton_Rogue.glb", "weapon": E + "Skeleton_Blade.gltf", "scale": 0.92, "tint": Color(1, 0.9, 0.8), "anims": SKEL_MELEE, "hit": 0.45},
		"juggernaut": {"model": E + "Skeleton_Warrior.glb", "weapon": E + "Skeleton_Axe.gltf", "scale": 1.5, "tint": Color(0.8, 0.8, 0.9), "anims": SKEL_MELEE, "hit": 0.45},
		"stormcaller": {"model": E + "Skeleton_Mage.glb", "weapon": E + "Skeleton_Staff.gltf", "scale": 1.0, "tint": Color(0.8, 0.9, 1.2), "anims": SKEL_CAST, "hit": 0.6},
		"bloodspeaker": {"model": E + "Skeleton_Mage.glb", "weapon": E + "Skeleton_Staff.gltf", "scale": 1.0, "tint": Color(1.2, 0.75, 0.75), "anims": SKEL_CAST, "hit": 0.6},
		"sky_raider": {"model": E + "Skeleton_Rogue.glb", "weapon": E + "Skeleton_Blade.gltf", "scale": 0.95, "tint": Color(0.85, 0.85, 1.1), "anims": SKEL_MELEE, "hit": 0.45},
		"saboteur": {"model": E + "Skeleton_Minion.glb", "weapon": E + "Skeleton_Blade.gltf", "scale": 0.9, "tint": Color(0.6, 0.6, 0.6), "anims": SKEL_MELEE, "hit": 0.45},
		"demolisher": {"model": E + "Skeleton_Warrior.glb", "weapon": E + "Skeleton_Axe.gltf", "scale": 1.3, "tint": Color(1.0, 0.85, 0.6), "anims": SKEL_MELEE, "hit": 0.45},
		"warlord": {"model": E + "Skeleton_Warrior.glb", "weapon": E + "Skeleton_Axe.gltf", "scale": 1.75, "tint": Color(1.2, 0.9, 0.5), "anims": SKEL_MELEE, "hit": 0.45},
		"storm_shaman": {"model": E + "Skeleton_Mage.glb", "weapon": E + "Skeleton_Staff.gltf", "scale": 1.6, "tint": Color(0.6, 0.9, 1.4), "anims": SKEL_CAST, "hit": 0.6},
		"beastmaster": {"model": E + "Skeleton_Warrior.glb", "weapon": E + "Skeleton_Axe.gltf", "scale": 1.8, "tint": Color(1.0, 0.75, 0.5), "anims": SKEL_MELEE, "hit": 0.45},
		"shadowblade": {"model": E + "Skeleton_Rogue.glb", "weapon": E + "Skeleton_Blade.gltf", "scale": 1.5, "tint": Color(0.5, 0.45, 0.7), "anims": SKEL_MELEE, "hit": 0.45},
	},
]
const TEAM_COLORS := ["red", "blue"]    # suffixe des modèles de bâtiments de chaque camp
const TEAM_NAMES := ["Orcs", "Morts-vivants"]

# --- Général (IA d'un camp, §6) ------------------------------------------------------------
const GENERAL_THINK_INTERVAL := 1.0     # délai entre deux décisions (s)
# Plan de construction, dans l'ordre. "tier_up" = améliorer l'hôtel de ville au palier suivant.
const GENERAL_BUILD_ORDER := ["burrow", "barracks", "forge", "tier_up", "watch_tower", "hunt_lodge", "stockpile",
	"ancestor_shrine", "beast_pen", "burrow", "spirit_hut", "tier_up", "workshop", "sky_roost", "watch_tower"]
# Composition d'armée visée : poids relatif de chaque unité (seules celles dont le bâtiment existe sont entraînées).
const GENERAL_ARMY_WEIGHTS := {"bruiser": 4, "skirmisher": 3, "outrider": 2, "juggernaut": 1, "stormcaller": 1,
	"bloodspeaker": 1, "sky_raider": 1, "saboteur": 1, "demolisher": 1}
const GENERAL_PEON_TARGET := 7          # péons que le Général veut avoir
const GENERAL_MIN_PEONS := 2            # en dessous, l'hôtel de ville entraîne des péons gratuitement (le camp ne peut pas mourir de faim)
const GENERAL_MIN_GUARD := 6            # force d'armée (nourriture) levée avant d'économiser pour le plan
const GENERAL_BUILDERS := 2             # péons envoyés sur un chantier
const GENERAL_DEFENSE_RADIUS := 34.0    # un ennemi à cette distance de l'hôtel de ville = base attaquée
const GENERAL_RETREAT_RATIO := 0.35     # l'assaut est rappelé quand l'armée tombe sous cette part de son effectif de départ
const GENERAL_EXPAND_TIME := 150.0      # pas de colonisation de mine avant ce moment de la partie (s)
const GENERAL_MISTAKE_INTERVAL := 50.0  # délai entre deux tirages d'erreur (s)
const GENERAL_MISTAKE_DURATION := 110.0 # durée d'une erreur si personne ne la corrige (s)
# Difficulté : compétence et fréquence d'erreurs du Général ENNEMI ; le Général du joueur garde
# toujours le réglage "ally" (il se trompe assez souvent pour qu'il y ait de quoi l'influencer).
# error_rate : probabilité d'erreur à chaque tirage ; attack_size : nourriture d'armée avant d'attaquer ;
# income : multiplicateur des récoltes de ses péons ; train : multiplicateur de vitesse d'entraînement.
const DIFFICULTIES := {
	"ally": {"name": "Allié", "error_rate": 0.55, "attack_size": 12, "income": 1.0, "train": 1.0},
	"easy": {"name": "Facile", "error_rate": 0.6, "attack_size": 16, "income": 0.7, "train": 0.7},
	"normal": {"name": "Normal", "error_rate": 0.35, "attack_size": 12, "income": 1.0, "train": 1.0},
	"hard": {"name": "Difficile", "error_rate": 0.15, "attack_size": 10, "income": 1.3, "train": 1.25},
}

# --- Ordres au joueur, loyauté, confiance (§6.2, §6.5, §6.6) --------------------------------------
const ORDER_MAX_ACTIVE := 3             # ordres affichés au plus
const ORDER_DURATION := 150.0           # temps laissé pour un ordre avant qu'il soit compté comme ignoré (s)
const ORDER_NEW_INTERVAL := 25.0        # délai minimal entre deux nouveaux ordres (s)
const ORDER_GATHER_AMOUNT := 10         # ressources à déposer pour un ordre de récolte
const LOYALTY_START := 60.0
const LOYALTY_ORDER_DONE := 9.0         # gain par ordre accompli
const LOYALTY_DEPOSIT := 0.15           # gain par ressource déposée
const LOYALTY_ORDER_IGNORED := 14.0     # perte par ordre ignoré
const LOYALTY_REPRIEVE := 25.0          # loyauté rendue après avoir survécu (ou succombé) aux exécuteurs
const TRAITOR_SQUAD := 3                # unités envoyées tuer le traître
const TRUST_START := 30.0
const TRUST_KILL := 2.0                 # gain par ennemi tué
const TRUST_ORDER_DONE := 2.0
const TRUST_GOOD_ADVICE := 9.0          # gain quand un conseil accepté était bon
const TRUST_BAD_ADVICE := 7.0           # perte quand un conseil était mauvais
const TRUST_ORDER_IGNORED := 3.0

# --- Influence : roue de communication (§7) --------------------------------------------------
const INFLUENCE_COOLDOWN := 18.0        # délai entre deux suggestions (s)
const INFLUENCE_BASE_CHANCE := 0.12     # chance d'acceptation de base
const INFLUENCE_TRUST_WEIGHT := 0.6     # part apportée par une confiance de 100
const INFLUENCE_GOOD_BONUS := 0.35      # bonus si la suggestion est une bonne idée maintenant
const INFLUENCE_BAD_MALUS := 0.3        # malus sinon
const INFLUENCE_RANDOM := 0.1           # part de hasard (±)

# --- Expérience et talents en partie (§8) ------------------------------------------------------
const LEVEL_CAP := 30
const XP_BASE := 40                     # XP pour passer du niveau 1 au niveau 2
const XP_PER_LEVEL := 12                # XP en plus par niveau suivant
const XP_PER_RESOURCE := 2              # par bois ou or déposé
const XP_KILL := 15
const XP_ORDER := 30
const XP_BUILD_PER_SECOND := 2.0        # par seconde de travail sur un chantier
const XP_INFLUENCE := 40                # suggestion acceptée
const XP_INFLUENCE_CORRECT := 40        # bonus si elle était bonne
const RESPEC_COOLDOWN := 120.0          # délai entre deux redistributions de talents (s)
const TALENT_TIER_COST := 2             # points à investir dans un arbre par palier pour débloquer le suivant
# Arbres de talents : id → nom, arbre, palier (1 à 5), rangs max, description (%s = valeur par rang).
const TALENT_TREES := {"gathering": "Récolte", "construction": "Construction", "combat": "Combat"}
const TALENTS := {
	"efficient_swings": {"name": "Coups efficaces", "tree": "gathering", "tier": 1, "ranks": 3, "desc": "+10 % de vitesse de coupe et de minage par rang."},
	"deep_pockets": {"name": "Poches profondes", "tree": "gathering", "tier": 2, "ranks": 2, "desc": "+5 or transporté par rang."},
	"strong_back": {"name": "Dos solide", "tree": "gathering", "tier": 2, "ranks": 2, "desc": "+5 bois transporté par rang."},
	"light_load": {"name": "Charge légère", "tree": "gathering", "tier": 3, "ranks": 2, "desc": "-30 % de ralentissement en charge par rang."},
	"lucky_strike": {"name": "Coup de chance", "tree": "gathering", "tier": 3, "ranks": 2, "desc": "+12 % de chance de ressource bonus par coup, par rang."},
	"master_prospector": {"name": "Maître prospecteur", "tree": "gathering", "tier": 4, "ranks": 1, "desc": "Les veines riches se voient à travers les murs."},
	"titan_hauler": {"name": "Porteur titan", "tree": "gathering", "tier": 5, "ranks": 1, "desc": "+10 de capacité (bois et or), dépôt instantané."},
	"hammer_down": {"name": "Coups de marteau", "tree": "construction", "tier": 1, "ranks": 3, "desc": "+15 % de vitesse de construction par rang."},
	"careful_work": {"name": "Travail soigné", "tree": "construction", "tier": 1, "ranks": 3, "desc": "+15 % de vitesse de réparation par rang."},
	"reinforced": {"name": "Renforcé", "tree": "construction", "tier": 2, "ranks": 2, "desc": "Les bâtiments que tu construis ont +10 % de vie par rang."},
	"rapid_assembly": {"name": "Assemblage rapide", "tree": "construction", "tier": 3, "ranks": 2, "desc": "+25 % de vitesse de construction par rang."},
	"fortify": {"name": "Fortifier", "tree": "construction", "tier": 4, "ranks": 1, "desc": "Touche B : pose une barricade temporaire."},
	"architect": {"name": "Architecte", "tree": "construction", "tier": 5, "ranks": 1, "desc": "Touche F sur un chantier : l'achève d'un coup (long délai)."},
	"thick_skin": {"name": "Peau épaisse", "tree": "combat", "tier": 1, "ranks": 3, "desc": "+15 points de vie par rang."},
	"quick_feet": {"name": "Pieds lestes", "tree": "combat", "tier": 1, "ranks": 3, "desc": "+4 % de vitesse de déplacement par rang."},
	"tough": {"name": "Coriace", "tree": "combat", "tier": 2, "ranks": 3, "desc": "-8 % de dégâts subis par rang."},
	"power_swing": {"name": "Frappe puissante", "tree": "combat", "tier": 2, "ranks": 3, "desc": "+15 % de dégâts de mêlée par rang."},
	"adrenaline": {"name": "Adrénaline", "tree": "combat", "tier": 3, "ranks": 1, "desc": "L'endurance revient deux fois plus vite en combat."},
	"disarm": {"name": "Désarmer", "tree": "combat", "tier": 4, "ranks": 1, "desc": "20 % de chance d'arracher l'arme d'un ennemi (ses dégâts sont divisés par deux)."},
	"weapon_mastery": {"name": "Maîtrise des armes", "tree": "combat", "tier": 4, "ranks": 1, "desc": "Les armes ramassées frappent à pleine puissance."},
	"battle_frenzy": {"name": "Frénésie", "tree": "combat", "tier": 5, "ranks": 1, "desc": "Sous 30 % de vie : +40 % de dégâts, +15 % de vitesse."},
}
const BARRICADE_HEALTH := 400.0
const BARRICADE_LIFETIME := 60.0        # durée de vie d'une barricade (s)
const BARRICADE_COOLDOWN := 20.0        # délai entre deux barricades (s)
const ARCHITECT_COOLDOWN := 180.0       # délai entre deux usages d'Architecte (s)
const ADRENALINE_TIME := 5.0            # durée de l'effet après un coup donné ou reçu (s)
const PICKED_WEAPON_HITS := 15          # coups avant qu'une arme ramassée casse
const PICKED_WEAPON_DAMAGE := 1.5       # multiplicateur de dégâts d'une arme ramassée (sans Maîtrise)
const PICKED_WEAPON_MASTERY := 2.2      # multiplicateur avec Maîtrise des armes
const WEAPON_DROP_CHANCE := 0.3         # chance qu'un soldat ennemi lâche son arme en mourant

# --- Progression permanente : Renom (§9) ---------------------------------------------------------
const RENOWN_WIN := 100
const RENOWN_LOSS := 30
const RENOWN_PER_RESOURCES := 5         # 1 Renom par tranche de ressources déposées
const RENOWN_PER_KILL := 3
const RENOWN_PER_INFLUENCE := 10        # par suggestion acceptée qui était bonne
const RENOWN_NO_DEATH := 30             # bonus de survie (aucune mort)
# Améliorations permanentes : id → nom, catégorie, niveaux max, coût du premier niveau (puis +50 % par niveau), effet.
const META_UPGRADES := {
	"faster_pickaxe": {"name": "Pioche rapide", "category": "Outils", "levels": 3, "cost": 60, "desc": "+8 % de vitesse de minage par niveau."},
	"faster_axe": {"name": "Hache rapide", "category": "Outils", "levels": 3, "cost": 60, "desc": "+8 % de vitesse de coupe par niveau."},
	"sharpened_axe": {"name": "Hache affûtée", "category": "Outils", "levels": 3, "cost": 80, "desc": "+12 % de dégâts d'outil par niveau."},
	"increased_hp": {"name": "Vie accrue", "category": "Défense", "levels": 5, "cost": 50, "desc": "+10 points de vie par niveau."},
	"regeneration": {"name": "Régénération", "category": "Défense", "levels": 3, "cost": 70, "desc": "+30 % de régénération hors combat par niveau."},
	"move_speed": {"name": "Vitesse", "category": "Mobilité", "levels": 3, "cost": 70, "desc": "+3 % de vitesse de déplacement par niveau."},
	"jump_height": {"name": "Détente", "category": "Mobilité", "levels": 2, "cost": 50, "desc": "+12 % de hauteur de saut par niveau."},
	"dodge_roll": {"name": "Roulade", "category": "Mobilité", "levels": 1, "cost": 120, "desc": "Débloque la roulade (Ctrl), invulnérable un court instant."},
	"weapon_pickup": {"name": "Ramassage d'armes", "category": "Combat", "levels": 1, "cost": 120, "desc": "Débloque le ramassage des armes lâchées par les soldats."},
	"carry_capacity": {"name": "Capacité de portage", "category": "Utilitaire", "levels": 3, "cost": 60, "desc": "+2 bois et or transportés par niveau."},
	"learning": {"name": "Apprentissage", "category": "Utilitaire", "levels": 3, "cost": 80, "desc": "+10 % d'XP gagnée par niveau."},
}
const META_COST_GROWTH := 1.5
const DODGE_DISTANCE := 5.0             # longueur de la roulade (m)
const DODGE_TIME := 0.35                # durée (et invulnérabilité) de la roulade (s)
const DODGE_STAMINA := 25.0             # endurance dépensée
const DODGE_COOLDOWN := 0.8

# --- Campagne « L'Ascension » (§2.1) : arc court de 3 missions -------------------------------------
# map : carte ; difficulty : Général ennemi ; loyalty : loyauté de départ ; intro / outro : dialogues (texte).
const CAMPAIGN := [
	{"title": "1 — La corvée", "map": "valley", "difficulty": "easy", "loyalty": 60.0,
		"intro": ["Le Général : « Toi, là. Le péon. Tu as deux bras, sers-t'en. »",
			"Le Général : « Du bois, de l'or, des murs. Fais ce que je dis et tu vivras peut-être jusqu'à ce soir. »",
			"Objectif : aide le camp à raser la loge de guerre ennemie, au nord."],
		"outro": ["Le Général : « Hm. Tu n'es pas mort. C'est déjà plus que les autres. »"]},
	{"title": "2 — Une voix dans le rang", "map": "crossing", "difficulty": "normal", "loyalty": 55.0,
		"intro": ["Les autres péons chuchotent ton nom. Le Général l'a remarqué.",
			"Le Général : « On me dit que tu as des idées. Garde-les pour toi... sauf si elles sont bonnes. »",
			"Objectif : maintiens Q pour conseiller le Général, et détruis la base ennemie."],
		"outro": ["Le Général : « Bon œil, péon. Ne t'y habitue pas. »"]},
	{"title": "3 — La légende", "map": "valley", "difficulty": "hard", "loyalty": 40.0,
		"intro": ["L'ennemi connaît ton visage. Ses soldats te cherchent sur le champ de bataille.",
			"Le Général : « Ils ont peur d'un péon. D'UN PÉON. Soit. Montre-leur pourquoi. »",
			"Objectif : l'ennemi est aguerri et le Général se méfie de toi. Gagne quand même."],
		"outro": ["Le Général : « ... Reste près de moi, désormais. Légende. »"]},
]
const MAPS := {"valley": {"name": "La Vallée", "scene": "res://scenes/world/map_valley.tscn"},
	"crossing": {"name": "Le Carrefour", "scene": "res://scenes/world/map_crossing.tscn"}}

# --- Joueur : vie ---------------------------------------------------------------
const PLAYER_MAX_HEALTH := 100.0
const PLAYER_REGEN := 4.0               # points de vie / seconde hors combat
const PLAYER_REGEN_DELAY := 6.0         # secondes sans dégât avant de régénérer
const PLAYER_RESPAWN_TIME := 6.0        # délai d'entraînement du nouveau péon après la mort (s), une fois payé
const SHAKE_PLAYER_HURT := 0.45         # "trauma" quand le joueur est touché

# --- Arbres -----------------------------------------------------------------
const TREE_MAX_HEALTH := 100.0
const LOGS_PER_TREE := 4

# --- Hache ------------------------------------------------------------------
const AXE_DAMAGE := 25.0                # 4 coups pour abattre un arbre
const AXE_RANGE := 2.4                  # mètres depuis la caméra
const AXE_SWING_DURATION := 0.85        # durée totale d'un coup (s)
const AXE_HIT_TIME := 0.42              # instant de l'impact dans le coup (s)

# --- Game feel --------------------------------------------------------------
const SHAKE_AXE_HIT := 0.32             # "trauma" ajouté à chaque coup
const BARK_CHIPS_SURFACE_BIAS := 0.6   # 0 = éclats exactement à l'opposé du coup, plus = s'écartent de l'écorce
const TREE_SWAY_IMPULSE := 0.2          # vitesse angulaire (rad/s) ajoutée par coup
const TREE_SWAY_STIFFNESS := 60.0       # raideur du ressort d'oscillation
const TREE_SWAY_DAMPING := 4.5          # amortissement de l'oscillation

# --- Explosion de l'arbre en rondins -----------------------------------------
const SHAKE_TREE_BURST := 0.6           # "trauma" à proximité de l'explosion
const SHAKE_TREE_BURST_RADIUS := 15.0
const LOG_BURST_SPEED := 4.0            # vitesse horizontale d'éjection, dans la direction du coup (m/s)
const LOG_BURST_UP_SPEED := 4.5         # vitesse verticale d'éjection (m/s)
const LOG_BURST_SPREAD := 0.8           # dispersion latérale (0 = tout droit devant)
