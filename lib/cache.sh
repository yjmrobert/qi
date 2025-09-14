#!/bin/bash

# cache.sh - Cache management for qi
# Handles cache directory structure, metadata, and cleanup operations

# Cache metadata file names
REPO_METADATA_FILE=".qi-repo-meta"
SCRIPT_INDEX_FILE=".qi-script-index"
CACHE_LOCK_FILE=".qi-cache-lock"

# Initialize cache directory structure
init_cache() {
    local cache_dir="${1:-$CACHE_DIR}"

    log "DEBUG" "Initializing cache directory: $cache_dir"

    # Create cache directory if it doesn't exist
    if [[ ! -d "$cache_dir" ]]; then
        log "INFO" "Creating cache directory: $cache_dir"
        mkdir -p "$cache_dir" || {
            log "ERROR" "Failed to create cache directory: $cache_dir"
            return 1
        }
    fi

    # Check if cache directory is writable
    if [[ ! -w "$cache_dir" ]]; then
        log "ERROR" "Cache directory is not writable: $cache_dir"
        return 1
    fi

    # Create cache metadata directory
    local meta_dir="$cache_dir/.qi-meta"
    if [[ ! -d "$meta_dir" ]]; then
        mkdir -p "$meta_dir"
    fi

    log "DEBUG" "Cache directory initialized successfully"
    return 0
}

# Get repository directory path
get_repo_dir() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    echo "$cache_dir/$repo_name"
}

# Get repository metadata file path
get_repo_metadata_file() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    echo "$cache_dir/$repo_name/$REPO_METADATA_FILE"
}

# Create repository metadata
create_repo_metadata() {
    local repo_name="$1"
    local repo_url="$2"
    local repo_dir="$3"
    local custom_name="${4:-}"

    local metadata_file
    metadata_file="$(get_repo_metadata_file "$repo_name")"

    log "DEBUG" "Creating repository metadata: $metadata_file"

    cat >"$metadata_file" <<EOF
# qi repository metadata
# Created on $(date)

name=$repo_name
url=$repo_url
directory=$repo_dir
custom_name=$custom_name
added_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
last_updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
branch=$(get_config default_branch)
status=active
EOF

    log "DEBUG" "Repository metadata created successfully"
}

# Read repository metadata
read_repo_metadata() {
    local repo_name="$1"
    local key="${2:-}"

    local metadata_file
    metadata_file="$(get_repo_metadata_file "$repo_name")"

    if [[ ! -f "$metadata_file" ]]; then
        log "DEBUG" "Repository metadata not found: $metadata_file"
        return 1
    fi

    if [[ -n "$key" ]]; then
        # Return specific key value
        grep "^$key=" "$metadata_file" 2>/dev/null | cut -d'=' -f2- | xargs
    else
        # Return all metadata
        cat "$metadata_file"
    fi
}

# Update repository metadata
update_repo_metadata() {
    local repo_name="$1"
    local key="$2"
    local value="$3"

    local metadata_file
    metadata_file="$(get_repo_metadata_file "$repo_name")"

    if [[ ! -f "$metadata_file" ]]; then
        log "ERROR" "Repository metadata not found: $metadata_file"
        return 1
    fi

    log "DEBUG" "Updating repository metadata: $key=$value"

    # Create temporary file for atomic update
    local temp_file="$metadata_file.tmp"

    # Update the key or add it if it doesn't exist
    if grep -q "^$key=" "$metadata_file"; then
        sed "s|^$key=.*|$key=$value|" "$metadata_file" >"$temp_file"
    else
        cp "$metadata_file" "$temp_file"
        echo "$key=$value" >>"$temp_file"
    fi

    # Atomically replace the original file
    mv "$temp_file" "$metadata_file"

    log "DEBUG" "Repository metadata updated successfully"
}

# Check if repository exists in cache
repo_exists() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    [[ -d "$repo_dir" && -f "$repo_dir/$REPO_METADATA_FILE" ]]
}

# List all cached repositories
list_cached_repos() {
    local cache_dir="${1:-$CACHE_DIR}"

    if [[ ! -d "$cache_dir" ]]; then
        return 0
    fi

    # Find all directories with metadata files
    find "$cache_dir" -maxdepth 2 -name "$REPO_METADATA_FILE" -exec dirname {} \; |
        while read -r repo_dir; do
            basename "$repo_dir"
        done | sort
}

# Get repository name from URL
get_repo_name_from_url() {
    local url="$1"

    # Extract repository name from URL
    local repo_name
    repo_name=$(basename "$url" .git)

    # Clean up the name (remove invalid characters)
    repo_name=${repo_name//[^a-zA-Z0-9._-]/_}

    echo "$repo_name"
}

# Check for repository name conflicts
check_repo_name_conflict() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    if repo_exists "$repo_name" "$cache_dir"; then
        return 0 # Conflict exists
    else
        return 1 # No conflict
    fi
}

# Generate unique repository name
generate_unique_repo_name() {
    local base_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"
    local counter=1
    local repo_name="$base_name"

    while check_repo_name_conflict "$repo_name" "$cache_dir"; do
        repo_name="${base_name}_$counter"
        ((counter++))
    done

    echo "$repo_name"
}

# Remove repository from cache
remove_repo_from_cache() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    if [[ ! -d "$repo_dir" ]]; then
        log "ERROR" "Repository not found in cache: $repo_name"
        return 1
    fi

    log "INFO" "Removing repository from cache: $repo_name"
    log "DEBUG" "Removing directory: $repo_dir"

    # Remove the repository directory
    rm -rf "$repo_dir" || {
        log "ERROR" "Failed to remove repository directory: $repo_dir"
        return 1
    }

    log "INFO" "Repository removed successfully: $repo_name"
    return 0
}

