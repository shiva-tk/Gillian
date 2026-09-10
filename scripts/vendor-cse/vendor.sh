#!/usr/bin/env bash
# Re-vendor CSE's OCaml library into GillianCore/cse.
#
# CSE (default ~/dev/CSE) is the source of truth for the verified encoder.  This
# copies its hand-written libraries and its *generated* extraction over the top
# of GillianCore/cse, then re-applies Gillian's local additions.
#
# Gillian's own build wiring is deliberately preserved: the dune files here
# differ from CSE's (different library and public names, and the extraction is
# checked in rather than produced by a rocq rule), so they are never copied.
#
# Usage: scripts/vendor-cse/vendor.sh [path-to-CSE]

set -euo pipefail

CSE="${1:-$HOME/dev/CSE}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$(cd "$HERE/../.." && pwd)/GillianCore/cse"

LIBS=(smt smtlib syntax utils)

[ -d "$CSE/lib" ] || { echo "error: no CSE checkout at $CSE" >&2; exit 1; }
[ -d "$DEST" ]    || { echo "error: no vendored tree at $DEST" >&2; exit 1; }

# The extraction is a build artefact, so CSE must have been built.
EXTRACTED="$CSE/_build/default/lib/extracted"
if [ ! -f "$EXTRACTED/extracted.ml" ]; then
  echo "==> building CSE's extraction (not present in $CSE/_build)"
  (cd "$CSE" && eval "$(opam env)" && dune build lib/)
fi
[ -f "$EXTRACTED/extracted.ml" ] || {
  echo "error: $EXTRACTED/extracted.ml missing after build" >&2; exit 1; }

echo "==> vendoring $CSE -> $DEST"

# 1. Hand-written libraries: sources only, never dune files.
for lib in "${LIBS[@]}"; do
  for f in "$CSE/lib/$lib"/*.ml "$CSE/lib/$lib"/*.mli; do
    [ -e "$f" ] || continue
    cp "$f" "$DEST/$lib/$(basename "$f")"
  done
  echo "  $lib/"
done

# 2. The generated extraction. Extraction.v stays in CSE; it is the recipe, and
#    Gillian consumes the output.
cp "$EXTRACTED/extracted.ml" "$EXTRACTED/extracted.mli" "$DEST/extracted/"
echo "  extracted/ (generated)"

# 3. Gillian's local additions.
echo "==> re-applying Gillian's local additions"
python3 "$HERE/local_additions.py" "$DEST"

cat <<'MSG'
==> done. Next:
      dune build @check      # or: dune build GillianCore
    Review with:
      git -C . diff --stat GillianCore/cse
MSG
