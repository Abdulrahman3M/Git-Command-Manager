# Command Coverage

The command catalog is generated from the installed Git executable with `git help -a`. On this environment Git 2.55.0 reported 180 discoverable commands. `data/commands.json` is generated when the explorer opens; command names are not restricted to a fixed built-in list.

Recognized names map to shared categories. New or unrecognized names use **Other And Unclassified** and **RequiresReview**. This catalog includes built-in help output; external `git-foo` executables and contextual subcommands are not guaranteed to appear in `git help -a` and are not claimed as covered.

Support levels identify dedicated beginner flows as **Guided** and commands available through the generic preview/review surface as **Generic**. This is discovery coverage, not a claim that every command's arbitrary interactive mode is safely supported.
