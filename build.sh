#!/usr/bin/env bash
# =============================================================================
# build.sh -- Linux command-line entry for the Colorlight i9+ v6.1 project
# (port of build.ps1; wraps: vivado -mode batch -source scripts/build.tcl)
#
# Usage (works from bash, fish, zsh, ...):
#   ./build.sh init          # create project
#   ./build.sh bitstream     # synth + impl + bitstream (daily driver)
#   ./build.sh sim           # run RTL simulation
#   ./build.sh help          # list all targets
#
# Optional args (same names as the PowerShell wrapper):
#   -VivadoBin <path>        # directory containing vivado  (default: see below)
#   -NoLog                   # do not tee output to build/logs/
#
# Vivado discovery order: -VivadoBin > $VIVADO_BIN > $XILINX_VIVADO/bin > PATH
# Exit code is propagated from vivado (0=success, non-zero=failure).
# All output stays ASCII to match the .tcl conventions.
# =============================================================================
set -u

# ---- Resolve repo root (directory of this script) ----
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Parse args: build.sh <target> [-VivadoBin path] [-NoLog] ----
TARGET=""
VIVADO_BIN=""
NO_LOG=0
while [ $# -gt 0 ]; do
    case "$1" in
        -VivadoBin) if [ $# -lt 2 ]; then echo "ERROR: -VivadoBin requires a value" >&2; exit 2; fi
                     VIVADO_BIN="$2"; shift 2 ;;
        -NoLog)     NO_LOG=1; shift ;;
        -h|-help|--help) TARGET="help"; shift ;;
        -*)         echo "ERROR: unknown option: $1" >&2; exit 2 ;;
        *)          if [ -z "$TARGET" ]; then TARGET="$1"; shift; else
                        echo "ERROR: unexpected argument: $1" >&2; exit 2
                    fi ;;
    esac
done
[ -z "$TARGET" ] && TARGET="help"

# ---- Locate vivado: explicit arg > $VIVADO_BIN > $XILINX_VIVADO/bin > PATH ----
VIVADO=""
if [ -n "$VIVADO_BIN" ]; then
    if [ -x "$VIVADO_BIN/vivado" ]; then
        VIVADO="$VIVADO_BIN/vivado"
    else
        echo "ERROR: vivado not found in -VivadoBin: $VIVADO_BIN" >&2
        exit 2
    fi
elif [ -n "${XILINX_VIVADO:-}" ] && [ -x "$XILINX_VIVADO/bin/vivado" ]; then
    VIVADO="$XILINX_VIVADO/bin/vivado"
elif command -v vivado >/dev/null 2>&1; then
    VIVADO="$(command -v vivado)"
fi
if [ -z "$VIVADO" ]; then
    echo "ERROR: vivado not found." >&2
    echo "       Pass -VivadoBin <path> or set \$VIVADO_BIN / \$XILINX_VIVADO." >&2
    exit 2
fi

# ---- Log file (same naming as build.ps1) ----
LOG_DIR="$ROOT/build/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${TARGET}_$(date +%Y%m%d_%H%M%S).log"

# ---- Vivado home redirect ----
# /home is mounted read-only on this machine; Vivado needs to write runtime
# caches under $HOME/.Xilinx (XilinxTclStore app catalog), so give the vivado
# process its own writable HOME under build/ (gitignored). License lookup
# paths change accordingly -- free (ML Standard) flows are unaffected.
VIVADO_HOME="$ROOT/build/vivado_home"
mkdir -p "$VIVADO_HOME"

echo "==> target: $TARGET"
echo "==> vivado: $VIVADO"
echo "==> vivado_home: $VIVADO_HOME"
echo "==> log: $LOG_FILE"

cd "$ROOT" || exit 2
if [ "$NO_LOG" -eq 1 ]; then
    HOME="$VIVADO_HOME" "$VIVADO" -mode batch -notrace -nolog -nojournal -source scripts/build.tcl -tclargs "$TARGET"
    CODE=$?
else
    HOME="$VIVADO_HOME" "$VIVADO" -mode batch -notrace -nolog -nojournal -source scripts/build.tcl -tclargs "$TARGET" 2>&1 | tee "$LOG_FILE"
    CODE=${PIPESTATUS[0]}
fi

if [ "$CODE" -eq 0 ]; then
    echo "==> OK: $TARGET"
else
    echo "==> FAILED: $TARGET (exit=$CODE), see $LOG_FILE" >&2
fi
exit "$CODE"
