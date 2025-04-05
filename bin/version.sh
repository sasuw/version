#!/usr/bin/env bash

# version.sh - Find version information for CLI programs

readonly TIMEOUT_SECONDS="2s"
readonly VERSION="1.1.1"
readonly SCRIPT_NAME=$(basename "$0")
DEBUG=false
SHORT_OUTPUT=false
PROGRAM=""
PROGRAM_BASE=""
PROGRAM_PATH="" # Resolved path
VERSIONCHECKER_USER="versionchecker"

# --- Helper Functions ---

debug() {
    if $DEBUG; then
        # Prepend script name and PID for clarity in complex scenarios
        echo "[${SCRIPT_NAME} $$] DEBUG: $*" >&2
    fi
}

# Function to show version
show_version() {
    echo "${SCRIPT_NAME} ${VERSION}"
    exit 0
}

# Function to show usage
show_usage() {
    cat << EOF
${SCRIPT_NAME} ${VERSION} - Find version information for CLI programs

Usage: ${SCRIPT_NAME} [options] <program-name>
       ${SCRIPT_NAME} -h | --help
       ${SCRIPT_NAME} -v | --version

Finds the version of a specified command-line program using various methods.
Runs commands as the '${VERSIONCHECKER_USER}' user for security.

Prerequisites:
  1. A non-privileged user named '${VERSIONCHECKER_USER}' must exist.
     Linux:   sudo useradd -r -s /bin/false ${VERSIONCHECKER_USER}
     macOS:   sudo dscl . -create /Users/${VERSIONCHECKER_USER} UserShell /usr/bin/false
              sudo dscl . -create /Users/${VERSIONCHECKER_USER} NFSHomeDirectory /var/empty
              # (See script source 'setup_versionchecker_example' for more macOS details)
     FreeBSD: sudo pw useradd ${VERSIONCHECKER_USER} -d /nonexistent -s /usr/sbin/nologin
  2. The user running this script must have passwordless sudo permission
     to run commands as '${VERSIONCHECKER_USER}'. Add a rule like:
     <your_user> ALL=(${VERSIONCHECKER_USER}) NOPASSWD: ALL
     (Place this in /etc/sudoers or /etc/sudoers.d/versionchecker)
  3. On macOS/FreeBSD, GNU timeout (gtimeout) is needed:
     macOS:   brew install coreutils
     FreeBSD: pkg install coreutils

Options:
  -s, --short     Output only program name and version number (e.g., "git 2.34.1")
  -h, --help      Display this help message and exit
  -v, --version   Display script version and exit
  -d, --debug     Enable verbose debug output to stderr

Examples:
  ${SCRIPT_NAME} python
  ${SCRIPT_NAME} --short git
  ${SCRIPT_NAME} /usr/local/bin/node

Exit Codes:
  0  Success (version found)
  1  Error (program not found, permissions error, prerequisites not met, version undetermined)
  2  Invalid usage

Methods Tried:
  1. Common version flags (--version, -v, -V, etc.)
  2. Help output analysis (--help, -h)
  3. Package manager information (dpkg, brew, pkg)
  4. Binary string analysis (strings)
  5. No-argument execution (less reliable)
EOF
    exit 0
}

# Cleanup temp file
cleanup() {
    local tmpfile="${1:-}"
    debug "Cleaning up tmpfile: $tmpfile"
    rm -f "$tmpfile"
}

# Function to determine OS type
get_os_type() {
    case "$(uname -s)" in
        Linux)   echo "linux" ;;
        Darwin)  echo "macos" ;;
        FreeBSD) echo "freebsd" ;;
        *)       echo "unknown" ;;
    esac
}

# Function to check package manager availability
have_pkg_manager() {
    local os_type
    os_type=$(get_os_type)
    debug "Checking package manager for OS: $os_type"
    case "$os_type" in
        linux)   command -v dpkg-query &>/dev/null ;;
        macos)   command -v brew &>/dev/null ;; # Prioritize brew
        freebsd) command -v pkg &>/dev/null ;;
        *)       return 1 ;;
    esac
}

