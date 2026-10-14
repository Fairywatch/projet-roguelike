# Document de Game Design — Dream Dive
*Un roguelite d'action en 2D pixel art, sur PC*

---

## 1. Pitch

Le joueur incarne un **voyageur du rêve** qui explore son propre sommeil. Chaque **tour représente une nuit différente**, avec sa propre "personnalité" : certaines nuits sont paisibles, d'autres bien plus tourmentées — et ce niveau de tourment définit directement la difficulté de la tour.

Le jeu mêle exploration façon *Pokémon* (déplacement sur une carte, rencontres aléatoires) et combat d'action nerveux façon *Hadès*, dans un cadre roguelite exigeant : la mort est punitive, la progression n'est jamais garantie, et chaque run est différente.

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
3. Une **rencontre aléatoire** se déclenche (façon herbes hautes de Pokémon).
4. Transition stylisée selon le type d'étage → le joueur est **enfermé dans une arène de combat séparée**.
5. Combat en **temps réel** contre 2 à 4 ennemis (dash, esquive avec i-frames, attaques, patterns lisibles — inspiration Hadès).
6. Victoire → butin éventuel posé au sol (à prendre ou non), pièces, retour sur la carte.
7. Pour changer d'étage, le joueur prend le **portail**, toujours **gardé par un boss** : l'étage ne change qu'après la victoire.
8. Fin de la tour (le rêveur se réveille) ou mort → retour au menu.
9. Mort → reset du stuff de run, le joueur redescend de 5 étages, nouveau tirage aléatoire au-dessus (voir Structure & Difficulté).

---

## 4. Combat

- **Temps réel**, inspiration directe *Hadès* : dash avec i-frames, attaque en arc, objet actif. Touches : ZQSD (ou flèches) pour se déplacer, J attaque, K dash, L objet actif, E interagir, Tab passifs.
- Arène séparée de la map d'exploration, habillée avec les tuiles du type d'étage.
- **Rencontres** : 2 à 4 ennemis (un de plus tous les 4 étages). Les **boss combattent seuls**.
- Les mobs ont des patterns d'attaque **télégraphiés** clairement (lisibilité avant tout) : la difficulté augmente leurs PV, leur vitesse et leur cadence, **jamais la durée des télégraphes**.
- Brève invincibilité après un coup encaissé (plusieurs ennemis peuvent frapper en même temps).
- **PV façon Isaac** : les PV perdus le restent d'un combat à l'autre pendant toute la nuit. On les récupère avec les étoiles de la carte (+1 PV, pas au-delà du max), le Mouchoir usagé et les passifs de soin. Un +PV max arrive plein. PV affichés sur la carte.
- **Gardiens de portail** : un boss tiré au hasard dans le pool de la nuit (3 boss × 4 versions, jamais deux fois le même dans une nuit) ; le dernier portail de la nuit est gardé par le **boss final** de la nuit, multi-phases.
- **Transition selon le type d'étage** : douce et ondulante (paradoxal), brutale et saccadée (profond ; fondu simple si les flashs sont désactivés).
- Bestiaire : un par nuit (4 créatures, 3 boss, 1 boss final), détaillé dans [docs/bestiaire.md](bestiaire.md).

---

## 5. Structure des tours & difficulté

- Chaque tour est indépendante des autres (nuit différente = tour différente) et possède un **nombre limité d'étages** : narrativement, la tour se termine quand le personnage se réveille — pas de tour infinie.
- **Ordre des étages aléatoire** à chaque run, alternant sommeil paradoxal / sommeil profond.
- **Taille des étages** : petits au début (16×10 cases), de plus en plus grands jusqu'au dernier étage (34×20).
- **Courbe de difficulté** : +8 % par étage atteint, +15 % en sommeil profond (modificateur de type), plus le bonus propre à la nuit.
- **À la mort** : le joueur redescend de 5 étages en dessous de sa position actuelle, avec un **nouveau tirage aléatoire des étages au-dessus** de ce point. Une run n'est donc jamais totalement perdue, mais recule concrètement.
- **Quitter le jeu en plein combat compte comme une mort** (pas de fuite par la fermeture du jeu).
- **Plongée négative** : à l'étage 0, un second portail (rouge) mène aux profondeurs (étages -1 à -10), plus dangereuses (les boss de la nuit y rôdent). Les remonter rapporte un butin ; y mourir referme le passage pour la partie.

---

## 6. Modes de jeu & sélection des tours

- **Menu principal** : Continuer (partie sauvegardée), Choisir une nuit (hub), Paramètres.
- **Hub de la semaine** : un lieu où l'on marche, comme un menu vivant. Les 7 tours y sont alignées du lundi au dimanche, de plus en plus sombres et tordues. On y trouve aussi la Marchande de lune (boutique) et l'horloge du réveil (mode speedrun). Entrer dans une autre nuit que celle en cours demande une confirmation (la partie en cours est abandonnée).
- **Déblocage progressif** : on ne peut entrer dans une nuit qu'après avoir terminé celle de la veille. Les nuits terminées portent une étoile.
- **Les 7 nuits** (données dans `scripts/towers.gd`) :

| Nuit | Émotion | Étages | Difficulté | Cauchemars | Récompense |
|---|---|---|---|---|---|
| Lundi | Fatigue | 6 | +0 % | 10 % | 15 |
| Mardi | Stress | 7 | +15 % | 20 % | 25 |
| Mercredi | Doute | 8 | +30 % | 35 % | 35 |
| Jeudi | Frustration | 9 | +45 % | 50 % | 50 |
| Vendredi | Épuisement | 10 | +60 % | 65 % | 65 |
| Samedi | Solitude | 11 | +75 % | 80 % | 80 |
| Dimanche | Angoisse | 12 | +90 % | 95 % | 120 |

