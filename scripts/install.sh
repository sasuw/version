#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Function to get the real user when running with sudo
get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        whoami
    fi
}

# Function to determine OS type
get_os_type() {
    case "$(uname)" in
        "Linux")   echo "linux" ;;
        "Darwin")  echo "macos" ;;
        "FreeBSD") echo "freebsd" ;;
        *)         echo "unknown" ;;
    esac
}

# Function to check if running as root/sudo
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root or with sudo"
        exit 1
    fi
}

# Function to check and install dependencies
install_dependencies() {
    echo "Checking and installing dependencies..."
    case "$(get_os_type)" in
        "linux")
            if command -v apt-get >/dev/null; then
                apt-get update
                apt-get install -y sudo coreutils
            elif command -v yum >/dev/null; then
                yum install -y sudo coreutils
            fi
            ;;
            
        "macos")
            REAL_USER=$(get_real_user)
            if ! command -v gtimeout >/dev/null; then
                if ! command -v brew >/dev/null; then
                    echo "Homebrew not found. Please install Homebrew first as non-root user:"
                    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
                    exit 1
                fi
                
                # Install only coreutils for gtimeout
                if [ "$REAL_USER" != "root" ]; then
                    echo "Installing coreutils for timeout command..."
                    su - "$REAL_USER" -c 'brew install coreutils'
                else
                    echo "Error: Cannot determine the real user for Homebrew installation"
                    exit 1
                fi
            fi
            ;;
            
        "freebsd")
            if ! command -v gtimeout >/dev/null; then
                echo "Installing coreutils for timeout command..."
                pkg install -y sudo coreutils
            fi
            ;;
    esac
}

# Function to create versionchecker user
setup_versionchecker() {
    echo "Setting up versionchecker user..."
    case "$(get_os_type)" in
        "linux")
            useradd -r -s /bin/false versionchecker
            echo "ALL ALL=(versionchecker) NOPASSWD: /bin/bash" > /etc/sudoers.d/versionchecker
            ;;
            
        "macos")
            dscl . -create /Users/versionchecker
            dscl . -create /Users/versionchecker UserShell /bin/false
            dscl . -create /Users/versionchecker RealName "Version Checker"
            dscl . -create /Users/versionchecker UniqueID 401
            dscl . -create /Users/versionchecker PrimaryGroupID 20
            echo "ALL ALL=(versionchecker) NOPASSWD: /bin/bash" > /etc/sudoers.d/versionchecker
            ;;
            
        "freebsd")
            pw useradd versionchecker -d /nonexistent -s /usr/sbin/nologin
            mkdir -p /usr/local/etc/sudoers.d
            echo "ALL ALL=(versionchecker) NOPASSWD: /bin/sh" > /usr/local/etc/sudoers.d/versionchecker
            ;;
    esac
}

# Function to install program
install_program() {
    echo "Installing version.sh..."
    local install_dir="/usr/local/bin"
    local man_dir="/usr/local/share/man/man1"
    
    # Create directories if they don't exist
    mkdir -p "$install_dir"
    mkdir -p "$man_dir"
    
    # Install program
    cp "$SCRIPT_DIR/../bin/version.sh" "$install_dir/version"
    chmod 755 "$install_dir/version"
    
    # Install and compress man page
    cp "$SCRIPT_DIR/../doc/man/version.1" "$man_dir/version.1"
    gzip -f "$man_dir/version.1"
    
    # Update man database if needed
    if command -v mandb >/dev/null; then
        mandb >/dev/null 2>&1
    fi
}

# Function to verify installation
verify_installation() {
    echo "Verifying installation..."
    local errors=0
    
    # Check program installation
    if ! [ -x "/usr/local/bin/version" ]; then
        echo "Error: Program installation failed"
        errors=$((errors + 1))
    fi
    
    # Check man page installation
    if ! [ -f "/usr/local/share/man/man1/version.1.gz" ]; then
        echo "Error: Man page installation failed"
        errors=$((errors + 1))
    fi
    
    # Check versionchecker user
    case "$(get_os_type)" in
        "linux"|"freebsd")
            if ! id versionchecker >/dev/null 2>&1; then
                echo "Error: versionchecker user creation failed"
                errors=$((errors + 1))
            fi
            ;;
        "macos")
            if ! dscl . -read /Users/versionchecker >/dev/null 2>&1; then
                echo "Error: versionchecker user creation failed"
                errors=$((errors + 1))
            fi
            ;;
    esac
    
    # Check sudo configuration
    if ! sudo -l -U versionchecker >/dev/null 2>&1; then
        echo "Error: versionchecker sudo configuration failed"
        errors=$((errors + 1))
    fi
    
    return $errors
}


# Main installation process
main() {
    echo "Starting installation of version utility..."
    
    # Check if running as root
    check_root
    
    # Store the real user for MacOS
    REAL_USER=$(get_real_user)
    if [ "$(get_os_type)" = "macos" ] && [ "$REAL_USER" = "root" ]; then
        echo "Error: Please run this script with sudo instead of as root"
        exit 1
    fi
    
    # Install dependencies
    install_dependencies
    
    # Setup versionchecker user
    setup_versionchecker
    
    # Install program and man page
    install_program
    
    # Verify installation
    if verify_installation; then
        echo "Installation completed successfully!"
        echo "You can now use 'version' command and access its man page with 'man version'"
    else
        echo "Installation completed with errors. Please check the messages above."
        exit 1
    fi
}

# Check for uninstall flag
if [ "$1" = "--uninstall" ]; then
    echo "Uninstalling version utility..."
    check_root
    
    # For MacOS, remove Homebrew packages as real user
    if [ "$(get_os_type)" = "macos" ]; then
        REAL_USER=$(get_real_user)
        if [ "$REAL_USER" != "root" ]; then
            echo "Removing Homebrew packages..."
            # Only remove coreutils if no other programs need it
            # su - "$REAL_USER" -c 'brew remove coreutils'
        fi
    fi
    
    # Remove program and man page
    rm -f /usr/local/bin/version
    rm -f /usr/local/share/man/man1/version.1.gz
    
    # Remove versionchecker user and sudo configuration
    case "$(get_os_type)" in
        "linux")
            userdel versionchecker
            rm -f /etc/sudoers.d/versionchecker
            ;;
        "macos")
            dscl . -delete /Users/versionchecker
            rm -f /etc/sudoers.d/versionchecker
            ;;
        "freebsd")
            pw userdel versionchecker
            rm -f /usr/local/etc/sudoers.d/versionchecker
            ;;
    esac
    
    echo "Uninstallation completed"
    exit 0
fi

# Run main installation
main