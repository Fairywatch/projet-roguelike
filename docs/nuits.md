# Les lieux des nuits

*Fiches validées. Avancement de la production :*

| Nuit | État |
|---|---|
| Lundi | **Produit** (`tools/gen_places.py`, `scripts/visual/places.gd`, `scripts/exploration/rules/lundi.gd`, testé par `tests/test_places.gd`) |
| Mardi | **Produit** (règle : `scripts/exploration/rules/mardi.gd`) |
| Mercredi | **Produit** (règle : `scripts/exploration/rules/mercredi.gd`) |
| Jeudi | **Produit** (règle : `scripts/exploration/rules/jeudi.gd`) |
| Vendredi | **Produit** (règle : `scripts/exploration/rules/vendredi.gd`) |
| Samedi | **Produit** (règle : `scripts/exploration/rules/samedi.gd`) |
| Dimanche | Fiche |

## Règles retenues

- **Chaque nuit a deux lieux** : un pour le **sommeil paradoxal** (clair, coloré, étrange), un pour le **sommeil profond** (sombre, plus inquiétant). Ce sont des **lieux abstraits**, nés de l'émotion de la nuit, pas des lieux de la vraie vie.
- **Nouvelles tuiles** (sol et murs) pour chaque lieu, et **décors propres** autour.
- **Les décors interactifs gardent leur effet mais changent d'apparence** selon le lieu. Pour rester lisibles, chaque effet garde **sa couleur de lueur** d'une nuit à l'autre :

| Effet | Famille | Lueur | Aujourd'hui |
|---|---|---|---|
| Soigne 1 PV | paradoxal | dorée | Étoile |
| Montre le portail | paradoxal | blanche | Lune |
| Pas de rencontre pendant 15 s | paradoxal | orange | Horloge |
| Éclate (pour le plaisir) | paradoxal | bleu pâle | Bulle |
| S'allume et reste allumé | profond | ambre | Bougie |
| Déclenche un combat | profond | turquoise | Champignon |
| Peut contenir un objet | profond | violette | Cristal |

- **Les étages cauchemar** gardent leur traitement actuel : le lieu est le même, la palette s'assombrit et rougit.
- **Une règle d'étage par nuit**, liée à l'émotion. Elle **monte au fil de la nuit** : à peine perceptible au premier étage, à son maximum au dernier. Elle joue surtout sur l'**exploration**. En combat, elle ne touche jamais à la lisibilité des télégraphes.
- **L'arène de combat** prend les tuiles du lieu de l'étage, comme aujourd'hui.

---

## Lundi — Fatigue

*Le sommeil qui gagne : tout est mou, lent, ouaté.*