# Function to get package version (system specific)
# Returns only the version string, or empty string if not found
get_package_version() {
    local program_base="$1" # Use base name for package lookup
    local version=""
    local os_type
    os_type=$(get_os_type)
    debug "Getting package version for '$program_base' on '$os_type'"

    case "$os_type" in
        linux)
            if command -v dpkg-query &>/dev/null; then
                # Find package providing the command path
                local pkg_name
                pkg_name=$(dpkg-query -S "$PROGRAM_PATH" 2>/dev/null | cut -d: -f1 | head -n1)
                if [[ -n "$pkg_name" ]]; then
                    debug "Found package '$pkg_name' for path '$PROGRAM_PATH'"
                    version=$(dpkg-query -W -f='${Version}' "$pkg_name" 2>/dev/null)
                    # Clean up epoch prefix like "2:" from version
                    version="${version#*:}"
                    debug "dpkg version for '$pkg_name': '$version'"
                else
                    debug "Could not find package owning '$PROGRAM_PATH' via dpkg-query -S"
                    # Fallback: Guess package name might be program base name
                    version=$(dpkg-query -W -f='${Version}' "$program_base" 2>/dev/null)
                    version="${version#*:}"
                    debug "Fallback dpkg version for '$program_base': '$version'"
                fi
            fi
            ;;
        macos)
            if command -v brew &>/dev/null; then
                # Need the formula name, which might differ from command name (e.g., gnu-sed -> sed)
                # First, try finding formula owning the path
                local formula
                formula=$(brew list --formula -1 | while read -r f; do brew --prefix "$f" && echo " $f"; done | grep "^$(dirname "$PROGRAM_PATH")/bin " | awk '{print $2}' | head -n1)
                # Fallback: guess formula name is program base name
                [[ -z "$formula" ]] && formula="$program_base"

                debug "Trying brew formula: '$formula'"
                if brew info --json=v1 "$formula" &>/dev/null; then
                   version=$(brew info --json=v1 "$formula" | grep '"installed"' | grep -Eo '"version": "[^"]+"' | cut -d'"' -f4 | head -n1)
                   debug "Brew version: '$version'"
                else
                    debug "Brew formula '$formula' not found or info failed."
                fi
            fi
            # Add MacPorts support if needed (omitted for brevity, similar logic)
            ;;
        freebsd)
            if command -v pkg &>/dev/null; then
                # Find package providing the command path
                local pkg_name
                pkg_name=$(pkg which "$PROGRAM_PATH" 2>/dev/null | sed -n 's/.* was installed by package //p')
                if [[ -n "$pkg_name" ]]; then
                    debug "Found package '$pkg_name' for path '$PROGRAM_PATH'"
                    version=$(pkg query '%v' "$pkg_name" 2>/dev/null)
                    debug "pkg version for '$pkg_name': '$version'"
                else
                    debug "Could not find package owning '$PROGRAM_PATH' via pkg which"
                     # Fallback: Guess package name might be program base name
                    version=$(pkg query '%v' "$program_base" 2>/dev/null)
                    debug "Fallback pkg version for '$program_base': '$version'"
                fi
            fi
            ;;
    esac

    # Basic cleanup: remove leading/trailing whitespace
    version=$(echo "$version" | awk '{$1=$1};1')
    echo "$version"
}

# Timeout command wrapper for different systems
# Usage: run_with_timeout <timeout_secs> <command> [args...]
# Returns exit code of the command, or 124 if timed out.
run_with_timeout() {
    local timeout_duration="$1"
    shift
    local cmd=("${@}")
    local timeout_bin=""
    local os_type
    os_type=$(get_os_type)

    case "$os_type" in
        linux)
            timeout_bin="timeout"
            ;;
        macos|freebsd)
            if command -v gtimeout &>/dev/null; then
                timeout_bin="gtimeout"
            else
                echo "Error: GNU timeout (gtimeout) not found. Please install coreutils." >&2
                 case "$os_type" in
                    macos)   echo "Run: brew install coreutils" >&2 ;;
                    freebsd) echo "Run: pkg install coreutils" >&2 ;;
                 esac
                return 127 # Command not found-like error
            fi
            ;;
        *)
            echo "Error: Unsupported OS for timeout command." >&2
            return 1
            ;;
    esac

    debug "Running with timeout: $timeout_bin $timeout_duration ${cmd[*]}"
    "$timeout_bin" "$timeout_duration" "${cmd[@]}"
    local exit_code=$?
    debug "Timeout command finished with exit code: $exit_code"
    return $exit_code
}

