# Document de Game Design — Dream Dive
*Un roguelite d'action en 2D pixel art, sur PC*

---

## 1. Pitch

Le joueur incarne un **voyageur du rêve** qui explore son propre sommeil. Chaque **tour représente une nuit différente**, avec sa propre "personnalité" : certaines nuits sont paisibles, d'autres bien plus tourmentées — et ce niveau de tourment définit directement la difficulté de la tour.

Le jeu mêle exploration façon *Pokémon* (déplacement sur une carte, cauchemars qui rôdent) et combat d'action nerveux façon *Hadès*, dans un cadre roguelite où **la mort fait reculer sans tout effacer** : on redescend de deux étages et on garde quelques objets, chaque run est différente, et la progression se mérite.

---

## 2. Univers & Narration

- Le joueur explore **son propre sommeil**. Chaque **tour = une nuit différente** de sa vie de rêveur.
- **Le jeu couvre une semaine : 7 nuits, du lundi au dimanche.** Chaque jour, la semaine du rêveur se dégrade un peu plus sur le plan des émotions (fatigue, stress, doute, frustration, épuisement, solitude, angoisse), donc chaque nuit est plus difficile que la précédente.
- Chaque tour (nuit) a son ambiance propre : certaines nuits sont calmes, d'autres bien plus tourmentées — reflet de l'état d'esprit du personnage à ce moment de sa vie.
- Les étages d'une même tour ne suivent **aucun ordre logique fixe** — l'ordre est aléatoire à chaque run, pour refléter la non-linéarité réelle du sommeil.
- Deux grandes familles d'étages, alternant de façon imprévisible au sein d'une tour :
  - **Sommeil paradoxal** : rythme rapide, ambiance vive et changeante, plus de PNJ et d'événements narratifs, rebondissements fréquents.
  - **Sommeil profond** : rythme plus lent, ambiance sombre/oppressante, moins de PNJ mais mobs plus dangereux.
