#!/bin/bash

# utils.sh - Common utility functions for qi
# Provides logging, validation, and general purpose helper functions

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo "$@" >&2
}

info() {
    if [[ "${QI_VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*" >&2
    fi
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

debug() {
    if [[ "${QI_VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

# Validation functions
validate_url() {
    local url="$1"
    
    # Basic URL validation for git repositories
    if [[ ! "$url" =~ ^(https?|git|ssh)://.*\.git$ ]] && [[ ! "$url" =~ ^git@.*:.*\.git$ ]]; then
        return 1
    fi
    
    return 0
}

validate_name() {
    local name="$1"
    
    # Repository name validation: alphanumeric, dashes, underscores only
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    return 0
}

validate_file_exists() {
    local file="$1"
    [[ -f "$file" ]]
}

validate_dir_exists() {
    local dir="$1"
    [[ -d "$dir" ]]
}

# String utilities
trim() {
    local var="$1"
    # Remove leading and trailing whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# File utilities
ensure_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        debug "Creating directory: $dir"
        mkdir -p "$dir" || {
            error "Failed to create directory: $dir"
            return 1
        }
    fi
}

safe_remove_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        warn "Directory does not exist: $dir"
        return 1
    fi
    
    debug "Removing directory: $dir"
    rm -rf "$dir" || {
        error "Failed to remove directory: $dir"
        return 1
    }
}

# Process utilities
is_command_available() {
    local command="$1"
    command -v "$command" >/dev/null 2>&1
}

get_script_directory() {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

# Lock file utilities
create_lock() {
    local lock_file="$1"
    local timeout="${2:-30}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if (set -C; echo $$ > "$lock_file") 2>/dev/null; then
            debug "Lock acquired: $lock_file"
            return 0
        fi
        
        sleep 1
        ((count++))
    done
    
    error "Failed to acquire lock: $lock_file (timeout after ${timeout}s)"
    return 1
}

release_lock() {
    local lock_file="$1"
    
    if [[ -f "$lock_file" ]]; then
        rm -f "$lock_file"
        debug "Lock released: $lock_file"
    fi
}

# Cleanup function for locks
cleanup_locks() {
    local cache_dir="${1:-$QI_CACHE_DIR}"
    
    if [[ -d "$cache_dir" ]]; then
        find "$cache_dir" -name "*.lock" -type f -delete 2>/dev/null || true
        debug "Cleaned up lock files in $cache_dir"
    fi
}

# Array utilities
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

# Text formatting utilities
format_list_item() {
    local prefix="$1"
    local text="$2"
    printf "  %s %s\n" "$prefix" "$text"
}

format_table_row() {
    local col1="$1"
    local col2="$2"
    local col3="${3:-}"
    
    if [[ -n "$col3" ]]; then
        printf "%-20s %-30s %s\n" "$col1" "$col2" "$col3"
    else
        printf "%-20s %s\n" "$col1" "$col2"
    fi
}

# Error code definitions
readonly E_SUCCESS=0
readonly E_GENERAL_ERROR=1
readonly E_INVALID_USAGE=2
readonly E_NETWORK_ERROR=3
readonly E_FILE_ERROR=4
readonly E_GIT_ERROR=5
readonly E_PERMISSION_ERROR=6
readonly E_NOT_FOUND=7
readonly E_CONFLICT=8

# Export commonly used functions
export -f log info warn error success debug
export -f validate_url validate_name validate_file_exists validate_dir_exists
export -f trim ensure_directory safe_remove_directory
export -f is_command_available create_lock release_lock
export -f array_contains format_list_item format_table_row