# Function to check if output likely contains version information
contains_version_info() {
    local output="$1"
    local program_base="$2" # Use base name for checks

    debug "Checking output for version info (program base: $program_base)"
    # Strip potential color codes first
    output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    # Strip the stderr marker and everything after it, if present
    output=$(echo "$output" | sed '/^--- STDERR ---/,$d')
    debug "Cleaned output for check: '$output'"


    # 1. Look for common patterns like "ProgramName version 1.2.3", "Version: 1.2.3", "v1.2.3"
    # Be more specific to avoid matching help text mentioning "version"
    # Match start of line or space before program name/version keyword
    # Allow for 'goX.Y.Z' style versions too
    if echo "$output" | grep -qiE "(^|[[:space:]])${program_base}[[:space:]]+(version[[:space:]]+|v|go)[0-9]+(\.[0-9]+)*"; then
        debug "Matched: Program base + 'version'/'v'/'go' + number"
        return 0
    fi
     if echo "$output" | grep -qiE "(^|[[:space:]])version[[:space:]]*:[[:space:]]*[0-9]+(\.[0-9]+)*"; then
        debug "Matched: 'Version:' + number"
        return 0
    fi
    if echo "$output" | grep -qiE "(^|[[:space:]])version[[:space:]]+[0-9]+(\.[0-9]+)*"; then
         debug "Matched: 'version' + number"
         return 0
    fi

    # 2. Check for stand-alone version numbers (X.Y.Z or X.Y or goX.Y...) if they seem prominent
    # Avoid matching if it looks like part of a date, URL, or other text
    local version_pattern="(go)?[0-9]+\.[0-9]+(\.[0-9]+([-.][a-zA-Z0-9]+)*)?" # goX.Y[.Z][-build...] or X.Y[.Z][-build...]
    # Count unique potential versions
    local version_count
    # Ensure grep only matches whole words/versions where appropriate, avoid partial matches within other numbers/words unless it's the 'go' prefix.
    # Using grep -o then checking context is safer.
    local versions_found
    versions_found=$(echo "$output" | grep -oE "$version_pattern")
    version_count=$(echo "$versions_found" | wc -l) # Count all occurrences first

    debug "Found $version_count version-like patterns ($version_pattern)"

    if [[ "$version_count" -gt 0 ]]; then
        local unique_versions
        unique_versions=$(echo "$versions_found" | sort -u)
        local unique_count
        unique_count=$(echo "$unique_versions" | wc -l)
        debug "Found $unique_count unique version-like patterns."

         # If exactly one unique version found, check if it's plausible context
         if [[ "$unique_count" -eq 1 ]]; then
             local single_version="$unique_versions"
             # Check if it's on a line with the program name or 'version', or maybe alone
             if echo "$output" | grep -qE "(^|[[:space:]])${program_base}.*[[:space:]]${single_version}" || \
                echo "$output" | grep -qiE "(^|[[:space:]])version.*[[:space:]]${single_version}" || \
                echo "$output" | grep -qE "^${single_version}[[:space:]]*$"; then
                debug "Single unique version pattern '$single_version' looks plausible."
                return 0
             fi
         fi
    fi

    # 3. Check for "built with", "using", "library" version lines (less reliable)
    if echo "$output" | grep -qiE "(built|using|library).*[[:space:]]+(go)?[0-9]+\.[0-9]+"; then
        debug "Matched: Built/using/library pattern"
        return 0 # Less certain, but maybe
    fi

    debug "No definitive version information pattern found in output."
    return 1
}

