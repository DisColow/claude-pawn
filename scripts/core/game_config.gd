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
