# GreenGo 🌿

An eco-friendly travel app for iOS built with SwiftUI, Swift 6, and iOS 26.

## Features

- 🗺️ **Eco Map** — Live OpenStreetMap markers for eco-friendly hotels, cycling, nature spots, recycling, and more powered by Overpass API
- 🌍 **Translator** — Real-time translation with speech input and text-to-speech output using Apple's Translation framework (18 languages)
- 👟 **Pedometer** — Step counter using CoreMotion
- 🎮 **Games** — Reef Rescuers ocean cleanup game, Eco Trivia, Wild Recall memory game
- 📬 **Contact** — In-app feedback form
- ⚙️ **Settings** — Theme selection, preferences

## Requirements

- Xcode 26+
- iOS 26+
- Swift 6
- Apple Developer account (free or paid) to run on device

## Setup

1. Clone the repo
2. Open `GreenGo.xcodeproj`
3. In Signing & Capabilities set your own Team ID and Bundle Identifier
4. Build and run

## Known Notes

### Map Loading
The eco map may occasionally take a moment to load markers depending on which Overpass API mirror responds first. This is not a bug — it is a known limitation of public Overpass API instances which are community-run servers with no guaranteed response time. A lot of effort went into getting this as fast and reliable as possible, with automatic mirror fallback built in. Please be patient when the map is loading.

### Contact Form
The contact form is powered by Supabase Edge Functions. If you fork or build your own version of this app, you will need to set up your own Supabase project and replace the endpoint in `ContactView.swift`. The current endpoint is the developer's own instance.

### Sound
Some in-app sounds may not always be audible. This is completely expected — if your phone is on silent or the volume is low, sounds will not play. This is normal iOS behavior and not a bug.

### Android Version
An Android version is in progress. MIT App Inventor was used originally but has known limitations with video playback, email, and other features that make a proper native Android Studio build the better path forward. The Android APK will be added to Releases when ready.

## Development Time

For transparency — the iOS version of this app took approximately **40–50 hours** across multiple AI sessions and tools to build and stabilize. Swift 6 strict concurrency, Apple's Translation framework, and iOS 26 compatibility were the main challenges. This is mentioned not as a complaint but so other developers know what to expect when converting an App Inventor project to native iOS.

## License

© 2026 Elie Khalil. All rights reserved.
Source code is visible for reference only. No license is granted to copy, modify, or redistribute this code without explicit written permission from the author.
