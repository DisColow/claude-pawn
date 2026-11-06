# PAWN — Cahier des Charges & Spécifications Techniques

> **Type de document :** Game Design & Technical Specification  
> **Titre de travail :** PAWN  
> **Moteur :** Godot Engine 4.7+ (Forward+)  
> **Plateforme cible initiale :** Windows (PC)  
> **Perspective :** Vue à la 1ère personne (FPS), simulation d'ouvrier dans un RTS asymétrique.

---

## 1. Vision & Concept

Vous n'êtes pas le commandant. Vous êtes un simple travailleur — un **péon** orque — au cœur d'une guerre stratégique menée par une IA : le **Général**.
Vous récoltez du bois, minez de l'or, construisez les bâtiments du camp et défendez votre vie.

---

## 2. Le Travailleur (The Worker)

- **Vue FPS & Conscience Corporelle (*Body Awareness*) :**
  - Bras d'orque visibles manipulant les outils et tenant la charge.
  - Buste et jambes visibles en regardant vers le bas sans jamais obstruer la visibilité du sol.
  - Ombre portée et bruits de pas cadencés.
  - **Anti-clipping au premier plan (*Z-Clip Depth Scaling*) :** Les bras, les outils (hache), le bois transporté et les éléments du corps utilisent la mise à l'échelle de profondeur (`use_z_clip_scale = true`, `z_clip_scale = 0.1`). Cette technique standard de l'industrie du FPS garantit que la vue subjective (mains, arme, bois) s'affiche toujours au premier plan, sans jamais être coupée ou traversée par les troncs d'arbres ou les parois du décor lorsque le joueur s'y colle.
- **Locomotion :**
  - Marche / Course (WASD / ZQSD).
  - Sprint (Maj) avec consommation et régénération d'endurance.
  - Saut (Espace).

---

## 3. Récolte & Découpe de Bois (Wood Gathering)

### 3.1 Mécanique de coupe
- **Outil :** Hache de base orque (dégâts configurables, 4 coups pour abattre un arbre).
- **Feedback & Game Feel :**
  - Éclats de bois projetés en particules (`WoodChipsVFX`).
  - Oscillation élastique du tronc à chaque coup (*sway*).
  - Secousse d'écran (*camera shake*) et son d'impact boisé percutant.
- **Chute physique de l'arbre :**
  - Craquement du bois (`tree_creak`).
  - La souche (`Stump`) reste ancrée au sol.
  - Le tronc bascule avec accélération gravitationnelle réaliste vers le sol (pivot charnière au sommet de la souche).
  - Impact au sol : nuage de poussière (`DustImpactVFX`), son sourd d'écrasement, et apparition de **4 rondins de bois physiques** éparpillés devant la souche.

### 3.2 Transport sur l'épaule & Règle de coupe en cours de transport (⭐ AMENDEMENTS)
- **Portage sur l'épaule (Dégagement de la vue) :**
  - **Les rondins sont portés sur l'épaule gauche**, calés et retenus par le bras gauche.
  - **Champ de vision 100% dégagé :** La charge repose sur le côté gauche / périphérique de l'écran, ce qui laisse le centre et l'avant de la vue totalement libres pour courir, explorer et viser sans gêne visuelle.
  - La pile de rondins sur l'épaule s'étoffe visuellement au fur et à mesure des ramassages (de 1 à 10 rondins).
- **Coupe continue :**
  - **Le travailleur peut continuer à couper du bois même s'il a déjà des rondins sur l'épaule.**
  - La main droite conserve la hache active en permanence pour abattre de nouveaux arbres.
- **Capacité de charge :**
  - Capacité de base : 10 rondins.
  - Pénalité de vitesse proportionnelle à la charge (jusqu'à -35% à 10 rondins).
  - À 10/10 rondins, le joueur peut continuer à couper des arbres, mais doit déposer son bois au camp pour pouvoir en ramasser de nouveaux.

### 3.3 Dépôt au camp (Stockpile)
- Zone de stockage dédiée au campement.
- Approcher du dépôt ou appuyer sur `E` décharge le bois porté dans l'économie du camp, incrémente le stock global, et fait grandir visuellement la pile de bois.

---

## 4. Données de Configuration (Data-Driven)

Toutes les valeurs d'équilibrage sont centralisées dans `GameConfig.gd` :
- `WALK_SPEED = 5.2`
- `SPRINT_SPEED = 8.2`
- `BASE_WOOD_CAPACITY = 10`
- `MAX_CARRY_SPEED_PENALTY = 0.35`
- `TREE_MAX_HEALTH = 100.0`
- `AXE_DAMAGE = 25.0`
- `LOGS_PER_TREE = 4`