# Tries running the program with a specific flag as the versionchecker user
# Returns:
#   0: Success, version info found (output on stdout)
#   1: Command ran, but no version info found or other error
#   2: Command timed out
#   3: Sudo permission error
# 127: Command (timeout) not found or other critical error
# Tries running the program with a specific flag as the versionchecker user
# Returns:
#   0: Success, version info found (output on stdout)
#   1: Command ran, but no version info found or other error
#   2: Command timed out
#   3: Sudo permission error
# 127: Command (timeout) not found or other critical error
try_version_flag() {
    local program_path="$1" # Use full path
    local flag="$2"         # Flag can be empty
    local program_base="$3" # Base name for contains_version_info
    local tmpfile_stdout tmpfile_stderr
    local sudo_output
    local sudo_exit_code
    local cmd_array=()
    local output="" # Combined output for final check

    # Use mktemp with a template for safety
    tmpfile_stdout=$(mktemp "/tmp/${SCRIPT_NAME}_${program_base}_stdout_XXXXXX") || {
        echo "Error: Failed to create stdout temporary file." >&2
        return 1
    }
    tmpfile_stderr=$(mktemp "/tmp/${SCRIPT_NAME}_${program_base}_stderr_XXXXXX") || {
        echo "Error: Failed to create stderr temporary file." >&2
        rm -f "$tmpfile_stdout" # Clean up stdout file
        return 1
    }
    # Ensure cleanup happens even if the script exits unexpectedly
    trap 'rm -f "$tmpfile_stdout" "$tmpfile_stderr"' EXIT INT TERM HUP

    debug "Attempting flag '$flag' for '$program_path' via sudo as '$VERSIONCHECKER_USER'"

    # Prepare command array for sudo execution
    cmd_array=(sudo -n -u "${VERSIONCHECKER_USER}" env -i HOME="/tmp" LC_ALL=C PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin" "$program_path")
    [[ -n "$flag" ]] && cmd_array+=("$flag")

    # Execute with timeout, redirecting stdout/stderr of the *sudo* command
    # Debug output from run_with_timeout itself goes to the script's stderr, not the files.
    run_with_timeout "$TIMEOUT_SECONDS" "${cmd_array[@]}" > "$tmpfile_stdout" 2> "$tmpfile_stderr"
    sudo_exit_code=$?

    # Read stderr content for error checking
    local stderr_content
    stderr_content=$(cat "$tmpfile_stderr")

    # Check sudo/timeout exit code
    if [[ $sudo_exit_code -eq 124 ]]; then
        debug "Command timed out (exit code 124)."
        # Cleanup handled by trap
        trap - EXIT INT TERM HUP # Remove trap specific to this run
        return 2 # Timeout specific code
    elif [[ $sudo_exit_code -eq 1 ]]; then
         # Check if it was a sudo password prompt error (requires -n flag) - check stderr
         if echo "$stderr_content" | grep -qE 'sudo: a password is required|sudo: sorry, you must have a tty to run sudo'; then
             echo "Error: Passwordless sudo required or TTY issue for user '$USER' to run as '${VERSIONCHECKER_USER}'." >&2
             echo "       Check sudoers configuration and ensure '-n' flag works." >&2
             # Cleanup handled by trap
             trap - EXIT INT TERM HUP
             return 3 # Sudo permission error
         fi
         # Otherwise, could be a normal error from the command itself (exit code 1)
         debug "Command failed with exit code 1 (non-timeout, non-sudo-auth)."
    elif [[ $sudo_exit_code -ne 0 ]]; then
        # Any other non-zero exit code
        debug "Command failed with unexpected exit code $sudo_exit_code."
        debug "Stderr from failed command:"
        debug "$stderr_content"
        debug "Stdout from failed command (if any):"
        debug "$(cat "$tmpfile_stdout")"
        # Cleanup handled by trap
        trap - EXIT INT TERM HUP
        return 1 # General command error
    fi

    # Command ran (exit 0 or 1 without sudo auth error) - combine output for analysis
    output=$(cat "$tmpfile_stdout")
    # Append stderr if it contains potentially useful info (and isn't just empty)
    # Avoid appending if it looks like a standard flag error for Go
    if [[ -s "$tmpfile_stderr" ]] && ! echo "$stderr_content" | grep -qE 'flag provided but not defined'; then
        debug "Appending potentially relevant stderr content:"
        debug "$stderr_content"
        output+=$'\n'"--- STDERR ---"$'\n'"$stderr_content"
    elif [[ -s "$tmpfile_stderr" ]]; then
        debug "Ignoring stderr content (likely flag error):"
        debug "$stderr_content"
    fi

    debug "Command finished with exit code $sudo_exit_code. Combined output for analysis:"
    # Use printf to handle potential '%' characters safely
    if $DEBUG; then
        printf "DEBUG Raw Output to Check: %s\n" "$output" >&2 # <-- Renamed slightly for clarity
    fi

    # Cleanup tmpfiles now
    rm -f "$tmpfile_stdout" "$tmpfile_stderr"
    trap - EXIT INT TERM HUP # Remove trap specific to this run

    # Now check the combined output (primarily stdout)
    if contains_version_info "$output" "$program_base"; then
        debug "Version info found in output."
        printf "%s" "$output" # Print the output containing version info (use printf)
        return 0
    else
        debug "No version info found in output (Exit code was $sudo_exit_code)."
        # Distinguish: Command ran (e.g., exit 0) but no version vs command failed (e.g. exit 1, 2)
        # If exit code was 0, it just didn't have the info we recognise.
        # If exit code was non-zero (but not timeout/sudo), it failed in some other way.
        return 1 # Indicate failure to find version OR command error
    fi
}

# Function to extract a simple version number (goX.Y.Z, X.Y.Z or X.Y) from output
extract_version() {
    local output="$1"
    local version=""

    # Try specific 'goX.Y.Z' format first, including potential suffixes
    version=$(echo "$output" | grep -oE 'go[0-9]+\.[0-9]+(\.[0-9]+)?([-.][a-zA-Z0-9_]+)*' | head -n1)

    # If not found, prioritize X.Y.Z format, including potential suffixes like -beta, _p1
    if [[ -z "$version" ]]; then
        version=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9_]+)*' | head -n1)
    fi

    # If not found, try X.Y format
    if [[ -z "$version" ]]; then
        version=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+([-.][a-zA-Z0-9_]+)*' | head -n1)
    fi

    # If still not found, try just 'vX' or 'version X' pattern as last resort number grab
    if [[ -z "$version" ]]; then
       # Extract the number part after 'v' or 'version'
       version=$(echo "$output" | grep -oE '(^|[[:space:]])(v|version)[[:space:]]*([0-9]+([.][0-9]+)*([-.][a-zA-Z0-9_]+)*)' | sed -E 's/.*(v|version)[[:space:]]*//i' | head -n1)
    fi

    debug "Extracted version: '$version'"
    echo "$version"
}

