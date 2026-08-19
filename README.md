# SeekES

macOS Elasticsearch client.

## Download

[Download the latest macOS app](https://github.com/newpanjing/seekes/releases/latest/download/SeekES-latest.zip)

The app is distributed unsigned. macOS may require allowing it from **System Settings > Privacy & Security** on first launch.

## Xcode

Open `SeekES.xcodeproj` in Xcode, select the `SeekES` scheme, then run it. The project already configures the macOS 14 deployment target, bundle identifier, App Sandbox, outgoing network access, Info.plist, and localized resources.

`project.yml` is the Xcode project source. After changing it, run `xcodegen generate` to regenerate `SeekES.xcodeproj`.
