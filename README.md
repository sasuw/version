# version

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

The provided install script
- creates the user `versionchecker` which is used to launch the program to check
- copies the version.sh script to `/usr/bin`
- creates an alias `vv` for the 
- copies the man page file to `/usr/local/share/man/man1`

### Preparation

#### All platforms

`git clone` this project with
```bash
git clone https://github.com/sasuw/version
```
`cd` yourselfo to the scripts directory in the project
```bash
cd version/scripts
```

### Install using the provided install script

#### MacOS

##### Install pre-requisites

*Either* install `timeout` from GNU Coreutils manually in your chosen way *or* install [Homebrew](https://brew.sh/) if not already installed (so that the install script can install the missing dependency if necessary)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
#### All platforms

#### Run the installer
```bash
sudo ./install.sh
```

### Uninstalling

#### All platforms

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
./version program_name
```
Short output format:
```bash
./version -s program_name
```

## Examples
Detailed output:

```bash
$ ./version python3
Version information (using --version):
Python 3.9.5
```
Short output:
```bash
$ ./version -s git
git 2.34.1
```
Special cases (short format):

```bash
$ ./version -s nonexistent
nonexistent not-found

$ ./version -s firefox
firefox gui-program

$ ./version -s restricted-program
restricted-program no-permission

$ ./version -s unknown-version
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
  - Installed via `brew` (Homebrew) on MacOS
  - Installed via `pkg` on FreeBSD

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

If you have an issue with `version` not working for a specific program, please specify the OS, the program version and how to install it or find it if it is not a part of the OS default programs. Also provide the manual steps for finding the program version. There are many programs out there, for which it is not possible to find a version, as they are not versioned.

## License
MIT License

## Author
Sasu Welling

## Bugs
Report bugs by adding a new issue.