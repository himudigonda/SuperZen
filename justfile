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
