<div align="center">

<img src="docs/banner.svg" alt="re-flow — Flow / تک‌نقطه" width="100%">

<br/>

[![Build & Release](https://github.com/re-code-sh/re-flow/actions/workflows/build.yml/badge.svg)](https://github.com/re-code-sh/re-flow/actions)
[![Latest Release](https://img.shields.io/github/v/release/re-code-sh/re-flow?label=Release&color=EFA55C)](https://github.com/re-code-sh/re-flow/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Android%20arm64-3DDC84?logo=android&logoColor=white)](https://github.com/re-code-sh/re-flow/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Language](https://img.shields.io/badge/Language-Persian%20%7C%20English-EFA55C)](#-fork-enhancements)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline-4ade80)](#)

### **re-flow (Flow / تک‌نقطه) — Enhanced Fork**
*A behavioral science-backed daily focus protocol, habit tracker, and self-calibration OS.*

**[ ⬇️ Download Latest Release (APK) ](https://github.com/re-code-sh/re-flow/releases/latest)** · [Fork Enhancements](#-fork-enhancements) · [Core Protocol](#-core-protocol) · [Build from Source](#-build-from-source)

</div>

---

## 🚀 Fork Enhancements

This repository (**`re-flow`**) is an internationalized, upgraded, and feature-enhanced fork of the original [Flow (تک‌نقطه)](https://github.com/Mahdi-mortazavi/flow) app.

### 🌐 Full Dual-Language & Locale Engine
- **Seamless Language Switching**: Instant toggling between **English (LTR)** and **Persian (RTL)** with complete UI & typography adaptation.
- **Dynamic OS Launcher App Title**: Launcher label automatically switches between **Flow** and **تک‌نقطه** depending on system/app locale.
- **Locale-Aware Local Notifications**: Morning planning nudges, evening review alarms, focus end timers, and habit reminders dynamically broadcast in the active language.
- **Psychological Tone Localization**: Behavioral science concepts naturally translated into English (*The Boulder*, *Brain Vault*, *Stats Mirror*, *Optimism Gap*, *Pebble*).

### 🎨 Liquid Glass Accent Color Palettes
- **Dynamic Real-Time Theme Engine**: Instantly switch the entire app's accent color across primary buttons, Boulder highlights, timer progress rings, active state indicators, and glass glows without an app restart.
- **6 Curated Liquid Glass Palettes**:
  | Palette | Color Badge | Hex | Persian Name | English Name |
  |---|---|---|---|---|
  | **Ember** *(Default)* | ![](https://img.shields.io/badge/-%20-EFA55C) | `#EFA55C` | کهربایی | Ember |
  | **Alpine Pine** | ![](https://img.shields.io/badge/-%20-4EAF7B) | `#4EAF7B` | سوزن کاج | Alpine Pine |
  | **Abyssal Indigo** | ![](https://img.shields.io/badge/-%20-5486EB) | `#5486EB` | نیلی ژرف | Abyssal Indigo |
  | **Smoked Mulberry** | ![](https://img.shields.io/badge/-%20-D65B6E) | `#D65B6E` | شاتوتی | Smoked Mulberry |
  | **Mist Slate** | ![](https://img.shields.io/badge/-%20-A2ADC0) | `#A2ADC0` | گرانیت مه‌آلود | Mist Slate |
  | **Night Iris** | ![](https://img.shields.io/badge/-%20-9F7AEA) | `#9F7AEA` | شفق شبانه | Night Iris |

### 📈 Non-Punitive "Active Days" Task Capacity Progression
- **Self-Compassion Progression System**: Unlocks daily task slots based on total completed active days in local SQLite without streak-reset punishment:
  - **0–14 Active Days**: 3 tasks max (1 Boulder + 2 secondary tasks)
  - **15–29 Active Days**: 4 tasks max (1 Boulder + 2 secondary + 1 Pebble)
  - **30+ Active Days**: 5 tasks max hard cap (1 Boulder + 2 secondary + 2 Pebbles)
- **"Pebble" (سنگریزه) Slots**: Slots 4 & 5 designated for low-energy, quick-win tasks (<15 minutes).

### 📦 Automated CI/CD & Multi-ABI Release Pipeline
- **Automated GitHub Release Workflows**: Triggers APK compilation (universal + split `arm64-v8a`, `armeabi-v7a`, `x86_64`) on version tags.
- **Keystore Signing & Checksums**: Fully automated keystore signing and SHA-256 artifact verification.

### 🧪 Reliability & Code Hygiene
- **57+ Automated Unit & Widget Tests**: Full test coverage for L10n, capacity limits, repository layer, and state management.
- **Zero-Issue Analysis & Formatting**: Enforces strict `flutter analyze` zero-issue policies and `dart format` compliance.

---

## 🧠 Core Protocol

| Feature | Description |
|---|---|
| **🔥 The Boulder (تخته‌سنگ)** | Pick 1 primary goal each morning; secondary tasks queue behind it. |
| **🎯 Prediction (پیش‌بینی)** | Calibrate morning success probability % vs night outcome to measure the *Optimism Gap*. |
| **⏱ Deep Focus (تمرکز عمیق)** | Crash-proof timer tied to OS wall clock + intruding thought capture (*Brain Vault*). |
| **🌱 Recovery Habits (عادت‌ها)** | Anchor cues + friction pause for bad habits. Measures *Recovery Rate* instead of streaks. |
| **🌙 Night Review (مرور شب)** | 60-second review + 3-Why root cause analysis when The Boulder fails. |
| **🪞 Stats Mirror (آینه)** | Judgment-free metrics: Win Rate, Optimism Gap, Recovery Rate & Golden Hour energy peak. |

---

## 📱 Screenshots

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

## 🔒 Privacy & Data Ownership

- **100% Offline**: No account creation, no internet connection required, no remote servers, zero analytics tracking.
- **Local SQLite Storage**: All data stays securely on your device with JSON export, backup & restore options.

---

## 🛠 Build from Source

```bash
git clone https://github.com/re-code-sh/re-flow.git
cd re-flow
flutter pub get
flutter run
```

### 🧪 Quality Assurance Commands
```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

---

## 📄 License & Credits

- Original project by [Mahdi-mortazavi/flow](https://github.com/Mahdi-mortazavi/flow).
- Fork maintained by [re-code-sh/re-flow](https://github.com/re-code-sh/re-flow).
- Released under the MIT License.
