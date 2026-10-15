# Architecture

`Core/GitProcess` is the only Git process boundary and uses argument arrays. `Core/GitDiscovery` creates the installed command inventory. `Core/Workspace` parses porcelain status. `Core/Safety` assigns risk tiers. The dashboard, palette, and assistant call these shared modules through `Core/App`; they do not implement Git operations independently.

`TUI/Renderer` owns terminal output, `TUI/Input` owns keys, and `TUI/Theme` owns colors and glyph tiers.
