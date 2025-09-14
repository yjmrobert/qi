#!/bin/bash

# utils.sh - Common utilities for qi
# Provides helper functions used throughout the application

# URL validation patterns
URL_PATTERN_HTTPS='^https://[a-zA-Z0-9._-]+/[a-zA-Z0-9._/-]+\.git$'
URL_PATTERN_SSH='^git@[a-zA-Z0-9._-]+:[a-zA-Z0-9._/-]+\.git$'
URL_PATTERN_HTTP='^http://[a-zA-Z0-9._-]+/[a-zA-Z0-9._/-]+\.git$'
URL_PATTERN_FILE='^file://.*\.git$'

# Color codes for output
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
# COLOR_PURPLE='\033[0;35m'  # Unused color variable
# COLOR_CYAN='\033[0;36m'  # Unused color variable
# COLOR_WHITE='\033[1;37m'  # Unused color variable
COLOR_RESET='\033[0m'

# Check if running in a terminal (for colored output)
is_terminal() {
    [[ -t 1 ]]
}

# Print colored text
print_color() {
    local color="$1"
    shift
    local text="$*"

    if is_terminal; then
        echo -e "${color}${text}${COLOR_RESET}"
    else
        echo "$text"
    fi
}

# Print success message
print_success() {
    print_color "$COLOR_GREEN" "✓ $*"
}

# Print error message
print_error() {
    print_color "$COLOR_RED" "✗ $*" >&2
}

# Print warning message
print_warning() {
    print_color "$COLOR_YELLOW" "⚠ $*" >&2
}

# Print info message
print_info() {
    print_color "$COLOR_BLUE" "ℹ $*"
}

