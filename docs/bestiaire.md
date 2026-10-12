# Bestiaire de Dream Dive — fiches à valider

*Fiches validées. Avancement de la production :*

| Nuit | État |
|---|---|
| Lundi | **Produit** (`scripts/combat/mobs/lundi/`, testé par `tests/test_monday.gd`) |
| Mardi | **Produit** (`scripts/combat/mobs/mardi/`, testé par `tests/test_mardi.gd`) |
| Mercredi | **Produit** (`scripts/combat/mobs/mercredi/`, testé par `tests/test_mercredi.gd`) |
| Jeudi | **Produit** (`scripts/combat/mobs/jeudi/`, testé par `tests/test_jeudi.gd`) |
| Vendredi | **Produit** (`scripts/combat/mobs/vendredi/`, testé par `tests/test_vendredi.gd`) |
| Samedi et dimanche | À produire (ces nuits utilisent encore les anciens monstres en attendant) |

## Règles retenues

- **Tout le bestiaire est nouveau** : les 6 ennemis actuels et la Terreur nocturne sont remplacés.
- **Chaque créature incarne l'émotion de sa nuit**, dans son apparence *et* son comportement.
- **Le ton s'assombrit au fil de la semaine** : décalé et presque attendrissant le lundi, oppressant le dimanche. Inspirations : *The Binding of Isaac* (créatures étranges, humour noir), *Hollow Knight* (silhouettes lisibles, boss marquants), *Undertale* (des ennemis qui ont une personnalité, des attaques qui racontent quelque chose).
- **Difficulté lisible** : les télégraphes restent clairs à toutes les nuits ; la difficulté vient de patterns plus riches et de combats plus denses.
- **Pas d'interaction avec le décor** des étages : tout se joue dans l'arène.

### Par nuit

- **4 créatures**, chacune avec une **variante de comportement** (même créature, autre attaque) : **8 ennemis par nuit**.
- **3 boss tirés au hasard** pour les portails, déclinés en variantes : 3 boss × 4 versions (normale, cauchemar, élite, comportement) = 12 combinaisons. Une même combinaison ne sort jamais deux fois dans une même nuit (le dimanche a besoin de 11 boss de portail).
- **1 boss de fin dédié**, très difficile, gardant le dernier portail. Il a **plusieurs phases** et incarne l'épreuve de la nuit (voir `scripts/story.gd`).

### Variantes (valables pour tous les ennemis et les boss tirés au hasard)

| Variante | Quand | Effet |
|---|---|---|
| **Cauchemar** | Étages cauchemar | Teinte sombre, +30 % de PV, un coup de plus dans son pattern |
| **Élite** | Rare (environ 1 sur 10) | Plus grande, aura, +60 % de PV, butin meilleur |
| **Comportement** | Tirée au hasard | Une autre attaque, décrite dans chaque fiche (« Variante ») |

---

## Lundi — Fatigue

*Ton : doux et décalé. Les créatures sont lentes, mais elles ralentissent et endorment.*

| Créature | Apparence | Comportement | Variante |
|---|---|---|---|
| **Bâilleur** | Boule molle façon oreiller, une énorme bouche | Ouvre la bouche (télégraphe) puis **aspire** le joueur vers lui | Expire un nuage de sommeil qui **ralentit** |
| **Mouton insomniaque** | Mouton aux yeux cernés, une barrière sous le bras | Saute par-dessus sa barrière en arc, **onde de choc** à l'atterrissage | Un troupeau de 3 petits moutons qui sautent l'un après l'autre |
| **Veilleuse fatiguée** | Petite lampe qui clignote | Quand elle s'éteint, elle **se téléporte** près du joueur ; lance des orbes de lumière lents | Lance ses orbes **en spirale** |
| **Paupière lourde** | Paupière flottante, cils comme des pattes | Fermée : invulnérable. Ouverte : **rayon** en ligne droite (télégraphé) | Deux paupières qui s'ouvrent à tour de rôle |

