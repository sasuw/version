#!/bin/bash

# install.sh - Installer for the 'version' utility

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# set -u # Disable for now, SUDO_USER might be unset
# Pipelines return status of the last command to exit with non-zero status,
# or zero if all commands exit successfully.
set -o pipefail

# --- Configuration ---
# Assuming version.sh is in ../bin relative to install.sh
SCRIPT_DIR=$(dirname "$(realpath "$0")")
SOURCE_PROGRAM_PATH="${SCRIPT_DIR}/../bin/version.sh"
SOURCE_MAN_PATH="${SCRIPT_DIR}/../doc/man/version.1"

INSTALL_DIR="/usr/local/bin"
MAN_DIR="/usr/local/share/man/man1"
PROGRAM_NAME="version"
MAN_PAGE_NAME="${PROGRAM_NAME}.1"
VERSIONCHECKER_USER="versionchecker"

# --- Helper Functions ---

# Function to determine OS type
get_os_type() {
    # Use uname -s for consistency
    case "$(uname -s)" in
        Linux)   echo "linux" ;;
        Darwin)  echo "macos" ;;
        FreeBSD) echo "freebsd" ;;
        *)       echo "unknown" ;;
    esac
}

# Function to get the real user even when running with sudo
get_real_user() {
    # $USER is the current user, $SUDO_USER is the user who invoked sudo
    if [[ -n "${SUDO_USER}" ]]; then
        echo "${SUDO_USER}"
    else
        # Fallback if not running via sudo (though check_root should prevent this)
        id -un
    fi
}

# Check if running as root/sudo
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "Error: This script must be run with sudo or as root." >&2
        exit 1
    fi
     # On macOS, Homebrew operations should be done by the real user.
     # The script will now just instruct the user, so this check is informative.
     if [[ "$(get_os_type)" == "macos" ]] && [[ -z "${SUDO_USER}" ]] && [[ "$(id -u)" -eq 0 ]]; then
         echo "Warning: Running directly as root on macOS is discouraged." >&2
         echo "         It's recommended to run using 'sudo ./install.sh'" >&2
         # Allow to continue, but installation might behave unexpectedly if brew is needed.
     fi
}

# Check for required commands (like package managers)
check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: Required command '$1' not found." >&2
        return 1
    fi
    return 0
}

# --- Installation Steps ---

install_dependencies() {
    local os_type
    os_type=$(get_os_type)
    echo "INFO: Checking dependencies..."

    case "$os_type" in
        linux)
            if ! command -v timeout &>/dev/null; then
                 echo "INFO: 'timeout' command not found (needed by version script)."
                 if check_command apt-get; then
                    echo "INFO: Attempting to install 'coreutils' using apt-get..."
                    apt-get update >/dev/null
                    apt-get install -y coreutils
                 elif check_command yum; then
                     echo "INFO: Attempting to install 'coreutils' using yum..."
                     yum install -y coreutils
                 elif check_command dnf; then
                     echo "INFO: Attempting to install 'coreutils' using dnf..."
                     dnf install -y coreutils
                 else
                     echo "Error: Cannot find 'timeout' and no supported package manager (apt/yum/dnf) found." >&2
                     echo "       Please install 'coreutils' manually." >&2
                     exit 1
                 fi
            else
                 echo "INFO: 'timeout' command found."
            fi
            ;;
        macos)
            if ! command -v gtimeout &>/dev/null; then
                echo "Error: Dependency missing: GNU timeout ('gtimeout') not found." >&2
                echo "       The 'version' script requires 'gtimeout' from the 'coreutils' package." >&2
                if check_command brew; then
                    local real_user
                    real_user=$(get_real_user)
                    echo "       Please install it using Homebrew by running this command as user '$real_user':" >&2
                    echo >&2 # Empty line for spacing
                    echo "         brew install coreutils" >&2
                    echo >&2 # Empty line for spacing
                else
                     echo "       Homebrew ('brew') command not found. Please install Homebrew first," >&2
                     echo "       then install coreutils: brew install coreutils" >&2
                fi
                exit 1
            else
                 echo "INFO: 'gtimeout' command found."
            fi
            ;;
        freebsd)
            if ! command -v gtimeout &>/dev/null; then
                echo "INFO: 'gtimeout' command not found (needed by version script)."
                 if check_command pkg; then
                     echo "INFO: Attempting to install 'coreutils' using pkg..."
                     pkg install -y coreutils
                 else
                     echo "Error: Cannot find 'gtimeout' and 'pkg' command not found." >&2
                     echo "       Please install 'coreutils' manually." >&2
                     exit 1
                 fi
            else
                echo "INFO: 'gtimeout' command found."
            fi
            ;;
        *)
            echo "Warning: Skipping dependency check for unknown OS type." >&2
            ;;
    esac
     echo "INFO: Dependency check complete."
}

