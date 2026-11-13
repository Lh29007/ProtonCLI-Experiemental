# Proton-CLI

> Run Windows games with Proton directly from the command line — without launching the Steam client.

**Proton-CLI** is a lightweight command-line launcher designed to run Windows applications and games using **Valve Proton** or compatible Proton builds such as **GE-Proton**.

## Installation

### Quick Install

Simply run:

```bash
curl -fsSL https://raw.githubusercontent.com/Lh29007/ProtonCLI/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

The installer will automatically:

* Check for administrator privileges
* Install the required dependencies
* Download the latest Proton-CLI version
* Verify the script syntax before installation
* Install `proton-cli` to `/usr/local/bin`
* Create the required Proton-CLI directories in the user's home directory

### Verify the Installation

```bash
proton-cli version
```

Run a system diagnostic with:

```bash
proton-cli doctor
```

### Install GE-Proton

Once Proton-CLI is installed:

```bash
proton-cli install
```

### Uninstall

To completely remove Proton-CLI:

```bash
sudo proton-cli uninstall
```



The goal is simple: make Proton usable outside the Steam graphical interface while keeping the experience fast, scriptable and easy to use.

> 🚧 **Status: Early development**
>
> Proton-CLI is currently experimental. Features, commands and configuration formats may change.

---

## ✨ Features

* 🎮 Run Windows `.exe` applications with Proton
* ⚡ Command-line focused
* 🧩 Support for GE-Proton runtimes
* 📦 Automatic Proton runtime installation
* 🗂️ Separate Wine/Proton prefixes for games
* 📝 Per-game logs
* 🔍 Dependency and environment diagnostics
* 🐧 Designed for Linux
* 💻 Works independently from the Steam graphical client

---

## 🚀 Quick Start

Clone the repository:

```bash
git clone https://github.com/Lh29007/proton-cli.git
cd proton-cli
```

Make the launcher executable:

```bash
chmod +x proton-cli
```

Check your system:

```bash
./proton-cli doctor
```

Install a Proton runtime:

```bash
./proton-cli install
```

Then run a Windows executable:

```bash
./proton-cli run /path/to/game.exe
```

---

## 🎮 Example

For example:

```bash
./proton-cli run "/path/to/DELTARUNE.exe"
```

Proton-CLI creates an isolated prefix for the game and launches it through the selected Proton runtime.

Example output:

```text
======================================
             Proton-CLI
======================================

Runtime : GE-Proton11-6-x86_64
Game    : /path/to/DELTARUNE.exe
Prefix  : ./prefixes/DELTARUNE
Log     : ./logs/DELTARUNE.log

fsync: up and running.
```

---

## 🦾 arm64 (experimental)

GE-Proton only publishes x86_64 builds, so on an arm64 (aarch64) machine `proton-cli install` stops with an explicit error. Two environment variables let you work around this:

* `PROTON_RUNTIME_URL` — URL of a Proton `.tar.gz` to install instead of GE-Proton. The archive must contain `proton` and `files/bin/wine`, and the Wine binary must be arm64 (`ARM aarch64`).
* `PROTON_WRAPPER` — a command placed in front of Proton at launch, for example an emulator such as FEX-Emu or box64 when running an **x86_64** runtime on arm64.

```bash
PROTON_RUNTIME_URL="https://example.com/Proton-arm64.tar.gz" ./proton-cli install
PROTON_WRAPPER="box64" ./proton-cli run /path/to/game.exe
```

`proton-cli doctor` shows both overrides. This path has been tested only with a fake archive on x86_64; it has **not** been validated on a real arm64 machine.

---

## 🧰 Commands

The command interface is currently evolving.

### `doctor`

Check the local environment and required dependencies:

```bash
./proton-cli doctor
```

Example:

```text
✓ wine
✓ git
✓ wget
✓ Runtime directory
✓ Prefix directory

