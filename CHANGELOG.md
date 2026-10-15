# Changelog

## [0.2.1] - 2026-10-15

### Changed

- Centered the README project title and placed the version beside it, removing the duplicate title line.


## [0.2.0] - 2026-10-15

### Added

- Integrated Project Management workflows for creating a local project folder, cloning GitHub repositories, connecting and verifying remotes, and managing local changes.
- Shared repository snapshots, remote and branch inventories, upstream tracking, and ahead/behind status.
- Safe branch management, history review, fetch, fast-forward-only pull, and confirmed push workflows.
- GitHub CLI account status, private repository creation, and repository page metadata editing.
- Project Management access from Task Dashboard, Command Palette, and Assistant Console.
- Official user-provided GitHub header image and a complete project overview README.
- Project Management guide, architecture and workflow updates, expanded shared state, and safety documentation.

### Fixed

- Empty new-project folder input now returns a validation message instead of a parameter-binding error.
- Scripted project-setup coverage now follows the same selection steps as the interactive workflow.

## [0.1.1] - 2026-10-15

### Added

- Semantic, function-specific icons with color roles and Emoji, Symbol, and ASCII fallbacks.
- Terminal-sized menu viewports for large command lists.

### Fixed

- Arrow-key navigation delay by diff-rendering legacy console frames and caching icon-tier detection.
- Git rename status parsing so the companion source path is not counted as another changed file.

## [0.1.0] - 2026-10-15

### Added

- Task Dashboard, Command Palette, and Assistant Console interface modes.
- Installed Git command discovery and machine-readable catalog export.
- Shared Git process boundary, workspace parser, and risk policy.