# Create the non-privileged user for running checks
setup_versionchecker_user() {
    local os_type
    os_type=$(get_os_type)
    echo "INFO: Setting up '${VERSIONCHECKER_USER}' user..."

    if id -u "${VERSIONCHECKER_USER}" &>/dev/null; then
        echo "INFO: User '${VERSIONCHECKER_USER}' already exists. Skipping creation."
        return 0
    fi

    case "$os_type" in
        linux)
            echo "INFO: Creating system user '${VERSIONCHECKER_USER}' with nologin shell (useradd)..."
            # -r creates a system user, typically with no home dir and UID < 1000
            # -s specifies nologin shell
            useradd -r -s /sbin/nologin "${VERSIONCHECKER_USER}" || \
            useradd -r -s /usr/sbin/nologin "${VERSIONCHECKER_USER}" || \
            useradd -r -s /bin/false "${VERSIONCHECKER_USER}" || \
            { echo "Error: Failed to create user '${VERSIONCHECKER_USER}' using useradd." >&2; exit 1; }
            ;;
        macos)
            echo "INFO: Creating user '${VERSIONCHECKER_USER}' with nologin shell (dscl)..."
            local next_uid
            # Find the next available UID above 500
            next_uid=$(dscl . -list /Users UniqueID | awk '$2 > 500 {uid[$2]=1} END { for (i=501; ; i++) if (!uid[i]) { print i; exit } }')
            echo "INFO: Assigning UID ${next_uid}..."

            dscl . -create "/Users/${VERSIONCHECKER_USER}" || { echo "Error: dscl failed to create user node." >&2; exit 1; }
            dscl . -create "/Users/${VERSIONCHECKER_USER}" UserShell /usr/bin/false
            dscl . -create "/Users/${VERSIONCHECKER_USER}" RealName "Version Checker Service User"
            dscl . -create "/Users/${VERSIONCHECKER_USER}" UniqueID "${next_uid}"
            dscl . -create "/Users/${VERSIONCHECKER_USER}" PrimaryGroupID 20 # 'staff' group GID
            dscl . -create "/Users/${VERSIONCHECKER_USER}" NFSHomeDirectory /var/empty
            dscl . -create "/Users/${VERSIONCHECKER_USER}" IsHidden 1 # Hide from login screen
            echo "INFO: User '${VERSIONCHECKER_USER}' created successfully."
            ;;
        freebsd)
            echo "INFO: Creating user '${VERSIONCHECKER_USER}' with nologin shell (pw)..."
            # -d /nonexistent prevents home dir creation
            # -s specifies nologin shell
            pw useradd "${VERSIONCHECKER_USER}" -d /nonexistent -s /usr/sbin/nologin -G nogroup || \
            { echo "Error: Failed to create user '${VERSIONCHECKER_USER}' using pw." >&2; exit 1; }
            ;;
        *)
            echo "Error: Cannot create user on unknown OS type." >&2
            exit 1
            ;;
    esac
     echo "INFO: User '${VERSIONCHECKER_USER}' setup complete."
}

install_program_and_manpage() {
    echo "INFO: Installing program and man page..."

    # Check if source files exist
    if [[ ! -f "${SOURCE_PROGRAM_PATH}" ]]; then
        echo "Error: Source file not found: ${SOURCE_PROGRAM_PATH}" >&2
        exit 1
    fi
     if [[ ! -f "${SOURCE_MAN_PATH}" ]]; then
        echo "Error: Source man page not found: ${SOURCE_MAN_PATH}" >&2
        # Allow installation without man page? For now, exit.
        exit 1
    fi

    # Create directories if they don't exist
    echo "INFO: Ensuring install directories exist..."
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${MAN_DIR}"

    # Install program
    local install_path="${INSTALL_DIR}/${PROGRAM_NAME}"
    echo "INFO: Copying ${SOURCE_PROGRAM_PATH} to ${install_path}"
    cp "${SOURCE_PROGRAM_PATH}" "${install_path}"
    chmod 755 "${install_path}"
    echo "INFO: Program installed."

    # Install and compress man page
    local man_install_path="${MAN_DIR}/${MAN_PAGE_NAME}"
    echo "INFO: Copying ${SOURCE_MAN_PATH} to ${man_install_path}"
    cp "${SOURCE_MAN_PATH}" "${man_install_path}"
    echo "INFO: Compressing man page ${man_install_path}"
    gzip -f "${man_install_path}"
    echo "INFO: Man page installed."

    # Update man database (optional, runs if mandb exists)
    if command -v mandb &>/dev/null; then
        echo "INFO: Updating man database (mandb)..."
        mandb &>/dev/null || echo "Warning: mandb command failed, but proceeding." >&2
    fi
     echo "INFO: Program and man page installation complete."
}