# Validate git repository URL
validate_git_url() {
    local url="$1"

    # Check if URL matches expected patterns
    if [[ "$url" =~ $URL_PATTERN_HTTPS ]] ||
        [[ "$url" =~ $URL_PATTERN_SSH ]] ||
        [[ "$url" =~ $URL_PATTERN_HTTP ]] ||
        [[ "$url" =~ $URL_PATTERN_FILE ]]; then
        return 0
    fi

    # Additional check for URLs without .git suffix
    if [[ "$url" =~ ^https://[a-zA-Z0-9._-]+/[a-zA-Z0-9._/-]+$ ]] ||
        [[ "$url" =~ ^git@[a-zA-Z0-9._-]+:[a-zA-Z0-9._/-]+$ ]] ||
        [[ "$url" =~ ^file://.* ]]; then
        return 0
    fi

    return 1
}

# Normalize git repository URL
normalize_git_url() {
    local url="$1"

    # Add .git suffix if not present
    if [[ ! "$url" =~ \.git$ ]]; then
        url="$url.git"
    fi

    echo "$url"
}

# Validate repository name
validate_repo_name() {
    local name="$1"

    # Check for empty name
    if [[ -z "$name" ]]; then
        return 1
    fi

    # Check for invalid characters (allow alphanumeric, dots, hyphens, underscores)
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        return 1
    fi

    # Check for reserved names
    case "$name" in
        "." | ".." | ".qi-meta" | ".qi-cache-lock" | ".qi-repo-meta" | ".qi-script-index")
            return 1
            ;;
    esac

    return 0
}

# Sanitize repository name
sanitize_repo_name() {
    local name="$1"

    # Replace invalid characters with underscores
    name=${name//[^a-zA-Z0-9._-]/_}

    # Remove leading/trailing dots and underscores
    name=$(echo "$name" | sed 's/^[._]*//; s/[._]*$//')

    # Ensure name is not empty
    if [[ -z "$name" ]]; then
        name="repo"
    fi

    echo "$name"
}

# Check if command exists
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Check required dependencies
check_dependencies() {
    local missing_deps=()

    # Check for required commands
    local required_commands=("git" "find" "grep" "sed" "awk" "sort" "uniq")

    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "ERROR" "Please install the missing commands and try again"
        return 1
    fi

    log "DEBUG" "All required dependencies are available"
    return 0
}

# Check network connectivity
check_network() {
    local host="${1:-github.com}"
    local timeout="${2:-5}"

    log "DEBUG" "Checking network connectivity to $host"

    if command_exists "ping"; then
        if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
            log "DEBUG" "Network connectivity OK"
            return 0
        fi
    fi

    # Fallback: try to resolve hostname
    if command_exists "nslookup"; then
        if nslookup "$host" >/dev/null 2>&1; then
            log "DEBUG" "DNS resolution OK"
            return 0
        fi
    fi

    log "WARN" "Network connectivity check failed"
    return 1
}

# Format file size
format_size() {
    local bytes="$1"

    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt $((1024 * 1024)) ]]; then
        echo "$((bytes / 1024))K"
    elif [[ $bytes -lt $((1024 * 1024 * 1024)) ]]; then
        echo "$((bytes / 1024 / 1024))M"
    else
        echo "$((bytes / 1024 / 1024 / 1024))G"
    fi
}

# Get directory size in bytes
get_dir_size() {
    local dir="$1"

    if [[ -d "$dir" ]]; then
        du -sb "$dir" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Confirm action with user
confirm() {
    local message="$1"
    local default="${2:-n}"

    # Skip confirmation in non-interactive mode or if force is enabled
    if [[ ! -t 0 ]] || [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    while true; do
        read -rp "$message $prompt " response

        # Use default if no response
        if [[ -z "$response" ]]; then
            response="$default"
        fi

        case "$response" in
            [yY] | [yY][eE][sS])
                return 0
                ;;
            [nN] | [nN][oO])
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Show progress spinner
show_spinner() {
    local pid="$1"
    local message="${2:-Processing...}"
    local delay=0.1
    local spinstr="|/-\\" # Spinner characters

    # Don't show spinner in non-interactive mode
    if [[ ! -t 1 ]]; then
        return
    fi

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r%s %c" "$message" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%s... done\n" "$message"
}

# Create temporary directory
create_temp_dir() {
    local prefix="${1:-qi}"

    if command_exists "mktemp"; then
        mktemp -d -t "${prefix}.XXXXXX"
    else
        local temp_dir="/tmp/${prefix}.$$"
        mkdir -p "$temp_dir"
        echo "$temp_dir"
    fi
}

# Clean up temporary directory
cleanup_temp_dir() {
    local temp_dir="$1"

    if [[ -n "$temp_dir" && -d "$temp_dir" && "$temp_dir" =~ /tmp/ ]]; then
        log "DEBUG" "Cleaning up temporary directory: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# Get current timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Parse timestamp
parse_timestamp() {
    local timestamp="$1"
    local format="${2:-%Y-%m-%d %H:%M:%S}"

    if command_exists "date"; then
        date -d "$timestamp" +"$format" 2>/dev/null || echo "$timestamp"
    else
        echo "$timestamp"
    fi
}

# Calculate time difference
time_diff() {
    local start_time="$1"
    local end_time="${2:-$(date +%s)}"

    local diff=$((end_time - start_time))

    if [[ $diff -lt 60 ]]; then
        echo "${diff}s"
    elif [[ $diff -lt 3600 ]]; then
        echo "$((diff / 60))m $((diff % 60))s"
    else
        echo "$((diff / 3600))h $((diff % 3600 / 60))m"
    fi
}

# Escape string for use in regex
escape_regex() {
    local string="$1"
    echo "$string" | sed 's/\[/\\[/g' | sed 's/\]/\\]/g' | sed 's/\./\\./g'
}

# Join array elements with delimiter
join_array() {
    local delimiter="$1"
    shift
    local array=("$@")

    local result=""
    for ((i = 0; i < ${#array[@]}; i++)); do
        if [[ $i -gt 0 ]]; then
            result="$result$delimiter"
        fi
        result="$result${array[i]}"
    done

    echo "$result"
}

# Split string by delimiter into array
split_string() {
    local string="$1"
    local delimiter="$2"

    IFS="$delimiter" read -ra array <<<"$string"
    printf '%s\n' "${array[@]}"
}

# Check if array contains element
array_contains() {
    local element="$1"
    shift
    local array=("$@")

    for item in "${array[@]}"; do
        if [[ "$item" == "$element" ]]; then
            return 0
        fi
    done

    return 1
}

# Remove duplicates from array
remove_duplicates() {
    local array=("$@")
    local unique_array=()

    for item in "${array[@]}"; do
        if ! array_contains "$item" "${unique_array[@]}"; then
            unique_array+=("$item")
        fi
    done

    printf '%s\n' "${unique_array[@]}"
}

# Retry command with exponential backoff
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local command=("$@")

    local attempt=1
    local current_delay="$delay"

    while [[ $attempt -le $max_attempts ]]; do
        log "DEBUG" "Attempt $attempt/$max_attempts: ${command[*]}"

        if "${command[@]}"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log "DEBUG" "Command failed, retrying in ${current_delay}s..."
            sleep "$current_delay"
            current_delay=$((current_delay * 2))
        fi

        ((attempt++))
    done

    log "ERROR" "Command failed after $max_attempts attempts: ${command[*]}"
    return 1
}
