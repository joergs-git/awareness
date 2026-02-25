# App Store Screenshot Guide

## Required Device Sizes

### iPhone (required)

| Display Size | Resolution (portrait) | Devices |
|---|---|---|
| 6.9" | 1320 x 2868 | iPhone 16 Pro Max |
| 6.7" | 1290 x 2796 | iPhone 15 Plus, 15 Pro Max, 14 Plus, 14 Pro Max |
| 6.5" | 1242 x 2688 | iPhone 11 Pro Max, XS Max |
| 5.5" | 1242 x 2208 | iPhone 8 Plus, 7 Plus, 6s Plus |

**Tip:** Submit for 6.9" and 6.7" at minimum. Apple can auto-generate the smaller sizes if you check "Use 6.7-inch display screenshots" in App Store Connect.

### iPad (required if app supports iPad)

| Display Size | Resolution (portrait) | Devices |
|---|---|---|
| 13" | 2064 x 2752 | iPad Pro 13" (M4) |
| 12.9" | 2048 x 2732 | iPad Pro 12.9" (3rd–6th gen) |

**Tip:** Submit for 13" at minimum. Apple can auto-generate 12.9" from 13".

### Apple Watch (required if watch app exists)

| Display Size | Resolution | Devices |
|---|---|---|
| Ultra 2 (49mm) | 410 x 502 | Apple Watch Ultra 2 |
| Series 10 (46mm) | 416 x 496 | Apple Watch Series 10 (46mm) |
| Series 10 (42mm) | 374 x 446 | Apple Watch Series 10 (42mm) |
| Series 9 (45mm) | 396 x 484 | Apple Watch Series 9 (45mm) |
| Series 9 (41mm) | 352 x 430 | Apple Watch Series 9 (41mm) |

**Tip:** Submit for Series 10 (46mm) at minimum.

## Screenshot Count

- Minimum: 1 per device size
- Maximum: 10 per device size
- Recommended: 4–6 per device, showing the most important features

## Recommended Screenshots (iPhone)

Capture these in order of importance:

### 1. Blackout Screen (text mode)
- Shows the core experience: full black screen with "Breathe." text
- **How:** Open app → tap "Test Blackout" → screenshot during blackout

### 2. Home Screen / Status
- Shows the main ContentView with ☯ icon, status, next blackout countdown
- **How:** Just open the app (make sure it's in normal running state, not snoozed)

### 3. Progress View
- Shows the donut chart, today's stats, and 14-day bar chart
- **How:** Tap the progress/stats section in the main view

### 4. Settings Screen
- Shows the settings form with time window, intervals, duration, visual mode
- **How:** Tap the gear icon / Settings

### 5. Notification
- Shows a rich notification with "Awareness ☯" title and action buttons
- **How:** Schedule a test notification, lock the phone, wait for it to arrive, screenshot from lock screen

### 6. Blackout Screen (image mode)
- Shows a blackout with a custom image (e.g. nature/meditation scene)
- **How:** Set visual mode to Image, select a calming image, trigger test blackout

## Recommended Screenshots (iPad)

Same as iPhone, but in landscape or split-view if the layout benefits from it. The app uses the same UI, so portrait works fine too.

## Recommended Screenshots (Apple Watch)

### 1. Main Screen
- Shows the watch ContentView with status and next blackout time

### 2. Blackout Screen
- Shows the full-screen black with "Breathe." text on the watch

### 3. Complication on Watch Face
- Shows the ☯ complication on an actual watch face
- **How:** Add the complication to a watch face, then screenshot the face

### 4. Progress View
- Shows the compact donut chart and stats on the watch

### 5. Settings Screen
- Shows the watch settings form

## Capture Tips

### iOS Simulator
```bash
# Boot a specific simulator
xcrun simctl boot "iPhone 16 Pro Max"

# Take a screenshot
xcrun simctl io booted screenshot screenshot.png
```

### Physical Device
- **iPhone/iPad:** Press Side Button + Volume Up simultaneously
- **Apple Watch:** Press Side Button + Digital Crown simultaneously

### Best Practices
- Use a clean status bar (full signal, full battery, simple time like 9:41 AM)
- Use the iOS Simulator's "Features > Status Bar > Override" to set a clean status bar
- Show the app in a realistic but attractive state (some progress data, reasonable settings)
- Avoid personal data in screenshots
- Consider using a dark wallpaper/background for lock screen notification screenshots
- For the blackout screenshot, the plain black + white text is the most striking visual
- If adding device frames or marketing text overlays, use tools like Fastlane Frameit or Screenshots Pro

### Simulator Status Bar Override
```bash
# Set a clean status bar on the simulator
xcrun simctl status_bar booted override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularMode active \
  --cellularBars 4
```

## File Naming Convention

Use descriptive names for easy management in App Store Connect:

```
screenshots/
├── iphone-6.9/
│   ├── 01-blackout.png
│   ├── 02-home.png
│   ├── 03-progress.png
│   ├── 04-settings.png
│   └── 05-notification.png
├── ipad-13/
│   ├── 01-blackout.png
│   ├── 02-home.png
│   ├── 03-progress.png
│   └── 04-settings.png
└── watch-46mm/
    ├── 01-main.png
    ├── 02-blackout.png
    ├── 03-complication.png
    ├── 04-progress.png
    └── 05-settings.png
```
