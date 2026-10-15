# Problems And Solutions

This document records confirmed problems and fixes after verification. Unverified hypotheses belong in task notes and must not be described here as resolved incidents.

## 2026-10-15 ? Slow Arrow Navigation

- **Symptom:** Moving through application menus with the arrow keys had a noticeable delay, especially in the command inventory.
- **Evidence-Based Root Cause:** The non-ANSI console path wrote menu fragments directly through `Write-Host` and reset the cursor at the start of each frame, causing a full repaint on every keypress. Large menus also rebuilt and rendered every command on each frame. Icon tier detection could repeat settings and console checks for each item.
- **Solution:** Buffered the non-ANSI frame and rendered only changed rows while preserving console colors; limited rendering to a terminal-sized menu viewport centered on the current selection; cached automatic icon-tier detection.
- **Relevant Files:** `src/TUI/Renderer.psm1`, `src/TUI/Menu.psm1`, `src/TUI/Theme.psm1`.
- **Verification:** Added viewport boundary tests. The full application suite passed on PowerShell 7.6.5 and Windows PowerShell 5.1.26100.9444 (118 passed, 0 failed, 0 unverified on each). Interactive timing was not benchmarked in this verification.
- **Version:** `0.1.1`.

## 2026-10-15 ? Icons Were Generic And Monochrome

- **Symptom:** The interface icons did not match the modern colorful, function-specific style requested by the user, as seen in FFmpeg User Manager and File Control Manager.
- **Evidence-Based Root Cause:** The icon table only had a small set of generic names, and menu entries rendered the icon using the same style as the selected text rather than a semantic color for each icon.
- **Solution:** Added semantic icon names for Git operations and interface actions, assigned role colors per icon, and rendered icons separately from labels. Kept Emoji, Symbol, and ASCII variants for terminal compatibility.
- **Relevant Files:** `src/TUI/Theme.psm1`, `src/TUI/Menu.psm1`, `src/Core/App.psm1`.
- **Verification:** Added assertions for semantic colors and preserved tier fallback checks. The full application suite passed on PowerShell 7.6.5 and Windows PowerShell 5.1.26100.9444 (118 passed, 0 failed, 0 unverified on each). Terminal-specific color emoji appearance depends on the terminal and font.
- **Version:** `0.1.1`.

## 2026-10-15 ? Renamed Paths Were Counted More Than Once

- **Symptom:** A staged Git rename appeared as two staged paths and also created a phantom unstaged path.
- **Evidence-Based Root Cause:** Git's NUL-delimited porcelain status output represents a rename with a status record followed by a second NUL-delimited source-path record. The parser treated that companion source record as an independent path.
- **Solution:** Updated the workspace status parser to consume the companion source path for rename/copy records and added regression coverage.
- **Relevant Files:** `src/Core/Workspace.psm1`, `tests/Unit/Git.Tests.ps1`.
- **Verification:** The regression initially reproduced staged=2 and unstaged=1; after the parser fix, the staged rename was counted once and no phantom unstaged path appeared. The full application suite passed on PowerShell 7.6.5 and Windows PowerShell 5.1.26100.9444 (118 passed, 0 failed, 0 unverified on each).
- **Version:** `0.1.1`.

## Recording Future Incidents

After each new fix has been accepted and verified, add a dated entry with the symptom, evidence-based cause, solution, affected files, verification result and release version. Keep unresolved or unverified findings out of the resolved-issues sections.
## 2026-10-15 ? Blank New Project Folder Input

- **Symptom:** Pressing Enter without a destination path in New Project Setup raised a parameter-binding error instead of showing a validation message and allowing the user to retry.
- **Evidence-Based Root Cause:** The shared validator required a non-empty string at PowerShell parameter binding time. The UI's validation callback therefore could not receive an empty input and return its normal validation result.
- **Solution:** Allowed the empty string through the boundary of Test-NewProjectDirectoryPath so the validator can reject it deliberately with the existing user-facing message.
- **Relevant Files:** src/Core/ProjectManagement.psm1, tests/Unit/ProjectManagement.Tests.ps1, tests/Unit/Tui.Tests.ps1.
- **Verification:** Added direct validator and end-to-end scripted UI retry regressions. Full suite passed on PowerShell 7.6.5 and Windows PowerShell 5.1.26100.9444 with 166 passed, 0 failed, and 0 unverified on each.
- **Version:** 0.2.0.
