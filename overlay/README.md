<p align="center"><img src="misc/fliper/icon.svg" width="96" alt="Fliper"></p>

# Fliper Engine

**A game engine with an AI studio built in.** Talk, and the Fliper AI plans, codes, draws, tests and
opens your game. Full 2D and 3D, PBR materials and textures, global illumination, physics, animation,
and export to Windows, macOS, Linux, Android, iOS and the web.

- **Fliper panel in every project:** chat on the right side of the editor. It reads and writes your project,
  runs the game headless to catch errors, opens it for you to play, looks at the screen and pulls free
  sprites from the [Fliper Feira](https://fliperstudio.com/feira/).
- **Bring your AI:** Fliper models (key at [fliperstudio.com/account](https://fliperstudio.com/account)),
  or your own OpenRouter / OpenAI key. Your key stays in your editor settings, never in the project.
- **Publish:** one click to the Fliper Arcade, or export to Steam.

## Download

[Releases](../../releases): Windows, Linux and macOS (Apple Silicon). On macOS, right-click › Open the first time.

## Built on Godot

Fliper Engine is based on [Godot Engine](https://godotengine.org) 4.7.2, by Juan Linietsky, Ariel Manzur and
the Godot community, under the MIT license (see `LICENSE.txt`, `COPYRIGHT.txt` and `README-GODOT.md`).
Fliper changes: branding, the Fliper editor theme, and the built-in Fliper AI panel (`misc/fliper/`).
Thank you, Godot contributors.

## Build

```
pip install scons
scons platform=linuxbsd target=editor   # or windows / macos
```

Regenerate the brand assets with `python3 misc/fliper/marca.py` and the built-in panel with
`python3 misc/fliper/embutir_addon.py`. CI: `.github/workflows/fliper-build.yml`.

License: MIT. © Fliper Studio and the Godot Engine contributors.
