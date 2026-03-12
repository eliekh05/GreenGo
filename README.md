Let me check the MapView.swift for what features it actually has:Got everything I need. Here is the updated README:

---

# GreenGo 🌿

An eco-friendly travel app for iOS built with SwiftUI, Swift 6, and iOS 26.

---

## Features

- 🗺️ **Eco Map** — Live map powered by OpenStreetMap and the Overpass API. Shows real-world locations across three filterable categories: Stay (hotels, hostels, guest houses, campsites, chalets, resorts and more), Cycling (bike rentals, repair stations, bicycle shops), and Nature (nature reserves, parks, gardens, national parks, forests, beaches, peaks, waterfalls, viewpoints and more). Markers load dynamically as you pan and zoom, with automatic fallback across multiple Overpass mirrors.
- 🌍 **Translator** — Real-time translation with speech input and text-to-speech output using Apple's Translation framework (18 languages)
- 👟 **Pedometer** — Step counter using CoreMotion
- 🎮 **Games** — Reef Rescuers ocean cleanup game, Eco Trivia, Wild Recall memory game
- 📬 **Contact** — In-app feedback form. Please just use it normally to send feedback. Do not attempt to probe, spam, inject anything, or abuse it in any way. Build and run the app as intended and leave it at that.
- ⚙️ **Settings** — Theme selection, preferences

---

## Requirements

- Xcode 26+
- iOS 26+
- Swift 6
- Free Apple Developer account (see Publishing section below)

---

## Setup

1. Clone the repo
2. Open `GreenGo.xcodeproj`
3. In Signing & Capabilities set your own Team ID and Bundle Identifier
4. Build and run

---

## Known Notes

### Map
Markers load live from Overpass API and may take a moment depending on which mirror responds. This is expected behavior from community-run public servers with no guaranteed uptime.

### Contact Form
Just build and run. Do not open, probe, or interact with the backend in any way outside of normal in-app use. No spamming, no XSS, no cyberattacks, no reports, nothing. If you mess with it, you will lose access to the services it relies on permanently. You have been warned.

### Sound
If sounds glitch while your phone is not on silent, that is not a bug. iOS has audio session limits and an incoming call or a burst of rapid news notifications can interrupt playback. That is a system-level limitation, not something the app controls.

### Android
The Android version is coming but may take a while. Android Studio alone requires around 20 GB of downloads just to get set up, on top of runtimes, emulators, and actual device testing. It will be released when it is properly ready.

### Tested Devices
The app has been tested on:
- iPhone 17 Pro Max

Older devices may or may not have issues — nobody can guarantee that. It is strongly recommended to use an iOS 26 compatible device only.

---

## Development Time

For transparency — the iOS version of this app took approximately **40–50 hours** across multiple AI sessions and tools to build and stabilize. Swift 6 strict concurrency, Apple's Translation framework, and iOS 26 compatibility were the main challenges. This is mentioned not as a complaint but so other developers know what to expect when converting an App Inventor project to native iOS.

---

## Publishing — Read This Carefully

**Do not publish this app anywhere.** Not the App Store. Not Google Play. Not any other store, website, PWA, or social media account. All of the above lead to publishing and distribution which is strictly not permitted.

Use only the **free Apple Developer account** to build and sideload on your own device for personal testing. That is all.

If you have a paid Apple Developer account, do not open Bundle ID management, certificates, provisioning profiles, or any licensing portal from Apple or any other company. Do not create accounts anywhere to distribute this. Do not make a website for it. Do not post it anywhere.

If this app appears on any app store, website, PWA, or social media account, the author will take action with GitHub, Apple, or any relevant company to ensure that person cannot develop or distribute software again. This is not a joke.

---

## License

© 2026 Elie Khalil. All rights reserved.
Source code is visible for reference only. No license is granted to copy, modify, distribute, or publish this code without explicit written permission from the author.
