# File Change Map

| Path | Phase | Reason | Expected Change | Status | Permanent/Temporary |
|---|---|---|---|---|---|
| src/Core/App.psm1 | P02-P05 | Shared mode routing and user workflows | Integrated Project Management across all modes | Modified; verified | Permanent |
| src/Core/ProjectManagement.psm1 | P05 | Shared repository and GitHub domain functions | URL validation, project setup, remote/branch inventory, metadata arguments | New; verified | Permanent |
| src/Core/Workspace.psm1 | P02 | Porcelain v1 -z parsing | Correct rename source-path handling | Modified; regression verified | Permanent |
| src/Import-Modules.ps1 | P02 | Module order | Import one shared Project Management module | Modified; verified | Permanent |
| src/TUI/*.psm1 | P03-P05 | Flicker-free renderer, menu, input, theme | Shared UI styling, fast redraw, project icons | Modified; tests pass | Permanent |
| data/commands.json | P02 | Installed Git command catalog | Existing checked-in catalog retained; tests must not overwrite it | Restored after test pollution was fixed | Permanent |
| tests/Unit/*.Tests.ps1 | P02-P05 | Regression and integration coverage | Full modes, project setup, safety, version/docs consistency | Modified; 166/0 on both editions | Permanent |
| README.md | P04-P05 | Project landing page | Official image, polished English overview, synchronized version | Modified; verified | Permanent |
| AGENT.md, VERSION, CHANGELOG.md | P04-P05 | Repository engineering and SemVer rules | SemVer 0.2.0; README/changelog sync gate | New/modified; verified | Permanent |
| docs/*.md | P04-P05 | User, architecture, security, verification, incident records | Complete Project Management guide and 0.2.0 evidence | New/modified; verified | Permanent |
| assets/Git-Command-Manager-Header.png | P05 | Official project banner | Exact user-provided PNG bytes | New; SHA-256 matched | Permanent |
| Shared-Project-State/** | P01-P05 | Resumable implementation/evidence state | Record decisions, tests, blockers, and final publish handoff | Modified/new | Operational state |
| .gitignore | P01-P05 | Repository hygiene | Exclude local-only state and generated artifacts | Modified; review before commit | Permanent |
