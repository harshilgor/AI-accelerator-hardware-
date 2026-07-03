# OpenROAD + SkyWater 130nm — optional physical synthesis flow
#
# Prerequisites (Linux or WSL recommended):
#   - OpenROAD-flow-scripts (ORFS) or manual OpenROAD + sky130 PDK install
#   - https://openroad-flow-scripts.readthedocs.io/
#
# This repository uses Yosys generic techmap by default (no PDK required).
# Run this script only after ORFS/PDK setup to map RTL to Sky130 geometry.
#
# Usage (from repo root, bash/WSL):
#   bash scripts/openroad/run_sky130.sh mac_unit

set -euo pipefail

BLOCK="${1:-mac_unit}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$ROOT/synth/openroad/$BLOCK"
mkdir -p "$BUILD"

if ! command -v openroad >/dev/null 2>&1; then
    echo "ERROR: openroad not found in PATH."
    echo "Install OpenROAD-flow-scripts or add OpenROAD to PATH."
    echo "See docs/SYNTHESIS.md section 6."
    exit 1
fi

echo "OpenROAD Sky130 flow placeholder for block: $BLOCK"
echo "Build dir: $BUILD"
echo ""
echo "Next steps (manual ORFS integration):"
echo "  1. Point ORFS DESIGN_CONFIG at rtl/$BLOCK"
echo "  2. Run make for sky130hd"
echo "  3. Copy reports into synth/openroad/$BLOCK/"
echo ""
echo "TensorMesh-16 — Harshil Gor"
