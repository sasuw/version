# version

A command-line tool to determine version information of command-line executable programs on Linux, macOS, and FreeBSD. No more guessing: is it `-version`, `--version`, `-v`, `-V`, or even just `version`?

This tool prioritizes safety by running target programs with minimal privileges and strict timeouts.

## Features

**Multiple version detection methods:**
  *   Common version flags (`--version`, `-v`, etc.)
  *   Analysis of help output (`--help`, `-h`)
  *   Query system package managers (dpkg, brew, pkg)
  *   Binary string analysis (`strings`)
  *   Execution without arguments (last resort)
    
**Safe execution:**
  *   Runs target programs as a dedicated unprivileged user (`versionchecker`) via `sudo`.
  *   Uses a minimal, sanitized environment (`env -i`).
  *   Implements short command timeouts to prevent hangs.
  *   Checks executable permissions before attempting runs.

**Flexible output:**
  *   Detailed output including the method used to find the version.
  *   Short format showing just program name and version (ideal for scripting).

## Prerequisites

Before installing and using `version`, ensure the following requirements are met:

1.  **Operating System:** Linux (Debian/Ubuntu, RHEL/Fedora derivatives), macOS, or FreeBSD.
2.  **Git:** Required to clone the repository.
3.  **sudo Access:** You need `sudo` privileges on your machine to run the installation script.
4.  **Coreutils (`timeout`/`gtimeout`):**
 	*   **Linux:** The `timeout` command (part of `coreutils`) is usually pre-installed. If not, install `coreutils` using your package manager (e.g., `sudo apt install coreutils`, `sudo yum install coreutils`).
  	*   **macOS/FreeBSD:** The `gtimeout` command (part of `coreutils`) is required. The installer will check for it. If missing on macOS, you'll be instructed to install it via Homebrew (`brew install coreutils`). On FreeBSD, the installer will attempt to install it via `pkg` if missing.
5.  **Manual Sudo Configuration (Post-Installation):** This is crucial for the script to function. After installation, the user(s) who will run the `version` command **must** be granted passwordless `sudo` permission to run commands *as* the `versionchecker` user. You will need to add a rule to `/etc/sudoers` (or a file in `/etc/sudoers.d/`) using `visudo`. The rule looks like this:
    ```
    # Allow <your_username> to run any command as versionchecker without a password
    <your_username> ALL=(versionchecker) NOPASSWD: ALL
    ```
    Replace `<your_username>` with the actual username. (The sudoers path might be `/usr/local/etc/sudoers` on FreeBSD).

## Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/sasuw/version.git
    cd version
    ```

2.  **Navigate to the scripts directory:**
    ```bash
    cd scripts
    ```

3.  **Run the installer with sudo:**
    ```bash
    sudo ./install.sh
    ```

**What the installer does:**

*   Checks for and attempts to install the `coreutils` dependency (`timeout`/`gtimeout`) if missing and possible (Linux/FreeBSD). On macOS, it checks and instructs you to install `coreutils` via Homebrew if needed, then exits.
*   Safely creates the dedicated, non-privileged user `versionchecker` with no login shell.
*   Copies the `version` script to `/usr/local/bin/version` and makes it executable.
*   Copies the man page to `/usr/local/share/man/man1/version.1` and compresses it.
*   Verifies the installation of files and user.

**Post-Installation Steps (Manual):**

1.  **(Required)** Configure the `sudoers` rule as described in the **Prerequisites** section to allow your user to run commands as `versionchecker`. The `version` command will **not work** without this step.
2.  **(Optional)** Add a convenient alias (like `vv` for `version -s`) to your shell's configuration file (`~/.bashrc`, `~/.zshrc`, `~/.config/fish/config.fish`, etc.):
    ```bash
    # For Bash/Zsh:
    alias vv='version -s'

    # For Fish:
    alias vv 'version -s'
    ```
    Remember to source your config file or restart your shell after adding the alias.

## Uninstallation

1.  Navigate to the `scripts` directory within the cloned repository.
2.  Run the uninstall command with sudo:
    ```bash
    sudo ./install.sh --uninstall
    ```

This will remove:
*   The `/usr/local/bin/version` script.
*   The `/usr/local/share/man/man1/version.1.gz` man page.
*   The `versionchecker` user.

**Manual Cleanup Required:**
*   Remove the `sudoers` rule you added manually.
*   Remove any aliases you added to your shell configuration.
*   Dependencies (like `coreutils`) are *not* removed automatically. You can remove them using your package manager if no longer needed.

## Usage

```bash
# General syntax
version [options] <program-name>

# Get detailed version info for python3
version python3

# Get short version info for git
version -s git
version --short git

# Use the optional alias (if configured)
vv curl

# Show help
version -h
version --help

# Show version script's own version
version -v
version --version

# Enable debug output
version -d <program-name>

# Get short version info for git
version -s git
version --short git

# Show version script's own version
version -v
version --version

## Show help
version -h
version --help

## Use the optional alias (if configured)
vv curl
```

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
If you have an issue with `version` not working for a specific program, please specify the OS, the program version and how to install it or find it if it is not a part of the OS default programs. Also provide the manual steps for finding the program version. There are many programs out there, for which it is not possible to find a version, as they are not versioned.

## License
MIT License

## Author
Sasu Welling

## Bugs
Report bugs by adding a new issue.