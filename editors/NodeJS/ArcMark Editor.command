#!/bin/bash
# ArcMark Editor — macOS quick-access launcher.
# Double-click this file in Finder to start the editor and open it in your browser.

set -e

# Resolve the folder this .command lives in (Finder's CWD is usually $HOME when double-clicked).
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ ! -d "$DIR/node_modules" ]; then
  echo "First run: installing dependencies..."
  if command -v npm >/dev/null 2>&1; then
    npm install
  else
    echo "npm was not found. Install Node.js (nodejs.org) and run 'npm install' in this folder."
    read -n 1 -s -r -p "Press any key to close."
    exit 1
  fi
fi

echo "Starting ArcMark editor on http://localhost:4200 ..."
(node server.js --open >/dev/null 2>&1 &)
echo "Editor started in the background. Close this Terminal when done."