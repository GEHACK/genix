---
title: GEHACK Contest Environment
description: What you get on a team workstation — editors, compilers, tooling, and how to submit
---

A standard **GNOME desktop on NixOS 26.05**. Firefox is the browser: it sits in the dock
and opens on the contest judge when you log in. Everything below is installed and ready the
moment you log in — nothing to set up.

> Want to run this environment yourself? See **[The GEHACK Live Image](build.md)**.

## Desktop

| | |
|---|---|
| Operating system | NixOS 26.05 |
| Desktop | GNOME (Wayland) |
| Browser | Firefox |
| Keyboard layouts | US and NL (switch from the GNOME top bar) |
| Shell | Bash by default; Zsh is installed too (with autosuggestions and syntax highlighting) |
| Trackpad | Press <kbd>Super</kbd>+<kbd>T</kbd> (or the laptop's touchpad key), or run **Toggle Trackpad**, to switch it off while typing and back on |

## Languages & compilers

| Language | Toolchain | Notes |
|----------|-----------|-------|
| C | GCC | `gnu17` standard; `gdb` and `cmake` included |
| C++ | GCC (g++) | `gnu++20` standard; `gdb` and `cmake` included |
| Python | CPython 3 & PyPy 3 | Both interpreters installed; PyPy for speed |
| Java | JDK 21 | `JAVA_HOME` preset |
| Kotlin | Kotlin compiler | JVM-based; runs on JDK 21 |

## Compile helpers

Pre-configured wrappers that build with contest-appropriate flags so you don't have to
remember them. Each takes the source basename.

| Command | Runs |
|---------|------|
| `mygcc sol` | gcc `-std=gnu17 -Wall -O2 -static` → `sol.c` to `sol` |
| `mygpp sol` | g++ `-std=gnu++20 -Wall -O2 -static` → `sol.cpp` to `sol` |
| `mypython sol.py` | PyPy 3 interpreter |
| `myjavac Sol.java` | javac (JDK 21, UTF-8) |
| `mykotlinc Sol.kt` | kotlinc (JDK 21) → JVM classes in the current dir |

```console
$ mygpp solution      # compiles solution.cpp → ./solution
$ ./solution < in     # run it
```

## Editors & IDEs

Pick whatever you're fastest in — all are installed.

- **VS Code** — with C/C++ (plus CMake Tools), Python and Java extensions; build & debug
  tasks pre-wired for C/C++ (g++ `-std=c++23` / gcc `-std=c17`, gdb). AI/Copilot features,
  the welcome page and update prompts are switched off. The Vim extension is installed but
  off by default: run **Vim: Toggle Vim Mode** from the Command Palette
  (<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>) to turn it on.
- **Neovim** — clangd, pyright and jdtls language servers plus treesitter highlighting.
- **Vim**, **Emacs**, **nano**, **gedit**, **Geany**
- **JetBrains** — PyCharm (Python), IntelliJ IDEA (Java & Kotlin), CLion (C/C++)
- **Eclipse** and **NetBeans** (Java)
- **Code::Blocks** (C/C++)

## Command-line tools

Debugging, profiling and the usual shell utilities:

`gdb` · `valgrind` · `strace` · `cmake` · `git` · `tmux` · `screen` ·
`shellcheck` · `btop` · `htop` · `iotop` · `wget` · `curl` · `zip` / `unzip` / `7z`

## Submitting solutions

The DOMjudge `submit` command-line tool is installed and pre-pointed at the contest
judge — no URL to configure.

```console
$ submit solution.cpp        # submit for the current problem
$ submit -p A solution.cpp   # submit explicitly for problem A
```

You can also submit from the DOMjudge web interface in Firefox: it is the browser's
homepage and the first bookmark on the toolbar.

## Printing

The contest printer, **PSGEWIS1**, is set up as the default printer. Print from any
application with <kbd>Ctrl</kbd>+<kbd>P</kbd>, or from the terminal:

```console
$ lp solution.cpp
```

## Extras

| | |
|---|---|
| Offline DevDocs | Full [DevDocs](https://devdocs.io/) mirror at `https://docs.gehack.nl` (also on the Firefox bookmarks toolbar) — no internet needed |
| Games | GNOME games (Sudoku, Mines, Mahjongg…), SuperTux, SuperTuxKart, Neverball, plus terminal classics |

## Good to know

- **No internet during the contest.** The machine can reach the judge, the DevDocs mirror
  and the printer; other machines on the contest network are blocked.
- **Firefox is locked down**: extensions cannot be installed and the homepage is fixed to
  the judge.
- **USB devices plugged in after the machine has started are blocked.** Ask a GEHACK
  volunteer if you need to connect something.
- **WiFi and Bluetooth are disabled.**
- **Your screen and webcam are streamed** to the contest organisation.
- **Nix commands are disabled** for the contest account; everything you need is already
  installed.
