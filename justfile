set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

build:
    xcodebuild -scheme SuperZen -project SuperZen.xcodeproj -configuration Debug -destination 'platform=macOS' build

test:
    xcodebuild -scheme SuperZen -project SuperZen.xcodeproj -configuration Debug -destination 'platform=macOS' test

test-scripts:
    shellcheck -x scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh
    scripts/tests/run.sh

format:
    xcrun swift-format format --in-place --parallel --recursive SuperZen SuperZenTests SuperZenUITests Packages/SuperZenCore/Sources Packages/SuperZenCore/Tests Packages/SuperZenCore/Package.swift scripts
    swiftlint lint --fix

lint:
    swiftlint lint --strict

clean:
    xcodebuild -scheme SuperZen -project SuperZen.xcodeproj clean
    rm -rf build/

version:
    scripts/release.sh version

bump version:
    scripts/release.sh bump {{version}}

release-check version:
    scripts/release.sh check {{version}}

notes version:
    scripts/release.sh notes {{version}}

dmg:
    scripts/create_dmg.sh

ship version:
    scripts/release.sh check {{version}}
    just lint
    just test
    scripts/ship.sh {{version}}

nuke:
    rm -rf build/
    rm -rf DerivedData/
    rm -rf ~/Library/Application\ Support/SuperZen
    @echo "System data cleared."
