# SeekES

SeekES is a macOS desktop client for connecting to and managing Elasticsearch clusters. It provides index and mapping exploration, document viewing and editing, search and aggregation queries, and multi-connection management for everyday investigation and data exploration without relying on the command line.

Website: [https://newpanjing.github.io/seekes/](https://newpanjing.github.io/seekes/)

## Download

[Download the latest macOS app](https://github.com/newpanjing/seekes/releases/latest/download/SeekES-latest.zip)

The app is distributed unsigned. macOS may require allowing it from **System Settings > Privacy & Security** on first launch.

## Features

- Manage multiple Elasticsearch connections in one native macOS application.
- Browse indices, mappings, and settings, then view and edit documents.
- Write and run search, aggregation, and analysis requests with immediate response inspection.

## Xcode

Open `SeekES.xcodeproj` in Xcode, select the `SeekES` scheme, then run it. The project already configures the macOS 14 deployment target, bundle identifier, App Sandbox, outgoing network access, Info.plist, and localized resources.

`project.yml` is the Xcode project source. After changing it, run `xcodegen generate` to regenerate `SeekES.xcodeproj`.