Architecture: x86_64
Kernel: Linux
```

---

### `install`

Download and install a compatible Proton runtime:

```bash
./proton-cli install
```

The installer detects the system architecture and downloads the appropriate runtime.

---

### `list`

List installed Proton runtimes:

```bash
./proton-cli list
```

---

### `run`

Run a Windows executable:

```bash
./proton-cli run "/path/to/game.exe"
```

Proton-CLI automatically creates or reuses a prefix for the application.

---

## 📁 Directory Structure

A typical Proton-CLI installation looks like:

```text
proton-cli/
├── proton-cli
├── proton-setup.sh
├── README.md
├── .gitignore
│
├── runtimes/
│   └── GE-Proton11-6-x86_64/
│
├── prefixes/
│   └── DELTARUNE/
│
├── cache/
│
└── logs/
    └── DELTARUNE.log
```

Runtime files, prefixes, caches and logs are local files and should **not** be committed to Git.

---

## 🧩 Proton Runtimes

Proton-CLI is designed to work with Proton-compatible runtimes.

Examples include:

* Valve Proton
* GE-Proton
* Other compatible Proton builds

The runtime is responsible for the actual Windows compatibility layer.

Proton-CLI acts as the command-line launcher and management layer around it.

---

## 🗂️ Prefixes

Each game can have its own Proton/Wine prefix.

For example:

```text
prefixes/
└── DELTARUNE/
```

This keeps the Windows environment of one game separate from another.

Prefixes can contain:

* Windows registry files
* Wine configuration
* Installed Windows components
* Application-specific data

Because prefixes can become large, they are ignored by Git.

---

## 📝 Logs

Game logs are stored in:

```text
logs/
```

For example:

```text
logs/DELTARUNE.log
```

When a game fails to start, the log is one of the first things to check.

```bash
tail -100 logs/DELTARUNE.log
```

---

## 🖥️ Requirements

Proton-CLI is currently intended for Linux systems.

Typical requirements include:

* Linux
* `bash` / POSIX shell
* `wget` or `curl`
* `git`
* Wine/Proton dependencies
* Vulkan support for games requiring DirectX translation
* An x86_64 system for x86_64 Proton builds

Your GPU and graphics drivers must also support the technologies required by the game.

---

## 🎯 Project Goals

The long-term goal is to make Proton much easier to use outside Steam.

Planned ideas include:

* [ ] Automatic Steam game detection
* [ ] Steam Flatpak detection
* [ ] Automatic `.exe` discovery
* [ ] Game profiles
* [ ] Multiple Proton runtimes
* [ ] Runtime switching
* [ ] Automatic configuration
* [ ] Better Vulkan/DXVK diagnostics
* [ ] Prefix management
* [ ] Game management commands
* [ ] Performance profiles
* [ ] Better error messages
* [ ] Automatic updates
* [ ] Optional GUI
* [ ] Integration with `umu`
* [ ] Screenshot and debugging utilities

---

## ⚡ Why Proton-CLI?

Steam provides an excellent graphical interface for Proton, but sometimes you simply want to run a Windows application from a terminal.

For example:

```bash
proton-cli run game.exe
```

instead of opening a launcher first.

This makes Proton easier to use for:

* Scripts
* Custom launchers
* Desktop shortcuts
* Game managers
* Servers
* Automation
* Linux power users
* Minimal environments

---

## 🔬 Development

This project is currently in an early stage.

The architecture may change significantly as Proton-CLI evolves.

If you want to experiment with the project:

```bash
git clone https://github.com/Lh29007/proton-cli.git
cd proton-cli
chmod +x proton-cli
./proton-cli doctor
```

Bug reports, ideas and contributions are welcome.

---

## 🤝 Contributing

Contributions are welcome.

Before submitting a pull request:

1. Test your changes on Linux.
2. Keep the shell scripts portable where possible.
3. Avoid committing Proton runtimes or game prefixes.
4. Keep generated files out of the repository.
5. Explain what your change does.

---

## ⚠️ Disclaimer

Proton-CLI is an independent community project.

It is **not affiliated with or endorsed by Valve Corporation**.

Proton itself is developed by Valve and contributors.

Proton-CLI does not redistribute proprietary Steam game files.

Users are responsible for obtaining and using their own games and software legally.

---

## 📜 License

This project is released under the **MIT License**.

See [`LICENSE`](LICENSE) for details.

---

## ⭐ Support the Project

If you find Proton-CLI useful:

⭐ Star the repository
🐛 Report bugs
💡 Suggest features
🔧 Contribute improvements

Every contribution helps make Proton easier to use outside Steam.

---

**Proton-CLI — Proton from the terminal.**
