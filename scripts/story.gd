class_name Story
extends RefCounted

# Recit du jeu : la semaine du reveur est l'image d'une vie entiere et des epreuves qu'on y
# traverse. Chaque nuit est un age de la vie ; chacune se termine par une petite lueur d'espoir.
# Le texte est raconte par l'introduction (facon The Binding of Isaac), par les habitants du
# reve (PNJ) et par une fin a chaque nuit.
# PREMIER JET : ce fichier ne contient que du texte, a reecrire librement.
#
# Une scene de recit = une liste de tableaux {"text": ..., "vignette": ...}. Vignettes
# disponibles (dessinees par scripts/story/cutscene.gd) :
#   bed      : le reveur couche, la lune a la fenetre
#   thoughts : le reveur, ses soucis qui tournent autour de lui
#   towers   : les 7 tours de la semaine qui apparaissent
#   dive     : le reveur qui plonge dans le sommeil
#   tower    : la tour de la nuit qui vient de se terminer, le reveur devant
#   dawn     : le lever du jour

const INTRO := [
	{"vignette": "bed", "text": "Il etait une fois un reveur qui ne dormait plus vraiment."},
	{"vignette": "thoughts", "text": "Chaque soir, ses journees le suivaient jusque dans ses reves : les voix, les regrets, les peurs qu'il n'avait jamais dites."},
	{"vignette": "towers", "text": "Une semaine entiere pesait sur lui. Sept jours, comme les sept ages d'une vie... et chaque jour plus lourd que le precedent."},
	{"vignette": "thoughts", "text": "Pour se reveiller enfin apaise, il lui faudrait traverser chaque nuit, et affronter ce qui s'y cachait."},
	{"vignette": "dive", "text": "Alors il ferma les yeux... et plongea."},
]

# id de nuit (scripts/towers.gd) -> fin de la nuit.
const ENDINGS := {
	"lundi": [
		{"vignette": "tower", "text": "Lundi. L'enfant qu'il etait veillait tard, les yeux grands ouverts, a ecouter les disputes derriere la porte. Il avait appris tres tot a etre fatigue."},
		{"vignette": "tower", "text": "Mais cette nuit, pour la premiere fois, il s'est endormi sans attendre que le silence revienne."},
	],
	"mardi": [
		{"vignette": "tower", "text": "Mardi. Les devoirs, les notes, le regard des autres. Toujours plus vite, toujours mieux, de peur de decevoir."},
		{"vignette": "tower", "text": "Il a compris cette nuit qu'on pouvait l'aimer aussi les jours ou il echouait."},
	],
	"mercredi": [
		{"vignette": "tower", "text": "Mercredi. Le milieu de la semaine, le milieu du chemin. Qui devenir ? Chaque choix ressemblait a une porte qui se refermait."},
		{"vignette": "tower", "text": "Il a cesse d'attendre d'etre sur. Il a choisi, et le chemin s'est dessine sous ses pas."},
	],
	"jeudi": [
		{"vignette": "tower", "text": "Jeudi. Les efforts sans recompense, les portes closes, la colere avalee chaque soir en rentrant."},
		{"vignette": "tower", "text": "Cette nuit, il a laisse la colere passer, comme un orage. Sa valeur ne s'etait jamais mesuree a ses reussites."},
	],
	"vendredi": [
		{"vignette": "tower", "text": "Vendredi. Prendre soin de tout le monde, sauf de soi. Porter les autres jusqu'a ne plus tenir debout."},
		{"vignette": "tower", "text": "Il s'est enfin autorise a s'asseoir. Et le monde ne s'est pas effondre."},
	],
	"samedi": [
		{"vignette": "tower", "text": "Samedi. Les amis eloignes, les chaises vides, le silence d'une maison trop grande."},
		{"vignette": "tower", "text": "Il a compris que ceux qu'on a aimes restent un peu en nous, meme apres leur depart."},
	],
	"dimanche": [
		{"vignette": "tower", "text": "Dimanche. La peur de ce qui vient, de ce qui finit. La plus longue de toutes les nuits."},
		{"vignette": "dawn", "text": "Il a cesse de lutter contre l'aube. Elle est venue quand meme, douce et pale."},
		{"vignette": "dawn", "text": "Et pour la premiere fois depuis tres longtemps, le reveur s'est reveille repose."},
	],
}

# id de nuit -> une replique par habitant du reve (meme ordre que DreamNpc.NPCS :
# hibou, lapin, marchande). Dite au premier echange, avant de proposer la quete.
const NPC_LINES := {
	"lundi": [
		"Moi non plus je ne dors jamais. Les grands parlent si fort, derriere les portes...",
		"Tic, tac. Les enfants ne devraient pas compter les heures de la nuit, tu sais.",
		"Je vends de la lune aux petits qui ont peur du noir. Tu en as eu besoin, autrefois ?",
	],
	"mardi": [
		"Hou hou... Encore une interrogation demain ? Tu revises meme en dormant.",
		"Vite, vite, toujours en retard ! Qui t'a appris a courir comme ca ?",
		"Une bonne note ne s'achete pas, voyageur. Le calme non plus, d'ailleurs.",
	],
	"mercredi": [
		"Tant de chemins... et aucune chouette pour te dire lequel prendre.",
		"Ma montre hesite entre deux heures. Comme toi, entre deux vies.",
		"On me demande souvent la bonne lune. Il n'y en a pas, il n'y a que la tienne.",
	],
	"jeudi": [
		"Tu serres les poings dans ton sommeil. Qu'est-ce qui t'a ete refuse ?",
		"Toutes ces heures donnees, et personne pour les compter. Je connais ca.",
		"La colere, je la garde dans un bocal. Elle eclaire, mais elle brule les doigts.",
	],
	"vendredi": [
		"Tu portes tant de monde sur ton dos... Il te reste une plume pour toi ?",
		"Mes aiguilles tournent trop vite ce soir. Les tiennes aussi, je crois.",
		"Je ne vends rien a ceux qui oublient de se reposer. Assieds-toi un instant.",
	],
	"samedi": [
		"Il y avait du monde, ici, avant. Tu te souviens de leurs voix ?",
		"Personne n'est venu remonter ma montre depuis des annees.",
		"Les etoiles s'eteignent une a une, mais leur lumiere voyage encore longtemps.",
	],
	"dimanche": [
		"La nuit la plus longue... Je veillerai avec toi jusqu'au bout.",
		"Il ne reste presque plus de tic-tac. N'aie pas peur de l'aube.",
		"Ma derniere lune est pour toi, voyageur. Demain, il fera jour.",
	],
}
