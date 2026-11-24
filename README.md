# sub3 — Subtitle Audio Player

A Flutter audio and subtitle player designed for language learning and sentence mining across Android and Desktop (Linux, macOS, Windows).

## What the App Does

`sub3` pairs audio files with `.srt` or `.vtt` subtitle tracks in a local SQLite library and provides an interactive player with word lookup, local AI translation, and one-tap Anki flashcard export with clipped audio.

### Key Features

- **Subtitle & Audio Library**: Import `.srt`/`.vtt` subtitles alongside audio files and manage saved entries locally with SQLite (`sqflite` / `sqflite_common_ffi`).
- **Synchronized Playback**:
  - Play/pause, seek bar, and ±10s skip controls.
  - Auto-scrolling and highlighting of the active subtitle cue (`Sync` toggle).
  - Real-time subtitle sync offset controls (`-1s`, `-0.5s`, `+0.5s`, `+1s`, and reset).
  - Jump directly to and play any individual subtitle line.
- **Tap-to-Lookup Dictionary**: Tap any word in a subtitle cue to view its English definition and phonetics in a bottom sheet (powered by `freedictionaryapi.com`).
- **Local AI Subtitle Translation**:
  - Streamed, per-cue translation with in-memory caching for **Portuguese (BR)**, **Spanish**, **English**, **French**, and **Japanese**.
  - **Android (Offline / On-Device)**: Downloads and runs `Hy-MT2 1.8B Q4_K_M` (`unsloth/Hy-MT2-1.8B-GGUF`) locally on-device via `flutter_gguf`.
  - **Desktop**: Connects to a local **Ollama** instance (configured by default to `maternion/hy-mt2:1.8b`).
- **Anki Sentence Mining**:
  - Clips the exact audio segment for any subtitle cue (respecting the current sync offset) and creates a flashcard in the `sub3` deck with `Sentence`, `Audio`, and `Translation` fields.
  - **Android**: Clips audio using embedded FFmpeg (`ffmpeg_kit_flutter_new_audio`) and sends cards directly to **AnkiDroid** via the AnkiDroid API.
  - **Desktop**: Clips audio using system `ffmpeg` and sends cards to **Anki** via **AnkiConnect** (`http://127.0.0.1:8765`).

## Requirements

- **Flutter SDK** (Dart `^3.7.0`)
- **Android**:
  - Android SDK (`minSdk` 24+)
  - [AnkiDroid](https://github.com/ankidroid/Anki-Android) installed (if using Anki card export)
  - ~462 MB free storage to download the offline GGUF translation model inside the app
- **Desktop (Linux / macOS / Windows)**:
  - [Ollama](https://ollama.com/) running locally with `maternion/hy-mt2:1.8b` pulled (for translation)
  - `ffmpeg` available on `PATH` (for audio clipping)
  - Desktop Anki with the [AnkiConnect](https://ankiweb.net/shared/info/2055492159) add-on running on port `8765` (for Anki export)

## Getting Started & Building

### Install Dependencies

```bash
flutter pub get
```

### Run on Desktop / Android

```bash
flutter run
```

### Build for Android (Release APK)

```bash
flutter pub get
flutter build apk --release
```
