#!/bin/bash
set -e

VERSION=$1
if [ -z "$VERSION" ]; then echo "❌ Error: Provide a version (e.g. 1.0.1)"; exit 1; fi

DMG_PATH="build/SuperZen-${VERSION}.dmg"

echo "🚢 Shipping v$VERSION to GitHub..."

# 1. Extract Release Notes from CHANGELOG.md
# Scrapes everything from the specific header until the next header (or end of file)
awk "/## \[$VERSION\]/ { print; flag=1; next } /## \[/ { flag=0 } flag" CHANGELOG.md > RELEASE_NOTES.md

# Append Gatekeeper instructions for unsigned app
cat << EOF >> RELEASE_NOTES.md

## ⚠️ INSTALLATION NOTE (Gatekeeper)
Because this app is unsigned, macOS will flag it as "damaged" or "cannot be opened". 
To fix this, drag SuperZen to your /Applications folder, then run this in Terminal:
\`\`\`bash
xattr -cr /Applications/SuperZen.app
\`\`\`
EOF

# 2. Git Operations
git add .
git commit -m "chore: release v$VERSION" || true
git push origin main

# 3. Create Tag and GitHub Release
git tag -a "v$VERSION" -F RELEASE_NOTES.md
git push origin "v$VERSION"

# 4. Upload to GitHub via GH CLI
gh release create "v$VERSION" "$DMG_PATH" \
    --title "SuperZen v$VERSION" \
    --notes-file RELEASE_NOTES.md

rm RELEASE_NOTES.md
echo "✨ v$VERSION is now live on GitHub Releases!"
