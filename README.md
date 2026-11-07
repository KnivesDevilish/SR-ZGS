<p align="center">
  <img src="docs/SR-ZGS%20Artwork.png" alt="Sonic Riders: Zero Gravity Artwork" width="750">
</p>

<h1 align="center">
  Sonic Riders: Zero Gravity — Static Recompilation
</h1>

<p align="center">
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-GPLv3-blue.svg" alt="License: GPL v3">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/Focus-Game%20Preservation-pink" alt="Preservation Project">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-green" alt="Platform">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/Recompiler-DolRecomp-orange" alt="Engine">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/Chassis-ModernGekko-purple" alt="Chassis">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/Status-Experimental-B00020" alt="Experimental">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/Type-Static%20Recompilation-blueviolet" alt="Static Recompilation">
  </a>
  <a href="https://github.com/KnivesDevilish/SR-ZGS/stargazers">
  <img src="https://img.shields.io/github/stars/KnivesDevilish/SR-ZGS?style=flat&logo=github&color=yellow" alt="GitHub Stars">
  </a>
</p>

A modern static recompilation project for **Sonic Riders: Zero Gravity** (Nintendo Wii), with the long-term goal of delivering a high-performance native PC experience on Linux and Windows, with Android support as a future target.

The project uses **DolRecomp** to generate native code from the original PowerPC game executable and a modified fork of **ModernGekko**, a Dolphin-derived runtime, to provide the execution environment and Wii hardware services. The fork also contains the SR-ZGS launcher and its Netplay lobby.

SR-ZGS aims to provide a clean, modular architecture that separates recompiled game logic, modding facilities, and hardware-agnostic platform interfaces, progressively reducing its reliance on existing emulation technology.

**Current Status:** SR-ZGS is an experimental hybrid static recompilation project. It still relies on ModernGekko for graphics, audio, input and system-level functionality. A fully independent native runtime is a long-term development goal.

Requires your own legally obtained copy of the game.

---

## Project Status

**Current stage: Experimental — Phase 1**

- [x] DolRecomp code generation for the Wii executable.
- [x] Integration of the generated game module with ModernGekko.
- [x] PC execution through the ModernGekko runtime.
- [x] Full game completion successfully tested using ModernGekko's JIT64 CPU core.
- [x] 60 FPS observed during developer testing using JIT64.
- [x] StaticRecomp execution path tested.
- [x] SR-ZGS launcher with Netplay lobby, music, patch notes and update check (English, Spanish and Japanese).
- [ ] In-game menu.
- [ ] First public release (0.1.0).
- [ ] Improve and optimize StaticRecomp execution performance.
- [ ] Independent runtime implementation.
- [ ] Independent graphics and audio systems.
- [ ] Broader hardware and operating system testing.
- [ ] Native modding support.

### Performance Notes

The 60 FPS result was achieved using ModernGekko's JIT64 CPU core with `MODERNGEKKO_STATICRECOMP=0`.

The StaticRecomp CPU core (`MODERNGEKKO_STATICRECOMP=1`) has also been tested, but currently exhibits significantly lower performance on the reference hardware.

Improving the performance of the StaticRecomp execution path is an ongoing development goal.

These results are specific to the tested hardware and configuration and should not be considered universal performance guarantees.

---

## 🐧 Architecture

SR-ZGS currently consists of three main components:

### DolRecomp

Translates the original PowerPC game executable (`main.dol`) into generated C code that can be compiled for desktop systems.

### ModernGekko

Provides the runtime environment that hosts the generated game module.

ModernGekko is based on Dolphin technology and currently provides:

- Graphics and rendering.
- Audio services.
- Controller and input handling.
- Wii system-level functionality.

