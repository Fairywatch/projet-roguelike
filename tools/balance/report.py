"""Tableau d'equilibrage a partir des lignes "SIM {json}" de combat_sim.gd.

    python tools/balance/report.py sortie1.txt [sortie2.txt ...]

Pour chaque nuit : PV perdus en moyenne par combat (ennemis, gardien, boss final), part des
combats qui couteraient 3 PV ou plus (les PV de depart), duree, et le classement des boss.
"""
import json
import statistics
import sys
from collections import defaultdict

NIGHTS = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
START_HP = 3


def load(paths):
    rows = []
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith("SIM "):
                    rows.append(json.loads(line[4:]))
    return rows


def summary(rows):
    hp = [r["hp_lost"] for r in rows]
    return {
        "n": len(rows),
        "hp": statistics.mean(hp),
        "deadly": sum(h >= START_HP for h in hp) / len(hp),
        "time": statistics.mean(r["time"] for r in rows),
        "timeouts": sum(not r["won"] for r in rows),
    }


def fmt(s):
    if not s:
        return "%-24s" % "-"
    extra = " T%d" % s["timeouts"] if s["timeouts"] else ""
    return "%4.1f PV %3d%% %4.0fs%-4s" % (s["hp"], round(s["deadly"] * 100), s["time"], extra)


def main():
    rows = load(sys.argv[1:])
    by = defaultdict(list)
    for r in rows:
        mode = "C" if r["nightmare_mode"] else "N"
        by[(r["kit"], mode, r["night"], r["kind"], r["floor"])].append(r)
    for kit in sorted({r["kit"] for r in rows}):
        for mode, label in (("N", "Normal"), ("C", "Cauchemar")):
            print("\n=== kit %s, mode %s : PV perdus / combat, %% de combats a 3 PV ou plus, duree" % (kit, label))
            print("%-9s %-26s %-26s %-26s %-26s" % ("nuit", "ennemis (1er/milieu/fin)", "", "", "gardiens (moy.)"))
            for night in range(7):
                floors = sorted({k[4] for k in by if k[:3] == (kit, mode, night) and k[3] == "creatures"})
                cells = [fmt(summary(by[(kit, mode, night, "creatures", f)]) if by[(kit, mode, night, "creatures", f)] else None) for f in floors]
                guardians = [r for k, v in by.items() if k[:4] == (kit, mode, night, "guardian") for r in v]
                finals = [r for k, v in by.items() if k[:4] == (kit, mode, night, "final") for r in v]
                print("%-9s %s | gardien %s | final %s" % (NIGHTS[night], "  ".join(cells), fmt(summary(guardians)) if guardians else "-", fmt(summary(finals)) if finals else "-"))
    print("\n=== boss (tous modes, kit none) : PV perdus moyens, duree, nombre de combats")
    bosses = defaultdict(list)
    for r in rows:
        if r["kind"] != "creatures" and r["kit"] == "none":
            bosses[(r["night"], r["mobs"][0] if r["mobs"] else "?")].append(r)
    for (night, name), rs in sorted(bosses.items(), key=lambda kv: -statistics.mean(r["hp_lost"] for r in kv[1])):
        s = summary(rs)
        print("%-9s %-22s %4.1f PV  %4.0fs  n=%d%s" % (NIGHTS[night], name, s["hp"], s["time"], s["n"], "  timeouts=%d" % s["timeouts"] if s["timeouts"] else ""))


if __name__ == "__main__":
    main()
