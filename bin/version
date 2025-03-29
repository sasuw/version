#!/bin/bash

# version.sh - Find version information for CLI programs

#!/bin/bash

# Function to determine OS type
get_os_type() {
    case "$(uname)" in
        "Linux")   echo "linux" ;;
        "Darwin")  echo "macos" ;;
        "FreeBSD") echo "freebsd" ;;
        *)         echo "unknown" ;;
    esac
}

# Function to check package manager availability
have_pkg_manager() {
    case "$(get_os_type)" in
        "linux")   command -v dpkg &>/dev/null ;;
        "macos")   command -v brew &>/dev/null || command -v port &>/dev/null ;;
        "freebsd") command -v pkg &>/dev/null ;;
        *)         return 1 ;;
    esac
}

# Function to get package version (system specific)
get_package_version() {
    local program="$1"
    local version=""
    
    case "$(get_os_type)" in
        "linux")
            if command -v dpkg &>/dev/null; then
                version=$(dpkg -l "$program" 2>/dev/null | grep "^ii" | awk '{print $3}' | grep -oE "[0-9]+(\.[0-9]+)+")
            fi
            ;;
            
        "macos")
            if command -v brew &>/dev/null; then
                local formula=$(brew list | grep -E "^${program}(@[0-9.]+)?$" | head -n1)
                if [ -n "$formula" ]; then
                    version=$(brew info --json=v2 "$formula" | grep -o '"version": "[^"]*"' | cut -d'"' -f4)
                fi
            fi
            if [ -z "$version" ] && command -v port &>/dev/null; then
                version=$(port installed "$program" 2>/dev/null | grep -v "None of the specified ports" | grep active | awk '{print $2}')
            fi
            ;;
            
        "freebsd")
            if command -v pkg &>/dev/null; then
                version=$(pkg info "$program" 2>/dev/null | grep -E "^Version" | cut -d: -f2- | tr -d ' ')
            fi
            ;;
    esac
    
    echo "$version"
}

# Function to create versionchecker user (system specific)
setup_versionchecker() {
    if ! command -v sudo &>/dev/null; then
        echo "Error: sudo is not available"
        exit 1
    }

    case "$(get_os_type)" in
        "linux")
            if ! id versionchecker &>/dev/null; then
                echo "versionchecker user not found. Setting up..."
                sudo useradd -r -s /bin/false versionchecker
                echo "ALL ALL=(versionchecker) NOPASSWD: /bin/bash" | sudo tee /etc/sudoers.d/versionchecker >/dev/null
            fi
            ;;
            
        "macos")
            if ! dscl . -read /Users/versionchecker &>/dev/null; then
                echo "versionchecker user not found. Setting up..."
                sudo dscl . -create /Users/versionchecker
                sudo dscl . -create /Users/versionchecker UserShell /bin/false
                sudo dscl . -create /Users/versionchecker RealName "Version Checker"
                sudo dscl . -create /Users/versionchecker UniqueID 401
                sudo dscl . -create /Users/versionchecker PrimaryGroupID 20
                echo "ALL ALL=(versionchecker) NOPASSWD: /bin/bash" | sudo tee /etc/sudoers.d/versionchecker >/dev/null
            fi
            ;;
            
        "freebsd")
            if ! pw user show versionchecker >/dev/null 2>&1; then
                echo "versionchecker user not found. Setting up..."
                sudo pw useradd versionchecker -d /nonexistent -s /usr/sbin/nologin
                echo "ALL ALL=(versionchecker) NOPASSWD: /bin/sh" | sudo tee /usr/local/etc/sudoers.d/versionchecker >/dev/null
            fi
            ;;
    esac
}

# Function to get system-specific shell
get_system_shell() {
    case "$(get_os_type)" in
        "freebsd") echo "/bin/sh" ;;
        *)         echo "/bin/bash" ;;
    esac
}

# Timeout command wrapper for different systems
timeout_cmd() {
    case "$(get_os_type)" in
        "linux")
            timeout "$@"
            ;;
        "macos")
            if command -v gtimeout &>/dev/null; then
                gtimeout "$@"
            else
                echo "Please install GNU timeout: brew install coreutils" >&2
                exit 1
            fi
            ;;
        "freebsd")
            if command -v gtimeout &>/dev/null; then
                gtimeout "$@"
            else
                echo "Please install GNU timeout: pkg install coreutils" >&2
                exit 1
            fi
            ;;
    esac
}

