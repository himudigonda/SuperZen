set shell := ["zsh", "-c"]

# Default recipe
default:
    @just --list

# Build the project
build:
    xcodebuild -scheme SuperZen -project SuperZen.xcodeproj -configuration Debug build

# Run tests
test:
    xcodebuild -scheme SuperZen -project SuperZen.xcodeproj -configuration Debug test

# Format Swift code
format:
    swift-format format --in-place --recursive .

# Lint Swift code
lint:
    swiftlint lint --strict

# Clean build artifacts
clean:
    xcodebuild -scheme SuperZen -project SuperZen.xcodeproj clean
    rm -rf build/

# Package the app into a DMG (Usage: just dmg 1.0.0)
dmg version:
    chmod +x scripts/create_dmg.sh
    ./scripts/create_dmg.sh {{version}}

# Full production release (Usage: just ship 1.0.0)
ship version:
    @just format
    @just lint
    @just dmg {{version}}
    chmod +x scripts/ship.sh
    ./scripts/ship.sh {{version}}

# Factory reset: Wipes build folders and local app data
nuke:
    rm -rf build/
    rm -rf DerivedData/
    rm -rf ~/Library/Application\ Support/SuperZen
    @echo "🧨 System data cleared."

