# Document de Game Design — [Titre provisoire]
*Un roguelite d'action en 2D pixel art, sur PC*

---

## 1. Pitch

Le joueur incarne un **voyageur du rêve** qui explore son propre sommeil. Chaque **tour représente une nuit différente**, avec sa propre "personnalité" : certaines nuits sont paisibles, d'autres bien plus tourmentées — et ce niveau de tourment définit directement la difficulté de la tour.

Le jeu mêle exploration façon *Pokémon* (déplacement sur une carte, rencontres aléatoires) et combat d'action nerveux façon *Hadès*, dans un cadre roguelite exigeant : la mort est punitive, la progression n'est jamais garantie, et chaque run est différente.

---

## 2. Univers & Narration

- Le joueur explore **son propre sommeil**. Chaque **tour = une nuit différente** de sa vie de rêveur.
- Chaque tour (nuit) a son ambiance propre : certaines nuits sont calmes, d'autres bien plus tourmentées — reflet de l'état d'esprit du personnage à ce moment de sa vie.
- Les étages d'une même tour ne suivent **aucun ordre logique fixe** — l'ordre est aléatoire à chaque run, pour refléter la non-linéarité réelle du sommeil.
- Deux grandes familles d'étages, alternant de façon imprévisible au sein d'une tour :
  - **Sommeil paradoxal** : rythme rapide, ambiance vive et changeante, plus de PNJ et d'événements narratifs, rebondissements fréquents.
  - **Sommeil profond** : rythme plus lent, ambiance sombre/oppressante, moins de PNJ mais mobs plus dangereux.
- **Les PNJ font partie intégrante du rêve lui-même** — ce sont des habitants propres à cet univers onirique, pas des représentations d'autres personnes.
- **Tours difficiles = nuits plus tourmentées** : les nuits les plus dures correspondent à des périodes où le personnage porte des peurs plus profondes ou des problèmes de vie plus lourds — la difficulté est donc directement liée à l'état intérieur du personnage à ce moment-là, et justifiée narrativement.
- **Fil rouge narratif** : les nuits suivent une forme de chronologie dans la vie du personnage. En débloquant et en traversant les tours dans l'ordre, le joueur découvre progressivement des fragments de ce qui lui est arrivé — un moteur narratif pour donner envie d'avancer, au-delà du simple défi de gameplay. Chaque nuit tourmentée peut ainsi correspondre à un événement ou une période précise de sa vie.

---

## 3. Boucle de gameplay

1. Le joueur explore la carte d'un étage (déplacement libre).
2. Une **rencontre aléatoire** se déclenche (façon herbes hautes de Pokémon).
3. Transition stylisée (écran qui se déforme/ondule, façon bascule dans le rêve) → le joueur est **enfermé dans une arène de combat séparée**, pré-conçue selon le type de mob/biome de l'étage.
4. Combat en **temps réel** (dash, esquive avec i-frames, attaques, patterns de mobs lisibles — inspiration Hadès).
5. Victoire → retour sur la carte d'exploration, loot potentiel.
6. Exploration de PNJ (quêtes) et coffres, en plus des combats, comme sources de loot.
7. Progression à travers les étages jusqu'à la fin de la tour (le rêveur se réveille) ou jusqu'à la mort.
8. Mort → reset du stuff de run, le joueur redescend de 5 étages, nouveau tirage aléatoire au-dessus (voir Structure & Difficulté).

---

## 4. Combat

- **Temps réel**, inspiration directe *Hadès* : dash avec i-frames, combos courts, moveset lisible.
- Arène séparée de la map d'exploration (option la plus simple techniquement — pas de gestion de collision complexe avec le décor d'exploration).
- 3-4 arènes pré-conçues par étage, réutilisées pour plusieurs rencontres, avec variations visuelles selon le type de mob.
- Les mobs ont des patterns d'attaque télégraphiés clairement (lisibilité avant tout, pour une difficulté juste).
- Piste à explorer : transition différente selon le type d'étage (douce/floue pour sommeil paradoxal, brutale/saccadée pour sommeil profond) — pas de coût technique supplémentaire, juste un habillage de la transition existante.

---

## 5. Structure des tours & difficulté

