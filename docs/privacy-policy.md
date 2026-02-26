# Awareness — Privacy Policy

**Last updated:** February 26, 2026

## Overview

Awareness is a mindfulness timer that blacks out your screen at random intervals, reminding you to pause and breathe. Your privacy is important — Awareness is designed to work entirely on your device with no data collection whatsoever.

## Data Collection

**Awareness does not collect, store, or transmit any personal data.** There are no user accounts, no cloud services, no analytics, and no tracking of any kind.

## Apple Health

If you choose to enable Apple Health integration (iOS/watchOS), Awareness writes mindful session data to the Health app on your device. This data is stored locally by Apple Health and is governed by Apple's privacy policies. Awareness requests write-only access and does not read your health data. You can revoke this permission at any time in Settings > Health > Awareness.

## Settings Storage

Your preferences (interval range, duration, visual mode, etc.) are stored locally on your device:

- **macOS**: `UserDefaults` (standard macOS preferences system)
- **Windows**: A JSON file in your local app data folder (`%APPDATA%\Awareness\`)
- **iOS/iPadOS**: `UserDefaults` (standard iOS preferences system)
- **watchOS**: `UserDefaults` (standard watchOS preferences system)

No settings data is sent to any server.

## WatchConnectivity

When you use Awareness on both iPhone and Apple Watch, settings and progress data are synced directly between the two devices using Apple's WatchConnectivity framework. This is a device-to-device transfer over Bluetooth or local Wi-Fi — no data passes through any external server.

## Analytics & Tracking

Awareness contains **no analytics SDKs, no crash reporting services, no ad networks, and no tracking pixels**. The app makes no network requests except for an optional check for new versions on GitHub (a public API call that sends no personal information).

## Third-Party Services

Awareness uses no third-party services. The only external network call is the optional update checker, which queries the public GitHub Releases API (`api.github.com`) to check if a newer version is available. No personal data is included in this request.

## Children's Privacy

Awareness does not collect any data from anyone, including children. The app is suitable for users of all ages.

## Changes to This Policy

If this privacy policy changes, the updated version will be published at this URL. Since Awareness collects no data, significant changes are unlikely.

## Contact

If you have questions about this privacy policy, contact:

**Email:** joergsflow@gmail.com
**GitHub:** [github.com/joergs-git/awareness](https://github.com/joergs-git/awareness)
