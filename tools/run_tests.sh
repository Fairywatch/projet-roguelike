#!/usr/bin/env bash
# Lance tous les tests du jeu (tests/test_*.gd) sans fenetre. Sort en erreur si l'un echoue.
#   tools/run_tests.sh [chemin de l'executable Godot]      (par defaut : $GODOT, sinon "godot")
# Un test reussit s'il affiche "<nom> OK" sans "SCRIPT ERROR" ni assertion ratee.
set -u
GODOT_BIN="${1:-${GODOT:-godot}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

# Import des ressources et des classes (obligatoire apres un clone ou l'ajout d'une classe).
timeout 600 "$GODOT_BIN" --headless --path "$ROOT" --import > /dev/null 2>&1

failed=0
total=0
for file in tests/test_*.gd; do
	name="$(basename "$file" .gd)"
	total=$((total + 1))
	output="$(timeout 240 "$GODOT_BIN" --headless --path "$ROOT" -s "res://$file" 2>&1)"
	if echo "$output" | grep -q "^$name OK" && ! echo "$output" | grep -qE "SCRIPT ERROR|Assertion failed|Parse Error"; then
		echo "ok    $name"
	else
		failed=$((failed + 1))
		echo "ECHEC $name"
		echo "$output" | grep -E -A4 "SCRIPT ERROR|Assertion failed|Parse Error" | head -20
	fi
done
echo "$((total - failed)) / $total tests reussis"
[ "$failed" -eq 0 ]
