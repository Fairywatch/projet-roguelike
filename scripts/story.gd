class_name Story
extends RefCounted

# Recit du jeu : la semaine du reveur est l'image d'une vie entiere et des epreuves qu'on y
# traverse. Chaque nuit est un age de la vie ; chacune se termine par une petite lueur d'espoir.
# Le texte est raconte par l'introduction (facon The Binding of Isaac), par les habitants du
# reve (PNJ) et par une fin a chaque nuit.
# Ce fichier ne contient que du texte, a reecrire librement. Relu apres la refonte des cinematiques :
# chaque phrase decrit ce que montre son plan (les voix derriere la porte, les sept nuits...).
#
# Chaque phrase s'affiche sur un plan anime de la cinematique (scripts/story/intro.gd pour
# l'intro, scripts/story/endings.gd pour les fins) : garder le meme nombre de phrases.

const INTRO := [
	"Il était une fois un rêveur qui ne dormait plus vraiment.",
	"Chaque soir, ses journées le suivaient jusque dans son lit : les voix derrière la porte, les regrets, les peurs jamais dites.",
	"Toute une semaine pesait sur lui. Sept nuits, comme les sept âges d'une vie, chacune plus lourde que la précédente.",
	"Pour se réveiller enfin reposé, il lui faudrait les traverser une à une, et regarder en face ce qui s'y cachait.",
	"Alors il ferma les yeux...",
	"...et plongea.",
]

# id de nuit (scripts/towers.gd) -> fin de la nuit. Chaque phrase accompagne un plan de la video
# (scripts/story/endings.gd) : elle montre ce qui arrive au lieu d'expliquer la lecon.
const ENDINGS := {
	"lundi": [
		"Lundi. Derrière la porte, les voix montaient puis retombaient. L'enfant comptait les fissures du plafond en attendant le silence.",
		"Cette nuit, le silence est venu plus tôt. Il a remonté la couverture jusqu'au menton, et ses yeux se sont fermés tout seuls.",
	],
	"mardi": [
		"Mardi. Les copies rouges de corrections, la pendule qui courait plus vite que sa main, les regards posés sur lui.",
		"Sur la copie ratée, une main a posé une petite étoile dorée. Juste comme ça, pour rien.",
	],
	"mercredi": [
		"Mercredi. Au carrefour, chaque chemin portait le visage de quelqu'un qu'il aurait pu devenir.",
		"Il a fait un pas sans être sûr. Sous ses pieds, les pierres se sont allumées, une à une.",
	],
	"jeudi": [
		"Jeudi. Les portes restaient closes, quoi qu'il fasse. Le soir, il rentrait les poings serrés au fond des poches.",
		"Cette nuit, l'orage a grondé longtemps au-dessus de la fournaise. Puis il s'est éloigné, et l'air sentait la pluie.",
	],
	"vendredi": [
		"Vendredi. Des cartons, des valises, les soucis des autres. Il portait tout, et personne ne voyait ses genoux trembler.",
		"Il a posé les cartons et s'est assis sur un banc. Quelqu'un avait laissé là une tasse de thé encore chaude.",
	],
	"samedi": [
		"Samedi. La salle de bal était vide, les chaises alignées le long des murs, la musique jouée pour personne.",
		"Puis, une à une, des silhouettes de lumière sont entrées. Elles avaient la démarche de ceux qu'il avait aimés.",
	],
	"dimanche": [
		"Dimanche. La plus longue des nuits. Chaque tic-tac rapprochait la semaine suivante, et toutes ses peurs.",
		"Il a cessé de compter. L'aube est venue quand même, et les sept tours se sont défaites dans la lumière.",
		"Et pour la première fois depuis très longtemps, le rêveur s'est réveillé reposé.",
	],
}

