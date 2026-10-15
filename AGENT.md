# Agent Instructions

## Problem Analysis And Fix Quality

- Reproduce the reported problem before changing code whenever practical. Capture the exact input, visible behavior, error output, environment, and relevant application state.
- Separate observed facts from hypotheses. Trace the behavior through the responsible modules and identify the root cause with evidence before choosing a fix.
- Define the expected behavior and acceptance criteria before implementation. Prefer the smallest complete change at the layer responsible for the defect.
- Preserve unrelated working-tree changes. Inspect `git status` and the relevant diff before editing; do not discard or overwrite work that is not part of the task.
- For defects, add or update a focused regression test that fails for the reproduced behavior and passes after the fix. Run the narrowest relevant checks first, then the appropriate broader suite.
- Check compatibility with Windows PowerShell 5.1 and PowerShell 7 for PowerShell source changes. Record checks that could not be performed; never imply they passed.
- Review the final diff for correctness, security, encoding, naming, and unintended changes. Do not claim a problem is solved until fresh verification supports the claim.

## Semantic Versioning

- Every code change that modifies application behavior, including a feature, update, or bug fix, must update the root `VERSION` file before the change is considered complete.
- Follow Semantic Versioning `MAJOR.MINOR.PATCH`: increment PATCH for backward-compatible fixes, MINOR for backward-compatible functionality, and MAJOR for incompatible public behavior or interfaces. For a `0.y.z` version, treat changes as pre-release development and still choose the increment matching the change's compatibility and scope.
- Keep release notes and any other version references synchronized with `VERSION`. The runtime application version must continue to be read from this file rather than maintained as a duplicate constant.
- In the same version change, update README.md so its main heading is exactly # Git Command Manager and its version line is exactly Git Command Manager - vMAJOR.MINOR.PATCH for the value in VERSION; update the matching top release entry in CHANGELOG.md too.
- Add a static regression assertion that the README project/version lines and the top changelog version match VERSION; run that assertion before considering a version update complete.
- Verify that `VERSION` contains exactly three non-negative numeric components (`MAJOR.MINOR.PATCH`) and that the application's version display reports the same value. Use a SemVer validation check before reporting the version update complete.

## Problem And Solution Records

- After a problem's fix has been accepted and verified, record it in `docs/PROBLEMS_AND_SOLUTIONS.md`.
- Each record must describe the user-visible symptom, evidence-based root cause, implemented solution and relevant files, regression or verification performed with its result, and the version containing the fix.
- Keep hypotheses and unverified work clearly marked as unresolved; do not describe them as confirmed causes or completed fixes.