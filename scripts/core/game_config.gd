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

# --- Dépôt de bois du camp ---------------------------------------------------
const STOCKPILE_AUTO_DEPOSIT := false   # true = décharger dès qu'on entre dans la zone, false = appuyer sur E
const STOCKPILE_UNLOAD_INTERVAL := 0.09 # délai entre deux rondins déchargés (s)
const STOCKPILE_FLY_TIME := 0.32        # durée du vol d'un rondin de l'épaule à la pile (s)
const STOCKPILE_FLY_ARC := 0.5          # hauteur de la cloche du vol (m)
const STOCKPILE_STACK_BASE := 7         # rondins dans la rangée du bas d'un tas (pyramide : 7+6+…+1 = 28)
const STOCKPILE_STACKS := 3             # nombre de tas visibles (au-delà, seul le compteur monte)

# --- Or ------------------------------------------------------------------------
const BASE_GOLD_CAPACITY := 10          # or que contient le sac à dos
const GOLD_PER_SWING := 1               # or tiré d'une veine par coup de pioche
const MAX_GOLD_CARRY_SPEED_PENALTY := 0.15  # ralentissement à sac plein
const VEIN_GOLD := 40                   # or d'une veine pleine
const VEIN_REGEN_INTERVAL := 6.0        # secondes pour qu'une veine entamée regagne 1 or

# --- Bâtiments du camp --------------------------------------------------------
# name : nom affiché ; health : points de vie ; build_time : secondes de travail du péon ;
# wood / gold : coût payé par le Général ; scale : agrandissement du modèle (miniatures KayKit).
const BUILDINGS := {
	"bastion": {"name": "Bastion", "health": 2500.0, "build_time": 40.0, "wood": 0, "gold": 0, "scale": 3.2},
	"lumber_mill": {"name": "Scierie", "health": 1200.0, "build_time": 12.0, "wood": 30, "gold": 0, "scale": 4.5},
	"tower": {"name": "Tour de guet", "health": 800.0, "build_time": 10.0, "wood": 30, "gold": 20, "scale": 4.0},
	"barracks": {"name": "Caserne", "health": 1500.0, "build_time": 16.0, "wood": 50, "gold": 40, "scale": 4.5},
}
const BUILDING_START_HEALTH_RATIO := 0.1  # part des points de vie au début du chantier (le reste monte avec la construction)
const BUILD_RANGE := 3.0                # distance max au chantier pour y travailler (m, depuis son bord)
const LUMBER_MILL_SAW_SPEED := 5.0      # rotation de la scie quand la scierie est debout (rad/s)
const SHAKE_BUILDING_COLLAPSE := 0.8    # "trauma" à proximité d'un bâtiment qui s'effondre
const SHAKE_BUILDING_COLLAPSE_RADIUS := 30.0
const DEBUG_BUILDING_DAMAGE := 300.0    # dégâts infligés par la touche de test K

# --- Tour de guet -------------------------------------------------------------
const TOWER_RANGE := 16.0               # portée de tir (m)
const TOWER_DAMAGE := 14.0              # dégâts par flèche
const TOWER_FIRE_INTERVAL := 1.1        # délai entre deux tirs (s)

# --- Joueur : vie ---------------------------------------------------------------
const PLAYER_MAX_HEALTH := 100.0
const PLAYER_REGEN := 4.0               # points de vie / seconde hors combat
const PLAYER_REGEN_DELAY := 6.0         # secondes sans dégât avant de régénérer
const PLAYER_RESPAWN_TIME := 6.0        # secondes entre la mort et la réapparition au bastion
const SHAKE_PLAYER_HURT := 0.45         # "trauma" quand le joueur est touché

# --- Unités -------------------------------------------------------------------
# health ; speed (m/s) ; damage (par coup, contre joueur et unités) ; building_damage (par coup,
# contre les bâtiments) ; attack_interval (s) ; attack_range (m) ; aggro (m : distance à laquelle
# l'unité se détourne vers un adversaire vivant) ; scale (taille du modèle).
const UNITS := {
	"skeleton_minion": {"health": 50.0, "speed": 3.4, "damage": 7.0, "building_damage": 12.0,
		"attack_interval": 1.3, "attack_range": 1.7, "aggro": 9.0, "scale": 0.95},
	"skeleton_warrior": {"health": 110.0, "speed": 2.9, "damage": 12.0, "building_damage": 22.0,
		"attack_interval": 1.5, "attack_range": 1.8, "aggro": 9.0, "scale": 1.12},
	"grunt": {"health": 160.0, "speed": 4.6, "damage": 18.0, "building_damage": 0.0,
		"attack_interval": 1.2, "attack_range": 1.9, "aggro": 22.0, "scale": 1.12},
}
const UNIT_KNOCKBACK := 3.5             # recul d'une unité touchée (m/s)
const UNIT_CORPSE_TIME := 4.0           # durée d'affichage d'un cadavre (s)

# --- Général (IA du camp) ---------------------------------------------------------
const GENERAL_THINK_INTERVAL := 1.0     # délai entre deux décisions (s)
const GRUNT_COST_WOOD := 0
const GRUNT_COST_GOLD := 25
const GRUNT_CAP := 6                    # nombre maximal de grunts vivants
const GRUNT_TRAIN_TIME := 8.0           # délai entre deux recrutements (s)

# --- Vagues ennemies --------------------------------------------------------------
const WAVE_COUNT := 8                   # survivre à toutes les vagues = victoire
const WAVE_FIRST_DELAY := 150.0         # délai avant la première vague (s)
const WAVE_INTERVAL := 75.0             # délai entre la fin de l'apparition d'une vague et la suivante (s)
const WAVE_BASE_SIZE := 2               # ennemis de la première vague
const WAVE_GROWTH := 1.5                # ennemis en plus par vague
const WAVE_WARRIOR_FROM := 3            # vague à partir de laquelle des guerriers squelettes apparaissent
const WAVE_SPAWN_INTERVAL := 1.2        # délai entre deux apparitions (s)

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
