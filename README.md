# Proton-CLI

Run Windows programs with Proton from the command line, without starting Steam.

Proton-CLI is a POSIX shell launcher. It downloads a Proton runtime for your
machine, creates one Wine prefix per program, and runs the program with that
runtime. It works on **x86_64** and **aarch64 (arm64)** Linux.

> Status: early development (`0.7.0-exp`). Commands and file layouts may still change.

---

## Install

The installer downloads a pinned release, verifies its SHA-256 checksum and
installs `proton-cli` into `/usr/local/bin`:

```bash
curl -fsSL https://raw.githubusercontent.com/Lh29007/ProtonCLI-Experiemental/v0.7.0-exp/install.sh | sudo sh
```

It needs `curl`, `tar`, `gzip`, `file` and `sha256sum`. Missing dependencies are
installed with `apt`, `dnf` or `pacman` when available.

To install from a local checkout, point the installer at the files:

```bash
sudo env PROTON_CLI_URL="file://$PWD/proton-cli" \
         PROTON_CLI_SHA_URL="file://$PWD/proton-cli.sha256" sh install.sh
```

## Quick start

```bash
proton-cli doctor                   # check the system
proton-cli install                  # download a runtime for this machine
proton-cli run /path/to/game.exe    # run a program
```

## Runtimes by architecture

`proton-cli install` detects the machine architecture:

| Host            | Default source                                                                 | Runtime name            |
|-----------------|--------------------------------------------------------------------------------|-------------------------|
| x86_64          | [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom/releases)      | `GE-Proton*-x86_64`     |
| aarch64 (arm64) | [DroidDeck-Proton](https://github.com/Droid-Deck/DroidDeck-Proton/releases)    | `DroidDeck-Proton-*-aarch64` |

```bash
proton-cli install                  # auto: picks the source for this machine
proton-cli install ge               # GE-Proton (x86_64 only)
proton-cli install droiddeck        # DroidDeck-Proton (aarch64 only)
proton-cli update                   # install the latest release if it is newer
proton-cli list                     # installed runtimes; the default is marked
proton-cli use <runtime>            # choose the default runtime
proton-cli remove <runtime>         # delete a runtime
```

Every archive is checked against its `.sha512sum` before extraction. An archive
without a checksum is refused, except for a custom `PROTON_RUNTIME_URL` archive,
which is installed with a warning. The Wine binary in the archive must match the
machine's architecture.

## Running programs

```bash
proton-cli run game.exe [arguments]
```

- Output is shown live and saved to `~/.local/share/proton-cli/logs/<game>.log`.
- The program's exit status is returned by `proton-cli`.
- Each game gets its own prefix. Prefix names include a hash of the full path, so
  two different `setup.exe` files never share one.

### Per-game settings

```bash
proton-cli config game.exe show
proton-cli config game.exe runtime <name>      # use a specific runtime for this game
proton-cli config game.exe runtime default     # back to the default runtime
proton-cli config game.exe wrapper <command>   # e.g. an emulator, see below
proton-cli config game.exe wrapper none
```

Settings are stored in `~/.config/proton-cli/games/`.

### Prefixes and Winetricks

```bash
proton-cli prefix <name>                # create a standalone prefix
proton-cli reset game.exe               # delete the game's prefix (asks first)
proton-cli reset game.exe --yes         # delete without asking
proton-cli winetricks game.exe corefonts vcrun2019
```

`winetricks` must be installed separately. It runs inside the game's prefix with
the runtime's own Wine.

## arm64 and x86_64 runtimes on arm64

On an arm64 host, DroidDeck-Proton runs natively. An **x86_64** runtime needs an
x86 emulator in front of Proton. Set one globally or per game:

```bash
PROTON_WRAPPER="box64" proton-cli run game.exe
proton-cli config game.exe wrapper "FEX-Emu"
```

`run` warns when it finds an x86_64 runtime on arm64 with no wrapper configured.

## Environment variables

| Variable               | Purpose                                                                  |
|------------------------|--------------------------------------------------------------------------|
| `PROTON_RUNTIME_URL`   | Install this Proton `.tar.gz` instead of a release. Checksum optional.   |
| `PROTON_WRAPPER`       | Command placed in front of Proton (default for all games).               |
| `GITHUB_TOKEN`         | Authenticate GitHub API calls (raises the rate limit).                   |
| `PROTON_GE_API`, `PROTON_DROIDDECK_API` | Override release API URLs (used by the tests).             |

## Files

| Path                                  | Content                              |
|---------------------------------------|--------------------------------------|
| `~/.local/share/proton-cli/runtimes/` | Installed runtimes                   |
| `~/.local/share/proton-cli/prefixes/` | Wine prefixes, one per game          |
| `~/.local/share/proton-cli/cache/`    | Downloaded archives and checksums    |
| `~/.local/share/proton-cli/logs/`     | Per-game logs                        |
| `~/.config/proton-cli/runtime`        | Default runtime name                 |
| `~/.config/proton-cli/games/`         | Per-game settings                    |

Runtimes, prefixes, caches, logs and games are never stored in the repository.

## Commands

```
install [auto|ge|droiddeck]     update [auto|ge|droiddeck]
use <runtime>                   list
remove <runtime>                run <game.exe> [args]
config <game.exe> show|runtime <name|default>|wrapper <cmd|none>
prefix <name>                   reset <game.exe> [--yes]
winetricks <game.exe> <verb>... doctor
version                         uninstall
```

## Tests

```bash
bash tests/run-tests.sh
```

The suite runs offline. It starts a local HTTP server that serves fake GitHub
releases, fake Proton archives (with real ELF headers for x86-64 and aarch64) and
checksums. An arm64 host is simulated with a `uname` shim, so both code paths run
on any machine. The suite also lints the scripts with `shellcheck` when it is
installed. CI runs the lint and the tests on x86_64 and native arm64 runners.

## Release

The installer is pinned to a tag and checks a SHA-256 file published with it:

```bash
sh -n proton-cli && sh -n install.sh && bash tests/run-tests.sh
sha256sum proton-cli > proton-cli.sha256
git add proton-cli proton-cli.sha256 install.sh
git commit -m "Release vX.Y.Z"
git tag vX.Y.Z && git push origin main vX.Y.Z
```

`VERSION` must match in `proton-cli` and `install.sh`. The installer's default
ref is `v$VERSION`, so bumping `VERSION` is enough. The tests fail if
`proton-cli.sha256` is stale.

## Known limits

- The aarch64 path, including the DroidDeck-Proton archive layout, has been tested
  with fake archives only. It has not been checked on a real arm64 machine.
- GE-Proton has no aarch64 build. On aarch64, use DroidDeck-Proton or
  `PROTON_RUNTIME_URL`.
- Game compatibility depends on the runtime, your GPU and drivers. Proton-CLI does
  not fix game-specific problems.
- Steam game detection, GUI and runtime-per-profile features are not implemented yet.
  See [docs/ideas.txt](docs/ideas.txt).

## Contributing

1. Run the tests and the linters before you open a pull request.
2. Keep the scripts POSIX `sh` (`proton-cli`, `install.sh`).
3. Never commit runtimes, prefixes, logs or game files.

## Disclaimer

Proton-CLI is an independent community project. It is not affiliated with or
endorsed by Valve Corporation. Proton is developed by Valve and contributors.
Proton-CLI does not redistribute Steam game files. Use only games and software
you have the right to use.

## License

MIT. See [LICENSE](LICENSE).
