---
title: GEHACK Contest Environment
description: What you get on a team workstation — editors, compilers, tooling, and how to submit
---

A standard **GNOME desktop on NixOS 26.05**. Firefox is the browser and sits in the
dock by default. Everything below is installed and ready the moment you log in — nothing
to set up.

> Want to run this environment yourself? See **[The GEHACK Live Image](build.md)**.

## Desktop

| | |
|---|---|
| Operating system | NixOS 26.05 |
| Desktop | GNOME (Wayland) |
| Browser | Firefox |
| Keyboard layouts | US and NL (switch from the GNOME top bar) |

## Languages & compilers

| Language | Toolchain | Notes |
|----------|-----------|-------|
| C | GCC | `gnu17` standard; `gdb` and `cmake` included |
| C++ | GCC (g++) | `gnu++20` standard; `gdb` and `cmake` included |
| Python | CPython 3 & PyPy 3 | Both interpreters installed; PyPy for speed |
| Java | JDK 21 | `JAVA_HOME` preset |

*Kotlin support exists in the image but is disabled for this contest.*

## Compile helpers

Pre-configured wrappers that build with contest-appropriate flags so you don't have to
remember them. Each takes the source basename.

| Command | Runs |
|---------|------|
| `mygcc sol` | gcc `-std=gnu17 -Wall -O2 -static` → `sol.c` to `sol` |
| `mygpp sol` | g++ `-std=gnu++20 -Wall -O2 -static` → `sol.cpp` to `sol` |
| `mypython sol.py` | PyPy 3 interpreter |
| `myjavac Sol.java` | javac (JDK 21, UTF-8) |

```console
$ mygpp solution      # compiles solution.cpp → ./solution
$ ./solution < in     # run it
```

## Editors & IDEs

Pick whatever you're fastest in — all are installed.

- **VS Code** — with C/C++, Python and Java extensions; build & debug tasks pre-wired
  for C/C++ (g++ `-std=c++23`, gdb). Separate Vim and no-Vim launchers.
- **Neovim** — clangd, pyright and jdtls language servers plus treesitter highlighting.
- **Vim**, **Emacs**, **nano**, **gedit**, **Geany**
- **JetBrains** — PyCharm (Python), IntelliJ IDEA (Java), CLion (C/C++)
- **Eclipse** and **NetBeans** (Java)
- **Code::Blocks** (C/C++)

## Command-line tools

Debugging, profiling and the usual shell utilities:

`gdb` · `valgrind` · `strace` · `cmake` · `git` · `tmux` · `screen` ·
`shellcheck` · `btop` · `htop` · `iotop` · `wget` · `zip` / `unzip` / `7z`

## Submitting solutions

The DOMjudge `submit` command-line tool is installed and pre-pointed at the contest
judge — no URL to configure.

```console
$ submit solution.cpp        # submit for the current problem
$ submit -p A solution.cpp   # submit explicitly for problem A
```

You can also submit from the DOMjudge web interface in Firefox.

## Extras

| | |
|---|---|
| Offline docs | Available in-browser at `http://docs` |
| Games | GNOME games (Sudoku, Mines, Mahjongg…), SuperTux, plus terminal classics |