# Modify the try_version_flag function to use the system-specific shell
try_version_flag() {
    local program="$1"
    local flag="$2"
    local program_base="$3"
    local system_shell=$(get_system_shell)
    
    # Create a temporary file for output
    local tmpfile=$(mktemp)
    
    # Run the command with timeout and as versionchecker user
    if timeout_cmd 1s sudo -u versionchecker "$system_shell" -c "
        unset DISPLAY
        unset WAYLAND_DISPLAY
        unset XAUTHORITY
        unset SESSION_MANAGER
        unset DBUS_SESSION_BUS_ADDRESS
        \"$program\" $flag" > "$tmpfile" 2>&1; then
        local output=$(cat "$tmpfile")
        rm "$tmpfile"
        
        if contains_version_info "$output" "$program_base"; then
            echo "$output"
            return 0
        fi
    else
        local exit_code=$?
        rm "$tmpfile"
        if [ $exit_code -eq 124 ]; then
            return 2
        fi
    fi
    return 1
}

# Main script logic
# Check requirements first
case "$(get_os_type)" in
    "macos"|"freebsd")
        if ! command -v gtimeout &>/dev/null; then
            echo "GNU timeout not found. Please install coreutils:"
            case "$(get_os_type)" in
                "macos")   echo "brew install coreutils" ;;
                "freebsd") echo "pkg install coreutils" ;;
            esac
            exit 1
        fi
        ;;
esac

# Setup versionchecker user if needed
setup_versionchecker

# Function to show usage
show_usage() {
    echo "Usage: $0 [-s|--short] <program-name>"
    echo "Options:"
    echo "  -s, --short    Output only program name and version number"
    exit 1
}

# Parse arguments
SHORT_OUTPUT=false
PROGRAM=""

while (( $# > 0 )); do
    case "$1" in
        -s|--short)
            SHORT_OUTPUT=true
            shift
            ;;
        *)
            PROGRAM="$1"
            PROGRAM_BASE=$(basename "$PROGRAM")
            shift
            ;;
    esac
done

# Check if a program name was provided
if [ -z "$PROGRAM" ]; then
    show_usage
fi

# Check and setup versionchecker user if needed
if ! id versionchecker &>/dev/null; then
    echo "versionchecker user not found. Setting up..."
    if ! command -v sudo &>/dev/null; then
        echo "Error: sudo is not available. Please run these commands as root:"
        echo "useradd -r -s /bin/false versionchecker"
        echo "echo 'ALL ALL=(versionchecker) NOPASSWD: /bin/bash' > /etc/sudoers.d/versionchecker"
        exit 1
    fi
    
    # Try to create user and sudoers entry
    if ! sudo useradd -r -s /bin/false versionchecker; then
        echo "Error: Failed to create versionchecker user"
        exit 1
    fi
    
    if ! echo "ALL ALL=(versionchecker) NOPASSWD: /bin/bash" | sudo tee /etc/sudoers.d/versionchecker >/dev/null; then
        echo "Error: Failed to create sudoers entry"
        # Clean up user if sudoers fails
        sudo userdel versionchecker
        exit 1
    fi
    
    echo "versionchecker user setup completed"
fi

# Resolve program path, handling python and similar cases
program_path=""
if command -v "$PROGRAM" &> /dev/null; then
    program_path=$(command -v "$PROGRAM")
elif command -v "${PROGRAM}3" &> /dev/null; then  # Try with '3' suffix for python, ruby etc.
    program_path=$(command -v "${PROGRAM}3")
else
    if $SHORT_OUTPUT; then
        echo "${PROGRAM_BASE} not-found"
    else
        echo "Error: Program '$PROGRAM' not found"
    fi
    exit 1
fi

# Check permissions for both current user and versionchecker
if ! ( [ -x "$program_path" ] && [ -r "$program_path" ] ) || \
   ! sudo -u versionchecker test -x "$program_path" || \
   ! sudo -u versionchecker test -r "$program_path"; then
    if $SHORT_OUTPUT; then
        echo "${PROGRAM_BASE} no-permission"
    else
        echo "Error: No permission to execute '$PROGRAM' (either as current user or versionchecker)"
    fi
    exit 1
fi

# Check if the program exists
if ! command -v "$PROGRAM" &> /dev/null; then
    echo "Error: Program '$PROGRAM' not found"
    exit 1
fi

# Prevent GUI and session interactions
unset DISPLAY
unset WAYLAND_DISPLAY
unset XAUTHORITY
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Array of common version flags
VERSION_FLAGS=(
    "--version"
    "-version"
    "-v"
    "-V"
    "--ver"
    "-ver"
    "version"
)

# Function to check if output contains version information
contains_version_info() {
    local output="$1"
    local program_base="$2"
    
    # Check for program name followed by version-like string
    if echo "$output" | grep -iE "^${program_base}[[:space:]]+(v[0-9]+|[0-9]+(\.[0-9]+)*)" > /dev/null; then
        return 0
    fi
    
    # Check for common version patterns
    if echo "$output" | grep -iE "version|v[0-9]" > /dev/null; then
        return 0
    fi

    # Check for "compiled with" or "linked with" followed by version
    if echo "$output" | grep -iE "(compiled|linked).+[0-9]+\.[0-9]+\.[0-9]+" > /dev/null; then
        return 0
    fi

    # Last resort: look for X.Y.Z pattern
    # Count how many unique version-like strings we find
    local version_count=$(echo "$output" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | sort -u | wc -l)
    if [ "$version_count" -eq 1 ]; then
        # If we found exactly one X.Y.Z pattern, consider it a version
        return 0
    fi
    
    return 1
}