### Paradoxal : la Mer de coton
Une étendue de couettes et de nuages où l'on s'enfonce un peu à chaque pas.
- **Palette** : lavande, bleu pâle, blanc crème ; lumière dorée et douce.
- **Sol** : couette matelassée, coutures en losange. **Murs** : piles d'oreillers.
- **Décors** : plumes qui flottent, rideaux qui ondulent, lampes de chevet éteintes.
- **Interactifs** : soin = *veilleuse étoile* · guide = *lanterne de rêve* · pause = *réveil endormi* (il ronfle, le temps s'arrête) · bulle = *bulle de bâillement*.

### Profond : la Brume de sommeil
Un marais de brume grise où le sol devient de la mousse et où les draps pendent du vide.
- **Palette** : gris-bleu, ardoise ; lumière froide et voilée.
- **Sol** : mousse épaisse, flaques de brume. **Murs** : rideaux lourds et sombres.
- **Décors** : draps suspendus, fauteuils à moitié engloutis.
- **Interactifs** : lumière = *lampe de chevet* · combat = *tas de draps qui respire* · objet = *coffre à jouets*.

### Règle : Paupières lourdes
De temps en temps, pendant l'exploration, l'écran **se ferme comme des paupières** (un fondu au noir bref), puis se rouvre.
- **Premier étage** : rare et très court (environ toutes les 30 s, 0,3 s).
- **Dernier étage** : fréquent et plus long (environ toutes les 10 s, 0,8 s).
- **En combat** : rien.

---

## Mardi — Stress

*Le temps qui manque : tout tourne, tout presse.*

### Paradoxal : les Engrenages
Un mécanisme géant où l'on marche sur des cadrans et entre des rouages qui tournent.
- **Palette** : cuivre, laiton, ivoire ; lumière vive et jaune.
- **Sol** : cadrans d'horloge gravés. **Murs** : rouages imbriqués.
- **Décors** : aiguilles plantées dans le sol, feuilles qui volent, sabliers.
- **Interactifs** : soin = *étoile dorée de bonne note* · guide = *boussole* · pause = *sablier retourné* · bulle = *bulle de stress*.

### Profond : la Salle des pendules
Des couloirs sombres où d'immenses balanciers vont et viennent.
- **Palette** : brun sombre, bordeaux ; lumière tremblante.
- **Sol** : parquet noir ciré. **Murs** : boiseries et horloges comtoises.
- **Décors** : balanciers, papiers froissés, tiroirs entrouverts.
- **Interactifs** : lumière = *lampe de bureau* · combat = *réveil qui sonne* · objet = *tiroir verrouillé*.

### Règle : Tic-tac
**Plus on reste sur un étage, plus les rencontres deviennent fréquentes** : le stress monte quand on traîne. Le compteur repart à zéro à chaque nouvel étage. Une petite horloge discrète dans l'interface montre où on en est.
- **Premier étage** : la pression monte très lentement.
- **Dernier étage** : elle monte vite, il faut aller droit au but.

---

## Mercredi — Doute

*Ne plus savoir quoi croire : tout se reflète, tout se ressemble.*

### Paradoxal : le Palais des reflets
Des galeries de verre et de miroirs où chaque chose a son double.
- **Palette** : argent, bleu ciel, rose nacré ; lumière irisée.
- **Sol** : carrelage-miroir. **Murs** : parois de verre.
- **Décors** : cadres vides, statues sans visage, escaliers qui ne mènent nulle part.
- **Interactifs** : soin = *reflet d'étoile* · guide = *fil d'Ariane* · pause = *pièce figée en plein vol* · bulle = *bulle-point d'interrogation*.

### Profond : le Carrefour brumeux
Des routes qui se croisent dans le brouillard, sans jamais dire laquelle est la bonne.
- **Palette** : vert-de-gris, gris mousse ; lumière blafarde.
- **Sol** : vieux pavés. **Murs** : haies taillées.
- **Décors** : panneaux aux flèches contradictoires, lampadaires, bancs.
- **Interactifs** : lumière = *lampadaire* · combat = *masque posé au sol* · objet = *valise abandonnée*.

### Règle : Faux portails
L'étage contient des **portails leurres** en plus du vrai. En prendre un **ramène au point de départ de l'étage**. Le vrai se reconnaît à un détail qu'on apprend à repérer : sa lueur est stable, les faux scintillent.
- **Premier étage** : un seul faux portail, qui scintille beaucoup.
- **Dernier étage** : trois faux portails, presque identiques au vrai.

---

## Jeudi — Frustration

*Rien n'avance : on attend, on bute, ça chauffe.*

### Paradoxal : l'Usine à attendre
Des files d'attente infinies et des tapis roulants qui ne mènent nulle part.
- **Palette** : gris acier, orange de chantier ; lumière de néons.
- **Sol** : dalles grises à bandes jaunes. **Murs** : guichets fermés.
- **Décors** : barrières de file d'attente, tampons géants « REFUSÉ », tickets par terre.
- **Interactifs** : soin = *ticket gagnant* · guide = *panneau SORTIE* · pause = *feu rouge* · bulle = *bulle de colère*.

### Profond : la Fournaise
Des couloirs de briques chauffées au rouge, pleins de vapeur.
- **Palette** : rouge sombre, noir, orange braise ; lumière de forge.
- **Sol** : plaques de métal rivetées. **Murs** : briques rougeoyantes.
- **Décors** : tuyaux, chaudières, vapeur.
- **Interactifs** : lumière = *braise* · combat = *cocotte qui siffle* · objet = *coffre-fort*.

### Règle : Portes closes
Des **barrières** ferment certains passages. Elles s'ouvrent **après avoir gagné un combat sur l'étage**. Le chemin vers le portail reste toujours possible, mais il faut se battre pour l'ouvrir.
- **Premier étage** : une seule barrière, sur un détour.
- **Dernier étage** : trois barrières, dont une sur le chemin du portail.

---

## Vendredi — Épuisement

*Tout pèse : chaque pas coûte, on n'en peut plus.*

### Paradoxal : la Montagne de cartons
Des empilements de cartons, de sacs et de charges à porter, sous une lumière de fin de journée.
- **Palette** : beige, sable, brun clair ; lumière orangée et rasante.
- **Sol** : parquet couvert de rubans adhésifs. **Murs** : cartons empilés.
- **Décors** : sacs, valises, piles qui penchent.
- **Interactifs** : soin = *tasse de thé chaud* · guide = *phare de poche* · pause = *banc* (on s'assoit, le temps s'arrête) · bulle = *bulle de soupir*.

### Profond : les Mines de plomb
Des galeries basses où le plafond semble descendre.
- **Palette** : gris plomb, bleu nuit ; lumière de lampe à huile.
- **Sol** : roche sombre et rails. **Murs** : étais de bois et roche.
- **Décors** : wagonnets, pioches, gravats.
- **Interactifs** : lumière = *lampe de mineur* · combat = *sac qui bouge* · objet = *filon*.

### Règle : Fardeau
**Le rêveur ralentit peu à peu** pendant l'exploration d'un étage. Le soin (thé) et la pause (banc) le remettent d'aplomb. En combat, **le dash se recharge un peu plus lentement**.
- **Premier étage** : ralentissement à peine sensible, dash normal.
- **Dernier étage** : jusqu'à −30 % de vitesse sur la carte, dash 25 % plus lent.

---

## Samedi — Solitude

*Le temps libre, et personne : tout est grand, beau et vide.*

### Paradoxal : la Salle de bal vide
Une immense salle de bal dorée, lustres allumés, où personne ne danse.
- **Palette** : or pâle, blanc cassé, bleu nuit ; lumière froide de lune.
- **Sol** : marbre en damier. **Murs** : colonnes et hautes fenêtres.
- **Décors** : chaises vides en cercle, guirlandes éteintes, verres posés.
- **Interactifs** : soin = *lettre reçue* · guide = *phare lointain* · pause = *boîte à musique* · bulle = *bulle-souvenir*.

### Profond : le Quai désert
Des pontons au-dessus d'une eau noire, dans le brouillard.
- **Palette** : gris-bleu, noir d'encre ; la seule lumière vient d'un phare au loin.
- **Sol** : planches de ponton. **Murs** : eau noire et brume.
- **Décors** : bancs vides, bouées, lampadaires éteints.
- **Interactifs** : lumière = *lanterne flottante* · combat = *téléphone qui sonne* · objet = *bouteille à la mer*.

### Règle : Personne
**Les étages se vident** au fil de la nuit : moins de décors, plus de PNJ de quête, et des **silhouettes au loin qui s'effacent** quand on s'approche. Les rencontres sont **plus rares mais plus nombreuses** quand elles arrivent : la solitude, puis la foule.
- **Premier étage** : encore quelques PNJ, rencontres normales.
- **Dernier étage** : aucun PNJ, rencontres rares mais avec un ennemi de plus.

---

## Dimanche — Angoisse

*La peur de ce qui vient : la lumière s'en va.*

### Paradoxal : le Crépuscule sans fin
Un coucher de soleil qui ne finit jamais, sur un sol de verre qui le reflète.
- **Palette** : orange, rose, violet ; lumière rasante et ombres très longues.
- **Sol** : dalles de verre teinté. **Murs** : silhouettes d'arbres noirs.
- **Décors** : réverbères qui s'allument un à un, horloges fondues, ombres qui s'étirent.
- **Interactifs** : soin = *dernier rayon de soleil* · guide = *fil de lumière* · pause = *soleil figé* · bulle = *bulle de crépuscule*.

### Profond : le Cœur de la nuit
Un noir presque total, où le sol bat comme un cœur et où des veines de lumière courent dans les murs.
- **Palette** : noir, rouge profond ; lumière de veines qui pulse.
- **Sol** : chair sombre qui pulse doucement. **Murs** : parois veinées.
- **Décors** : veines lumineuses, yeux qui s'ouvrent dans le noir.
- **Interactifs** : lumière = *luciole* · combat = *œil fermé* · objet = *boîte scellée*.

### Règle : La nuit se referme
**L'obscurité gagne depuis les bords de l'écran** avec le temps passé sur un étage. Les lumières (soin, guide, lumière) la repoussent un moment. En combat, les bords de l'arène sont plus sombres, mais les télégraphes brillent toujours.
- **Premier étage** : elle avance lentement et s'arrête loin du joueur.
- **Dernier étage** : elle avance vite et ne laisse qu'un cercle autour du rêveur.
