# Pocket Little Farm

A cozy **offline** farm for **iOS** and **iPadOS**. Short check-ins, Tamagotchi-style care, no account and no servers.

## Open in Xcode

```bash
cd ~/Desktop/PocketLittleFarm
xcodegen generate
open PocketLittleFarm.xcodeproj
```

Select your Development Team under Signing, then run on a simulator or device.

## Play

1. Choose **Plant** and tap empty soil (seeds start in inventory).
2. **Water** when plots look thirsty.
3. **Harvest** when ripe (✨).
4. Tap the chicken pen or use **Feed hens** / **Eggs**.
5. Use **Settings → Debug time skip** to test wilt and eggs without waiting real hours.

## Architecture

- **SwiftUI** — shell, shop, inventory, settings
- **SpriteKit** — farm map
- **FarmSimulator** — pure timestamp simulation (unit tested)
- **SaveStore** — local JSON in Application Support

## Design notes

See the product plan in the Grok session: short sessions, soft neglect consequences, original IP (not a Farm Town clone).
