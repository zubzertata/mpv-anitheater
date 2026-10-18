# 🎬 mpv-anitheater v1.0 — Anime, K-Drama & Cinema Media Suite (Auto Translator, Dual-Subs, GLSL Shaders & 3D Spatial Audio)

![Version](https://img.shields.io/badge/release-v1.0.0-00d4ff?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-22c55e?style=for-the-badge)
![MPV](https://img.shields.io/badge/mpv-%3E%3D0.37.0-a855f7?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-f59e0b?style=for-the-badge)

**mpv-anitheater** is a high-performance, cross-platform media player suite engineered specifically for **Anime, Asian dramas (K-Dramas), and Cinema lovers**. It features **built-in real-time subtitle translation into 16 languages**, **smart bilingual dual subtitles**, **9 GPU-accelerated GLSL upscaling profiles** (*ArtCNN, FSRCNNX, SSimSuperRes, Anime4K, AMD CAS*), **studio-grade 3D spatial audio** (*Dolby Atmos, DTS:X, BS2B*), an **interactive 6-band graphic equalizer**, **Volume Boost**, and a customized **UOSC glass interface**.

---

## 📑 Table of Contents

1. [✨ Key Features (v1.0)](#-key-features-v10)
2. [📥 How to Download MPV & Install This Build](#-how-to-download-mpv--install-this-build)
   - [🪟 Windows Installation (Portable & Global)](#-windows-installation)
   - [🍎 macOS Installation](#-macos-installation)
   - [🐧 Linux Installation](#-linux-installation)
3. [🎨 Video & GLSL Shader Profiles](#-video--glsl-shader-profiles)
4. [🎧 Spatial Audio, Channel Modes, Volume Boost & Equalizer](#-spatial-audio-channel-modes-volume-boost--equalizer)
5. [💬 Subtitle Translation, Dual-Sub & Style Manager](#-subtitle-translation-dual-sub--style-manager)
6. [⌨️ Keyboard Shortcuts Reference](#️-keyboard-shortcuts-reference)
7. [📂 Repository Structure](#-repository-structure)
8. [🔧 Troubleshooting & FAQ](#-troubleshooting--faq)

---

## ✨ Key Features (v1.0)

### 💬 1. Real-Time Subtitle Translator & Smart Bilingual (Dual-Sub) Mode
* **Automatic & 1-Click Translation:** Translates embedded (`.mkv`, `.mp4`) or external (`.ass`, `.srt`, `.vtt`) subtitle tracks into **16 languages** (*Spanish, English, Japanese, Korean, French, German, Italian, Portuguese, Chinese, Russian, Arabic, Hindi, Turkish, Polish, Dutch, Swedish*) with multi-threaded chunk concurrency.
* **Smart Bilingual / Dual-Sub Engine:** Display two subtitle tracks simultaneously (**Original Language on Top + Translated Target Language on Bottom**).
* **On-the-Fly Secondary Track Translation:** If a video does not include subtitles in the language you want for the top track, select **Translate on the fly for Top Subtitle** to generate and display that language at the top (`secondary-sid`) without replacing your primary bottom subtitle.
* **Full ASS Formatting Preservation:** Protects complex `.ass` override tags (`{\pos}`, `\N`, `\h`, vector drawings, and custom typesetting) during translation.
* **Smart Forced-Track Filtering:** Automatically bypasses short "Signs & Songs" tracks to select and translate full dialogue tracks.

### 🎨 2. Live Subtitle Style Customizer & User Profile Manager
* **🚫 "Off Custom" (Native Video Style Mode):** Disables external style overrides (`sub-ass-override=no`) with a single click to render embedded fansub or Blu-ray subtitles exactly as authored.
* **5 Built-In Curated Presets:**
  * *🎨 Hey Comic Signature* (High-contrast legibility)
  * *🌸 Anime / Sharp Fansub* (Crisp dark outline & elevated margin)
  * *🎬 Classic Cinema / Movies* (Warm amber tone without visual fatigue)
  * *📺 Series / Streaming Opaque Box* (Translucent dark background box)
  * *✨ K-Drama / Comfort Reading* (Clean rounded sans-serif typography)
* **Custom User Profiles:** Tweak font size, text color (*White, Cinema Yellow, Cyan, Green*), border/opaque box style, font family, and vertical screen position in real time, then **save your own named profiles** (e.g., *My Anime*, *Night Movies*, *Sitcoms*) persisted in `sub_profiles.json`.

### 🖥️ 3. 9 GPU-Accelerated GLSL Video Profiles & Heuristic Classifier
* **Automatic Content Classifier:** Inspects track metadata, chapter titles, container signatures, aspect ratios, and frame rates to automatically apply the optimal video pipeline for Anime, Cinema, TV Series, or K-Dramas.
* **9 Selectable Shader Profiles:** From battery-saving laptop modes (*AMD Contrast Adaptive Sharpening*, *Modo Eco*) to ultra-high-definition neural upscalers (*ArtCNN C4F32*, *FSRCNNX*, *SSimSuperRes*, *KrigBilateral*, *Anime4K Fast Restore*).
* **Ambient Crop & Glow Engine:** Crops ultrawide black bars (`autocrop`) or adds a soft ambient light glow around letterboxed content, persisting seamlessly across playlist episodes.

### 🎧 4. Studio Audio Suite: Virtual Surround, 6-Band EQ & Volume Boost
* **8 Spatial Audio Modes:** *Standard Direct*, *Dolby Atmos Virtual Surround*, *Dolby Voice 3D Dialogue*, *DTS:X / Neural:X Spatial*, *Binaural Pro (BS2B Headphones)*, *Expanded Stereo (Music/Live)*, *Night Mode (Smart DRC)*, and *HDMI/Optical Bitstream Passthrough*.
* **7 Channel Layouts:** Switch instantly between *Auto-Safe*, *Mono (1.0)*, *Stereo (2.0)*, *Stereo 2.1 (LFE)*, *Quadraphonic (4.0)*, *Surround 5.1*, and *Surround 7.1*.
* **5-Level Volume Boost (`+4 dB` to `+12 dB` & `Auto DRC`):** Compensates for quiet multi-channel movies or low-volume tracks using anti-clipping soft limiters (`alimiter`) and dynamic normalization (`dynaudnorm`), complete with live badge indicators (`+4`, `+8`, `+12`, `DRC`) on the control bar.
* **Interactive 6-Band Graphic Equalizer:** Drag the visual fader knobs (`64 Hz`, `250 Hz`, `1 kHz`, `2.5 kHz`, `6 kHz`, `14 kHz`) directly with your mouse, scroll with the mouse wheel, or choose from 6 acoustic presets.

### ⏱️ 5. Enhanced Timeline, Chapter Ranges, Auto-Skip & Interactive A-B Loop
* **Color-Coded Chapter Ranges:** Distinct **Emerald Green** markers for *Openings (OP)* and **Vivid Purple** markers for *Endings (ED)* on the timeline.
* **4 Intro/Ending Skip Modes:** Choose between *Manual (Tab Notification)*, *Auto-Skip Opening & Ending*, *Auto-Skip Opening Only*, or *Disabled*.
* **Interactive A-B Segment Loop:** Press `l` (or use the control bar button) to set Point `A` and Point `B` with golden markers and a cyan segment highlight directly on the timeline.
* **Visual Audio & Subtitle Delay Panels:** Fine-tune audio or subtitle synchronization (`+0.50s`, `+0.10s`, `0.00s Reset`, `-0.10s`, `-0.50s`) directly from the UI menus.
* **In-Player Language Priority Configurator (`alang` / `slang`):** Build your preferred audio and subtitle language arrival queues via click-to-order badges (`[#1]`, `[#2]`, `[#3]`) or free-text input without editing `.conf` files manually.

---

## 📥 How to Download MPV & Install This Build

This repository provides the complete, cross-platform configuration package (`portable_config`) alongside automated helper scripts for `FFmpeg`. Follow the steps below for your operating system.

---

### 🪟 Windows Installation

#### Step 1: Download the Official MPV Player Binary
1. Go to the official Windows builds by **shinchiro** on SourceForge or GitHub:
   * **Recommended Link:** [mpv-winbuild-cmake Releases (GitHub)](https://github.com/shinchiro/mpv-winbuild-cmake/releases) or [SourceForge Mirror](https://sourceforge.net/projects/mpv-player-windows/files/64bit/)
2. Download the latest `mpv-x86_64-v3-*.7z` (for modern CPUs) or `mpv-x86_64-*.7z` archive.
3. Extract the `.7z` archive into a folder of your choice (for example, `C:\Program Files\mpv\` or `D:\Apps\mpv\`) using [7-Zip](https://www.7-zip.org/) or WinRAR.

#### Step 2: Install This Custom Build (`portable_config`)
1. Download this repository (click **Code → Download ZIP** on GitHub, or clone it via Git).
2. Copy the **`portable_config`** folder and **`descargar-ffmpeg.bat`** into the **same folder where `mpv.exe` is located**:
   ```text
   📁 Your MPV Folder/
   ├── mpv.exe
   ├── descargar-ffmpeg.bat
   └── 📁 portable_config/
       ├── mpv.conf
       ├── input.conf
       ├── 📁 fonts/
       ├── 📁 script-opts/
       ├── 📁 scripts/
       └── 📁 shaders/
   ```

#### Step 3: Set Up FFmpeg (Required for Internal Subtitle Extraction)
* To translate subtitles embedded inside `.mkv` or `.mp4` files, MPV needs `ffmpeg`.
* Double-click **`descargar-ffmpeg.bat`**. It will check if `ffmpeg` is already installed on your PC; if not, it will automatically download a lightweight official `ffmpeg.exe` binary and place it inside `portable_config\`.

#### Step 4: Launch & Enjoy!
* Double-click **`mpv.exe`** (or run `installer\mpv-install.bat` as Administrator inside your MPV folder to associate video files with MPV).

---

### 🍎 macOS Installation

#### Step 1: Install MPV and FFmpeg via Homebrew
Open **Terminal** and run:
```bash
brew install --cask mpv
brew install ffmpeg
```
*(Alternatively, download the standalone `mpv.app` bundle from [mpv.io/installation](https://mpv.io/installation/)).*

#### Step 2: Install the Configuration Files
Copy the contents of the `portable_config` folder into `~/.config/mpv/`:
```bash
# Clone the repository
git clone https://github.com/zubzertata/mpv-anitheater.git
cd mpv-anitheater

# Create the MPV config directory and copy all files
mkdir -p ~/.config/mpv
cp -r portable_config/* ~/.config/mpv/

# Ensure the ziggy helper binary has execution permissions
chmod +x ~/.config/mpv/scripts/uosc/bin/ziggy-darwin
```

---

### 🐧 Linux Installation

#### Step 1: Install MPV and FFmpeg
Install `mpv`, `ffmpeg`, and `curl` using your distribution's package manager:
* **Ubuntu / Debian / Linux Mint:**
  ```bash
  sudo apt update && sudo apt install mpv ffmpeg curl
  ```
* **Arch Linux / Manjaro:**
  ```bash
  sudo pacman -S mpv ffmpeg curl
  ```
* **Fedora:**
  ```bash
  sudo dnf install mpv ffmpeg curl
  ```

#### Step 2: Install the Configuration Files
Copy the contents of `portable_config` into `~/.config/mpv/`:
```bash
git clone https://github.com/zubzertata/mpv-anitheater.git
cd mpv-anitheater

mkdir -p ~/.config/mpv
cp -r portable_config/* ~/.config/mpv/

# Ensure the ziggy helper binary has execution permissions
chmod +x ~/.config/mpv/scripts/uosc/bin/ziggy-linux
```

---

## 🎨 Video & GLSL Shader Profiles

Access these at any time via **Right-Click → 🎨 Perfil de Video** or by pressing **`b`**:

| Profile | Active Shaders & Scalers | Best Used For | GPU Load |
| :--- | :--- | :--- | :--- |
| **✨ Automático (Adaptativo)** | Dynamic selection based on content | Everyday mixed playback (Anime, Movies, TV) | Adaptive |
| **🔋 Bajo Consumo** | `AMD_CAS.glsl` + `spline36` | Laptops, integrated GPUs, cool & quiet operation | Very Low |
| **⚖️ Intermedio / Equilibrado** | `SSimSuperRes.glsl` + `KrigBilateral.glsl` | 1080p → 1440p/4K upscaling on mid-range GPUs | Medium |
| **📺 Series, K-Drama & TV** | `Deband` + `KrigBilateral.glsl` + `AMD_CAS.glsl` | Streaming episodes with dark-scene banding | Low–Med |
| **🌸 Anime Ligero** | `Anime4K_Fast_Restore.glsl` + `KrigBilateral.glsl` | 1080p Anime line restoration on modest GPUs | Low–Med |
| **🔥 Anime Ultra** | `ArtCNN_C4F32.glsl` + `KrigBilateral.glsl` + `Deband` | Maximum neural line reconstruction for Anime | High |
| **🎬 Cine & Películas Ultra** | `FSRCNNX_x2_16-0-4-1.glsl` + `KrigBilateral.glsl` | Live-action movies, Blu-ray Remuxes & 4K downscaling | High |
| **💎 Estándar Limpio** | Pure `spline64` + `SSimDownscaler.glsl` | Reference-grade neutral scaling without sharpening | Low |
| **⚡ Modo Eco Extremo** | Hardware `bilinear` (0 shaders, `deband=no`) | Maximum battery life on unplugged laptops | Minimal |

---

## 🎧 Spatial Audio, Channel Modes, Volume Boost & Equalizer

Access via **Right-Click → 🎚️ Ecualizador / Sonido Espacial** or press **`E`**:

* **Spatial Audio Profiles:**
  * **🔊 Standard (Direct):** Bit-accurate original audio without spatial filters.
  * **🎬 Dolby Atmos / Virtual Surround:** 120° 3D soundstage (`extrastereo` + `aecho`) + LFE sub-bass boost + center dialogue clarity.
  * **🗣️ Dolby Voice (3D Vocal Clarity):** Emphasizes 1 kHz–3 kHz speech frequencies with gentle spatial width.
  * **🌐 DTS:X / Neural:X Spatial:** Wide Haas acoustic delay stage + TruBass harmonic punch + high-frequency detail.
  * **🎧 Binaural Pro (BS2B):** Bauer stereophonic-to-binaural crossfeed for fatigue-free headphone listening.
  * **🎵 Expanded Stereo (Music / Live):** Phase widening + crystalizer treble definition for concerts and OSTs.
  * **🌙 Night Mode (Smart DRC):** Tames loud explosions while boosting whispered dialogue (`dynaudnorm`).
  * **🔌 HDMI / Optical Passthrough:** Pure bitstream passthrough (`ac3`, `eac3`, `dts`, `dtshd`, `truehd`) to external AV receivers.
* **Volume Boost (`V` key or Control Bar Button):**
  * **🔇 Off (0 dB)** · **📢 Soft (+4 dB)** · **🔊 Medium (+8 dB)** · **🚀 High (+12 dB)** · **🌙 Auto DRC (Continuous Leveler)**.

---

## 💬 Subtitle Translation, Dual-Sub & Style Manager

Press **`T`** or **`c`** (or click the **💬 Subtitles** icon on the control bar) to open the unified subtitle hub:

1. **⚡ Traducir subtítulo actual ahora:** Translates the active subtitle track into your chosen target language and loads it automatically.
2. **🌐 Modo Bilingüe (Subtítulo Superior):**
   * Enable **1-Click Smart Dual Sub** to put the original track at the top of the screen and the translated track at the bottom.
   * Choose any existing subtitle track from the file for the top position, or use **Translate on the fly for Top Subtitle** to translate any missing language directly into the top slot.
3. **🎨 Estilo y Perfiles de Subtítulos:**
   * Switch to **🚫 Off Custom (Native Video Style)** to preserve embedded ASS typesetting and fonts.
   * Switch between the 5 built-in presets or customize font size, color, border/opaque box, font family, and vertical position, then save your own custom profiles.

---

## ⌨️ Keyboard Shortcuts Reference

| Shortcut | Action |
| :--- | :--- |
| **`Right-Click`** / **`TAB`** | Open **Master Control Menu** |
| **`T`** / **`c`** | Open **Unified Subtitles, Dual-Sub & Translation Menu** |
| **`E`** | Open **Audio, Spatial Sound & 6-Band Equalizer Menu** |
| **`V`** | Cycle **Volume Boost** (`Off` → `+4 dB` → `+8 dB` → `+12 dB` → `Auto DRC`) |
| **`B`** | Open **Control Bar Customizer** (Show/Hide buttons) |
| **`b`** | Cycle **Video & Shader Profile** |
| **`e`** | Toggle **Extreme Eco Mode** (Battery Saver) |
| **`m`** | Toggle **Binaural Spatial Audio** |
| **`n`** | Toggle **Night Audio Mode (DRC)** |
| **`l`** / **`L`** | Cycle **A-B Segment Loop** (`Set A` → `Set B` → `Clear`) / Clear Loop |
| **`s`** / **`v`** | Cycle subtitle track / Toggle subtitle visibility |
| **`Ctrl + s`** | Cycle secondary (top) subtitle track |
| **`a`** | Cycle audio track |
| **`[`** / **`]`** | Adjust subtitle delay (`-0.10s` / `+0.10s`) |
| **`{`** / **`}`** | Adjust audio delay (`-0.10s` / `+0.10s`) |
| **`Space`** | Play / Pause |
| **`f`** / **`Esc`** | Toggle Fullscreen / Exit Fullscreen |
| **`Shift + Right / Left`** | Exact 1-second seek forward / backward |
| **`Right / Left`** | 5-second keyframe seek forward / backward |
| **`Up / Down`** / **`Wheel`** | Increase / Decrease Volume (`±2%`) |
| **`F5`** | Take clean video screenshot |
| **`i`** | Toggle technical playback statistics (`stats`) |
| **`q`** | Quit and save playback position (`watch-later`) |

---

## 📂 Repository Structure

```text
├── descargar-ffmpeg.bat                 # Automated FFmpeg downloader for Windows
├── descargar-ffmpeg.sh                  # FFmpeg verification & install helper for Linux/macOS
├── README.md                            # Documentation & SEO guide
└── portable_config/                     # Cross-platform MPV configuration root
    ├── mpv.conf                         # Core hardware decoding, audio/video & subtitle defaults
    ├── input.conf                       # Custom keyboard & mouse bindings
    ├── fonts/                           # Bundled UI icon fonts & subtitle typography
    ├── script-opts/                     # Persistent configuration files for Lua modules
    │   ├── autoload.conf
    │   ├── controller.conf
    │   ├── thumbfast.conf
    │   ├── traduccion.conf
    │   ├── uosc.conf
    │   └── uosc_controls.conf
    ├── scripts/
    │   ├── ambient-manager.lua          # Dynamic Ambient Crop & letterbox glow manager
    │   ├── autocrop.lua                 # Automatic black-bar detection
    │   ├── autoload.lua                 # Automatic folder episode playlist loader
    │   ├── controller.lua               # Video/Audio/EQ/Boost/Language priority engine
    │   ├── skip_intro.lua               # Opening/Ending chapter detector & auto-skipper
    │   ├── thumbfast.lua                # High-speed on-the-fly timeline thumbnail generator
    │   ├── window_border.lua            # Native Windows 11 DWM rounded corners integration
    │   ├── traduccion/                  # Multi-threaded subtitle extraction & translation engine
    │   │   ├── main.lua
    │   │   ├── parser.lua
    │   │   ├── translator.lua
    │   │   └── backends/google.lua
    │   └── uosc/                        # Customized UOSC interface with EQ sliders & A-B timeline
    └── shaders/                         # Curated GLSL GPU shaders
        ├── AMD_CAS.glsl
        ├── Anime4K_Fast_Restore.glsl
        ├── ArtCNN_C4F32.glsl
        ├── FSRCNNX_x2_16-0-4-1.glsl
        ├── KrigBilateral.glsl
        ├── SSimDownscaler.glsl
        ├── SSimSuperRes.glsl
        ├── adaptive-sharpen-modern-film.glsl
        ├── ambient_baked_0.glsl
        └── ambient_baked_1.glsl
```

---

## 🔧 Troubleshooting & FAQ

* **Subtitles inside `.mkv` files aren't translating automatically:**
  Make sure `ffmpeg` is installed. On Windows, run `descargar-ffmpeg.bat` so `ffmpeg.exe` is placed inside `portable_config/`. On macOS/Linux, verify `ffmpeg -version` works in your terminal.
* **Embedded Anime fansub styles look different from the original release:**
  Open the Subtitles menu (`T` or `c`) → **🎨 Estilo y Perfiles de Subtítulos** → select **🚫 Off Custom (Estilo Nativo del Video)**.
* **High GPU usage on a laptop or integrated graphics:**
  Open the main menu (`Right-Click`) → **🎨 Perfil de Video** → select **🔋 Bajo Consumo (AMD CAS + Spline36)** or press **`e`** for **⚡ Modo Eco Extremo**.

---

## 📜 Credits & Acknowledgments

* **[MPV Player](https://mpv.io/)** — Core multimedia engine.
* **[uosc](https://github.com/tomasklaen/uosc)** & **[thumbfast](https://github.com/po5/thumbfast)** — Base UI framework and thumbnailing engine, customized with interactive graphic EQ sliders, dynamic island notifications, and A-B loop timeline markers.
* **Shader Authors:** Artoriuz (`ArtCNN`), igv (`FSRCNNX`, `KrigBilateral`, `SSimSuperRes`, `SSimDownscaler`), bloc97 (`Anime4K`), AMD (`FidelityFX CAS`).
