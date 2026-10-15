# Testing

## Full Application Suite

Latest Local Run On 2026-10-15:

- PowerShell 7.6.5: 166 PASS, 0 FAIL, 0 UNVERIFIED.
- Windows PowerShell 5.1.26100.9444: 166 PASS, 0 FAIL, 0 UNVERIFIED.

Command: pwsh -NoProfile -File tests/Run-Tests.ps1
Command: powershell.exe -NoProfile -File tests/Run-Tests.ps1

The suite includes static source and SemVer checks, three-interface scripted flows, README/image/changelog synchronization, project-folder validation and retry, shared GitHub URL and argument-safety checks, and disposable local repository/remote integration. Git tests use temporary repositories.

## Skill And Platform Validation

The official TUI project validator previously reported 22/22 rules. This full run revalidated application source parsing and the application test suite on both supported Windows PowerShell editions.

UNVERIFIED: Manual Windows Terminal flicker observation, Linux PowerShell 7, GitHub Actions, external GitHub CLI page-management operations, authenticated push/pull against GitHub, hook-failure UI, missing identity UI, and merge-conflict recovery. A local bare remote verified first push and upstream tracking; this does not replace live GitHub verification.

GitHub CLI (gh) is not installed in the current environment. Repository creation and metadata editing are implemented through its supported argument interface and covered by validation tests, but cannot be exercised against a live GitHub account here.
