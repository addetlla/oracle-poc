#!/bin/bash
# Build and deploy BurgerQuick ADF application
# Override any path via env var: MW_HOME, OJDEPLOY, AUTODEPLOY
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# --- Discover JDeveloper install ---
if [ -z "$MW_HOME" ]; then
  # Check common locations
  for candidate in \
    "$HOME/Oracle/Middleware/Oracle_Home" \
    "$HOME/Oracle/Middleware" \
    "/opt/oracle/middleware" \
    "/u01/app/oracle/middleware"; do
    if [ -f "$candidate/jdeveloper/jdev/bin/ojdeploy" ]; then
      MW_HOME="$candidate"
      break
    fi
  done
fi

OJDEPLOY="${OJDEPLOY:-$MW_HOME/jdeveloper/jdev/bin/ojdeploy}"

if [ ! -x "$OJDEPLOY" ]; then
  echo "ERROR: ojdeploy not found at $OJDEPLOY" >&2
  echo "Set MW_HOME or OJDEPLOY to the correct path." >&2
  exit 1
fi

# --- Discover WebLogic autodeploy directory ---
if [ -z "$AUTODEPLOY" ]; then
  AUTODEPLOY=$(find "$HOME/.jdeveloper" -maxdepth 4 -name "autodeploy" -type d 2>/dev/null | head -1)
fi

if [ -z "$AUTODEPLOY" ]; then
  echo "ERROR: Could not find WebLogic autodeploy directory." >&2
  echo "Set AUTODEPLOY to the correct path." >&2
  exit 1
fi

WORKSPACE="${WORKSPACE:-$SCRIPT_DIR/Application1.jws}"
PROFILE="${PROFILE:-Application1_Project1_Application1}"

echo "=== Building EAR ==="
"$OJDEPLOY" -workspace "$WORKSPACE" -profile "$PROFILE"

echo "=== Deploying to WebLogic (autodeploy) ==="
cp -v deploy/Application1_Project1_Application1.ear "$AUTODEPLOY/"

echo "=== Done ==="
echo "Open: http://127.0.0.1:7101/ViewController/faces/pages/employeeDirectory.jspx"