verify_installation() {
    local os_type="$1" # Pass OS type to avoid recalculating
    local errors=0
    echo "INFO: Verifying installation..."

    # Check program exists and is executable
    if [[ ! -x "${INSTALL_DIR}/${PROGRAM_NAME}" ]]; then
        echo "Error: Verification failed: Program '${INSTALL_DIR}/${PROGRAM_NAME}' not found or not executable." >&2
        errors=$((errors + 1))
    else
        echo "INFO: [OK] Program file found and executable."
    fi

    # Check man page exists
    if [[ ! -f "${MAN_DIR}/${MAN_PAGE_NAME}.gz" ]]; then
        echo "Error: Verification failed: Man page '${MAN_DIR}/${MAN_PAGE_NAME}.gz' not found." >&2
        errors=$((errors + 1))
    else
        echo "INFO: [OK] Man page file found."
    fi

    # Check versionchecker user exists
    if ! id -u "${VERSIONCHECKER_USER}" &>/dev/null; then
        echo "Error: Verification failed: User '${VERSIONCHECKER_USER}' does not exist." >&2
        errors=$((errors + 1))
    else
         echo "INFO: [OK] User '${VERSIONCHECKER_USER}' exists."
    fi

    # Check for gtimeout where needed
    case "$os_type" in
        macos|freebsd)
            if ! command -v gtimeout &>/dev/null; then
                 echo "Error: Verification failed: Required command 'gtimeout' not found." >&2
                 errors=$((errors + 1))
            else
                echo "INFO: [OK] Required command 'gtimeout' found."
            fi
            ;;
        linux)
             if ! command -v timeout &>/dev/null; then
                 echo "Error: Verification failed: Required command 'timeout' not found." >&2
                 errors=$((errors + 1))
             else
                echo "INFO: [OK] Required command 'timeout' found."
             fi
            ;;
    esac

    if [[ "$errors" -gt 0 ]]; then
        echo "Error: Verification finished with $errors error(s)." >&2
        return 1
    else
         echo "INFO: Verification successful."
         return 0
    fi
}

# --- Main Install Logic ---
run_install() {
    local os
    os=$(get_os_type)
    echo "Starting installation of '${PROGRAM_NAME}' utility for OS: ${os}"
    echo "--------------------------------------------------"

    check_root
    install_dependencies # Exits on macOS if brew install needed
    setup_versionchecker_user
    install_program_and_manpage

    echo "--------------------------------------------------"
    if verify_installation "$os"; then
        echo
        echo "Installation successful!"
        echo
        echo "You can now use the command: ${PROGRAM_NAME}"
        echo "Access the manual page with: man ${PROGRAM_NAME}"
        echo
        echo "---------------------- IMPORTANT ----------------------"
        echo "Manual steps required:"
        echo
        echo "1. Configure Sudo:"
        echo "   The '${PROGRAM_NAME}' script needs to run commands as the '${VERSIONCHECKER_USER}' user."
        echo "   You MUST grant passwordless sudo permission to the user(s) who will run '${PROGRAM_NAME}'."
        echo "   Add a rule like this to '/etc/sudoers' or a file in '/etc/sudoers.d/'"
        echo "   (use 'visudo' to edit):"
        echo
        echo "   <your_username> ALL=(${VERSIONCHECKER_USER}) NOPASSWD: ALL"
        echo
        echo "   Replace <your_username> with the actual login name of the user."
        echo "   Example for user 'admin': admin ALL=(${VERSIONCHECKER_USER}) NOPASSWD: ALL"
        echo "   (On FreeBSD, the sudoers path might be /usr/local/etc/sudoers.d/)"
        echo
        echo "2. Optional Alias:"
        echo "   For convenience, you can add an alias for the short output format."
        echo "   Add this line to your shell configuration file (~/.bashrc, ~/.zshrc, ~/.config/fish/config.fish):"
        echo
        echo "   # For bash/zsh:"
        echo "   alias vv='${PROGRAM_NAME} -s'"
        echo "   # For fish:"
        echo "   alias vv '${PROGRAM_NAME} -s'"
        echo
        echo "   Remember to restart your shell or source the config file after adding the alias."
        echo "--------------------------------------------------"
    else
        echo
        echo "Installation failed. Please review the error messages above." >&2
        exit 1
    fi
}

