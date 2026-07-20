# Pocket Little Farm

**Open source** cozy offline farm for **iOS** and **iPadOS**.

A little **paper scrapbook** farm that lives on your phone — check in for a minute or two, water, harvest, feed the hens, then go live your day. No account. No servers. No ads.

[![License: MIT](https://img.shields.io/badge/License-MIT-cream.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20iPadOS-lightgrey)](#)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](#)

## Features

- **Fully offline** — save stays on device
- **Paper tapestry diorama** — iso plots on a scrapbook stage (SpriteKit)
- **Tamagotchi-style care** — thirst → wilt → lost (soft stakes, recoverable)
- **Morning post** — daily coins, seeds, and feed so you can’t soft-lock forever
- **Chickens** — feed, collect eggs, sell at the shop
- **Native Apple stack** — SwiftUI + SpriteKit (no Unity)

## Requirements

- Xcode 15+ (or current Xcode with iOS 17+ SDK)
- iOS / iPadOS 17.0+
- Apple Developer team for device install (simulator works free)

## Build

```bash
git clone https://github.com/DarkFleetGameStudios/PocketLittleFarm.git
cd PocketLittleFarm
# Optional: regenerate project if you edit project.yml
# brew install xcodegen && xcodegen generate
open PocketLittleFarm.xcodeproj
```

1. Select your **Development Team** under Signing & Capabilities  
2. Run on a simulator or device  

Or from the CLI:

```bash
xcodebuild -scheme PocketLittleFarm -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Play loop

1. **Plant** seeds on empty soil  
2. **Water** when plots say WATER  
3. **Harvest** when RIPE  
4. Feed hens / collect eggs  
5. Sell goods in the shop; buy more seeds  
6. Settings → **debug time skip** to test care without waiting real hours  

## Project layout

```
PocketLittleFarm/
  App/            # SwiftUI app entry, GameStore
  Farm/           # SpriteKit scene, paper materials
  Simulation/     # Pure offline FarmSimulator (unit tested)
  Models/         # SaveGame, crops, economy balance
  Persistence/    # Local JSON save
  UI/             # Shop, inventory, almanac, settings
PocketLittleFarmTests/
```

## Open source

- **License:** [MIT](LICENSE) — free to use, modify, and ship (with attribution)  
- **Org:** [Dark Fleet Game Studios](https://github.com/DarkFleetGameStudios)  
- Issues and PRs welcome: balance tweaks, art, widgets, accessibility  

### Ideas for contributors

- Real paper cutout art atlases  
- Home Screen widget / Live Activity care peek  
- App Intents (“Water my farm”)  
- Sound / Core Haptics  
- visionOS or AR table diorama  

## Design notes

Inspired by the *feeling* of classic social farms and short-session care toys — original systems, art direction, and branding. Not affiliated with Slashkey Farm Town or similar titles.

## License

Copyright © 2026 Dark Fleet Game Studios. Released under the [MIT License](LICENSE).
