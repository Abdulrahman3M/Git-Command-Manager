# Task Plan

## Objective

Build `Git Command Manager` in the owner-selected directory, using one safety-aware Git engine behind Task Dashboard, Command Palette, and Assistant Console. Publish all project files to a new private GitHub repository named `Git-Command-Manager`.

## Scope

- Implement and package the PowerShell TUI application and tests.
- English Title Case UI; Dashboard is the first-run default.
- Persist interface preference and permit live switching.
- Keep command definitions, validation, execution, risk controls, and settings shared.
- Validate on supported PowerShell platforms and publish privately.

## Must Preserve

- Project root exactly `D:\Test\02 ? Assistance Projects\Git Command Manager`.
- Project display name exactly `Git Command Manager`.
- Use existing owner handoff as specification.
- One shared Git command engine; safe defaults and explicit confirmation for risky operations.

## Out of Scope

- Public repository publication.
- Renaming the user-selected directory or creating a second product identity.
- Unverified claims about platforms or workflows not actually tested.

## Acceptance Criteria

- Three integrated modes work through the same engine; Dashboard defaults on first run.
- Interface mode is configurable, persisted, and switchable without restart.
- UI uses English Title Case, consistent responsive renderer/input/theme, and clear operation context.
- Tests/static validator pass on supported Windows PowerShell editions; Linux/CI/manual items are explicitly verified or reported.
- All project files are pushed to a new private `Git-Command-Manager` repository.

## Phase Map

| Phase | Objective | Status | Dependency |
|---|---|---|---|
| P01 | Handoff, scope, and local setup | COMPLETE | None |
| P02 | Shared command engine and safety | COMPLETE | P01 |
| P03 | Three interfaces and persistent settings | COMPLETE | P02 |
| P04 | Documentation, quality, and platform verification | COMPLETE WITH LIMITATIONS RECORDED | P02, P03 |
| P05 | Publish to the owner-selected private GitHub repository | COMPLETE | P04 |

## P01 ? Handoff And Local Setup

- Prerequisites: Owner-provided target and handoff.
- Steps: Read handoff and requested skills; establish project scaffold and local Git history.
- Expected files: Project root, scaffold, docs, tests, local Git.
- Acceptance: Project name/path, requested interface decisions, and scope recorded.
- Verification: Inspect root, branch, HEAD, and current state.
- Dependency: P02.

## P02 ? Shared Engine And Safety

- Prerequisites: P01.
- Steps: Review command inventory, process execution, workspace operations, safety policy, and generic command behavior.
- Expected files: `src/Core/`, `data/commands.json`, core tests, security and architecture docs.
- Acceptance: Shared engine, argument-array process invocation, validation/confirmation boundaries, command catalog consistency.
- Verification: TUI runner, focused repository tests, edge-case review.
- Dependency: P03.

## P03 ? Three Interfaces And Settings

- Prerequisites: P02.
- Steps: Validate hierarchical dashboard, searchable palette, guided workflows, settings access, mode persistence, and live switching.
- Expected files: `src/Core/App.psm1`, `src/TUI/`, settings tests.
- Acceptance: All modes present and share engine; dashboard first-run default; preference restored after restart.
- Verification: Unit tests and interactive terminal walkthrough.
- Dependency: P04.

## P04 ? Verification And Documentation

- Prerequisites: P02, P03.
- Steps: Validate package, tests, Title Case strings, Git workflows, docs, responsive terminal behavior, and CI.
- Expected files: `tests/`, `docs/`, `.github/workflows/`, launchers.
- Acceptance: Required checks passed or limitations recorded accurately.
- Verification: Official TUI validator/runner, platform and interactive checks, scope review.
- Dependency: P05.

## P05 ? Private GitHub Publication

- Prerequisites: P04 and authenticated repository-creation/push capability.
- Steps: Create `Abdulrahman3M/Git-Command-Manager` as Private; configure remote; push all project files; verify repository visibility and HEAD.
- Expected files: Git remote and published repository.
- Acceptance: Private repository exists with complete project history/files.
- Verification: Read repository metadata, visibility, branch, and file list.
- Dependency: Task completion.
