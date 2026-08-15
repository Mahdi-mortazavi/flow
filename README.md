<div align="center">

<img src="docs/banner.svg?v=3" alt="re-flow — Flow / تک‌نقطه" width="100%">

<br/>

[![GitHub Release](https://img.shields.io/github/v/release/re-code-sh/re-flow?style=for-the-badge&logo=github&color=EFA55C&logoColor=white)](https://github.com/re-code-sh/re-flow/releases/latest)
[![Build Status](https://img.shields.io/github/actions/workflow/status/re-code-sh/re-flow/build.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=CI)](https://github.com/re-code-sh/re-flow/actions)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/re-code-sh/re-flow/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Locales](https://img.shields.io/badge/Locale-Persian%20%7C%20English-EFA55C?style=for-the-badge)](#-key-features)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline-4ade80?style=for-the-badge)](#-privacy--local-data)

### **re-flow (Flow / تک‌نقطه)**
*A liquid-glass daily focus protocol, habit engine, and self-calibration OS.*

[ **⬇️ Download Latest APK** ](https://github.com/re-code-sh/re-flow/releases/latest) · [Features](#-key-features) · [Accent Palettes](#-liquid-glass-accent-palettes) · [Build Instructions](#%EF%B8%8F-build-from-source)

</div>

---

## ⚡ Overview

**re-flow** (**Flow / تک‌نقطه**) is an open-source, 100% offline daily focus app built with Flutter. Built around a dark "Liquid Glass" theme, it eliminates streak anxiety, remote tracking, and clutter — centering your daily energy around one primary goal (**The Boulder / تخته‌سنگ**).

> [!NOTE]
> This repository is an enhanced, internationalized fork of [Mahdi-mortazavi/flow](https://github.com/Mahdi-mortazavi/flow) with full English/Persian LTR/RTL support, customizable accent palettes, dynamic OS launcher labels, active-days task scaling, and automated CI/CD releases.

---

## 🎨 Liquid Glass Accent Palettes

Instantly switch accent colors across buttons, progress rings, highlights, and glass glows in real-time — no app restart needed.

| Accent Palette | Preview Badge | Hex Code | Persian Name | English Name |
|---|---|---|---|---|
| **Ember** *(Default)* | ![](https://img.shields.io/badge/-%20-EFA55C) | `#EFA55C` | کهربایی | Ember |
| **Alpine Pine** | ![](https://img.shields.io/badge/-%20-4EAF7B) | `#4EAF7B` | سوزن کاج | Alpine Pine |
| **Abyssal Indigo** | ![](https://img.shields.io/badge/-%20-5486EB) | `#5486EB` | نیلی ژرف | Abyssal Indigo |
| **Smoked Mulberry** | ![](https://img.shields.io/badge/-%20-D65B6E) | `#D65B6E` | شاتوتی | Smoked Mulberry |
| **Mist Slate** | ![](https://img.shields.io/badge/-%20-A2ADC0) | `#A2ADC0` | گرانیت مه‌آلود | Mist Slate |
| **Night Iris** | ![](https://img.shields.io/badge/-%20-9F7AEA) | `#9F7AEA` | شفق شبانه | Night Iris |

---

## 🚀 Key Features

<details open>
<summary><b>🌐 Full Dual-Language & Native Locale Engine</b></summary>

- **Instant LTR / RTL Switching**: Seamless toggle between English and Persian with full typography and UI alignment.
- **Dynamic OS Launcher Title**: Launcher icon title automatically switches between **Flow** and **تک‌نقطه** depending on system/app locale.
- **Localized Timer & Numbers**: Clock displays English digits (`24:59`) in English mode and Persian numerals (`۲۴:۵۹`) in Persian mode.
- **Localized Notifications**: Morning planning nudges, evening review reminders, task alarms, and habit cues broadcast in your active language.
</details>

<details open>
<summary><b>⏰ Exact Scheduled Task Reminders & Alarms (P0)</b></summary>

- **Exact Background Alarms**: Set exact reminder times on any task with an iOS-style wheel time picker.
- **Direct Notification Deep-Linking**: Tapping the notification or its "Focus" action launches the app directly into Focus mode pre-loaded with that task.
- **Smart Lifecycle Management**: Notifications automatically cancel or reschedule if a task is marked done, edited, or deleted.
- **Visual Reminder Badges**: Task cards display active reminder times directly in the Today view.
</details>

<details open>
<summary><b>⚡ Direct Task-to-Focus Workflow & Auto-Completion</b></summary>

- **One-Tap Focus Launch**: Launch a focus session directly from any task card (including The Boulder) without extra menus.
- **In-Session Task Binding**: Active task title is prominently displayed inside the responsive focus ring with your chosen accent color.
- **Session Completion Flow**: Seamless post-timer prompt allowing you to mark the task completed or log focus time only.
</details>

<details open>
<summary><b>📱 Fluid Portrait Responsiveness & Overflow Protection</b></summary>

- **Dynamic LayoutBuilder Ring**: Circular timer ring and typography adapt smoothly ($180\text{dp} - 284\text{dp}$) across all vertical screen heights.
- **Zero RenderFlex Overflows**: Tested and verified across multiple aspect ratios (16:9, 19.5:9, 20:9, 21:9) and accessibility text scales ($1.3\times$).
- **Keyboard-Proof Bottom Sheets**: All modal sheets and wizards smoothly scroll when the soft keyboard is open.
- **Smart Multi-Line Truncation**: Ellipsis and wrapping for long task titles, habit cues, and category tags.
</details>

<details open>
<summary><b>🧭 3-Tab Liquid Glass Navigation & Floating Brain Vault</b></summary>

- **3-Tab Navigation Bar**: Floating glass bar separating **Tasks (کارها)**, **Habits (عادت‌ها)**, and **Leisure (فراغت)**.
- **Floating Brain Vault Pill**: Ergonomically elevated pill button above the bottom bar for rapid 2-second thought dumping without visual clutter.
</details>

<details open>
<summary><b>📈 Active Days Task Capacity Progression</b></summary>

- **Non-Punitive Scaling**: Task slots unlock automatically based on total completed active days in local SQLite without streak-reset penalties:
  - **0–14 Days**: 3 tasks max (1 Boulder + 2 secondary)
  - **15–29 Days**: 4 tasks max (1 Boulder + 2 secondary + 1 Pebble)
  - **30+ Days**: 5 tasks max cap (1 Boulder + 2 secondary + 2 Pebbles)
- **Pebble Slots (سنگریزه)**: Slots 4 & 5 designated for quick-win, low-energy tasks (<15 minutes).
</details>

<details open>
<summary><b>🧠 Core Behavioral Psychology & Habit Protocol</b></summary>

- **🪨 The Boulder**: Lock in 1 primary goal each morning. Secondary tasks queue behind it.
- **🎯 Prediction & Optimism Gap**: Estimate morning completion probability vs night outcome to track self-overestimation.
- **🏖️ Guilt-Free Play (Leisure)**: Dedicated leisure timer and block as the antidote to Parkinson's Law.
- **🌱 Habit Anchor & Friction**: Anchor routine cues and set friction pauses for bad habits. Measures *Recovery Rate* instead of fragile streaks.
- **🌙 60-Second Evening Review**: Nightly check-in + 3-Why root cause analysis when The Boulder fails.
</details>

---

## 📱 Interface Showcase

<div align="center">
<table>
<tr>
<td align="center" width="25%"><img src="docs/screenshots/today.png" alt="Today Screen" width="200"/><br/><sub><b>Today</b></sub></td>
<td align="center" width="25%"><img src="docs/screenshots/focus.png" alt="Focus Timer" width="200"/><br/><sub><b>Focus</b></sub></td>
<td align="center" width="25%"><img src="docs/screenshots/interrupt.png" alt="Interrupts" width="200"/><br/><sub><b>Interrupts</b></sub></td>
<td align="center" width="25%"><img src="docs/screenshots/mirror.png" alt="Stats Mirror" width="200"/><br/><sub><b>Stats Mirror</b></sub></td>
</tr>
</table>
</div>

---

## 🔒 Privacy & Local Data

- **100% Offline**: Zero remote telemetry, zero analytics tracking, no server dependency.
- **Local SQLite Database**: All plans, focus sessions, and habit logs stay strictly on device.
- **Backup & Restore**: JSON export/import for easy local data ownership and migrations.

---

## 🛠️ Build from Source

```bash
git clone https://github.com/re-code-sh/re-flow.git
cd re-flow
flutter pub get
flutter run
```

### 🧪 Code Hygiene & Verification

```bash
# Verify formatting
dart format --output=none --set-exit-if-changed lib test

# Run static analysis
flutter analyze

# Run unit & widget test suite (86 tests)
flutter test
```

---

## 📜 Credits & License

- Original project by [Mahdi-mortazavi/flow](https://github.com/Mahdi-mortazavi/flow).
- Maintained & upgraded by [re-code-sh/re-flow](https://github.com/re-code-sh/re-flow).
- Released under the [MIT License](LICENSE).
