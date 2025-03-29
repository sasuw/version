#!/bin/bash

# version.sh - Find version information for CLI programs

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

# Check if user has execute permission
program_path=$(which "$PROGRAM")
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

# Function to try a version flag with timeout
try_version_flag() {
    local program="$1"
    local flag="$2"
    local program_base="$3"
    
    # Create a temporary file for output
    local tmpfile=$(mktemp)
    
    # Run the command with timeout and as versionchecker user
    if timeout 1s sudo -u versionchecker bash -c "
        unset DISPLAY
        unset WAYLAND_DISPLAY
        unset XAUTHORITY
        unset SESSION_MANAGER
        unset DBUS_SESSION_BUS_ADDRESS
        \"$program\" $flag" > "$tmpfile" 2>&1; then
        local output=$(cat "$tmpfile")
        rm "$tmpfile"
        
        # Check if output contains version-like information
        if contains_version_info "$output" "$program_base"; then
            echo "$output"
            return 0
        fi
    else
        # Clean up and check if it was a timeout
        local exit_code=$?
        rm "$tmpfile"
        if [ $exit_code -eq 124 ]; then  # timeout exit code
            return 2
        fi
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
# For help output check:
if help_output=$(timeout 1s sudo -u versionchecker bash -c "
    unset DISPLAY
    unset WAYLAND_DISPLAY
    unset XAUTHORITY
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    \"$PROGRAM\" --help") 2>&1 || \
   help_output=$(timeout 1s sudo -u versionchecker bash -c "
    unset DISPLAY
    unset WAYLAND_DISPLAY
    unset XAUTHORITY
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    \"$PROGRAM\" -h") 2>&1; then
#if help_output=$(timeout 1s "$PROGRAM" --help 2>&1) || help_output=$(timeout 1s "$PROGRAM" -h 2>&1); then
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