# Get cache statistics
get_cache_stats() {
    local cache_dir="${1:-$CACHE_DIR}"

    if [[ ! -d "$cache_dir" ]]; then
        echo "Cache directory does not exist"
        return 1
    fi

    local repo_count
    repo_count=$(list_cached_repos "$cache_dir" | wc -l)

    local cache_size
    cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1 || echo "unknown")

    local script_count=0
    if [[ -f "$cache_dir/.qi-meta/$SCRIPT_INDEX_FILE" ]]; then
        script_count=$(wc -l <"$cache_dir/.qi-meta/$SCRIPT_INDEX_FILE" 2>/dev/null || echo 0)
    fi

    echo "Cache Statistics:"
    echo "================="
    echo "Cache directory:    $cache_dir"
    echo "Repositories:       $repo_count"
    echo "Scripts indexed:    $script_count"
    echo "Cache size:         $cache_size"
    echo "Last updated:       $(date)"
}

# Clean up cache
cleanup_cache() {
    local cache_dir="${1:-$CACHE_DIR}"
    # local force="${2:-false}"  # Parameter reserved for future use

    log "INFO" "Cleaning up cache: $cache_dir"

    # Remove empty directories
    find "$cache_dir" -type d -empty -delete 2>/dev/null || true

    # Remove stale lock files (older than 1 hour)
    find "$cache_dir" -name "$CACHE_LOCK_FILE" -mmin +60 -delete 2>/dev/null || true

    # Remove orphaned metadata files
    find "$cache_dir" -name "$REPO_METADATA_FILE" | while read -r metadata_file; do
        local repo_dir
        repo_dir="$(dirname "$metadata_file")"

        # Check if the repository directory looks valid (has .git directory)
        if [[ ! -d "$repo_dir/.git" ]]; then
            log "WARN" "Removing orphaned metadata file: $metadata_file"
            rm -f "$metadata_file"
        fi
    done

    # Rebuild script index
    rebuild_script_index "$cache_dir"

    log "INFO" "Cache cleanup completed"
}

# Acquire cache lock
acquire_cache_lock() {
    local cache_dir="${1:-$CACHE_DIR}"
    local timeout="${2:-30}"

    local lock_file="$cache_dir/$CACHE_LOCK_FILE"
    local waited=0

    # Try to acquire lock atomically
    while [[ $waited -lt $timeout ]]; do
        # Use noclobber to atomically create lock file
        if (
            set -C
            echo "$$" >"$lock_file"
        ) 2>/dev/null; then
            log "DEBUG" "Cache lock acquired: $lock_file"
            return 0
        fi

        # Check if lock file exists and if the process is still running
        if [[ -f "$lock_file" ]]; then
            local lock_pid
            lock_pid=$(cat "$lock_file" 2>/dev/null)

            # If PID is empty or process doesn't exist, remove stale lock
            if [[ -z "$lock_pid" ]] || ! kill -0 "$lock_pid" 2>/dev/null; then
                log "DEBUG" "Removing stale lock file: $lock_file"
                rm -f "$lock_file"
                continue
            fi
        fi

        log "DEBUG" "Waiting for cache lock... ($waited/$timeout)"
        sleep 1
        ((waited++))
    done

    log "ERROR" "Timeout waiting for cache lock"
    return 1
}

# Release cache lock
release_cache_lock() {
    local cache_dir="${1:-$CACHE_DIR}"
    local lock_file="$cache_dir/$CACHE_LOCK_FILE"

    if [[ -f "$lock_file" ]]; then
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null)

        # Only remove lock if it belongs to current process
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$lock_file"
            log "DEBUG" "Cache lock released: $lock_file"
        else
            log "WARN" "Lock file belongs to different process: $lock_pid"
        fi
    fi
}

# Rebuild script index (placeholder - will be implemented in script-ops.sh)
rebuild_script_index() {
    local cache_dir="${1:-$CACHE_DIR}"
    log "DEBUG" "Script index rebuild requested for: $cache_dir"
    # TODO: Implement in script-ops.sh
}

# Check cache integrity
check_cache_integrity() {
    local cache_dir="${1:-$CACHE_DIR}"
    local errors=0

    log "INFO" "Checking cache integrity: $cache_dir"

    # Check each repository - avoid subshell by using process substitution
    while read -r repo_name; do
        local repo_dir
        repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

        # Check if repository directory exists
        if [[ ! -d "$repo_dir" ]]; then
            log "ERROR" "Repository directory missing: $repo_dir"
            ((errors++))
            continue
        fi

        # Check if .git directory exists
        if [[ ! -d "$repo_dir/.git" ]]; then
            log "ERROR" "Git repository invalid: $repo_dir"
            ((errors++))
            continue
        fi

        # Check if metadata file exists
        local metadata_file
        metadata_file="$(get_repo_metadata_file "$repo_name")"
        if [[ ! -f "$metadata_file" ]]; then
            log "ERROR" "Repository metadata missing: $metadata_file"
            ((errors++))
            continue
        fi

        log "DEBUG" "Repository OK: $repo_name"
    done < <(list_cached_repos "$cache_dir")

    if [[ $errors -eq 0 ]]; then
        log "INFO" "Cache integrity check passed"
        return 0
    else
        log "ERROR" "Cache integrity check failed with $errors errors"
        return 1
    fi
}