SR-ZGS uses a modified fork of ModernGekko: [KnivesDevilish/ModernGekko](https://github.com/KnivesDevilish/ModernGekko), branch `knives/srzgs-launcher`, based on the original [ExpansionPak/ModernGekko](https://github.com/ExpansionPak/ModernGekko) by Hyperway. The `external/ModernGekko/` submodule points to this fork. On top of the original runtime, the fork adds:

- The SR-ZGS launcher (see [The SR-ZGS Launcher](#-the-sr-zgs-launcher)).
- The Netplay lobby with invite codes (see [Netplay](#-netplay)).
- GameCube controller profiles written for SR-ZGS, with a controller tester.
- Pictures in the bars beside a 4:3 game, chosen in the launcher (see [4:3 borders](#43-borders)).
- Small runtime adjustments, such as hiding the runtime's on-screen messages and skipping redundant checks of the game files at startup.

Like the original, the fork is licensed under the GNU GPL v3.

### SR-ZGS integration

The project's own code connects the generated module to ModernGekko.

Current source components:

- `src/recompiled/`: Generated code produced by DolRecomp.
- `src/core/`: Project-specific hooks and replacements.
- `src/platform/`: Module staging, runtime configuration and launch integration.
- `tools/`: Build scripts and recompilation configuration.
- `external/ModernGekko/`: ModernGekko submodule.
- `game_assets/`: Extracted game files (not distributed).

The project does not yet provide its own independent renderer, audio backend or Wii system implementation.


---

## ⚙️ Prerequisites & Setup

### Requirements

- **Compiler:** C11-compatible C compiler and C++23-compatible C++ compiler (required by ModernGekko). The main SR-ZGS module uses C++20.
- **Build System:** CMake 3.22+ and Ninja.
- **Additional Tools:** Git and pkg-config.
- **Recompilation Tools**: [DolRecomp](https://github.com/ExpansionPak/DolRecomp) and the SR-ZGS fork of [ModernGekko](https://github.com/KnivesDevilish/ModernGekko) (based on [ExpansionPak/ModernGekko](https://github.com/ExpansionPak/ModernGekko)).
  - Both come with the `external/ModernGekko/` submodule: DolRecomp is built from the revision ModernGekko pins, so nothing has to be downloaded separately.
- **Game Assets**: A legally obtained NTSC-U copy of *Sonic Riders: Zero Gravity* (Wii, Game ID: `RS9E8P`), with its extracted game files.

---

## 📝 Key Goals & Features

The long-term objective is to make SR-ZGS progressively more independent from its current runtime.

Potential development areas include:

- Investigating and progressively replacing runtime-dependent Wii services.
- Developing independent graphics and audio implementations.
- Improving compatibility across different PC hardware.
- Expanding configuration and customization options.
- Exploring native modding capabilities.

These are development goals, not features currently promised or available.

---

## 📁 Repository Structure

The repository is organized as follows:

```text
SR-ZGS/
├── database/
├── docs/                      # Launcher art, music, patch notes, 4:3 borders and test notes
├── external/
│   └── ModernGekko/           # SR-ZGS fork of the Dolphin-derived runtime (submodule)
├── game_assets/               # User-provided game files (not distributed)
├── mods/                      # Reserved for future project mod support
├── src/
│   ├── recompiled/            # DolRecomp-generated game code
│   ├── core/                  # Optional project-specific hooks and replacements (disabled by default).
│   └── platform/              # Runtime staging and launch integration
├── tools/
│   ├── dolrecomp/
│   └── build_tools.sh
├── CMakeLists.txt
├── CMakePresets.json
└── LICENSE
```

---

## 💻 Platform Status

SR-ZGS is currently in an experimental development stage.

- **Linux:** Current development and testing platform. Tested on Bazzite Linux with Wayland.
- **Windows:** Intended desktop target. Compatibility testing is still needed.
- **Android:** Long-term development target. No working Android build is currently provided.

For detailed hardware specifications, graphics settings, CPU execution modes and performance results, see [TESTING.md](docs/TESTING.md).

This is an observed test result, not a universal performance guarantee. Actual performance may vary depending on hardware, runtime configuration and future changes.

---

## 🚧 Game Asset Setup

SR-ZGS does not distribute copyrighted game executables or assets. You must provide your own legally obtained copy of **Sonic Riders: Zero Gravity** for Nintendo Wii.

### Required Game Copy

- NTSC-U release.
- Game ID: `RS9E8P`.
- A clean, unmodified disc dump is recommended.

### Extracting Game Files

1. Extract the contents of your Wii disc image using a suitable tool, such as Dolphin Emulator, Wiimm's ISO Tools or CleanRip.
2. Place the extracted game directory inside `game_assets/`.
3. Preserve the original directory structure.

The expected directory layout is:

```text
game_assets/
├── sys/
│   ├── main.dol
│   └── boot.bin
└── files/
```

The build configuration expects the extracted game root to contain both `sys/` and `files/`.

> [!NOTE]
> This repository does not provide or distribute any copyrighted game binaries or assets. You must extract the required game files from your own legally obtained copy, including `main.dol` and the required game data directories, to build and run SR-ZGS.

### Extracting with the Launcher

The launcher's **Game Files** page can also extract the game. Select your ISO, WBFS or RVZ image and press **Extract Game**: the launcher checks that the disc is `RS9E8P` and extracts it once into the SR-ZGS user directory (`~/.local/share/sr-zgs/games/RS9E8P` on Linux), where it is reused every time you play.

**Complete save:** the **Game Files** page can also install a save with the whole game completed at 100%, everything unlocked. Play once first, until the game makes its own save; then press **Install complete save**. Your save is copied first to `SaveBackups/RS9E8P/` in the user directory, and **Restore my save** brings it back. The complete save is in `docs/complete-save/`: only the game's save data (`0_Games.sav`), without the save's `banner.bin`, which holds the game's own icon and banner; your game's save keeps the one it made.

Building the recompiled code (step 3 below) reads `main.dol` from `game_assets/` by default. If you already extracted the game with the launcher, you can point the build at that copy instead of extracting it twice:

```bash
ASSETS_DIR="$HOME/.local/share/sr-zgs/games/RS9E8P" bash tools/dolrecomp/recompile.sh
cmake --preset quick -DSRZGS_GAME_ROOT="$HOME/.local/share/sr-zgs/games/RS9E8P"
```

`bash tools/preflight.sh "$HOME/.local/share/sr-zgs/games/RS9E8P"` checks that a folder has the expected layout and the same `main.dol` as the recompiled code.

---

## 🚀 Building & Getting Started

### Prerequisites

SR-ZGS requires the following tools:

- Git
- CMake 3.22 or newer
- Ninja
- A C/C++ compiler
- `pkg-config`

Make sure these dependencies are installed in the environment where you intend to build the project.

On Linux, `tools/build_tools.sh --chassis` checks the system libraries the runtime and the launcher need before it starts the long build, and prints the install command for Ubuntu/Debian and Fedora when something is missing. The launcher's music plays through PulseAudio (PipeWire's PulseAudio support works too).

**Linux users:** You can build SR-ZGS directly on your distribution if the required dependencies are installed. Alternatively, you can use [Distrobox](https://distrobox.it/) to work inside a separate development environment.

If you use Distrobox, enter your container before running the commands below. For example:

```bash
distrobox enter my-distrobox
```

### 1. Clone the Repository

Clone SR-ZGS with all its required submodules:

```bash
git clone --recursive https://github.com/KnivesDevilish/SR-ZGS.git
cd SR-ZGS
```

### 2. Build DolRecomp and ModernGekko

Build the recompilation tools and the ModernGekko runtime:

```bash
bash tools/build_tools.sh --chassis
```

### 3. Generate the Recompiled Game Code

Run the recompilation script:

```bash
bash tools/dolrecomp/recompile.sh
```

The generated code will be placed inside `src/recompiled/`.

### 4. Configure and Build SR-ZGS

SR-ZGS provides two CMake presets. Choose the one that best fits your needs.

**Quick preset:**

Intended for development iterations. Uses `-O1` for generated game code.

```bash
cmake --preset quick
cmake --build --preset quick
```

**Release preset:**

Intended for optimized builds. Uses `-O2` for generated game code.

```bash
cmake --preset release
cmake --build --preset release
```

### 5. Launch SR-ZGS

#### Using the Launcher

`tools/build_tools.sh --chassis` also builds the SR-ZGS launcher, and step 4 copies the recompiled module next to it, in `build/chassis/`. To play through the launcher:

```bash
cd build/chassis
./SR-ZGS
```

The first time, open **Game Files** and extract your copy of the game (see [Extracting with the Launcher](#extracting-with-the-launcher)), then press **PLAY**. See [The SR-ZGS Launcher](#-the-sr-zgs-launcher) for what each page does.

The commands below start the game directly from the build, without the launcher, which is useful during development.

SR-ZGS supports two CPU execution modes through the ModernGekko runtime. Both modes use the same runtime integration but execute the game's CPU code differently.

The following examples use the Quick preset. Replace `quick` with `release` to launch a Release build instead.

#### JIT64 Mode

To launch SR-ZGS using ModernGekko's JIT64 CPU core:

```bash
MODERNGEKKO_STATICRECOMP=0 cmake --build --preset quick --target srzgs_run
```

This is the execution mode used during developer testing in which the game was observed running at 60 FPS.

#### StaticRecomp Mode

To launch SR-ZGS using the StaticRecomp CPU execution path:

```bash
MODERNGEKKO_STATICRECOMP=1 cmake --build --preset quick --target srzgs_run
```

This execution mode is currently under performance investigation and may run significantly slower on some hardware.

#### Choosing the CPU Core

The selected CPU core is saved in the runtime configuration file, `config.ini`, inside the SR-ZGS user directory (`~/.local/share/sr-zgs/config.ini` on Linux):

```ini
[Core]
cpu_core=jit64
```

- `jit64` (default): ModernGekko's JIT64 CPU core, the validated full-speed mode.
- `staticrecomp`: runs the recompiled game module. Experimental.

The SR-ZGS launcher exposes the same option under **Settings → CPU core**.

When the `MODERNGEKKO_STATICRECOMP` environment variable is set, it takes priority over `config.ini`, both for the launcher and for `srzgs_run`. This makes it possible to test a mode without changing the saved setting, as in the commands above. If neither specifies a core, JIT64 is used.

At startup the runner reports the core it is using, for example `cpu core: JIT64 (from config.ini)`. It appears in the terminal, or in `Logs/ModernGekko.log` inside the user directory when the game is started from the launcher.

In Netplay, every player uses the host's CPU core. JIT64 is recommended, especially when players are on different systems (Windows and Linux).

#### Controls

SR-ZGS plays with a GameCube controller in port 1, which the Wii version of the game supports alongside the Wii Remote. The launcher writes its mapping to `Config/GCPadNew.ini` in the user directory the first time a gamepad is available, and **Controls → Replace with generated GameCube profile** writes it again. The first controller also answers to the keyboard:

| GameCube | Gamepad | Keyboard |
| --- | --- | --- |
| A | Bottom face button (A / Cross) | S |
| B | Right face button (B / Circle) | D |
| X | Left face button (X / Square) | A |
| Y | Top face button (Y / Triangle) | W |
| Z | Right trigger (RT / R2) | Q |
| L | Left shoulder (LB / L1) | Left Shift |
| R | Right shoulder (RB / R1) | E |
| Start | Start | Enter |
| Control stick | Left stick | Arrow keys |
| C-stick | Right stick | — |
| D-pad | D-pad | — |

The SR-ZGS controller drawing also has three extra buttons that the GameCube controller doesn't:

| SR-ZGS extra | Gamepad | Keyboard |
| --- | --- | --- |
| C | Left trigger (LT / L2) | — |
| − (Select) | Back / Select | Backspace |
| Menu | Guide / Home | M |

The game doesn't receive them: the profile stores them as `Extra/C`, `Extra/Select` and `Extra/Menu`, which the game's controller ignores. **Menu** opens the [in-game menu](#in-game-menu); C and − are kept for SR-ZGS features and mods later. **Controls → Button mapping** shows the drawing of the controller and of the keyboard and lights up whatever is pressed, extra buttons included.

On Linux the keyboard is read through X11, which the launcher uses by default. The first GameCube controller stays connected when the gamepad is unplugged, so the keyboard keeps working on its own. The emulated Wii Remote is left disconnected (`Source = 0` in `Config/WiimoteNew.ini`, checked every time the game starts), so keys don't also press Wii Remote buttons such as HOME. Without any gamepad, the launcher writes the profile for the keyboard alone (**Controls** shows *Keyboard only*); a gamepad connected later is added to the same profile and the keys keep working. A gamepad can report a different name depending on how it is connected (for example over USB and over Bluetooth); when the configured one is missing and exactly one other gamepad is connected, the launcher switches the profile to it and keeps the mapping.

### Build Configuration Notes

- **Quick:** Uses `-O1` for generated game code and is intended for faster development iterations.
- **Release:** Uses `-O2` for generated game code and is intended for optimized builds.
- Both presets support the JIT64 and StaticRecomp CPU execution modes.
- The 60 FPS result mentioned above refers to developer testing with JIT64 mode. Performance may vary depending on hardware and configuration.

Build scripts, dependencies, and runtime behavior may change as the project evolves.

---

## 🎮 The SR-ZGS Launcher

The launcher is the program players open to play SR-ZGS. It is part of the ModernGekko fork and is built as `build/chassis/SR-ZGS`. Its window is 960x540 (larger on a screen with a display scale above 100%), and most pages show their panels in two columns so they fit without scrolling.

- **PLAY:** starts the game alone or through Netplay. Summary cards show the time played, the controller, the display settings and the installed mods, and the **PATCH NOTES** panel shows what changed in this version.
- **Settings:** CPU core, graphics backend, internal resolution, screenshot resolution, visual effect, game volume, aspect ratio (16:9, 4:3 or stretched), 4:3 borders, window size, fullscreen and FPS in the window title. Changes are saved right away and apply the next time you press **PLAY**; the visual effect, the internal resolution, the game volume and the 4:3 border can also be changed while playing, in the [in-game menu](#in-game-menu).
- **Window size** (Settings → Display) is the game window's size when it isn't fullscreen. **Automatic**, the default, fits it to your screen: a 16:9 window about 85% of the primary monitor, in its middle. 960x540 to 2560x1440 are fixed sizes; one that doesn't fit your screen becomes the automatic one. How sharp the game looks is the internal resolution, not the window size: a small window with a high internal resolution looks very sharp.
- **Controls:** chooses the controller, writes its GameCube profile (see [Controls](#controls)) and shows a tester that lights up whatever is pressed.
- **Game Files:** extracts your own copy of the game (see [Extracting with the Launcher](#extracting-with-the-launcher)).
- **Mods & expansions:** lists the mod packages installed, shows the folder they go in (`Mods` in the SR-ZGS user directory) with a button to open it, and presents the planned custom expansions (see [Future Ecosystem & Expansion Plans](#-future-ecosystem--expansion-plans)). SR-ZGS has no mods of its own yet.
- **Credits:** the people and projects SR-ZGS is built on, their licenses, and the version check.

**With a gamepad.** The launcher works with a gamepad as well as with the mouse and keyboard: the D-pad or the left stick moves, **A** chooses and **B** goes back to the sidebar; **LB** and **RB** change the page, the right stick scrolls, and **right** goes from the sidebar into the page. While a gamepad is in use, the bottom right corner shows its buttons as the controller prints them (Xbox, PlayStation or Nintendo). On the **Controls** page the controller is being tested, so its buttons only light up the drawing: hold **B** (or press Escape) to stop testing and move through the page; **Test buttons** starts the test again. The Netplay lobby works with a gamepad too.

The bottom of the sidebar holds the language menu: English, Spanish, Japanese, or the system's language. The patch notes follow the chosen language. The launcher and the Netplay lobby each play their own music track; its volume is in **Settings → Audio**, next to the game's.

### 4:3 borders

When the game is shown in 4:3 on a wider screen, the bars beside it can show a picture instead of black: Sonic, Knuckles & Tails; Jet, Wave & Storm; a green grid; or a blue grid. The grids slide like the launcher's floor. Choose one in **Settings → Display → 4:3 borders**: **Random** (the default) picks one each time the game opens, and **None** keeps the bars black. The borders are drawn only on your screen, in Netplay too.

The character borders are always shown whole and undistorted, as large as the bar allows, whatever the window's size, the screen's shape or fullscreen; any space left in the bar shows a blurred copy of the picture. The grids fill the whole bar.

The pictures and their list are in `docs/borders/`. `tools/make_game_borders.py` draws both grids from scratch, makes the blurred copies and writes `borders.txt`; it also builds the two character borders from their full artworks, which are kept outside the repository.

### In-game menu

While playing, press **M** on the keyboard or **Guide / Home** on the gamepad (the **Menu** button of the SR-ZGS controller) to open the menu. In solo play the game pauses. Move with the D-pad, the control stick or the arrow keys, choose with **A** (S on the keyboard) and go back with **B** (D); M or Guide again closes it. The line at the bottom of the menu shows those buttons as your controller prints them (Xbox's A and B, PlayStation's cross and circle, a Nintendo pad's B and A), or as keyboard keys if the keyboard was the last thing you pressed; if you remap A or B in your controller profile, it shows the new ones.

- **Continue** goes back to the game.
- **Quick settings** change the visual effect, the internal resolution, the game's volume and, when the game is in 4:3, the border. Choose a row and press left or right (A goes round the choices): the change shows at once, even with the game paused, and the launcher keeps it for next time.
- **See controls** shows what each button of the GameCube controller is on your gamepad and on the keyboard, as your controller profile has them.
- **Take screenshot** takes a screenshot at high resolution (see below); the menu stays open.
- **Back to the launcher** closes the game and shows the launcher again.
- **Quit game** closes the game and the launcher.

The last two ask first, since progress the game hasn't saved is lost. In Netplay the match keeps going behind the menu, the game gets no input from you while it is open, and **Back to the lobby** ends the match for every player.

**Visual effects** are drawn over the game's picture, in one pass, so they run on integrated graphics such as a laptop's:

| Effect | What it does |
| --- | --- |
| Bloom | Lights and bright highlights glow softly |
| Chromatic aberration | Red and blue drift apart toward the edges, as through a camera lens |
| Vivid colors | Richer colors and a little more contrast |
| Sharpen | Details and edges stand out more |
| Outline | Dark lines along the edges, like a cartoon |
| Smooth edges (FXAA) | Softens jagged edges |
| CRT | Scanlines and darker corners, like an old TV |

An effect only sees the finished picture, not what is in it, so **Outline** draws its lines around everything on screen with a clear edge (characters, the track, the menus), not around the characters alone. Soft shading and most textures get no line.

**Screenshots:** press **F9**, or choose **Take screenshot** in the menu. They are taken at **Settings → Graphics → Screenshot resolution** (3840x2160 by default, up to 5120x2880), whatever the internal resolution, and never below it: the game is drawn at that resolution only for the few frames the picture needs, then goes back to its own, and the setting doesn't change. A paused game runs those frames without sound or input and pauses again, so the picture is of a moment a fraction of a second later. A message at the bottom of the screen says when the picture is saved and its size. Screenshots are PNG files named `SR-ZGS_0001.png`, `SR-ZGS_0002.png` and so on, in `ScreenShots/RS9E8P/` inside the user directory (`~/.local/share/sr-zgs/ScreenShots/RS9E8P/` on Linux). As with Dolphin's own, they show the game's picture without the visual effect, the 4:3 borders or the menu. A high resolution needs more video memory: if screenshots fail, choose a lower one.

The launcher's **Screenshots** page shows them, newest first, without opening any other program: choose one to see it large, go to the next or previous one with the arrow keys or the buttons, and delete one you don't want. **Open folder** opens the folder they are in.

SR-ZGS has no savestates: the game window has no savestate keys and the launcher doesn't offer them, so the game is played through as on the console. The game window keeps **F9** (a screenshot, as above), **F10** (pause), **Alt+Enter** (fullscreen) and **Ctrl+Esc** (close the game).

**Updates:** the launcher compares its version with the newest release published on [GitHub](https://github.com/KnivesDevilish/SR-ZGS/releases), when it opens (this can be turned off on the **Credits** page) or when you press **Check for updates**. It never downloads or installs anything: when a newer version exists, it only opens the download page in your browser. No release has been published yet.

The launcher keeps its settings in `config.ini` inside the SR-ZGS user directory (`~/.local/share/sr-zgs/` on Linux), together with the controller profile, saves and logs.

---

## 🌐 Netplay

Netplay lets up to four players race together. On the launcher's **PLAY** page, one player presses **Host Netplay** and the others **Join Netplay**; everyone then waits in the Netplay lobby until the host starts the match. There are two ways to connect:

- **Invite code** (default): the host gets an 8-character code (numbers and the letters a–f) to share with friends, who type it in **Join Netplay**. Nobody sees anybody else's IP address. Codes are handed out by the public server of the Dolphin project (`stun.dolphin-emu.org`); `invite_server` in the `[Netplay]` section of `config.ini` can name another one.
- **Direct IP:** friends connect to the host's address and UDP port (2626 by default). It is meant for players on the same network or on [Tailscale](https://tailscale.com/).

> [!WARNING]
> Anyone who sees an invite code can join the room, and an IP address identifies your connection. Don't show either one on stream or post them publicly.

Every player needs the same SR-ZGS release and the same game files. Everyone plays with the host's CPU core and the host's 16:9 or 4:3 choice; JIT64 is recommended, especially when players are on different systems.

Netplay is part of the experimental build and has had limited testing so far.

---

## 🧩 Future Ecosystem & Expansion Plans

### 💽 Custom Story Expansions & Modding Support

One of the long-term ambitions of **Sonic Riders: Zero Gravity Source** is to establish a modular ecosystem for custom content and community-created expansions.

The project aims to eventually support original story campaigns, additional characters, custom tracks, cutscenes and other fan-created content without requiring modifications to the original game assets.

Potential projects and concepts include:

- Custom story campaigns.
- Additional character slots.
- Original tracks and environments.
- Community-created expansions.
- Extended gameplay features.

<p align="left">
  <img src="docs/SR-ZGS Mods.png" alt="SR-ZGS x Custom Story" width="520">
</p>

<sub>This is a planned expansion concept and part of the project's long-term vision. Its implementation depends on future development of the required modding and expansion systems.</sub>

---

## 🤝 Contributing & FAQ

SR-ZGS is an experimental project, and contributions, technical feedback and testing reports are welcome.

Areas where help would be valuable include:

- C and C++ development.
- PowerPC and Wii system research.
- Static recompilation.
- Runtime development.
- Hardware compatibility testing.
- Documentation.

Whether you're interested in contributing code, testing the project or sharing technical knowledge, your help is appreciated.

Constructive feedback is always welcome. <3

### Does SR-ZGS currently support mods?
Not yet. Native project-specific mod loading is a future development goal. The `mods/` directory is reserved for future use and does not currently represent a fully implemented SR-ZGS mod loader. ModernGekko itself can load experimental code mod packages (`.mgm`) from the `Mods` folder of the SR-ZGS user directory; the launcher's **Mods & expansions** page lists them and opens that folder.

### Does SR-ZGS require Dolphin?
SR-ZGS currently uses a modified fork of **ModernGekko**, a Dolphin-derived runtime, to provide graphics, audio, input and Wii system services. You don't need to install Dolphin separately: the runtime is built from the `external/ModernGekko/` submodule. A more independent runtime is a long-term development goal.

### Is there a downloadable release?
Not yet. The first public version, 0.1.0, is still in development, so for now SR-ZGS is built from source as described above. Once a release is published, the launcher's **Check for updates** will point to it.

### Does the project run at 60 FPS?
The game successfully ran from start to finish at 60 FPS during developer testing. This is an observed result from a specific test configuration, not a guarantee for every system.

### Can I use files from the PS2 or GameCube versions?
No. SR-ZGS specifically targets the NTSC-U Nintendo Wii release of Sonic Riders: Zero Gravity (`RS9E8P`). Other versions have different executable structures and are outside the current project scope.

### Will Android be supported?
Android is a long-term target for the project. However, there is currently no supported Android build or verified mobile compatibility.

### Will custom story campaigns and fan content be supported?
Custom story campaigns, additional characters, tracks and other fan-created content are possibilities for future development. These features are not currently implemented.

### Are additional languages or voice localizations planned?
The launcher, its Netplay lobby and the patch notes are available in English, Spanish and Japanese. The game's own text and voices are those of your copy of the game. Additional text and audio localization options for the game may be explored in the future. No additional fan-dub integration is currently included in the working build.

### Do you plan to recompile other Sonic games?
SR-ZGS is currently focused on Sonic Riders: Zero Gravity. The project does not currently have plans to expand its scope to other Sonic titles.

---

## ❤️‍🔥 Credits & Acknowledgments

**Created by** 奈依茲・悪魔的 (JP: Naizu Akumateki · EN: KnivesDevilish), with the SR-ZGS contributors and testers: research, development and testing. The launcher and Netplay lobby music are original tracks by KnivesDevilish.

**Built on:**

- **DolRecomp** — Static recompilation framework.
- **ModernGekko** by Hyperway — Runtime for GameCube/Wii recomps. SR-ZGS uses a modified fork of it.
- **RecompCore** — SpecialK / aharonahdoot.
- **Recomp template** — Literally God / MrPoloGit, who also added macOS support.
- **Dolphin** — The Dolphin Team and its contributors: the foundation for much of the runtime technology.
- **Invite codes** — The Dolphin project's public server (`stun.dolphin-emu.org`).

**Licenses:**

| Component | License |
| --- | --- |
| SR-ZGS, ModernGekko | GNU GPL v3 |
| Dolphin | GNU GPL v2 or later |
| SDL 3 | zlib License |
| Dear ImGui | MIT License |
| Noto Sans CJK | SIL Open Font License 1.1 |

This project is an independent fan project and is not affiliated with or endorsed by SEGA. Sonic Riders: Zero Gravity and its characters are trademarks of SEGA.