**Boss tirés au hasard**
- **La Grande Couette** : une couette géante qui rampe et **recouvre des zones** de l'arène (à éviter), et libère des Bâilleurs.
- **Le Réveil Grincheux** : un réveil qui sonne des **anneaux d'onde de choc** avec des trous pour passer ; il fait « snooze » régulièrement (fenêtre d'attaque).
- **Le Chœur des Bâillements** : trois têtes qui **aspirent à tour de rôle**, dans des directions différentes.

**Boss de fin : La Porte des Voix** *(l'enfant qui écoute les disputes)*
1. La porte tremble ; des **mots-ombres** (« CHUT », « PLUS TARD ») la traversent en salves de projectiles.
2. Elle s'entrouvre : un **noir qui aspire** le joueur et répand un brouillard qui ralentit. On ne la blesse que quand elle grince (fenêtres courtes).
3. Les voix se taisent une à une : patterns plus lents mais plus larges, jusqu'au silence.

---

## Mardi — Stress

*Ton : encore décalé, mais tout s'accélère. Les créatures pressent le joueur et s'accumulent.*

| Créature | Apparence | Comportement | Variante |
|---|---|---|---|
| **Trotteuse** | Aiguille de montre sur pattes | **Fonce en ligne droite**, un peu plus vite à chaque fois | Deux aiguilles dont les trajectoires se croisent |
| **Pile de devoirs** | Pile de copies qui vacille | Lance des feuilles **en éventail** ; plus elle vit, plus la pile grandit et plus elle en lance | Se **divise** en deux petites piles quand on la frappe |
| **Stylo rouge** | Stylo qui coule, regard sévère | Tourne autour du joueur en laissant une **traînée d'encre rouge** blessante | Dessine un grand **X** au sol autour du joueur (télégraphe puis frappe) |
| **Battement** | Cœur nerveux qui palpite | Une **onde de choc à chaque battement**, et les battements accélèrent | Deux cœurs qui battent en rythme |

**Boss tirés au hasard**
- **Le Tableau Noir** : dessine à la craie des **motifs au sol** (télégraphes) qui frappent ensuite, de plus en plus vite.
- **L'Horloge de Classe** : ses aiguilles balaient l'arène comme des **bras rotatifs** qui accélèrent.
- **La Cloche** : sonne des **anneaux concentriques** à franchir au bon moment et appelle des Trotteuses.

**Boss de fin : L'Examen** *(la peur de décevoir)*
1. Une copie géante avec un œil : les **questions** tombent en projectiles en forme de lettres.
2. Le **compte à rebours** : l'arène rétrécit tant qu'on ne lui inflige pas assez de dégâts.
3. **La note** : une pluie d'encre rouge en motifs denses, puis un dernier coup de tampon.

---

## Mercredi — Doute

*Ton : étrange. Les créatures trompent : doubles, leurres, visages qui changent.*

| Créature | Apparence | Comportement | Variante |
|---|---|---|---|
| **Reflet** | Copie du rêveur en verre | **Imite les mouvements du joueur en miroir**, frappe quand il est aligné avec lui | Deux reflets (horizontal et vertical) |
| **Pile ou Face** | Pièce géante qui tourne sur elle-même | Retombe sur pile (**invulnérable**) ou face (vulnérable) : on ne sait qu'au dernier moment | Lance des pièces qui roulent en **courbes** imprévisibles |
| **Carrefour** | Panneau indicateur à plusieurs flèches | Tire deux salves : **l'une réelle, l'autre fausse** (indice visuel discret) | Se téléporte entre 3 positions dont 2 **leurres** |
| **Masque** | Masque flottant | **Change de visage** toutes les quelques secondes : joyeux (charge), triste (larmes en projectiles), vide (invisible) | Porte deux masques et change deux fois plus vite |

**Boss tirés au hasard**
- **Le Miroir Brisé** : se divise en éclats qui reflètent tous le boss ; seul le **vrai** reflet prend des dégâts.
- **Le Labyrinthe** : fait surgir des **murs** dans l'arène et attaque depuis les couloirs.
- **Les Deux Voies** : un boss jumeau ; frapper le mauvais **soigne l'autre**, il faut trouver lequel attaquer.

**Boss de fin : L'Autre Soi** *(qui devenir ?)*
1. Un double du rêveur qui utilise **les mêmes coups que le joueur** : dash, attaque, objet actif.
2. Il se divise en **trois futurs possibles** ; un seul est réel et les deux autres frappent puis disparaissent.
3. Le vrai double cesse d'attaquer quand **le joueur cesse d'attaquer** (façon Undertale) : on gagne en arrêtant de douter... ou on le bat.

---

## Jeudi — Frustration

*Ton : plus sombre. Les créatures s'énervent, bloquent, rebondissent de façon injuste.*

| Créature | Apparence | Comportement | Variante |
|---|---|---|---|
| **Grogne** | Petite boule de poils rouge | **S'énerve à chaque coup reçu** : grossit et accélère ; explose si on la laisse enragée | Une chaîne de 3 Grognes reliées |
| **Porte Close** | Porte sur pattes | **Invulnérable de face** : il faut la frapper de dos ; claque en ondes de choc | Porte tournante qui pivote sans arrêt |
| **Ressort** | Créature-ressort | **Rebondit sur les murs** de l'arène, plus vite à chaque rebond | Se divise à chaque rebond |
| **Cocotte-minute** | Marmite qui siffle | Monte en pression : si on ne la frappe pas assez vite, **explose** en grande zone ; chaque coup libère un jet de vapeur | Deux cocottes reliées qui partagent leur pression |

**Boss tirés au hasard**
- **Le Patron sans visage** : un costume vide qui tamponne « REFUSÉ » en **ondes de choc** et lance des dossiers.
- **Le Tapis Roulant** : des **zones qui repoussent** le joueur pendant qu'il attaque de loin.
- **Le Mur** : un mur qui **avance** ; il faut casser ses briques une à une avant d'être coincé.

**Boss de fin : La Colère** *(l'effort jamais récompensé)*
1. **Le grondement** : des éclairs télégraphiés tombent en motifs.
2. **La rage** : à mi-vie, il accélère et l'arène se couvre de zones brûlantes.
3. **L'orage passe** : il s'essouffle peu à peu ; il faut tenir et frapper au bon moment, sans s'acharner.

---

## Vendredi — Épuisement

*Ton : lourd. Les créatures portent, s'accrochent, se protègent les unes les autres.*

| Créature | Apparence | Comportement | Variante |
|---|---|---|---|
| **Fardeau** | Grosse créature avec des petites sur le dos | Quand on la frappe, elle **lâche ses passagers** qui deviennent des ennemis | Les **lance** sur le joueur |
| **Sangsue de sommeil** | Petite créature collante | **S'accroche au joueur** : le ralentit et vide son dash ; un dash la décroche | S'accroche aux autres ennemis et **les soigne** |
| **Soignant** | Silhouette en blouse, fuyante | **Soigne ou protège** les autres ennemis et fuit le joueur | **Relie deux ennemis** par un lien : invulnérables tant que le lien tient |
| **Bougie fondue** | Bougie qui coule | Laisse des **flaques de cire** qui ralentissent ; rapetisse en perdant de la vie | **Rallume** les ennemis vaincus une fois |

**Boss tirés au hasard**
- **Atlas** : un géant qui porte un monde, **frappe le sol** et fait rouler sa sphère dans l'arène.
- **Le Nid** : une mère-oiseau qui protège ses **œufs**, d'où éclosent des Soignants.
- **Le Balancier** : un énorme pendule qui **balaie** l'arène de plus en plus large.

**Boss de fin : Le Poids du Monde** *(porter les autres jusqu'à ne plus tenir)*
1. Fait de tous ceux qu'il porte : **protégé par des Soignants** qu'il faut faire tomber d'abord.
2. Il **lâche son fardeau** : une vague d'ennemis tombe dans l'arène.
3. Seul et épuisé : très lent, mais chaque coup est **lourd et rare**, et couvre une large zone.

---

## Samedi — Solitude

*Ton : mélancolique. Les créatures fuient, disparaissent, répètent, laissent le vide.*

| Créature | Apparence | Comportement | Variante |
|---|---|---|---|
| **Silhouette** | Ombre de quelqu'un qu'on a connu | **Fuit quand on approche** et lance des souvenirs de loin | Disparaît puis **réapparaît derrière** le joueur |
| **Écho** | Forme floue, contours tremblants | **Répète la dernière attaque du joueur** une seconde plus tard, en zone blessante | Double écho, encore décalé |
| **Chaise vide** | Chaise qui glisse toute seule | **Charge** en glissant à travers l'arène et tourne sur elle-même | Une rangée de chaises qui avancent **en formation** |
| **Lettre sans réponse** | Enveloppe qui vole | Lance des **avions de papier** qui suivent lentement le joueur | Se **divise** en 3 avions quand on la frappe |

**Boss tirés au hasard**
- **La Maison Vide** : ses fenêtres tirent des rayons, ses portes laissent sortir des Silhouettes.
- **Le Téléphone Muet** : sonne en **ondes de choc** ; il faut « décrocher » (le frapper) au bon moment.
- **La Foule Lointaine** : une foule de silhouettes qui **se disperse** quand on approche ; le vrai boss se cache dedans.

**Boss de fin : L'Absence** *(ceux qui sont partis)*
1. **Presque invisible** : on ne le repère qu'à ses traces et aux attaques qu'il annonce.
2. Il prend la **forme d'un être aimé** : des attaques douces mais incessantes.
3. L'arène s'éteint sauf un **cercle de lumière** autour du joueur ; il faut le retrouver dans le noir.

---

## Dimanche — Angoisse

*Ton : oppressant. Tout se resserre : comptes à rebours, mains qui agrippent, arène qui rétrécit.*

| Créature | Apparence | Comportement | Variante |
|---|---|---|---|
| **Compte à rebours** | Créature avec un chiffre sur le ventre | Décompte ; **explose à zéro** en grande zone si on ne l'a pas tuée | **Relance** le décompte des autres |
| **Mains du lundi** | Mains qui sortent du sol | **Agrippent** dans des cercles télégraphiés | Une ligne de mains qui **avance** vers le joueur |
| **Spirale** | Tourbillon sombre | **Attire** le joueur pendant que des projectiles tournent autour | Deux spirales qui tournent en sens contraire |
| **Ombre portée** | Ombre du joueur détachée de lui | Frappe **là où le joueur était une seconde avant** : il faut bouger sans arrêt | Trois ombres décalées dans le temps |

**Boss tirés au hasard**
- **Le Dimanche Soir** : une bête crépusculaire ; les **bords de l'arène s'assombrissent** et la réduisent.
- **La Liste du Lendemain** : un parchemin de tâches qui **pleut** en motifs serrés.
- **Le Cœur qui Bat** : un cœur géant dont les **battements accélèrent** en ondes de choc.

**Boss de fin : La Dernière Nuit** *(la peur de la fin, le dernier boss du jeu)*
1. Elle reprend les **attaques des boss de fin** de toute la semaine, en accéléré.
2. L'arène se **resserre dans le noir**.
3. **Survivre jusqu'à l'aube** : impossible à vaincre, il faut tenir jusqu'à ce que le jour se lève ; à l'aube, elle se dissout (en écho à la fin du récit : « il a cessé de lutter contre l'aube »).

---

## Volume de production

- **28 créatures** (4 par nuit) avec leur variante de comportement.
- **21 boss tirés au hasard** (3 par nuit).
- **7 boss de fin** à plusieurs phases.

Soit environ **56 sprites** et autant de comportements. Une fois les fiches validées, on produit **nuit par nuit**, en commençant par le lundi.
