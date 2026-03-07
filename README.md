# Cyber Blockx

> A cyberpunk-themed block puzzle game with Solana wallet integration, built with Flutter & Flame.

---

## Versions 
| Version | Platform |
|---------|----------|
| v1.12.0 | Android  |

> Add new releases above. Format: `| v1.x.x | YYYY-MM-DD | Android | [APK](url) \| [AAB](url) |`

---

## Features

### Gameplay
- Classic 10x20 block puzzle with 7 standard piece types (I, O, T, S, Z, J, L)
- Hold piece, ghost piece preview, next piece display
- Combo system with back-to-back bonus and perfect clear rewards
- Progressive difficulty: speed increases every 10 lines
- Three touch control modes: D-pad, buttons, swipe gestures

### Cyberpunk Visual Style
- Neon glow effects (cyan / magenta / purple palette)
- Lock flash, line clear animations, screen shake
- Futuristic typography (Orbitron + Share Tech Mono)
- Configurable glow intensity and glitch effects

### Procedural Audio
- All sound effects generated in real-time via FFT synthesis (zero audio assets)
- Procedural background music generator
- Independent volume controls for SFX, music, and haptic feedback

### Solana Wallet Integration
- Connect with **Phantom**, **Solflare**, or **Seed Vault**
- X25519 encrypted deep link handshake
- Sign messages to bind wallet and earn on-chain rewards

### Multi-Provider Authentication
- Wallet signature login
- Google Sign-In
- Apple Sign-In
- Link multiple providers to one account

### Leaderboard & Scores
- Local device high scores (offline)
- Cloud global leaderboard (synced via API)
- Score submission with anti-cheat metadata

### Localization
- 8 languages: English, Simplified Chinese, Traditional Chinese, Japanese, Korean, French, German + system default

### Country / Region Display
- Auto-detect user region via Cloudflare geo header on login
- Flag emoji shown on account page next to username or User ID

---

## Tech Stack

| Category | Library | Purpose |
|----------|---------|---------|
| Game Engine | `flame ^1.21.0` | Rendering, game loop, effects |
| Blockchain | `solana_mobile_client ^0.1.2` | Wallet adapter integration |
| Crypto | `pinenacl ^0.6.0` | X25519 key exchange |
| Auth | `google_sign_in ^6.2.1` | Google OAuth |
| Storage | `flutter_secure_storage ^9.2.2` | Encrypted token persistence |
| Audio | `audioplayers ^6.1.0` | Procedural sound playback |
| Sharing | `share_plus ^9.0.0` | Share card with image + text |
| Deep Link | `app_links ^6.3.3` | Wallet callback handling |

---

## Project Structure

```
lib/
├── main.dart                       # Entry point, deep link routing
├── core/
│   ├── board.dart                  # 10x20 grid logic
│   ├── game_state.dart             # Phases, scoring, level progression
│   └── tetromino.dart              # 7 piece definitions
├── game/
│   └── cyber_blockx_game.dart      # Flame game, rendering, VFX
├── models/
│   ├── api_response.dart           # Generic API wrapper
│   ├── auth_state.dart             # Token / auth models
│   ├── global_leaderboard_entry.dart
│   └── share_card_data.dart
├── services/
│   ├── api_service.dart            # REST API client
│   ├── auth_service.dart           # JWT token management
│   ├── audio_manager.dart          # Sound / music settings
│   ├── background_music_generator.dart
│   ├── google_sign_in_service.dart
│   ├── global_leaderboard_service.dart
│   ├── leaderboard_service.dart    # Local scores (SharedPreferences)
│   ├── localization_service.dart   # 8-language i18n
│   ├── share_card_service.dart     # Generate & share PNG cards
│   ├── sound_generator.dart        # Procedural SFX synthesis
│   └── visual_settings.dart        # Glow / glitch config
├── solana/
│   ├── wallet_service.dart         # Phantom / Solflare / Seed Vault
│   ├── crypto_helper.dart          # X25519 keypair
│   └── deep_link_handler.dart      # Callback parser
├── ui/
│   ├── screens/
│   │   ├── menu_screen.dart        # Main menu
│   │   ├── game_screen.dart        # Gameplay + HUD
│   │   ├── leaderboard_screen.dart # Local + cloud tabs
│   │   ├── settings_screen.dart    # Audio, language, visual
│   │   ├── controls_screen.dart    # Control scheme docs
│   │   ├── bind_account_screen.dart# Wallet / OAuth login
│   │   ├── account_screen.dart     # Profile, linked accounts
│   │   ├── badges_screen.dart      # Achievements
│   │   └── legal_page.dart         # Terms & privacy
│   ├── theme/
│   │   └── cyber_theme.dart        # Neon color palette & text styles
│   └── widgets/                    # HUD, overlays, touch controls, share card
└── utils/
    └── country_flags.dart          # ISO 3166 → flag emoji
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.10.8`
- Android SDK (API 21+)
- Java 17+

### Build

```bash
# Debug
flutter run

# Release APK (arm64 only — required for this project)
flutter build apk --release --target-platform android-arm64

# Release AAB
flutter build appbundle --release --target-platform android-arm64
```

> **Note:** Must specify `--target-platform android-arm64` because the build environment lacks `android-arm` gen_snapshot.

### Deep Link Testing

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "cyberblockx://onConnect?test=1" \
  com.ichuk.cybertetris.app
```

---

## Configuration

| Item | Value |
|------|-------|
| Package Name | `com.ichuk.cybertetris.app` |
| Deep Link Scheme | `cyberblockx://` |
| API Base URL | `https://api.cyberblockx.com` |
| OAuth Client ID | `cyberblockx_game` |

---

## Architecture

```
┌───────────────────────────────────────┐
│              UI Layer                 │
│  Screens / Widgets / Theme            │
├───────────────────────────────────────┤
│           Service Layer               │
│  AuthService · ApiService · Audio     │
│  Leaderboard · Localization · Share   │
├───────────────────────────────────────┤
│            Core Layer                 │
│  Board · GameState · Tetromino        │
├───────────────────────────────────────┤
│          Game Engine (Flame)          │
│  CyberBlockxGame · Rendering · VFX   │
├───────────────────────────────────────┤
│         Platform / External           │
│  Solana Wallets · Google/Apple Auth   │
│  SecureStorage · DeepLinks            │
└───────────────────────────────────────┘
```

**State Management:** `ChangeNotifier` + `ListenableBuilder` with singleton services.

---

## License

Proprietary. All rights reserved.
