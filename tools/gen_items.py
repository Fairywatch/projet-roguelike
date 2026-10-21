"""Icones des objets (une par objet de scripts/items/items.gd).

Lancer depuis la racine du projet : python tools/gen_items.py
Ecrit assets/sprites/items/<id>.png (pixel art, contour sombre automatique).
"""
from gen_pixel_art import from_ascii, rgba, save

# Couleurs partagees
WHITE, LILAC, GOLD, GOLD_D = rgba(250, 248, 255), rgba(196, 186, 236), rgba(255, 214, 96), rgba(206, 150, 60)
GREY, GREY_D, DARK, RED = rgba(176, 176, 196), rgba(116, 116, 140), rgba(40, 32, 52), rgba(226, 70, 84)
BROWN, SKIN, PURPLE, BLUE = rgba(168, 116, 70), rgba(244, 196, 160), rgba(150, 96, 206), rgba(110, 160, 240)

ICONS = {
    "plume_de_reve": ([
        "........WW", "......WWWw", ".....WWWw.", "....WWWw..", "...WWWw...",
        "..WWWw....", ".WWw......", "Ww........", "q.........",
    ], {"W": WHITE, "w": LILAC, "q": BROWN}),
    "sablier_fele": ([
        "GGGGGGGG", ".gSSSSg.", "..gSSg..", "...gS...", "...kg...", "..gssg..", ".gsSSSg.", "GGGGGGGG",
    ], {"G": BROWN, "g": rgba(200, 230, 255), "S": rgba(240, 210, 120), "s": rgba(160, 200, 230), "k": DARK}),
    "larme_de_crocodile": ([
        "...C...", "..CCC..", ".CCWCC.", ".CWCCC.", "CCCCCCC", "CCCCCCc", ".CCCCc.", "..ccc..",
    ], {"C": rgba(110, 210, 150), "W": WHITE, "c": rgba(50, 140, 90)}),
    "coup_de_barre": ([
        "..........RR", "........RRRr", "......RRRr..", "....RRRr....", "..RRRr......",
        "RRRr........", "rr..........", ".y.y.y......",
    ], {"R": PURPLE, "r": rgba(96, 56, 150), "y": GOLD}),
    "grelot_du_sommeil": ([
        "....k....", "...GGG...", "..GGWGG..", ".GGGWGGG.", ".GGGGGGG.", "GGGGGGGGG", "ggggggggg", "....k....",
    ], {"G": GOLD, "W": WHITE, "g": GOLD_D, "k": DARK}),
    "oeil_qui_traine": ([
        "..wwwwww..", ".wWWWWWWw.", "wWWBBBBWWw", "wWBBkkBBWw", "wWBBkkBBWw", ".wWBBBBWw.", "..wwwwww..", "....rr....",
    ], {"w": rgba(120, 90, 150), "W": WHITE, "B": BLUE, "k": DARK, "r": RED}),
    "croque_mort_au_chomage": ([
        "..KKKKKK..", "..KKKKKK..", "..KKKKKK..", "..PPPPPP..", "KKKKKKKKKK",
        "...SSSS...", "..SkSSkS..", "..SSSSSS..", "...SkkS...",
    ], {"K": rgba(44, 40, 56), "P": PURPLE, "S": WHITE, "k": DARK}),
    "pacte_dombre": ([
        ".PPPPPPPP.", "PppppppppP", ".pkkkkkkp.", ".pppppppp.", ".pkkkkkp..", ".pppppppp.", ".ppppRRp..", "PPPPPRRPPP",
    ], {"P": rgba(70, 50, 90), "p": rgba(120, 96, 140), "k": DARK, "R": RED}),
    "chaussons_de_velours": ([
        "......VVV...", "....VVVVVV..", "..VVVWWWVVV.", ".VVVVVVVVVVV", "VVVVVVVVVVVV", "ssssssssssss",
    ], {"V": rgba(150, 90, 190), "W": WHITE, "s": rgba(90, 60, 70)}),
    "oreiller_de_plumes": ([
        "W..........W", "WWWWWWWWWWWW", ".WWWWWWWWWW.", ".WWWwWWwWWW.", ".WWWWWWWWWW.", "WWWWWWWWWWWW", "W..........W",
    ], {"W": WHITE, "w": LILAC}),
    "doudou_protecteur": ([
        ".BB....BB.", "BbBBBBBBbB", ".BBBBBBBB.", ".BkBBBBkB.", ".BBBnnBBB.", "..BBBBBB..", ".BBBBBBBB.", "BBB.BB.BBB",
    ], {"B": rgba(196, 140, 96), "b": rgba(240, 170, 170), "k": DARK, "n": rgba(90, 60, 50)}),
    "cafe_serre": ([
        "..s.s....", "...s.s...", "WWWWWWW..", "WCCCCCWWW", "WCCCCCW.W", "WWWWWWWWW", ".WWWWW...", "ggggggggg",
    ], {"W": WHITE, "C": rgba(110, 66, 40), "s": GREY, "g": GREY_D}),
    "bras_de_morphee": ([
        "..........hh", "........hhhh", ".......Shhh.", ".....SSS....", "...SSS......", ".SSS........", "SS..........",
    ], {"S": rgba(90, 90, 170), "h": SKIN}),
    "coup_de_foudre": ([
        "....YYYY", "...YYYY.", "..YYYY..", ".YYYYYYY", "....YYY.", "...YYY..", "..YYY...", ".YY.....", "YY......",
    ], {"Y": rgba(255, 230, 90)}),
    "mouton_compteur": ([
        "..WWWW....", ".WWWWWWW..", "WWWWWWWWkk", "WWWWWWWWkK", ".WWWWWWWkk", "..k..k....",
    ], {"W": WHITE, "k": GREY_D, "K": DARK}),
    "veilleuse": ([
        "...YYY...", "..YYWYY..", "..YWWWY..", "..YYWYY..", "...YYY...", "....g....", "..ggggg..",
    ], {"Y": GOLD, "W": rgba(255, 250, 220), "g": GREY}),
    "ronflement_sonore": ([
        "ZZZZ......", "..Z.......", ".Z..zzz...", "ZZZZ..z...", ".....z..zz", "....zzz..z", "........z.", ".......zzz",
    ], {"Z": WHITE, "z": LILAC}),
    "somnambule": ([
        "...GG....", "..GGGG...", "..GGGGGGG", "..GGGG...", "..GGGG...", "..GG.GG..", ".GG...GG.",
    ], {"G": rgba(200, 210, 240)}),
    "couverture_lestee": ([
        "BBBBBBBBBBBB", "BbBbBbBbBbBB", "BBBBBBBBBBBB", "cccccccccccc",
        "BBBBBBBBBBBB", "BbBbBbBbBbBB", "BBBBBBBBBBBB", "cccccccccccc",
    ], {"B": BLUE, "b": rgba(70, 110, 200), "c": rgba(60, 80, 140)}),
    "marchand_de_sable": ([
        "...TT.....", "..TTTT....", "..kTTk..y.", ".SSSSSS...", "SSSSSSSS.y", "SSSySSSS..", "SSSSSSSS..", ".SSSSSS...",
    ], {"S": rgba(220, 190, 130), "T": BROWN, "k": DARK, "y": rgba(255, 245, 190)}),
    "berceuse_inversee": ([  # deux croches la tete en bas
        ".NN...NN.", "NNNN.NNNN", ".NNN..NNN", "..N....N.", "..N....N.", "..N....N.", "..NNNNNN.", "..NNNNNN.",
    ], {"N": PURPLE}),
    "reve_lucide": ([
        "..pppppp..", ".pWWWWWWp.", "pWWYYYYWWp", "pWYYWWYYWp", "pWWYYYYWWp", ".pWWWWWWp.", "..pppppp..",
    ], {"p": PURPLE, "W": WHITE, "Y": GOLD}),
    "cauchemar_apprivoise": ([
        "R........R", "RR.DDDD.RR", ".RDDDDDDR.", ".DDkDDkDD.", ".DDDDDDDD.", ".DDwDwDDD.", "..DDDDDD..", "..D....D..",
    ], {"D": rgba(90, 60, 130), "R": RED, "k": rgba(255, 230, 90), "w": WHITE}),
    "pile_rechargeable": ([
        "...gg...", ".GGGGGG.", ".GyyyyG.", ".GyyyyG.", ".GGGGGG.", ".GyyyyG.", ".GyyyyG.", ".GGGGGG.",
    ], {"g": GREY_D, "G": GREY, "y": rgba(120, 230, 120)}),
    "tisane_de_camomille": ([
        ".....YY..", "....YWWY.", "WWWWWYY..", "WttttW...", "WttttWWW.", "WttttW.W.", "WWWWWWWW.", ".gggggg..",
    ], {"Y": GOLD, "W": WHITE, "t": rgba(230, 180, 90), "g": GREY_D}),
    "poussiere_detoile": ([
        "..Y.......", ".YWY...y..", "..Y...yWy.", ".......y..", "...y......", "..yWy..Y..", "...y..YWY.", ".......Y..",
    ], {"Y": GOLD, "y": rgba(255, 190, 230), "W": WHITE}),
    "pyjama_en_soie": ([
        "PP.PPPP.PP", "PPPPWWPPPP", "PPPPWPPPPP", ".PPPWPPPP.", ".PPPWPPPP.", ".PPPWPPPP.", ".PPPPPPPP.",
    ], {"P": rgba(244, 170, 200), "W": WHITE}),
    "pyjama_a_epines": ([
        "k.k.k.k.k.", "PPkPPPPkPP", "PPPPWWPPPP", "kPPPWPPPPk", ".PPPWPPPP.", "kPPPWPPPPk", ".PPPPPPPP.",
    ], {"P": rgba(120, 170, 130), "W": WHITE, "k": DARK}),
    "miroir_de_poche": ([
        "..FFFF..", ".FMMMMF.", "FMWMMMMF", "FMMWMMMF", "FMMMMMMF", ".FMMMMF.", "..FFFF..", "...FF...", "...FF...",
    ], {"F": GOLD_D, "M": rgba(170, 210, 240), "W": WHITE}),
    "attrape_reves": ([
        "..RRRR..", ".R.W.WR.", "R.W.W.WR", "RW.WW.WR", ".RW..WR.", "..RRRR..", ".F..F..F", ".F..F..F",
    ], {"R": BROWN, "W": WHITE, "F": LILAC}),
    "billes_perdues": ([
        "..BB......", ".BWBB.....", ".BBBB.RR..", "..BB.RWRR.", ".....RRRR.", "..GG..RR..", ".GWGG.....", "..GG......",
    ], {"B": BLUE, "R": RED, "G": rgba(110, 210, 150), "W": WHITE}),
    "coeur_de_lune": ([
        ".RR...RR.", "RRRR.RRRR", "RRYYRRRRR", "RYYRRRRRR", ".YYRRRRR.", "..RRRRR..", "...RRR...", "....R....",
    ], {"R": RED, "Y": rgba(255, 240, 180)}),
    "reve_eveille": ([
        "W.......W", "WW..Y..WW", ".WWYYYWW.", "..YYWYY..", "YYYWWWYYY", "..YYYYY..", "..Y...Y..",
    ], {"W": WHITE, "Y": GOLD}),
    "etoile_du_berger": ([
        "....B....", "....B....", "...BWB...", "BBBWWWBBB", "..BWWWB..", "..BB.BB..", ".BB...BB.",
    ], {"B": rgba(150, 200, 255), "W": WHITE}),
    "sommeil_de_plomb": ([
        "...LL....", "..L..L...", ".LLLLLL..", "LLLLLLLL.", "LLlLLLLL.", "LLLLLLLL.", "llllllll.",
    ], {"L": GREY, "l": GREY_D}),
    "montre_a_gousset": ([
        "...GG...", "..G..G..", ".GGGGGG.", "GWWkWWWG", "GWWkWWWG", "GWWkkWWG", "GWWWWWWG", ".GGGGGG.",
    ], {"G": GOLD, "W": WHITE, "k": DARK}),
    # Objets actifs
    "sept_ans_de_malheur": ([
        ".MMMMM..", "MMWMMk..", "MMMMk.M.", "MMMk.MMM", "MMk.MMWM", ".k.MMMM.",
    ], {"M": rgba(170, 210, 240), "W": WHITE, "k": DARK}),
    "mouchoir_usage": ([
        "..WWWW....", ".WWwWWWW..", "WWWWWwWWW.", "WwWWWWWWWW", ".WWWWwWWW.", "..WWWWW...",
    ], {"W": WHITE, "w": GREY}),
    "reveil_strident": ([
        "y.RR...RR.y", ".RRRGGGRRR.", "..GWWWWWG..", ".GWWWkWWWG.", ".GWWWkWWWG.",
        ".GWWWkkWWG.", "..GWWWWWG..", "y..GGGGG..y", "..G.....G..",
    ], {"R": RED, "G": rgba(200, 60, 70), "W": WHITE, "k": DARK, "y": GOLD}),
    "oreiller_volant": ([
        "W.........W", "WW.PPPPP.WW", ".WPPPPPPPW.", "..PPpPPpP..", "..PPPPPPP..", "...PPPPP...",
    ], {"W": WHITE, "P": LILAC, "p": PURPLE}),
    "tasse_de_cafe": ([
        "..s.s...", "...s.s..", ".MMMMMM.", ".MCCCCMMM", ".MCCCCM.M", ".MMMMMMMM", "..MMMM...",
    ], {"M": rgba(220, 120, 90), "C": rgba(110, 66, 40), "s": GREY}),
}

if __name__ == "__main__":
    for item_id, (rows, palette) in ICONS.items():
        save(from_ascii(rows, palette), "items", f"{item_id}.png")
    print(len(ICONS), "icones")