# --- Uninstall Logic ---
run_uninstall() {
    local os
    os=$(get_os_type)
    echo "Starting uninstallation of '${PROGRAM_NAME}' utility for OS: ${os}"
    echo "--------------------------------------------------"
    check_root

    # Remove program and man page
    echo "INFO: Removing program file: ${INSTALL_DIR}/${PROGRAM_NAME}"
    rm -f "${INSTALL_DIR}/${PROGRAM_NAME}"
    echo "INFO: Removing man page: ${MAN_DIR}/${MAN_PAGE_NAME}.gz"
    rm -f "${MAN_DIR}/${MAN_PAGE_NAME}.gz"

    # Remove versionchecker user
    if id -u "${VERSIONCHECKER_USER}" &>/dev/null; then
        echo "INFO: Removing user '${VERSIONCHECKER_USER}'..."
        case "$os" in
            linux)
                userdel "${VERSIONCHECKER_USER}" || echo "Warning: 'userdel ${VERSIONCHECKER_USER}' failed. Manual removal might be needed." >&2
                ;;
            macos)
                 # Ensure user has no running processes first (might require manual intervention)
                 if pgrep -u "${VERSIONCHECKER_USER}" >/dev/null; then
                     echo "Warning: Processes running as user '${VERSIONCHECKER_USER}' detected." >&2
                     echo "         Cannot delete user while processes are running. Please stop them manually." >&2
                 else
                     dscl . -delete "/Users/${VERSIONCHECKER_USER}" || echo "Warning: 'dscl . -delete /Users/${VERSIONCHECKER_USER}' failed. Manual removal might be needed." >&2
                 fi
                ;;
            freebsd)
                 pw userdel "${VERSIONCHECKER_USER}" || echo "Warning: 'pw userdel ${VERSIONCHECKER_USER}' failed. Manual removal might be needed." >&2
                ;;
            *)
                echo "Warning: Cannot automatically remove user on unknown OS type." >&2
                ;;
        esac
    else
        echo "INFO: User '${VERSIONCHECKER_USER}' not found. Skipping removal."
    fi

    # NOTE: We do NOT remove the sudoers configuration file automatically,
    # as it was created manually by the administrator.
    echo
    echo "---------------------- REMINDER ----------------------"
    echo "Manual steps required:"
    echo
    echo "1. Remove Sudo Rule:"
    echo "   If you added a sudo rule for '${PROGRAM_NAME}', remember to remove it manually"
    echo "   from '/etc/sudoers' or '/etc/sudoers.d/' using 'visudo'."
    echo "   The rule looked like: <your_username> ALL=(${VERSIONCHECKER_USER}) NOPASSWD: ALL"
    echo
    echo "2. Remove Alias:"
    echo "   If you added the 'vv' alias to your shell configuration file, remove it manually."
    echo
    echo "3. Dependencies:"
    echo "   This script did not remove dependencies like 'coreutils' ('timeout'/'gtimeout')."
    echo "   You may remove them using your system's package manager if no other"
    echo "   programs require them (e.g., 'apt-get remove coreutils',"
    echo "   'brew uninstall coreutils', 'pkg remove coreutils')."
    echo "--------------------------------------------------"
    echo "Uninstallation complete."
}

# --- Script Entry Point ---

if [[ "$1" == "--uninstall" ]]; then
    run_uninstall
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
     echo "Usage: sudo $0 [--uninstall]"
     echo "  (no arguments)  Installs the '${PROGRAM_NAME}' utility and prerequisites."
     echo "  --uninstall     Removes the '${PROGRAM_NAME}' utility and the '${VERSIONCHECKER_USER}' user."
     exit 0
else
    run_install
fi

exit 0