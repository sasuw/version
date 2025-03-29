# version.sh

A robust command-line tool to determine version information of executable programs on Linux systems.

## Features

- Multiple version detection methods:
  - Common version flags (--version, -v, etc.)
  - Help output analysis
  - Package management (dpkg) query
  - Binary string analysis
- Safe execution:
  - Uses dedicated unprivileged user
  - Prevents GUI program execution
  - Implements command timeout
  - Checks executable permissions
- Two output formats:
  - Detailed with version information source
  - Short format showing just program and version

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/version.sh.git
Make the script executable:
bash
Copy code
chmod +x version.sh
First run will automatically set up the required unprivileged user (requires sudo):
bash
Copy code
./version.sh --help
Optionally install the man page:
bash
Copy code
sudo mkdir -p /usr/local/share/man/man1
sudo cp version.1 /usr/local/share/man/man1/
sudo gzip /usr/local/share/man/man1/version.1
sudo mandb
Usage
Basic usage:

bash
Copy code
./version.sh program_name
Short output format:

bash
Copy code
./version.sh -s program_name
Examples
Detailed output:

bash
Copy code
$ ./version.sh python3
Version information (using --version):
Python 3.9.5
Short output:

bash
Copy code
$ ./version.sh -s git
git 2.34.1
Special cases (short format):

bash
Copy code
$ ./version.sh -s nonexistent
nonexistent not-found

$ ./version.sh -s firefox
firefox gui-program

$ ./version.sh -s restricted-program
restricted-program no-permission

$ ./version.sh -s unknown-version
unknown-version undetermined
How It Works
The script attempts to determine program versions using these methods, in order:

Tries common version flags
Analyzes --help output for version flags
Queries package management system (dpkg)
Analyzes binary strings
Attempts execution without arguments
All program executions are performed:

As unprivileged 'versionchecker' user
With display-related environment variables unset
With a timeout to prevent hanging
With proper permission checks
Security Features
Creates and uses dedicated unprivileged user 'versionchecker'
Unsets display-related environment variables to prevent GUI launching
Implements command timeout to prevent hanging
Checks executable permissions for both current user and versionchecker
Safely handles program output and error conditions
Requirements
Linux system
Bash shell
sudo access (for initial setup)
Common utilities: grep, timeout, sudo, dpkg (optional)
Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

License
[Your chosen license]

Author
[Your name]

Bugs
Report bugs at [your issue tracker URL]

diff
Copy code
