# Architecture

## One Shared Git Engine

Core/App Routes Each Interface To Shared Workflows. The Three Interfaces Do Not Contain Separate Git Implementations.

- Core/GitProcess Is The Only Git Process Boundary And Receives Argument Arrays.
- Core/GitDiscovery Builds The Installed Command Inventory Used By The Dashboard And Command Palette.
- Core/Workspace Parses Repository Status, Paths, Branch, And Operation State.
- Core/Safety Classifies Command Risk And Applies Confirmation Rules.
- Core/ProjectManagement Validates GitHub URLs, Builds Safe Git And GitHub CLI Arguments, Inventories Remotes And Branches, And Produces Shared Repository Snapshots.
- Core/Settings Persists The Workspace And Preferred Interface Mode.

## Three Interaction Modes

Task Dashboard Is The First-Run Default And Organizes Actions Hierarchically. Command Palette Searches The Installed Command Catalog. Assistant Console Presents Guided Workflows. Each Routes Into Core/App And The Shared Modules Above.

## Flicker-Free TUI Ownership

- TUI/Renderer Owns Terminal Output, Buffered Frames, And Changed-Row Updates.
- TUI/Input Owns Interactive Keys And Scripted Test Input.
- TUI/Theme Owns Colors, Icons, Glyph Tiers, And Design Presets.
- TUI/Menu, TUI/Dialog, And TUI/Prompt Compose The Shared Renderer And Input Into Reusable Controls.

The Renderer Is The Only Terminal Writer. Selection Movement Reads Keys And Re-Renders Only Changed Rows; Terminal Size Bounds Large-Menu Viewports.

## Process Boundaries

Git And GitHub CLI Commands Are Launched Through Shared Process Helpers With Separate Argument Arrays, Explicit Working Directories, And Timeouts. URLs, Names, Paths, And Branch Values Are Validated At Their Domain Boundaries. The UI Only Presents The Returned State And Does Not Construct Independent Command Execution Paths.
