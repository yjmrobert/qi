#!/bin/bash

# cache.sh - Cache management for qi
# Handles cache directory structure, metadata storage, and cleanup operations

# Cache metadata files
readonly CACHE_METADATA_FILE=".qi-metadata"
readonly CACHE_LOCK_FILE=".qi-cache.lock"
readonly REPO_METADATA_FILE=".qi-repo-metadata"

# Initialize cache system
init_cache() {
    debug "Initializing cache system"
    
    # Ensure cache directory exists
    ensure_directory "$QI_CACHE_DIR" || {
        error "Failed to create cache directory: $QI_CACHE_DIR"
        return $E_FILE_ERROR
    }
    
    # Create cache metadata if it doesn't exist
    create_cache_metadata
    
    # Clean up any stale lock files
    cleanup_stale_locks
    
    debug "Cache system initialized successfully"
    return $E_SUCCESS
}

# Create cache metadata file
create_cache_metadata() {
    local metadata_file="$QI_CACHE_DIR/$CACHE_METADATA_FILE"
    
    if [[ ! -f "$metadata_file" ]]; then
        debug "Creating cache metadata file: $metadata_file"
        
        cat > "$metadata_file" << EOF
# qi cache metadata
# This file contains information about the cache structure
# Created: $(date -Iseconds)
version=1.0.0
created=$(date -Iseconds)
last_updated=$(date -Iseconds)
EOF
        
        success "Created cache metadata file"
    fi
}

# Update cache metadata
update_cache_metadata() {
    local metadata_file="$QI_CACHE_DIR/$CACHE_METADATA_FILE"
    
    if [[ -f "$metadata_file" ]]; then
        # Update last_updated timestamp
        sed -i "s/^last_updated=.*/last_updated=$(date -Iseconds)/" "$metadata_file"
        debug "Updated cache metadata"
    fi
}

# Get repository directory path
get_repo_dir() {
    local repo_name="$1"
    echo "$QI_CACHE_DIR/$repo_name"
}

# Get repository metadata file path
get_repo_metadata_file() {
    local repo_name="$1"
    local repo_dir
    repo_dir=$(get_repo_dir "$repo_name")
    echo "$repo_dir/$REPO_METADATA_FILE"
}

# Create repository metadata
create_repo_metadata() {
    local repo_name="$1"
    local repo_url="$2"
    local repo_dir
    local metadata_file
    
    repo_dir=$(get_repo_dir "$repo_name")
    metadata_file=$(get_repo_metadata_file "$repo_name")
    
    debug "Creating repository metadata: $metadata_file"
    
    cat > "$metadata_file" << EOF
# qi repository metadata
# Repository: $repo_name
name=$repo_name
url=$repo_url
added=$(date -Iseconds)
last_updated=$(date -Iseconds)
last_script_scan=
script_count=0
branch=$QI_DEFAULT_BRANCH
EOF
    
    debug "Created repository metadata for $repo_name"
}

# Read repository metadata
read_repo_metadata() {
    local repo_name="$1"
    local key="${2:-}"
    local metadata_file
    
    metadata_file=$(get_repo_metadata_file "$repo_name")
    
    if [[ ! -f "$metadata_file" ]]; then
        debug "Repository metadata not found: $metadata_file"
        return 1
    fi
    
    if [[ -n "$key" ]]; then
        # Return specific key value
        grep "^$key=" "$metadata_file" 2>/dev/null | cut -d'=' -f2- || return 1
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
    
    metadata_file=$(get_repo_metadata_file "$repo_name")
    
    if [[ ! -f "$metadata_file" ]]; then
        error "Repository metadata not found: $repo_name"
        return 1
    fi
    
    debug "Updating repository metadata: $repo_name.$key = $value"
    
    # Update or add the key-value pair
    if grep -q "^$key=" "$metadata_file"; then
        sed -i "s/^$key=.*/$key=$value/" "$metadata_file"
    else
        echo "$key=$value" >> "$metadata_file"
    fi
    
    # Always update the last_updated timestamp
    if [[ "$key" != "last_updated" ]]; then
        update_repo_metadata "$repo_name" "last_updated" "$(date -Iseconds)"
    fi
    
    # Update cache metadata as well
    update_cache_metadata
}

# Check if repository exists in cache
repo_exists() {
    local repo_name="$1"
    local repo_dir
    
    repo_dir=$(get_repo_dir "$repo_name")
    
    if [[ -d "$repo_dir" ]] && [[ -f "$(get_repo_metadata_file "$repo_name")" ]]; then
        return 0
    else
        return 1
    fi
}

# List all cached repositories
list_cached_repos() {
    local repo_dirs=()
    
    if [[ ! -d "$QI_CACHE_DIR" ]]; then
        return 0
    fi
    
    # Find all directories with metadata files
    while IFS= read -r -d '' dir; do
        local repo_name
        repo_name=$(basename "$dir")
        
        if [[ -f "$dir/$REPO_METADATA_FILE" ]]; then
            repo_dirs+=("$repo_name")
        fi
    done < <(find "$QI_CACHE_DIR" -maxdepth 1 -type d -not -path "$QI_CACHE_DIR" -print0 2>/dev/null)
    
    printf '%s\n' "${repo_dirs[@]}" | sort
}

