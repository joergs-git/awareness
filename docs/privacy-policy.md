# Awareness reminder — Privacy Policy

**Last updated:** March 19, 2026

## Overview

Awareness reminder (Atempause) is a mindfulness timer that blacks out your screen at random intervals, reminding you to pause and breathe. Your privacy is important — Awareness reminder is designed to minimize data collection and keep your information safe.

## Data Collection

**Awareness reminder does not collect any personally identifiable information.** There are no user accounts, no ad networks, and no tracking of any kind.

## Apple Health

If you choose to enable Apple Health integration (iOS/watchOS), Awareness reminder writes mindful session data to the Health app on your device. This data is stored locally by Apple Health and is governed by Apple's privacy policies. Awareness requests write-only access and does not read your health data. You can revoke this permission at any time in Settings > Health > Awareness reminder.

## Settings Storage

Your preferences (interval range, duration, visual mode, etc.) are stored locally on your device:

- **macOS**: `UserDefaults` (standard macOS preferences system)
- **Windows**: A JSON file in your local app data folder (`%APPDATA%\Awareness\`)
- **iOS/iPadOS**: `UserDefaults` (standard iOS preferences system)
- **watchOS**: `UserDefaults` (standard watchOS preferences system)

No settings data is sent to any server.

## WatchConnectivity

When you use Awareness reminder on both iPhone and Apple Watch, settings and progress data are synced directly between the two devices using Apple's WatchConnectivity framework. This is a device-to-device transfer over Bluetooth or local Wi-Fi — no data passes through any external server.

## Cross-Device Sync (Supabase)

If you enable Desktop Sync (by generating a sync key on iOS and entering it on macOS/Windows), your break events (timestamp, duration, completion status, and awareness score) are uploaded to a Supabase database to synchronize across your devices. Events are identified by a SHA-256 hash of your sync passphrase — **no account, email, or personal information is required or transmitted.**

## Smart Guru — Anonymous Practice Data

When you enable the Smart Guru adaptive scheduling feature (iOS), anonymous practice data is uploaded to help improve the algorithm. This includes:

- **Timestamps** of when breaks occurred
- **Duration** of each break (in seconds)
- **Completion status** (whether you completed the full break)
- **Awareness score** (your 0–100 self-assessment after each break)

This data is **fully anonymous**: it is identified only by a randomly generated device UUID (not linked to your Apple ID, name, or any personal information). You can opt out at any time by disabling Smart Guru in Settings. No data is uploaded when Smart Guru is off.

## Analytics & Tracking

Awareness reminder contains **no analytics SDKs, no crash reporting services, no ad networks, and no tracking pixels**. Network requests are limited to:

- **Update checker** — queries the public GitHub Releases API (`api.github.com`) to check for new versions. No personal data is included.
- **Supabase sync** — only when Desktop Sync or Smart Guru is enabled (see sections above).

## Third-Party Services

- **Supabase** (supabase.co) — used for cross-device sync and anonymous Smart Guru data. Row Level Security (RLS) ensures each user's data is isolated by their sync key hash. No personal data is stored.
- **GitHub API** — used for the optional update checker. No personal data is sent.

## Children's Privacy

Awareness reminder does not collect any data from anyone, including children. The app is suitable for users of all ages.

## Changes to This Policy

If this privacy policy changes, the updated version will be published at this URL. Since Awareness reminder collects no data, significant changes are unlikely.

## Contact

If you have questions about this privacy policy, contact:

**Email:** joergsflow@gmail.com
**GitHub:** [github.com/joergs-git/awareness](https://github.com/joergs-git/awareness)