# --- Main Script Logic ---

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            ;;
        -v|--version)
            show_version
            ;;
        -s|--short)
            SHORT_OUTPUT=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            # Enable debug mode in bash
            set -x
            debug "Debug mode enabled."
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            show_usage >&2 # Show usage on error
            exit 2
            ;;
        *)
            if [[ -n "$PROGRAM" ]]; then
                echo "Error: Only one program name can be specified." >&2
                show_usage >&2
                exit 2
            fi
            PROGRAM="$1"
            # Get base name early for use in messages and lookups
            PROGRAM_BASE=$(basename "$PROGRAM")
            shift
            ;;
    esac
done

# Turn off bash debug mode if it was enabled
set +x

# Check if a program name was provided
if [[ -z "$PROGRAM" ]]; then
    echo "Error: Program name not specified." >&2
    show_usage >&2
    exit 2
fi

debug "Starting version check for program: $PROGRAM (Base: $PROGRAM_BASE)"

# --- Prerequisite Checks ---

# 1. Check if versionchecker user exists
if ! id -u "${VERSIONCHECKER_USER}" > /dev/null 2>&1; then
    echo "Error: Prerequisite failed: User '${VERSIONCHECKER_USER}' does not exist." >&2
    echo "       Please create the user manually (see --help for examples)." >&2
    exit 1
fi
debug "Prerequisite check: User '${VERSIONCHECKER_USER}' exists."

# 2. Check if current user can sudo to versionchecker user without password
# Use a simple, non-intrusive command like 'id'
if ! sudo -n -u "${VERSIONCHECKER_USER}" id > /dev/null 2>&1; then
     echo "Error: Prerequisite failed: Current user '$USER' cannot run commands as '${VERSIONCHECKER_USER}' via passwordless sudo." >&2
     echo "       Please configure sudoers correctly (see --help for examples)." >&2
     # Provide more specific sudo error if possible (though output was discarded)
     # sudo -n -u "${VERSIONCHECKER_USER}" id # Run again to show error message
     exit 1
fi
debug "Prerequisite check: Passwordless sudo to '${VERSIONCHECKER_USER}' works."

# 3. Check for gtimeout on macOS/FreeBSD (done implicitly in run_with_timeout)
# Pre-check is good practice though
os_type_check=$(get_os_type)
if [[ "$os_type_check" == "macos" || "$os_type_check" == "freebsd" ]]; then
    if ! command -v gtimeout &>/dev/null; then
         echo "Error: Prerequisite failed: GNU timeout (gtimeout) not found on ${os_type_check}." >&2
         echo "       Please install coreutils ('brew install coreutils' or 'pkg install coreutils')." >&2
         exit 1
    fi
    debug "Prerequisite check: gtimeout found on ${os_type_check}."
