# version.sh

A command-line tool to determine version information of command line executable programs on Linux, *BSD and MacOS. No more guessing, is it `-version`, `--version`, `-V` or even just `version`!

## Features

### Multiple version detection methods
  - Common version flags (`--version`, `-v`, etc.)
  - Help output analysis
  - Package management query
  - Binary string analysis
### Safe execution
  - Uses dedicated unprivileged user
  - Prevents GUI program execution
  - Implements command timeout
  - Checks executable permissions
### Two output formats
  - Detailed with version information source
  - Short format showing just program and version

## Installation

### All platforms

#### Install pre-requisites

`git clone` this project with
```bash
git clone https://github.com/sasuw/version
```
`cd` yourselfo to the scripts directory
```bash
cd version/scripts
```

### MacOS

#### Install pre-requisites

*Either* install `timeout` from GNU Coreutils manually in your chosen way *or* install Homebrew if not already installed (so that install script installs the missing dependency if necessary)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Then run the installer with sudo
```bash
sudo ./install.sh
```

### Linux/FreeBSD

```bash
sudo ./install.sh
```

### All platforms
To uninstall:

```bash
sudo ./install.sh --uninstall
```

## Usage

The script can be used in two ways:

1. Full command:
```bash
version python3
version --short python3
```
2. Quick alias:
```bash
vv python3  # equivalent to 'version --short python3'
```

Basic usage:

```bash
./version.sh program_name
```
Short output format:
```bash
./version.sh -s program_name
```

## Examples
Detailed output:

```bash
$ ./version.sh python3
Version information (using --version):
Python 3.9.5
```
Short output:
```bash
$ ./version.sh -s git
git 2.34.1
```
Special cases (short format):

```bash
$ ./version.sh -s nonexistent
nonexistent not-found

$ ./version.sh -s firefox
firefox gui-program

$ ./version.sh -s restricted-program
restricted-program no-permission

$ ./version.sh -s unknown-version
unknown-version undetermined
```

## How It Works
The script attempts to determine program versions using these methods, in order:
- Tries common version flags
- Analyzes `--help` output for version flags
- Queries package management system (currently only `dpkg` on Linux)
- Analyzes binary strings
- Attempts execution without arguments

All program executions are performed as unprivileged 'versionchecker' user
- With display-related environment variables unset
- With a timeout to prevent hanging
- With proper permission checks

## Security Features
- Creates and uses dedicated unprivileged user 'versionchecker'
- Unsets display-related environment variables to prevent GUI launching
- Implements command timeout to prevent hanging
- Checks executable permissions for both current user and versionchecker
- Safely handles program output and error conditions

## System Requirements

- Linux (Debian/RedHat based), MacOS, or FreeBSD
- Root/sudo access for installation (to add dedicated `versionchecker` user for more security)
- GNU coreutils (for timeout command)
  - Installed by default on Linux
  - Installed via `Homebrew` on MacOS
  - Installed via `pkg` on FreeBSD

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

 If you have an issue with `version` not working for a specific program, please specify the OS, the program version and how to install it or find it if it is not a part of the OS default programs.

## License
MIT License

## Author
Sasu Welling

## Bugs
Report bugs by adding a new issue.