# Function to extract version number from output
extract_version() {
    local output="$1"
    local version=""
    
    # Try X.Y.Z format first
    version=$(echo "$output" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
    
    # If not found, try X.Y format
    if [ -z "$version" ]; then
        version=$(echo "$output" | grep -oE "[0-9]+\.[0-9]+" | head -n1)
    fi
    
    echo "$version"
}

# Function to extract version flag from help output
extract_version_flag_from_help() {
    local help_output="$1"
    local version_flag
    
    # Look for common patterns in help output that indicate version flags
    version_flag=$(echo "$help_output" | grep -oE -- '-(-)?v(ersion)?|--version' | head -n1)
    
    if [ -n "$version_flag" ]; then
        echo "$version_flag"
        return 0
    fi
    return 1
}

# 1. First try common version flags
for flag in "${VERSION_FLAGS[@]}"; do
    if output=$(try_version_flag "$PROGRAM" "$flag" "$PROGRAM_BASE"); then
        if $SHORT_OUTPUT; then
            version=$(extract_version "$output")
            if [ -n "$version" ]; then
                echo "${PROGRAM_BASE} ${version}"
                exit 0
            fi
        else
            echo "Version information (using $flag):"
            echo "$output"
            exit 0
        fi
    elif [ $? -eq 2 ]; then
        $SHORT_OUTPUT || echo "Warning: Program '$PROGRAM' timed out with flag '$flag', trying next..."
    fi
done

# 2. Try to find version flag from help output
help_output=""
if help_output=$(timeout 1s sudo -u versionchecker bash -c "
    unset DISPLAY
    unset WAYLAND_DISPLAY
    unset XAUTHORITY
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    \"$PROGRAM\" --help" 2>&1) || \
   help_output=$(timeout 1s sudo -u versionchecker bash -c "
    unset DISPLAY
    unset WAYLAND_DISPLAY
    unset XAUTHORITY
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    \"$PROGRAM\" -h" 2>&1); then
    # Only process help output if it doesn't contain error messages
    if ! echo "$help_output" | grep -q "unrecognized option\|invalid option"; then
        if version_flag=$(extract_version_flag_from_help "$help_output"); then
            if output=$(try_version_flag "$PROGRAM" "$version_flag" "$PROGRAM_BASE"); then
                if $SHORT_OUTPUT; then
                    version=$(extract_version "$output")
                    if [ -n "$version" ]; then
                        echo "${PROGRAM_BASE} ${version}"
                        exit 0
                    fi
                else
                    echo "Version information (found flag '$version_flag' in help):"
                    echo "$output"
                    exit 0
                fi
            fi
        fi
    fi
fi

# 3. Try using dpkg -l if available
if command -v dpkg &> /dev/null; then
    if dpkg_output=$(dpkg -l | grep "$PROGRAM_BASE" | head -n1); then
        version=$(echo "$dpkg_output" | awk '{print $3}' | grep -oE "[0-9]+(\.[0-9]+)+")
        if [ -n "$version" ]; then
            if $SHORT_OUTPUT; then
                echo "${PROGRAM_BASE} ${version}"
                exit 0
            else
                echo "Version information (found in dpkg database):"
                echo "$dpkg_output"
                exit 0
            fi
        fi
    fi
fi


# 4. Try using strings command
if command -v strings &> /dev/null; then
    program_path=$(which "$PROGRAM")
    version_info=$(strings "$program_path" | grep -i "version" | grep -E "[0-9]+\.[0-9]+(\.[0-9]+)?" | head -n1)
    if [ -n "$version_info" ]; then
        if $SHORT_OUTPUT; then
            version=$(extract_version "$version_info")
            if [ -n "$version" ]; then
                echo "${PROGRAM_BASE} ${version}"
                exit 0
            fi
        else
            echo "Version information (found in binary strings):"
            echo "$version_info"
            exit 0
        fi
    fi
fi

# 4. Last resort: try running without arguments
if output=$(try_version_flag "$PROGRAM" "" "$PROGRAM_BASE"); then
    if $SHORT_OUTPUT; then
        version=$(extract_version "$output")
        if [ -n "$version" ]; then
            echo "${PROGRAM_BASE} ${version}"
            exit 0
        fi
    else
        echo "Version information (no flag):"
        echo "$output"
        exit 0
    fi
elif [ $? -eq 2 ]; then
    $SHORT_OUTPUT || echo "Warning: Program '$PROGRAM' timed out without flags"
fi

# If we get here, we couldn't find version information
if $SHORT_OUTPUT; then
    echo "${PROGRAM_BASE} undetermined"
else
    echo "Could not determine version information for '$PROGRAM'"
fi
exit 1
