#!/bin/sh
# Copies the web build into table-notes/game/ and the source into game/src/. Never touches files outside game/.
set -e
R=/home/claude/table-notes; V=/home/claude/vanguards-descent
cd $R && git pull -q --ff-only
find game -maxdepth 1 -type f -delete
cp $V/build/game/* game/
rm -rf game/src && mkdir -p game/src
(cd $V/game && tar --exclude='./.godot' -cf - .) | (cd game/src && tar -xf -)
cp -r $V/tools game/src/tools
cp $V/web/save-bridge.js game/src/save-bridge.js
git add -A game
if git diff --cached --name-only | grep -v '^game/' ; then echo "REFUSING: staged files outside game/"; git reset -q; exit 1; fi
git diff --cached --stat | tail -1