fi


# --- Program Path and Permissions ---

# Resolve program path
found_path=""
if [[ "$PROGRAM" == */* ]]; then # If it contains a slash, assume path
    if command -v "$PROGRAM" &> /dev/null; then
        found_path=$(command -v "$PROGRAM")
    fi
else # Search in PATH
    if command -v "$PROGRAM" &> /dev/null; then
        found_path=$(command -v "$PROGRAM")
    # Try with '3' suffix for python, pip etc. only if base command wasn't found
    elif command -v "${PROGRAM}3" &> /dev/null; then
        debug "Program '$PROGRAM' not found, trying '${PROGRAM}3'"
        PROGRAM="${PROGRAM}3" # Update program name for consistency
        PROGRAM_BASE=$(basename "$PROGRAM") # Update base name too
        found_path=$(command -v "$PROGRAM")
        debug "Found '$PROGRAM' at path: $found_path"
    fi
fi


if [[ -z "$found_path" ]]; then
    if $SHORT_OUTPUT; then
        echo "${PROGRAM_BASE} not-found"
    else
        echo "Error: Program '$PROGRAM' not found in PATH or as specified."
    fi
    exit 1
fi

PROGRAM_PATH="$found_path"
debug "Resolved program path: $PROGRAM_PATH"

# Check execute permissions for *current user* first (basic sanity)
if [[ ! -x "$PROGRAM_PATH" ]]; then
     if $SHORT_OUTPUT; then
        echo "${PROGRAM_BASE} no-permission"
    else
        echo "Error: No execute permission for current user on '$PROGRAM_PATH'"
    fi
    exit 1
fi
# Read permission check (for strings command later)
if [[ ! -r "$PROGRAM_PATH" ]]; then
     if $SHORT_OUTPUT; then
        echo "${PROGRAM_BASE} no-permission"
    else
        echo "Warning: No read permission for current user on '$PROGRAM_PATH'. 'strings' method will fail." >&2
        # Don't exit yet, other methods might work
    fi
fi

# Check execute permissions for versionchecker user (relies on sudo working)
if ! sudo -n -u "${VERSIONCHECKER_USER}" test -x "$PROGRAM_PATH"; then
     if $SHORT_OUTPUT; then
        echo "${PROGRAM_BASE} no-permission-user"
    else
        echo "Error: User '${VERSIONCHECKER_USER}' does not have execute permission on '$PROGRAM_PATH'."
        echo "       Check file permissions: ls -l $PROGRAM_PATH"
    fi
    exit 1
fi
debug "Permission checks passed for current user and '${VERSIONCHECKER_USER}'."


# --- Version Detection Methods ---

# Array of common version flags
# Ordered roughly by commonality/specificity
VERSION_FLAGS=(
    "--version"
    "version"   # Some tools use 'version' as a command
    "-v"
    "-V"
    "--Version" # Case sensitive? Sometimes.
    "-version"  # Java style
    "--ver"
    "-ver"
)

VERSION_FOUND=false
VERSION_OUTPUT=""

# Method 1: Try common version flags
debug "Method 1: Trying common version flags..."
for flag in "${VERSION_FLAGS[@]}"; do
    debug "Trying flag: $flag"
    # Assign output directly if command succeeds (exit 0)
    if output=$(try_version_flag "$PROGRAM_PATH" "$flag" "$PROGRAM_BASE"); then
        debug "Flag '$flag' successful and contained version info."
        VERSION_FOUND=true
        VERSION_OUTPUT="$output"
        METHOD="flag '$flag'"
        break # Found it, stop trying flags
    else
        # Check specific return codes from try_version_flag
        try_rc=$?
        if [[ $try_rc -eq 2 ]]; then
            debug "Flag '$flag' timed out."
            $SHORT_OUTPUT || echo "Warning: Program '$PROGRAM' timed out with flag '$flag'." >&2
        elif [[ $try_rc -eq 3 ]]; then
            debug "Flag '$flag' failed due to sudo permissions."
            # Error already printed by try_version_flag
            exit 1 # Exit early for sudo issues
        elif [[ $try_rc -eq 1 ]]; then
            debug "Flag '$flag' ran but output didn't contain version info."
        else
             debug "Flag '$flag' failed with unexpected code $try_rc."
             # Potentially exit or just continue
        fi
    fi
done

# Method 2: Try analyzing help output (if version not found yet)
if ! $VERSION_FOUND; then
    debug "Method 2: Trying help flags (--help, -h)..."
    HELP_FLAGS=("--help" "-h")
    found_help_output=""
    for flag in "${HELP_FLAGS[@]}"; do
         debug "Trying help flag: $flag"
         # We only care if the command exits successfully (or potentially with error code 1 if it prints help then exits)
         # We don't need contains_version_info here, just capture the output
         if output=$(try_version_flag "$PROGRAM_PATH" "$flag" "$PROGRAM_BASE"); then
             # Command exited 0 and *might* contain version info itself
             debug "Help flag '$flag' ran successfully and output contained version-like info."
             VERSION_FOUND=true
             VERSION_OUTPUT="$output"
             METHOD="help flag '$flag' (direct)"
             break
         else
            try_rc=$?
            # Check if it failed with code 1 (common for help output) BUT didn't contain version info
            if [[ $try_rc -eq 1 ]]; then
                # Re-run to capture output even on failure code 1, IF it didn't timeout/sudo-fail
                # Use a slightly different call logic for help capture
                tmpfile_help=$(mktemp "/tmp/${SCRIPT_NAME}_${PROGRAM_BASE}_help_XXXXXX")
                trap 'cleanup "$tmpfile_help"' EXIT INT TERM HUP
                debug "Re-running help flag '$flag' to capture output despite non-zero exit..."
                help_cmd_array=(sudo -n -u "${VERSIONCHECKER_USER}" env -i HOME="/tmp" LC_ALL=C PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin" "$PROGRAM_PATH" "$flag")
                run_with_timeout "$TIMEOUT_SECONDS" "${help_cmd_array[@]}" > "$tmpfile_help" 2>&1
                help_rc=$?
                if [[ $help_rc -ne 124 && $help_rc -ne 3 ]]; then # Avoid timeout/sudo loops
                    found_help_output=$(cat "$tmpfile_help")
                    debug "Captured help output (exit code $help_rc):"
                    debug "$found_help_output"
                    # Check if THIS output contains a version string (less likely but possible)
                    if contains_version_info "$found_help_output" "$PROGRAM_BASE"; then
                         VERSION_FOUND=true
                         VERSION_OUTPUT="$found_help_output"
                         METHOD="help flag '$flag' (captured)"
                         cleanup "$tmpfile_help"
                         trap - EXIT INT TERM HUP
                         break
                    fi
                fi
                 cleanup "$tmpfile_help"
                 trap - EXIT INT TERM HUP
            elif [[ $try_rc -eq 2 ]]; then
                debug "Help flag '$flag' timed out."
                 $SHORT_OUTPUT || echo "Warning: Program '$PROGRAM' timed out with help flag '$flag'." >&2
            elif [[ $try_rc -eq 3 ]]; then
                 debug "Help flag '$flag' failed due to sudo permissions."
                 exit 1
            fi
         fi
    done
    # TODO: Could add logic here to parse 'found_help_output' for a version *flag* (e.g., grep for --version)
    # and then re-run try_version_flag with THAT flag, but it adds complexity.
fi


# Method 3: Try package manager (if version not found yet)
if ! $VERSION_FOUND; then
    debug "Method 3: Trying package manager..."
    if have_pkg_manager; then
        pkg_version=$(get_package_version "$PROGRAM_BASE") # Base name often works best here
        if [[ -n "$pkg_version" ]]; then
            debug "Package manager found version: $pkg_version"
            VERSION_FOUND=true
            # Format output for consistency
            VERSION_OUTPUT="${PROGRAM_BASE} version ${pkg_version} (from package manager)"
            # Extract just the version number if short output requested
            if $SHORT_OUTPUT; then
                VERSION_OUTPUT="${PROGRAM_BASE} ${pkg_version}"
            fi
            METHOD="package manager"
        else
            debug "Package manager did not find version info for '$PROGRAM_BASE' or its path."
        fi
    else
        debug "No supported package manager found or available."
    fi
fi

# Method 4: Try strings command (if version not found yet)
if ! $VERSION_FOUND; then
    debug "Method 4: Trying strings command..."
    if command -v strings &> /dev/null; then
        if [[ -r "$PROGRAM_PATH" ]]; then # Check read permission again
             # Look for patterns like "Version", "vX.Y", potentially near the program name
             # Be cautious as this can find unrelated strings
             strings_output=$(strings "$PROGRAM_PATH")
             # Try finding a single, clear version string first
             version_in_strings=$(echo "$strings_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+([-.][a-zA-Z0-9_]+)*' | sort -u)
             num_versions=$(echo "$version_in_strings" | wc -l)

             if [[ $num_versions -eq 1 ]]; then
                 debug "Found unique version string '$version_in_strings' in binary."
                 VERSION_FOUND=true
                 VERSION_OUTPUT="${PROGRAM_BASE} version ${version_in_strings} (from strings)"
                  if $SHORT_OUTPUT; then
                    VERSION_OUTPUT="${PROGRAM_BASE} ${version_in_strings}"
                 fi
                 METHOD="strings (unique version)"
            else
                 # More complex: Look for lines containing "version" AND a number pattern
                 version_info=$(echo "$strings_output" | grep -iE 'version.*[0-9]+\.[0-9]+' | head -n1)
                 if [[ -n "$version_info" ]]; then
                    extracted_ver=$(extract_version "$version_info")
                    if [[ -n "$extracted_ver" ]]; then
                        debug "Found potential version '$extracted_ver' near 'version' keyword in strings: $version_info"
                        VERSION_FOUND=true
                        VERSION_OUTPUT="${PROGRAM_BASE} version ${extracted_ver} (from strings: '${version_info}')"
                         if $SHORT_OUTPUT; then
                           VERSION_OUTPUT="${PROGRAM_BASE} ${extracted_ver}"
                        fi
                        METHOD="strings (keyword)"
                    fi
                 fi
            fi
        else
             debug "Cannot read '$PROGRAM_PATH', skipping strings."
        fi
    else
        debug "strings command not found."
    fi
fi

# Method 5: Try running with no arguments (last resort, less reliable)
if ! $VERSION_FOUND; then
    debug "Method 5: Trying execution with no arguments..."
    # Treat empty flag as no arguments
    if output=$(try_version_flag "$PROGRAM_PATH" "" "$PROGRAM_BASE"); then
        debug "No-argument execution successful and contained version info."
        VERSION_FOUND=true
        VERSION_OUTPUT="$output"
        METHOD="no arguments"
    else
        try_rc=$?
        if [[ $try_rc -eq 2 ]]; then
            debug "No-argument execution timed out."
            $SHORT_OUTPUT || echo "Warning: Program '$PROGRAM' timed out when run with no arguments." >&2
        elif [[ $try_rc -eq 3 ]]; then
            debug "No-argument execution failed due to sudo permissions."
            exit 1
        else
             debug "No-argument execution failed or didn't contain version info (exit code $try_rc)."
        fi
    fi
fi

# --- Final Output ---

debug "Finished all methods. Version found: $VERSION_FOUND"

if $VERSION_FOUND; then
    debug "Final raw output: $VERSION_OUTPUT"
    debug "Determined by method: $METHOD"
    if $SHORT_OUTPUT; then
        # If output already formatted by package manager, use it
        if [[ "$METHOD" == "package manager" || "$METHOD" == "strings (unique version)" || "$METHOD" == "strings (keyword)" ]]; then
             echo "$VERSION_OUTPUT" # Already formatted as "prog version"
        else
             # Extract version number from the captured output
             version=$(extract_version "$VERSION_OUTPUT")
             if [[ -n "$version" ]]; then
                 echo "${PROGRAM_BASE} ${version}"
             else
                 # Fallback if extraction fails but we thought we found something
                 echo "${PROGRAM_BASE} found-but-unparsed"
             fi
        fi
    else
        echo "Version information for '${PROGRAM}' (found via: ${METHOD}):"
        # Print the captured output, ensuring it ends with a newline
        printf "%s\n" "$VERSION_OUTPUT"
    fi
    exit 0
else
    if $SHORT_OUTPUT; then
        echo "${PROGRAM_BASE} undetermined"
    else
        echo "Error: Could not determine version information for '$PROGRAM'."
    fi
    exit 1
fi