# id de nuit -> une replique par habitant du reve (meme ordre que DreamNpc.NPCS :
# hibou, lapin, marchande). Dite au premier echange, avant de proposer la quete.
const NPC_LINES := {
	"lundi": [
		"Moi non plus je ne dors jamais. Les grands parlent si fort, derrière les portes...",
		"Tic, tac. Les enfants ne devraient pas compter les heures de la nuit, tu sais.",
		"Je vends de la lune aux petits qui ont peur du noir. Tu en as eu besoin, autrefois ?",
	],
	"mardi": [
		"Hou hou... Encore une interrogation demain ? Tu révises même en dormant.",
		"Vite, vite, toujours en retard ! Qui t'a appris à courir comme ça ?",
		"Une bonne note ne s'achète pas, voyageur. Le calme non plus, d'ailleurs.",
	],
	"mercredi": [
		"Tant de chemins... et aucune chouette pour te dire lequel prendre.",
		"Ma montre hésite entre deux heures. Comme toi, entre deux vies.",
		"On me demande souvent la bonne lune. Il n'y en a pas, il n'y a que la tienne.",
	],
	"jeudi": [
		"Tu serres les poings dans ton sommeil. Qu'est-ce qui t'a été refusé ?",
		"Toutes ces heures données, et personne pour les compter. Je connais ça.",
		"La colère, je la garde dans un bocal. Elle éclaire, mais elle brûle les doigts.",
	],
	"vendredi": [
		"Tu portes tant de monde sur ton dos... Il te reste une plume pour toi ?",
		"Mes aiguilles tournent trop vite ce soir. Les tiennes aussi, je crois.",
		"Je ne vends rien à ceux qui oublient de se reposer. Assieds-toi un instant.",
	],
	"samedi": [
		"Il y avait du monde, ici, avant. Tu te souviens de leurs voix ?",
		"Personne n'est venu remonter ma montre depuis des années.",
		"Les étoiles s'éteignent une à une, mais leur lumière voyage encore longtemps.",
	],
	"dimanche": [
		"La nuit la plus longue... Je veillerai avec toi jusqu'au bout.",
		"Il ne reste presque plus de tic-tac. N'aie pas peur de l'aube.",
		"Ma dernière lune est pour toi, voyageur. Demain, il fera jour.",
	],
}

# id de nuit -> remerciement de chaque habitant (meme ordre que NPC_LINES) quand on lui rend
# service : un petit signe que la nuit s'adoucit.
const NPC_THANKS := {
	"lundi": [
		"Merci. Écoute... on dirait que les voix se sont tues.",
		"Merci ! Le tic-tac ralentit, d'un coup. C'est l'heure de dormir.",
		"Merci, petit. Garde un bout de lune sous ton oreiller.",
	],
	"mardi": [
		"Merci. Tu vois ? Personne ne t'a mis de note.",
		"Merci ! Et pour une fois, on n'est pas en retard.",
		"Merci. Ça, c'était gratuit, et ça compte quand même.",
	],
	"mercredi": [
		"Merci. Ce chemin-là, tu l'as choisi tout seul.",
		"Merci ! Ma montre s'est décidée : c'est l'heure d'être toi.",
		"Merci. Regarde, ta lune brille déjà un peu.",
	],
	"jeudi": [
		"Merci. Celui-là, quelqu'un l'a vu, au moins.",
		"Merci ! Une heure rendue, pour une fois.",
		"Merci. Ouvre les mains : la colère peut sortir.",
	],
	"vendredi": [
		"Merci. À ton tour de recevoir, maintenant.",
		"Merci ! Prends ton temps, mes aiguilles peuvent attendre.",
		"Merci. Celle-ci, garde-la pour toi.",
	],
	"samedi": [
		"Merci. Ça faisait longtemps qu'on ne m'avait pas répondu.",
		"Merci ! Elle tourne de nouveau. Quelqu'un est venu.",
		"Merci. Tu vois, une lumière, ça se partage.",
	],
	"dimanche": [
		"Merci. Encore un peu de nuit, et puis le jour.",
		"Merci ! Plus qu'un tic-tac. Et puis le matin.",
		"Merci. Pour demain : un peu de lune, pour ne pas oublier.",
	],
}