- Pour l'instant, les nuits ne diffèrent que par ces paramètres et leur tour dans le hub : leur contenu propre reste à concevoir.
- **Mode Normal** : la boucle telle que décrite dans ce document.
- **Mode Speedrun** : un **chrono unique pour toute la nuit** (75 s par étage), qui ne tourne qu'en jeu. À zéro, **le réveil sonne** : la nuit s'arrête, sans récompense. La mort garde sa règle habituelle, et le chrono continue de tourner. Meilleur temps enregistré par nuit.

---

## 7. Méta-progression

- Entre les runs, le joueur gagne des **pièces** (indépendantes du loot en run, qui reset toujours à la mort) : 1 par combat gagné, 3 par gardien, 2 par quête, et une récompense en fin de nuit.
- La **boutique des songes** (menu) propose 3 objets passifs, renouvelés après chaque réveil (mort ou fin de nuit). Prix selon la rareté (15 / 35 / 80).
- Un achat rejoint la nuit en cours, ou attend dans le **sac de départ** de la prochaine nuit.
- Ce système garantit que même en cas de mort, le joueur repart avec un sentiment de progression tangible.

---

## 8. Système de loot

- **Reset complet du stuff de run à chaque mort** (roguelite pur) — justifié narrativement par le réveil/redémarrage du rêve.
- **Objets passifs** : cumulables sans limite (y compris plusieurs exemplaires du même). Chacun est décrit par des effets chiffrés (PV, dégâts, vitesse, critiques, esquive, vol de vie, bouclier, ennemis affaiblis...) : ajouter un passif ne demande pas de code.
- **Objet actif** : un seul à la fois, utilisé avec E en combat, 3 charges. Un combat gagné rend une charge. Prendre un nouvel actif laisse l'ancien au sol, avec ses charges restantes.
- Le butin tombe **au sol** : le joueur choisit de le prendre (E) ou non. Les objets au sol restent sur l'étage.
- Sources de loot :
  - Combats aléatoires (45 % de chance) et boss (garanti).
  - Coffres : deux par étage, dont un **scellé** qui s'ouvre après 2 combats gagnés sur l'étage.
  - PNJ à quêtes (récompense de quête).
  - Cristaux du sommeil profond (30 % de chance de contenir un objet).
- **Rareté** : commun, rare, légendaire. **Hiérarchie à deux axes** : la qualité du butin monte avec l'**étage atteint dans la tour** et avec les **combats gagnés sur l'étage**, plus un bonus selon la source (boss, coffre scellé, quête). Ce n'est jamais garanti : les poids passent d'environ 82/16/2 % à 42/42/16 %.

---

## 9. Exploration & rencontres

- Déplacement libre sur la carte de chaque étage.
- Rencontres **aléatoires**, non visibles à l'avance (façon herbes hautes) : 4 % par demi-seconde de marche en sommeil paradoxal, 7 % en sommeil profond (oppression).
- **PNJ** : présents sur 85 % des étages paradoxaux et 35 % des profonds. Ils proposent une quête courte : gagner N combats sur l'étage, ou rapporter un objet perdu à l'autre bout de l'étage.
- **Décors interactifs** : étoiles (rendent 1 PV perdu ; laissées en place si les PV sont pleins), lunes (flèche vers le portail), horloges (pas de rencontre pendant 15 s), champignons (spores : embuscade), cristaux (peuvent contenir un objet), bougies (restent allumées), et d'autres qui réagissent simplement au passage.

---

## 10. Direction artistique & son

- **2D pixel art** (1 pixel = 2 pixels écran), généré par `tools/gen_pixel_art.py` puis retouchable.
- Chaque famille d'étage a un traitement visuel distinct : paradoxal lumineux et coloré, profond dans la pénombre avec une lumière autour du joueur.
- Rêve / cauchemar : palettes claires ou sombres.
- Retours de combat : flash à l'impact, arrêt sur image, secousses, particules (chaque effet désactivable dans les Paramètres).
- **Son** : uniquement des enregistrements sous licence CC0 (voir `CREDITS.md`). Effets : bruitages de Kenney (tissu, impacts doux, verre, cloches, pièces), plusieurs variantes tirées au hasard, importés par `tools/import_sfx.py`. Musiques : morceaux d'OpenGameArt téléchargés par `tools/import_music.py` (piano onirique pour le sommeil paradoxal, ambiance sombre pour le profond, thème orchestral tendu pour les combats, épique pour les boss).

---

## 11. Questions ouvertes à trancher

- **Texte définitif du récit** : le premier jet de `scripts/story.gd` est à relire et réécrire.
- **Contenu propre à chaque nuit** : histoire, bestiaire, biomes et boss spécifiques (les 7 nuits ne diffèrent encore que par leurs paramètres).
- **Fin du jeu global** : que se passe-t-il quand le dimanche est terminé (fin de la semaine, nouvelle semaine plus dure) ?
- **Méta-progression au-delà des passifs** : capacités permanentes, cosmétiques ?

*Tranché depuis la première version : 7 nuits (une semaine), hub marchable pour les choisir, mode Speedrun (chrono global, fin = réveil), déblocage (terminer la nuit de la veille), taux de rencontre (4 % / 7 %), nature des achats (objets passifs).*

---

## 12. Prochaines étapes

- Donner à chaque nuit de la semaine son contenu : ambiance liée à son émotion, mobs et boss propres, particularité d'étage, fragment de récit.
- Trancher le fil rouge narratif et sa mise en scène.
- Équilibrage en jeu (nombre d'ennemis, prix de la boutique, chrono du speedrun, taux de rencontre).