- Une seconde dimension, indépendante de la famille : l'**intensité** de l'étage, **rêve** ou **cauchemar** (palette claire ou sombre). La part de cauchemars dépend de la nuit.
- **Les PNJ font partie intégrante du rêve lui-même** — ce sont des habitants propres à cet univers onirique, pas des représentations d'autres personnes (hibou insomniaque, lapin horloger, marchande de lune...).
- **Tours difficiles = nuits plus tourmentées** : les nuits les plus dures correspondent à des périodes où le personnage porte des peurs plus profondes ou des problèmes de vie plus lourds — la difficulté est donc directement liée à l'état intérieur du personnage à ce moment-là, et justifiée narrativement.
- **Fil rouge narratif** : la semaine est l'image d'une vie entière et des épreuves qu'on y traverse. Chaque nuit est un âge de la vie, avec sa peine et une petite lueur d'espoir à la fin : lundi l'enfance (les disputes entendues derrière la porte), mardi l'école (la pression), mercredi la jeunesse (qui devenir), jeudi la vie active (les efforts sans récompense), vendredi le soin des autres (l'épuisement), samedi les départs (la solitude), dimanche la fin (l'angoisse), jusqu'au réveil apaisé.
- **Comment le récit est raconté** (textes dans `scripts/story.gd`, premier jet à retravailler) :
  - une **introduction animée** façon *The Binding of Isaac* (tableaux illustrés et texte qui s'écrit), jouée la première fois qu'on va choisir une nuit et relisible dans le hub (Livre des songes) ;
  - les **habitants du rêve** : au premier échange, chacun dit une réplique liée à la nuit en cours ;
  - une **fin à chaque nuit**, racontée après son dernier boss.

---

## 3. Boucle de gameplay

1. Depuis le **menu principal**, le joueur rejoint le **hub de la semaine** et marche jusqu'à la tour de la nuit qu'il veut jouer (mode speedrun activable à l'horloge).
2. Il explore la carte d'un étage (déplacement libre, décors interactifs, coffres, PNJ).
3. Des **cauchemars errants** rôdent sur la carte, visibles : on les évite, on les sème, ou on les prend à revers pour les surprendre. En toucher un lance le combat.
4. Transition stylisée selon le type d'étage → le joueur est **enfermé dans une arène de combat séparée**.
5. Combat en **temps réel** contre 1 à 4 ennemis selon le mode (dash, esquive avec i-frames, attaques, patterns lisibles — inspiration Hadès).
6. Victoire → butin éventuel posé au sol (à prendre ou non), pièces, retour sur la carte.
7. Pour changer d'étage, le joueur prend le **portail**, toujours gardé : par un **boss** un étage sur trois (et au dernier), sinon par une **meute menée par une élite**. L'étage ne change qu'après la victoire.
8. Fin de la tour (le rêveur se réveille) ou mort → retour au menu.
9. Mort → le joueur perd son objet actif et ses passifs, sauf 2 gardés au hasard ; il redescend de 2 étages, nouveau tirage aléatoire au-dessus (voir Structure & Difficulté).

---

## 4. Combat

- **Temps réel**, inspiration directe *Hadès* : dash avec i-frames, attaque en arc, objet actif. **Enchaînement** : trois coups rapprochés, le troisième frappe deux fois plus fort et plus loin, puis demande un temps de récupération. **Coup plongeant** : attaquer pendant un dash ou juste après ajoute 1 dégât et de la portée, une fois toutes les 2,5 s. Touches : ZQSD (ou flèches) pour se déplacer, J attaque, K dash, L objet actif, E interagir, Tab passifs. **Manette** : stick gauche ou croix, X attaque, B dash, Y objet actif, A interagir, Select passifs, Start menu. Toutes les touches se changent dans Paramètres > Touches.
- **Rafale de plumes** (attaque spéciale, I / RB) : trois plumes en éventail, à distance, toutes les 3 s. Un ennemi n'est touché qu'une fois par rafale : elle sert à toucher loin ou plusieurs ennemis, pas à doubler les dégâts au corps à corps. Quatre objets la transforment (Plumier : +2 plumes ; Plume de paon : les plumes traversent ; Oreiller éventré : recharge plus rapide ; Bouquet final : le 3e coup lance une rafale), et le **Plumier avec la Plume de paon forment un ensemble**, la *Tempête de plumes* : la rafale part dans toutes les directions. `scripts/combat/feather.gd`.
- **Tutoriel** : le tout premier combat du jeu (lundi, étage 0) oppose un seul ennemi d'entraînement, immobile, et demande les gestes un par un (se déplacer, frapper, enchaîner trois coups, dasher, lancer une rafale) ; il se réveille ensuite pour un vrai combat. `scripts/ui/tutorial.gd`.
- **Annonces d'attaque** : chaque ennemi montre un « ! » et un anneau à ses pieds qui se referme jusqu'à sa frappe ; chaque danger (zone, rayon, onde, bras) s'annonce en pointillés qui se remplissent, puis frappe en plein (`scripts/combat/hazards/`).
- **Boss** : une barre de vie en haut de l'écran, avec un trait à chaque seuil de phase pour les boss de fin.
- **Ennemis hors champ** : l'arène est plus grande que l'écran ; une flèche au bord de l'écran montre chaque ennemi hors champ, et rougit quand il prépare une attaque. Le sol de l'arène est voilé pour que les annonces d'attaque ressortent.
- Arène séparée de la map d'exploration, habillée avec les tuiles du type d'étage.
- **Rencontres** : 2 à 4 ennemis en mode Cauchemar (un de plus tous les 4 étages), un de moins en mode Normal (1 à 3). Les **boss combattent seuls**.
- Les mobs ont des patterns d'attaque **télégraphiés** clairement (lisibilité avant tout) : la difficulté augmente leurs PV, leur vitesse et leur cadence, **jamais la durée des télégraphes**.
- Brève invincibilité après un coup encaissé (plusieurs ennemis peuvent frapper en même temps).
- **PV façon Isaac** : les PV perdus le restent d'un combat à l'autre pendant toute la nuit. On les récupère avec les étoiles de la carte (+1 PV, pas au-delà du max), le Mouchoir usagé et les passifs de soin. Un +PV max arrive plein. **8 PV au plus**, quels que soient les objets. PV affichés sur la carte.
- **Gardiens de portail** : un étage sur trois (étages 2, 5, 8 ; dans les profondeurs -3, -6, -9 et -10), un boss tiré au hasard dans le pool de la nuit (3 boss × 4 versions, jamais deux fois le même dans une nuit) ; le dernier portail de la nuit est gardé par le **boss final** de la nuit, multi-phases. Les autres portails sont gardés par une **meute menée par une élite** (butin garanti, on ne la fuit pas). `GameState.floor_has_boss()`.
- **Transition selon le type d'étage** : douce et ondulante (paradoxal), brutale et saccadée (profond ; fondu simple si les flashs sont désactivés).
- Bestiaire : un par nuit (4 créatures, 3 boss, 1 boss final), détaillé dans [docs/bestiaire.md](bestiaire.md).

---

## 5. Structure des tours & difficulté

- Chaque tour est indépendante des autres (nuit différente = tour différente) et possède un **nombre limité d'étages** : narrativement, la tour se termine quand le personnage se réveille — pas de tour infinie.
- **Ordre des étages aléatoire** à chaque run, alternant sommeil paradoxal / sommeil profond.
- **Taille des étages** : petits au début (16×10 cases), de plus en plus grands jusqu'au dernier étage (34×20).
- **Courbe de difficulté** : +8 % par étage atteint, +15 % en sommeil profond (modificateur de type), plus le bonus propre à la nuit.
- **À la mort** : le joueur redescend de 2 étages en dessous de sa position actuelle (les nuits ne font que 6 à 9 étages), avec un **nouveau tirage aléatoire des étages au-dessus** de ce point. Une run n'est donc jamais totalement perdue, mais recule concrètement.
- **Fuite** : on ne fuit jamais un gardien ni un boss. Un combat ordinaire se fuit en appuyant deux fois sur Menu : cela coûte 3 pièces, et les PV perdus pendant le combat le restent.
- **Quitter le jeu en plein combat compte comme une mort** (pas de fuite par la fermeture du jeu).
- **Plongée négative** : à l'étage 0, un second portail (rouge) mène aux profondeurs (étages -1 à -10), plus dangereuses (les boss de la nuit y rôdent). Les remonter rapporte un butin ; y mourir referme le passage pour la partie.

---

## 6. Modes de jeu & sélection des tours

- **Menu principal** : Continuer (partie sauvegardée), Choisir une nuit (hub), Sauvegardes, Paramètres.
- **Trois sauvegardes** indépendantes : chacune garde sa partie en cours et sa méta-progression (pièces, nuits terminées, améliorations, semaine). Le panneau Sauvegardes montre le résumé de chacune ; on en choisit une pour y jouer (le jeu la retient au prochain lancement), ou on l'efface, en deux appuis, pour y commencer une nouvelle partie. Les paramètres et les touches sont communs aux trois.
- **Hub de la semaine** : un lieu où l'on marche, comme un menu vivant. Les 7 tours y sont alignées du lundi au dimanche, de plus en plus sombres et tordues. On y trouve aussi la Marchande de lune (boutique) et l'horloge du réveil (mode speedrun). Entrer dans une autre nuit que celle en cours demande une confirmation (la partie en cours est abandonnée).
- **Déblocage progressif** : on ne peut entrer dans une nuit qu'après avoir terminé celle de la veille. Les nuits terminées portent une étoile.
- **Les 7 nuits** (données dans `scripts/towers.gd`) :

| Nuit | Émotion | Étages | Difficulté | Cauchemars | Récompense |
|---|---|---|---|---|---|
| Lundi | Fatigue | 6 | +0 % | 10 % | 15 |
| Mardi | Stress | 6 | +18 % | 20 % | 25 |
| Mercredi | Doute | 7 | +28 % | 35 % | 35 |
| Jeudi | Frustration | 7 | +46 % | 50 % | 50 |
| Vendredi | Épuisement | 8 | +56 % | 65 % | 65 |
| Samedi | Solitude | 8 | +74 % | 80 % | 80 |
| Dimanche | Angoisse | 9 | +84 % | 95 % | 120 |

*Équilibrage* : les nuits ont été raccourcies (6 à 9 étages au lieu de 6 à 12) ; le bonus de chaque nuit a été relevé pour que son dernier étage reste aussi dur qu'avant. Il reste modéré parce qu'il s'ajoute à des nuits plus longues (+8 % par étage), à plus d'étages cauchemar et à un bestiaire plus riche, alors que le joueur repart sans objet à chaque nuit. Les **boss** ne prennent que la moitié de ce palier en PV (leur rythme, lui, le suit en entier). Banc d'essai : `tools/balance/` (un bot joue les vrais combats de chaque nuit et mesure les PV perdus).

- Chaque nuit a son **bestiaire** (`docs/bestiaire.md`) et ses **deux lieux** (un pour le sommeil paradoxal, un pour le profond), avec tuiles, décors, lumière et une **règle d'étage** qui monte au fil de la nuit (`docs/nuits.md`, produits nuit par nuit).
- **Normal ou Cauchemar** : en entrant dans une tour, le joueur choisit son mode (`scripts/hub/mode_panel.gd`, gardé dans la sauvegarde). **Normal** : un ennemi de moins par combat (jamais plus de 3), des boss à 80 % de leurs PV qui attaquent 15 % moins souvent, et certains ennemis plus lents à tirer (la Veilleuse fatiguée prévient plus longtemps et ne tire pas juste après s'être rallumée près du joueur). **Cauchemar** : la difficulté d'origine. À ne pas confondre avec les **étages** cauchemar, tirés selon la nuit, qui donnent la variante cauchemar des ennemis.
- **Mode Speedrun** : un **chrono unique pour toute la nuit** (75 s par étage), qui ne tourne qu'en jeu. À zéro, **le réveil sonne** : la nuit s'arrête, sans récompense. La mort garde sa règle habituelle, et le chrono continue de tourner. Meilleur temps enregistré par nuit.

---

## 7. Méta-progression

- Entre les runs, le joueur gagne des **pièces** (indépendantes du loot en run, qui reset toujours à la mort) : 1 par combat gagné, 3 par gardien, 2 par quête, et une récompense en fin de nuit.
- La **boutique des songes** (menu) propose 3 objets passifs, renouvelés après chaque réveil (mort ou fin de nuit). Prix selon la rareté (15 / 35 / 80).
- Un achat rejoint la nuit en cours, ou attend dans le **sac de départ** de la prochaine nuit.
- **Améliorations permanentes** (boutique, « Pour toujours ») : Cœur solide (+1 PV de départ, 2 niveaux : 40 puis 90 pièces), Poches profondes (garde 1 objet de plus à la mort, 2 niveaux : 60 puis 120), Doudou de voyage (un objet commun au début de chaque nuit, 50), Amie de la marchande (une offre de plus en boutique, 45).
- **Bilan de nuit** : à la fin d'une nuit, le menu résume la run (combats gagnés, ennemis vaincus, objets pris, morts, temps de jeu).
- **Semaine suivante** : quand les sept nuits sont terminées, une nouvelle semaine commence. Toutes les nuits redeviennent à faire, avec +25 % de difficulté et +50 % de récompense par semaine écoulée.
- Ce système garantit que même en cas de mort, le joueur repart avec un sentiment de progression tangible.

---

## 8. Système de loot

- **À la mort**, l'objet actif, les malédictions et les passifs sont perdus, **sauf 2 passifs gardés au hasard** (3 ou 4 avec Poches profondes) : repartir les mains vides au milieu d'une nuit était presque injouable. Justifié narrativement par le réveil en sursaut : on garde des bribes du rêve.
- **Objets passifs** : cumulables sans limite (y compris plusieurs exemplaires du même), mais certains effets sont plafonnés pour qu'un empilement ne rende pas intouchable : esquive 50 %, soin en frappant 30 %, soin en tuant 50 %, 3 coups bloqués et 2 survies par combat, ennemis affaiblis de moitié au plus. Chacun est décrit par des effets chiffrés (PV, dégâts, vitesse, critiques, esquive, vol de vie, bouclier, ennemis affaiblis...) : ajouter un passif ne demande pas de code.
- **Objet actif** : un seul à la fois, utilisé avec L (Y à la manette) en combat, 3 charges. Un combat gagné rend une charge. Prendre un nouvel actif laisse l'ancien au sol, avec ses charges restantes.
- Le butin tombe **au sol** : le joueur choisit de le prendre (E) ou non. Les objets au sol restent sur l'étage.
- **Chaque objet a son icône et un tier** (S, A, B, C : sa puissance ; la rareté, elle, dit s'il est fréquent). Le ramasser affiche une **bannière façon Isaac** (icône, tier, nom, effet). L'**inventaire** (Tab / Select) met le jeu en pause : à gauche l'objet actif, les malédictions en cours et les passifs avec leur fiche (la liste défile au clavier, à la manette et à la molette) ; à droite la **fiche de stats** du joueur (PV, dégâts, attaques par seconde, portée, vitesse, dash, et chaque effet d'objet porté), calculée par `scripts/combat/player_stats.gd`, la même source que le combat.
- Sources de loot :
  - Combats ordinaires (45 % de chance) et gardiens, boss ou meute (garanti). **Contre le farm** : au plus **3 objets gagnés en combats ordinaires par étage** ; au-delà, seulement des pièces (gardiens, coffres, quêtes et cristaux comptent à part). La fiche de stats montre ce qu'il en reste sur l'étage.
  - Coffres : deux par étage, dont un **scellé** qui s'ouvre après 2 combats gagnés sur l'étage.
  - PNJ à quêtes (récompense de quête).
  - Cristaux du sommeil profond (30 % de chance de contenir un objet).
- **Rareté** : commun, rare, légendaire. **Hiérarchie à deux axes** : la qualité du butin monte avec l'**étage atteint dans la tour** et avec les **combats gagnés sur l'étage**, plus un bonus selon la source (boss, coffre scellé, quête). Ce n'est jamais garanti : les poids passent d'environ 82/16/2 % à 42/42/16 %. **Chaque légendaire ne tombe qu'une fois par nuit** (après une mort, ceux qu'on a perdus peuvent retomber).
- **Objets mystère et malédictions** : 20 % du butin tombe caché (icône « ? », « Objet mystère ») ; on ne découvre ce que c'est qu'en le prenant. Une fois sur deux, c'est un objet un peu meilleur que la normale ; sinon une **malédiction** qui dure 2 étages (celui-ci compris) : *Ombre jumelle* (un ennemi de plus par combat), *Cœur fêlé* (les coups ennemis font 2 dégâts), *Cauchemar tenace* (ennemis deux fois plus résistants), *Poches trouées* (plus aucun objet à trouver), *Pieds de plomb* (plus lent, dash plus lent). La mort efface les malédictions.

---

## 9. Exploration & rencontres

- Déplacement libre sur la carte de chaque étage.
- **Cauchemars errants** (`scripts/exploration/wanderer.gd`), à la place des rencontres invisibles : 3 sur un petit étage, jusqu'à 6 sur un grand, un de plus en sommeil profond. Chacun incarne une créature de la nuit (qui mène ensuite le combat), erre au hasard et regarde devant lui (un cône discret au sol). S'il voit le rêveur (pas à travers les murs), un « ! » surgit et il le poursuit, mais le rêveur court plus vite et peut le semer. Le toucher alors qu'il ne l'a pas vu (de dos, ou endormi près d'une horloge) est une **embuscade** : les ennemis commencent le combat étourdis. Chaque combat gagné sur l'étage en retire un (il en reste toujours un). La pression de l'étage (règle du mardi, Veilleuse, règle du samedi) change leur nombre, leur vue et leur vitesse.
- **PNJ** : présents sur 85 % des étages paradoxaux et 35 % des profonds. Ils proposent une quête courte : gagner N combats sur l'étage, ou rapporter un objet perdu à l'autre bout de l'étage.
- **Décors interactifs** : étoiles (rendent 1 PV perdu ; laissées en place si les PV sont pleins), lunes (flèche vers le portail), horloges (les cauchemars errants s'endorment 15 s), champignons (spores : embuscade), cristaux (peuvent contenir un objet), bougies (restent allumées), et d'autres qui réagissent simplement au passage.

---

## 10. Direction artistique & son

- **2D pixel art** (1 pixel = 2 pixels écran), généré par `tools/gen_pixel_art.py` puis retouchable.
- **Polices** : *Pixelify Sans* (pixel) pour les titres, les bannières, le nom des boss et les chiffres, pour rester dans le style des sprites ; *Nunito* pour les textes longs (récit, objets), plus lisible.
- Chaque famille d'étage a un traitement visuel distinct : paradoxal lumineux et coloré, profond dans la pénombre avec une lumière autour du joueur.
- Rêve / cauchemar : palettes claires ou sombres.
- **Cinématique d'introduction** : quatre plans en 3D, rendus en pixel art dans Blender (640×360, sans lissage, couleurs postérisées) par `tools/blender/intro_cinematic.py`, joués en vidéo (`assets/cinematics/intro/`). Le texte, les paupières et l'écran-titre restent dessinés par Godot par-dessus (`scripts/story/intro.gd`). Les **sept fins de nuit** sont faites de la même façon (`tools/blender/endings_cinematic.py`, vidéos dans `assets/cinematics/fins/`, `scripts/story/endings.gd`) : une scène par nuit, et deux pour le dimanche (l'aube où les tours se dissolvent, puis le réveil).
- Retours de combat : flash à l'impact, arrêt sur image (les coups rapprochés ne s'additionnent pas), secousses d'écran lisses qui croissent avec la force du coup, chiffres de dégâts (dorés pour un coup fort), recul visuel de l'ennemi touché, ennemi qui éclate en blanc à sa mort, coup qui balaie son arc, images fantômes et étirement pendant le dash, voile rouge quand on perd un cœur (chaque effet désactivable dans les Paramètres). Une attaque ou un dash demandé juste avant la fin de sa recharge part dès qu'il est prêt (`scripts/combat/player_combat.gd`, `scripts/visual/fx.gd`).
- **Interface** : HUD commun à la carte et à l'arène (`scripts/ui/game_hud.gd`) dans des bulles translucides : en haut à gauche les cœurs (un cœur perdu tremble et blanchit, le dernier bat), la jauge de dash et le lieu ; en haut à droite l'objet actif (icône, touche, charges), le nombre d'objets passifs et les pièces. Les messages s'affichent dans une bulle à la taille du texte (`scripts/ui/toast.gd`), la barre du boss porte son nom et s'éclaire à chaque coup, « Victoire ! » et « Vaincu... » surgissent au centre. Les panneaux du menu apparaissent en fondu, les boutons du menu principal en cascade.
- **Bruitages des cinématiques** : l'intro et les fins de nuit jouent des bruitages calés sur l'image (la veilleuse qui grésille, la porte, le tonnerre du jeudi, l'étoile du mardi...), listés dans `scripts/story/intro.gd` et `scripts/story/endings.gd`.
- **Son** : effets sonores enregistrés sous licence CC0 (voir `CREDITS.md`) : bruitages de Kenney (tissu, impacts doux, verre, cloches, pièces), plusieurs variantes tirées au hasard, importés par `tools/import_sfx.py`. **Musiques originales**, écrites dans `tools/compose_music.py` (partitions dans `music/`, retouchables dans MuseScore) et jouées par MuseScore 4 avec les Muse Sounds : *Rêverie* (menus et sommeil paradoxal : harpe, piano, célesta), *Profond* (sommeil profond : bourdon grave, chœur, soupirs des altos), *Combat* (cordes piquées façon Hollow Knight) et *Cauchemar* (boss : cuivres, timbales, chœur). Chaque nuit a aussi **son thème**, joué sur la carte (`tools/night_music.py`) : berceuse de boîte à musique le lundi, pendule de marimba le mardi, hésitation entre mineur et majeur le mercredi, cors et timbales qui butent le jeudi, altos et chœur le vendredi, piano et vibraphone clairsemés le samedi, battement de cœur puis aube en majeur le dimanche. En sommeil profond, le thème de la nuit passe sous un filtre (comme entendu de loin) ; les profondeurs gardent *Profond*. Tous les morceaux sont au même volume perçu (−20 LUFS sur la carte, −18 en combat, mesurés par ffmpeg) et encodés en Ogg Vorbis.

---

## 11. Questions ouvertes à trancher

- **Texte définitif du récit** : le premier jet de `scripts/story.gd` est à relire et réécrire.
- **Cosmétiques** : des tenues ou des veilleuses à débloquer ?

*Tranché depuis la première version : 7 nuits (une semaine), hub marchable pour les choisir, mode Speedrun (chrono global, fin = réveil), déblocage (terminer la nuit de la veille), taux de rencontre (4 % / 7 %), nature des achats (objets passifs), contenu propre à chaque nuit (bestiaire, lieux, règles d'étage, cinématique de fin), modes Normal / Cauchemar, recul de 2 étages à la mort, fin du jeu global (une nouvelle semaine plus dure), méta-progression (améliorations permanentes), fuite payante, objets gardés à la mort.*

---

## 12. Prochaines étapes

- Relire une dernière fois le texte du récit (`scripts/story.gd`).
- Tests : `tools/run_tests.sh` lance tous les tests sans fenêtre ; GitHub les rejoue à chaque push (`.github/workflows/tests.yml`).
- Équilibrage en jeu (nombre d'ennemis, prix de la boutique, chrono du speedrun, taux de rencontre).
