<p align="center"><img src="overlay/misc/fliper/icon.svg" width="96" alt="Fliper"></p>

# Fliper Engine

**A game engine with an AI studio built in.** Talk, and the Fliper AI plans, codes, draws, tests and opens your game.
Everything Godot does (2D and 3D, PBR, physics, animation, export to desktop, mobile and web), plus the Fliper panel.

- **Download:** [fliperstudio.com/download](https://fliperstudio.com/download/) (Windows, macOS, Linux) or [Releases](../../releases).
- **No install?** Make games in the browser at [fliperstudio.com/studio](https://fliperstudio.com/studio/).

## What is in this repository

Fliper Engine = official **Godot Engine 4.7.2-stable** + the files in [`overlay/`](overlay):

| | |
|---|---|
| `overlay/misc/fliper/addon/fliper/` | the Fliper AI panel (GDScript), copied into every new project |
| `overlay/editor/...` | Fliper editor theme and new-project defaults ([diff](mudancas-no-godot.diff)) |
| `overlay/misc/fliper/marca.py` | generates the logo, icons and splash |
| `instalador.iss` | Windows installer (Inno Setup) |

The build ([`.github/workflows/build.yml`](.github/workflows/build.yml)) clones Godot at the tag, copies `overlay/` on top,
embeds the panel and compiles. Anyone can reproduce the binaries from this repository.

## Build it yourself

```
git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git motor
cp -r overlay/. motor/ && python3 motor/misc/fliper/embutir_addon.py
cd motor && scons platform=linuxbsd target=editor production=yes   # or windows / macos
```

## Privacy

Fliper adds no telemetry to the editor. The AI panel only talks to the AI you choose (Fliper, OpenRouter or OpenAI),
when you send a message. "Sign in with Fliper" opens fliperstudio.com in your browser to connect your account.

## License and credits

MIT ([LICENSE.txt](LICENSE.txt)). Built on [Godot Engine](https://godotengine.org) by Juan Linietsky, Ariel Manzur and the
Godot community, MIT ([LICENSE-GODOT.txt](LICENSE-GODOT.txt)). Fliper is not affiliated with the Godot Foundation.
Thank you, Godot contributors.

Code signing for Windows is provided free of charge by [SignPath.io](https://about.signpath.io), certificate by
[SignPath Foundation](https://signpath.org) (once approved).
