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
const SHAKE_TREE_FALL := 0.75           # "trauma" à l'impact au sol (à proximité)
const SHAKE_TREE_FALL_RADIUS := 18.0    # au-delà, pas de secousse
const TREE_SWAY_IMPULSE := 0.2          # vitesse angulaire (rad/s) ajoutée par coup
const TREE_SWAY_STIFFNESS := 60.0       # raideur du ressort d'oscillation
const TREE_SWAY_DAMPING := 4.5          # amortissement de l'oscillation

# --- Chute physique des arbres ------------------------------------------------
const TREE_TRUNK_MASS := 350.0                      # kg
const TREE_CANOPY_MASS_SHARE := 0.35                # 0 = masse au centre du fût, 1 = au centre du feuillage
const TREE_FELL_KICK := 0.6                         # élan de bascule donné par le dernier coup (rad/s)
const TREE_FALL_ANGULAR_DAMP := 0.3
const TREE_HINGE_BREAK_ANGLE := deg_to_rad(55.0)    # la charnière cède au-delà de cette inclinaison
const TREE_IMPACT_MIN_TILT := deg_to_rad(35.0)      # contact considéré comme "impact au sol"
const TREE_MAX_FALL_TIME := 6.0                     # sécurité : éclatement forcé
const LOG_BURST_SPEED := 3.0                        # vitesse d'éjection des rondins à l'éclatement (m/s)
