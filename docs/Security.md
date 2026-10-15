# Security Model

- Git And GitHub CLI Use The Shared Process Boundary, Argument Arrays, An Explicit Working Directory, And Operation Timeouts.
- The App Never Uses Invoke-Expression Or Sends User Text To A Shell.
- Unknown Commands Require Review. State-Changing Operations Require Confirmation; Destructive Flags Are Classified Centrally.
- Creating A Repository, Staging, Committing, Changing Remotes, Branch Changes, Pulling, And Pushing Are Separate, Visible Actions.
- Pull Is Fast-Forward-Only. Project Management Does Not Offer Force Push Or Hard Reset. Branch Deletion Is Limited To Merged Local Branches.
- Public Repository Visibility Changes Require An Explicit Typed Confirmation.
- GitHub Repository URLs Are Restricted To GitHub HTTPS/SSH Forms And Checked Before Connection. Embedded Credentials Are Rejected.
- Remote URLs And Query Parameters Are Redacted In User-Facing Inventory And Confirmation Messages.
- GitHub Page Management Uses The User's Existing GitHub CLI Authentication. The App Does Not Read, Display, Or Persist The Credential.
- GitHub Repository Creation Defaults To Private And Does Not Push Automatically.
- Logs Record Failure Summaries Without Capturing Raw Process Output Or Credentials.
- The App Does Not Install Software, Elevate Privileges, Or Collect Telemetry.

Generic Command Arguments Are Whitespace-Delimited. Use Guided Workflows For Paths Containing Spaces Or Complex Argument Quoting.
