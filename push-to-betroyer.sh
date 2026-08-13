#!/usr/bin/env bash
set -e
cd /c/app
git remote set-url origin https://betroyer@github.com/betroyer/ET.git
git config --local user.name "betroyer"
git config --local user.email "delossantosbrent69@gmail.com"
git config --local credential.useHttpPath true
echo "Remote: $(git remote get-url origin)"
echo "Local user: $(git config --local user.name)"
echo ""
echo "Step 1: Sign in as betroyer (browser will open)..."
git credential-manager github login --username betroyer --browser --force
echo ""
echo "Step 2: Pushing to GitHub..."
git push -u origin main
echo ""
echo "Done. Check: https://github.com/betroyer/ET"
