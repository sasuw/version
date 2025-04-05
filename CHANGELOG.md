# Changelog

All notable changes to this project will be documented in this file.

## [1.1.1] - 2025-04-05

- now works also for `go`

## [1.1.0] - 2025-04-05

Updated man page, `version.sh` and `install.sh`

### version.sh

- Security Model: Removed automatic user/sudoers setup. Added explicit prerequisite checks for the versionchecker user and passwordless sudo access for the running user. Clear instructions are provided in --help.
- try_version_flag Reworked:
  - Uses sudo -n -u "${VERSIONCHECKER_USER}" ... correctly (-n prevents password prompts).
  - Uses env -i to run the command in a clean environment, explicitly passing essential variables like PATH, HOME, LC_ALL.
  - Wraps the sudo command with the run_with_timeout function.
  - Captures stdout and stderr of the target command to a temporary file.
  - Correctly checks the exit status of the timeout command (using $?).
  - Distinguishes between command success (0), timeout (124), sudo permission errors (by checking output when exit code is 1), and other command failures.
  - Uses mktemp safely and robust trap for cleanup.
  - Returns specific codes (0=success, 1=fail/no version, 2=timeout, 3=sudo error).
- run_with_timeout Function: Properly wraps timeout or gtimeout and returns the correct exit code, including 124 on timeout. Handles missing gtimeout error.
- Package Manager Logic (get_package_version):
  - Uses more robust commands: `dpkg-query -S / -W`, `brew info --json=v1`, `pkg which / query`.
  - Tries to find the package owning the specific program path first, falling back to the base name.
  - Returns only the version string.
  - Handles dpkg epoch prefixes (2:).
- Prerequisite Checks: Added checks at the beginning for user existence, sudo capability, and gtimeout.
- Path Resolution: Handles paths vs bare commands correctly, includes the python/python3 logic safely.
- Permissions Checks: Checks permissions for both the current user and the versionchecker user more clearly.
- contains_version_info: Refined regex patterns to be slightly more specific and avoid common false positives. Added stripping of ANSI color codes.
- extract_version: Improved regex to capture versions like 1.2.3-beta or 2.5_p1. Added fallback for vX style.
- Main Logic Flow: Structured clearly, trying methods sequentially and breaking when a version is found. Handles output formatting (--short vs long) at the end based on the successful method.
- Error Handling & Debugging: More consistent error messages to stderr, better debug messages, uses set -x in debug mode.
- Help Text: Significantly expanded to explain the prerequisites and methods.

### install.sh

- Secure: No longer creates dangerous sudoers rules. Instructs the admin on the correct, manual sudo setup needed by version.sh.
- User Creation: Safely creates the versionchecker user without login privileges. Uses a more robust method for finding an unused UID on macOS.
- Dependency Handling: Installs coreutils only where needed and possible (Linux/FreeBSD). On macOS, it correctly identifies the need for coreutils and tells the user how to install it via Homebrew, then exits (as required by Homebrew's user-context execution model).
- No Dotfile Modification: Completely removes the problematic add_alias and remove_alias functions. Suggests the alias setup to the user.
- Clear Instructions: Provides detailed, actionable instructions for the required manual steps (sudoers config) and optional steps (alias) upon successful installation and uninstallation.
- Verification: Checks the actual results of the installation (program, man page, user, dependencies).
- Uninstall: Removes only the things the script installed (program, man page, user). Reminds the user about manual cleanup (sudoers, alias, dependencies).
- Robustness: Uses set -e and set -o pipefail. Includes checks for command existence and source file existence. Better error messages.
- Structure: Clear separation of functions for different tasks. Consistent variable naming.

## [1.0.0] - 2025-03-30

First published version.