# Get repository count
get_repo_count() {
    local count=0
    local repos
    
    readarray -t repos < <(list_cached_repos)
    count=${#repos[@]}
    
    echo "$count"
}

# Clean up stale lock files
cleanup_stale_locks() {
    local lock_files
    
    debug "Cleaning up stale lock files"
    
    # Find lock files older than 1 hour
    readarray -t lock_files < <(find "$QI_CACHE_DIR" -name "*.lock" -type f -mmin +60 2>/dev/null || true)
    
    for lock_file in "${lock_files[@]}"; do
        if [[ -f "$lock_file" ]]; then
            debug "Removing stale lock file: $lock_file"
            rm -f "$lock_file" || warn "Failed to remove lock file: $lock_file"
        fi
    done
}

# Acquire cache lock
acquire_cache_lock() {
    local lock_file="$QI_CACHE_DIR/$CACHE_LOCK_FILE"
    local timeout="${1:-30}"
    
    debug "Acquiring cache lock: $lock_file"
    
    create_lock "$lock_file" "$timeout" || {
        error "Failed to acquire cache lock"
        return 1
    }
    
    # Set trap to release lock on exit
    trap "release_cache_lock" EXIT
    
    return 0
}

# Release cache lock
release_cache_lock() {
    local lock_file="$QI_CACHE_DIR/$CACHE_LOCK_FILE"
    
    if [[ -f "$lock_file" ]]; then
        release_lock "$lock_file"
    fi
}

# Get cache statistics
get_cache_stats() {
    local stats=()
    local repo_count
    local total_size
    local last_updated
    
    repo_count=$(get_repo_count)
    
    # Calculate total cache size
    if [[ -d "$QI_CACHE_DIR" ]]; then
        total_size=$(du -sh "$QI_CACHE_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
    else
        total_size="0"
    fi
    
    # Get last updated time
    if [[ -f "$QI_CACHE_DIR/$CACHE_METADATA_FILE" ]]; then
        last_updated=$(read_cache_metadata "last_updated" || echo "Unknown")
    else
        last_updated="Never"
    fi
    
    stats+=("repositories:$repo_count")
    stats+=("total_size:$total_size")
    stats+=("last_updated:$last_updated")
    
    printf '%s\n' "${stats[@]}"
}

# Read cache metadata
read_cache_metadata() {
    local key="${1:-}"
    local metadata_file="$QI_CACHE_DIR/$CACHE_METADATA_FILE"
    
    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi
    
    if [[ -n "$key" ]]; then
        grep "^$key=" "$metadata_file" 2>/dev/null | cut -d'=' -f2- || return 1
    else
        cat "$metadata_file"
    fi
}

# Remove repository from cache
remove_repo_from_cache() {
    local repo_name="$1"
    local repo_dir
    
    repo_dir=$(get_repo_dir "$repo_name")
    
    if [[ ! -d "$repo_dir" ]]; then
        warn "Repository directory not found: $repo_dir"
        return 1
    fi
    
    debug "Removing repository from cache: $repo_name"
    
    # Acquire lock before removing
    acquire_cache_lock || return 1
    
    # Remove repository directory
    safe_remove_directory "$repo_dir" || {
        error "Failed to remove repository directory: $repo_dir"
        release_cache_lock
        return 1
    }
    
    # Update cache metadata
    update_cache_metadata
    
    release_cache_lock
    
    success "Removed repository from cache: $repo_name"
    return 0
}

# Validate cache integrity
validate_cache() {
    local issues=0
    local repos
    
    debug "Validating cache integrity"
    
    if [[ ! -d "$QI_CACHE_DIR" ]]; then
        error "Cache directory does not exist: $QI_CACHE_DIR"
        return 1
    fi
    
    # Check cache metadata
    if [[ ! -f "$QI_CACHE_DIR/$CACHE_METADATA_FILE" ]]; then
        warn "Cache metadata file missing, recreating"
        create_cache_metadata
        ((issues++))
    fi
    
    # Check each repository
    readarray -t repos < <(list_cached_repos)
    
    for repo in "${repos[@]}"; do
        local repo_dir
        local metadata_file
        
        repo_dir=$(get_repo_dir "$repo")
        metadata_file=$(get_repo_metadata_file "$repo")
        
        # Check if repository directory exists
        if [[ ! -d "$repo_dir" ]]; then
            error "Repository directory missing: $repo_dir"
            ((issues++))
            continue
        fi
        
        # Check if it's a git repository
        if [[ ! -d "$repo_dir/.git" ]]; then
            error "Not a git repository: $repo_dir"
            ((issues++))
            continue
        fi
        
        # Check metadata file
        if [[ ! -f "$metadata_file" ]]; then
            warn "Repository metadata missing: $repo"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        success "Cache validation completed - no issues found"
        return 0
    else
        warn "Cache validation completed - found $issues issue(s)"
        return 1
    fi
}

# Export functions
export -f init_cache create_cache_metadata update_cache_metadata
export -f get_repo_dir get_repo_metadata_file create_repo_metadata
export -f read_repo_metadata update_repo_metadata repo_exists
export -f list_cached_repos get_repo_count cleanup_stale_locks
export -f acquire_cache_lock release_cache_lock get_cache_stats
export -f read_cache_metadata remove_repo_from_cache validate_cache