- Chaque tour est indépendante des autres (nuit différente = tour différente) et possède un **nombre limité d'étages** : narrativement, la tour se termine quand le personnage se réveille — pas de tour infinie.
- **Ordre des étages aléatoire** à chaque run, alternant sommeil paradoxal / sommeil profond.
- **Courbe de difficulté** : progression liée au *numéro d'étage atteint* (l'étage n°8 est toujours plus dur que le n°3, quel que soit son type), avec un **modificateur de type** en surcouche (un sommeil profond est toujours un peu plus oppressant/dangereux qu'un paradoxal du même palier).
- **À la mort** : le joueur redescend de 5 étages en dessous de sa position actuelle, avec un **nouveau tirage aléatoire des étages au-dessus** de ce point. Une run n'est donc jamais totalement perdue, mais recule concrètement, et le chemin à refaire au-dessus est toujours différent.

---

## 6. Modes de jeu & sélection des tours

- **Écran de sélection en début de partie** : le joueur choisit quelle tour (quelle nuit) explorer.
- **Déblocage progressif** : les tours les plus difficiles se débloquent en terminant les tours plus simples.
- **Nombre de tours** : non fixé pour l'instant, pensé pour pouvoir s'agrandir au fil du développement (contenu extensible plutôt que figé dès la V1).
- **Deux modes de jeu** :
  - **Mode Normal** : la boucle telle que décrite dans ce document (mort = recul de 5 étages, pas de contrainte de temps).
  - **Mode Speedrun** : un timer représente le moment où le rêveur va se réveiller — le joueur doit progresser avant l'expiration du temps, ce qui ajoute une pression supplémentaire et un objectif de rejouabilité orienté performance/vitesse.

---

## 7. Méta-progression

- Entre les runs, le joueur gagne des **pièces** (indépendantes du loot en run, qui reset toujours à la mort).
- Ces pièces permettent d'**acheter des items** en dehors des runs, pour faciliter les tentatives suivantes.
- Ce système garantit que même en cas de mort, le joueur repart avec un sentiment de progression tangible (contrairement au stuff en run, qui lui reset entièrement).
- À définir plus tard : nature exacte de ces items (boosts temporaires, débloquage de capacités permanentes, cosmétiques, etc.) — voir Questions ouvertes.

---

## 8. Système de loot

- **Reset complet du stuff de run à chaque mort** (roguelite pur) — justifié narrativement par le réveil/redémarrage du rêve.
- Trois sources de loot :
  - Combats aléatoires (drop de mobs).
  - PNJ à quêtes (récompense de quête).
  - Coffres liés à des quêtes/objectifs.
- **Hiérarchie de rareté à deux axes** :
  - Progression *dans l'étage* (plus on avance dans un étage, meilleur le loot potentiel).
  - Progression *dans la tour* (les étages hauts ont un meilleur plafond de rareté).
- Degré de randomness variable selon le palier atteint (pas juste "rare ou pas" — une vraie plage aléatoire par palier, à définir précisément).

---

## 9. Exploration & rencontres

- Déplacement libre sur la carte de chaque étage.
- Rencontres **aléatoires**, non visibles à l'avance (façon herbes hautes).
- Taux de rencontre à moduler selon le type d'étage (à définir — un sommeil profond pourrait avoir un taux plus élevé pour renforcer l'oppression, par exemple).
- PNJ visibles et non hostiles, proposant des quêtes courtes (éliminer X mobs, récupérer un objet, etc.), habitants du rêve indépendants du rêveur.
- Coffres présents sur la map, potentiellement liés à des petites énigmes ou quêtes.

---

## 10. Direction artistique

- **2D pixel art**, choisi pour rester simple et efficace à produire.
- Chaque tour (nuit) a une identité visuelle propre liée à son degré de tourment (nuits calmes vs nuits de peurs profondes).
- Chaque famille d'étage (paradoxal / profond) a un traitement visuel distinct (couleurs, densité de détails, luminosité).
- Les arènes de combat peuvent avoir un style renforcé/déformé par rapport à la carte d'exploration, pour accentuer la sensation d'un basculement dans le rêve.

---

## 11. Questions ouvertes à trancher

- **Détail du fil rouge narratif** : comment les fragments de vie du personnage sont-ils révélés concrètement (cinématiques courtes, objets/journaux à trouver en jeu, dialogues de PNJ, texte entre les tours) ? Et l'ordre des tours débloquées suit-il forcément la chronologie de vie, ou peut-il y avoir des sauts temporels ?
- **Nature des items de méta-progression** : boosts temporaires, capacités permanentes, cosmétiques ? À préciser.
- **Nombre de tours / structure globale du jeu** : combien de tours au total, y a-t-il une fin au jeu global (toutes les tours terminées) ?
- **Détail du système de déblocage** : critère précis pour débloquer une tour plus dure (juste "terminer" la précédente, ou un objectif plus spécifique) ?
- **Détail du mode Speedrun** : le timer est-il global sur toute la tour, ou reset-il à chaque étage ? Un échec au timer équivaut-il à une mort classique ?
- **Taux de rencontre exact** par type d'étage.

---

## 12. Prochaines étapes suggérées

- Trancher les questions ouvertes restantes, en particulier le détail du mode Speedrun et de la méta-progression.
- Prototyper la boucle de base : déplacement + rencontre aléatoire + transition + combat simple.
- Concevoir 2-3 exemples concrets d'étages (un paradoxal, un profond) avec mobs et loot associés, pour valider le concept d'écosystème par étage.
