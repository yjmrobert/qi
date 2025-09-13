#!/bin/bash

# git-ops.sh - Git operations for qi
# Handles cloning, updating, and managing git repositories

# Check if git is available
check_git_available() {
    if ! is_command_available "git"; then
        error "Git is not installed or not available in PATH"
        return $E_GENERAL_ERROR
    fi
    
    debug "Git is available: $(git --version)"
    return $E_SUCCESS
}

# Validate git URL
validate_git_url() {
    local url="$1"
    
    debug "Validating git URL: $url"
    
    if ! validate_url "$url"; then
        error "Invalid git URL format: $url"
        return $E_INVALID_USAGE
    fi
    
    return $E_SUCCESS
}

# Extract repository name from URL
extract_repo_name() {
    local url="$1"
    local repo_name
    
    # Extract repository name from URL
    # Examples:
    # https://github.com/user/repo.git -> repo
    # git@github.com:user/repo.git -> repo
    # https://gitlab.com/group/subgroup/repo.git -> repo
    
    repo_name=$(basename "$url" .git)
    
    if [[ -z "$repo_name" ]]; then
        error "Could not extract repository name from URL: $url"
        return $E_INVALID_USAGE
    fi
    
    debug "Extracted repository name: $repo_name"
    echo "$repo_name"
    return $E_SUCCESS
}

# Clone repository
clone_repository() {
    local repo_url="$1"
    local repo_name="$2"
    local repo_dir
    local clone_result
    
    repo_dir=$(get_repo_dir "$repo_name")
    
    debug "Cloning repository: $repo_url -> $repo_dir"
    
    # Check if git is available
    check_git_available || return $?
    
    # Validate URL
    validate_git_url "$repo_url" || return $?
    
    # Check if directory already exists
    if [[ -d "$repo_dir" ]]; then
        error "Repository directory already exists: $repo_dir"
        return $E_CONFLICT
    fi
    
    # Acquire cache lock
    acquire_cache_lock || return $E_GENERAL_ERROR
    
    # Clone the repository
    info "Cloning repository: $repo_url"
    
    if [[ "${QI_DRY_RUN:-false}" == "true" ]]; then
        info "[DRY RUN] Would clone: $repo_url -> $repo_dir"
        release_cache_lock
        return $E_SUCCESS
    fi
    
    # Perform the actual clone
    if git clone --branch "$QI_DEFAULT_BRANCH" --single-branch "$repo_url" "$repo_dir" 2>/dev/null; then
        clone_result=$E_SUCCESS
        success "Successfully cloned repository: $repo_name"
    elif git clone "$repo_url" "$repo_dir" 2>/dev/null; then
        # Fallback: clone default branch if specified branch doesn't exist
        clone_result=$E_SUCCESS
        warn "Cloned with default branch (specified branch '$QI_DEFAULT_BRANCH' not found)"
    else
        clone_result=$E_GIT_ERROR
        error "Failed to clone repository: $repo_url"
        
        # Clean up partial clone if it exists
        if [[ -d "$repo_dir" ]]; then
            safe_remove_directory "$repo_dir"
        fi
    fi
    
    release_cache_lock
    
    if [[ $clone_result -eq $E_SUCCESS ]]; then
        # Create repository metadata
        create_repo_metadata "$repo_name" "$repo_url"
        
        # Update last_updated timestamp
        update_repo_metadata "$repo_name" "last_updated" "$(date -Iseconds)"
        
        debug "Repository cloned and metadata created: $repo_name"
    fi
    
    return $clone_result
}

# Update repository
update_repository_git() {
    local repo_name="$1"
    local repo_dir
    local current_branch
    local remote_url
    local update_result
    
    repo_dir=$(get_repo_dir "$repo_name")
    
    debug "Updating repository: $repo_name"
    
    # Check if repository exists
    if [[ ! -d "$repo_dir" ]]; then
        error "Repository not found: $repo_name"
        return $E_NOT_FOUND
    fi
    
    # Check if it's a git repository
    if [[ ! -d "$repo_dir/.git" ]]; then
        error "Not a git repository: $repo_dir"
        return $E_GIT_ERROR
    fi
    
    # Change to repository directory
    pushd "$repo_dir" >/dev/null || {
        error "Failed to change to repository directory: $repo_dir"
        return $E_FILE_ERROR
    }
    
    # Get current branch and remote URL
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    remote_url=$(git remote get-url origin 2>/dev/null || echo "unknown")
    
    debug "Current branch: $current_branch"
    debug "Remote URL: $remote_url"
    
    info "Updating repository: $repo_name ($current_branch)"
    
    if [[ "${QI_DRY_RUN:-false}" == "true" ]]; then
        info "[DRY RUN] Would update: $repo_name"
        popd >/dev/null
        return $E_SUCCESS
    fi
    
    # Check for local changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        warn "Local changes detected in repository: $repo_name"
        
        if [[ "${QI_FORCE:-false}" != "true" ]]; then
            error "Use --force to update with local changes (will stash them)"
            popd >/dev/null
            return $E_CONFLICT
        fi
        
        # Stash local changes
        info "Stashing local changes"
        if ! git stash push -m "qi auto-stash $(date -Iseconds)" >/dev/null 2>&1; then
            warn "Failed to stash local changes"
        fi
    fi
    
    # Fetch and pull changes
    if git fetch origin >/dev/null 2>&1 && git pull origin "$current_branch" >/dev/null 2>&1; then
        update_result=$E_SUCCESS
        success "Successfully updated repository: $repo_name"
    else
        update_result=$E_GIT_ERROR
        error "Failed to update repository: $repo_name"
    fi
    
    popd >/dev/null
    
    if [[ $update_result -eq $E_SUCCESS ]]; then
        # Update repository metadata
        update_repo_metadata "$repo_name" "last_updated" "$(date -Iseconds)"
        debug "Repository metadata updated: $repo_name"
    fi
    
    return $update_result
}

# Get repository status
get_repo_status() {
    local repo_name="$1"
    local repo_dir
    local status_info=()
    
    repo_dir=$(get_repo_dir "$repo_name")
    
    if [[ ! -d "$repo_dir" ]]; then
        echo "error:Repository not found"
        return $E_NOT_FOUND
    fi
    
    if [[ ! -d "$repo_dir/.git" ]]; then
        echo "error:Not a git repository"
        return $E_GIT_ERROR
    fi
    
    pushd "$repo_dir" >/dev/null || {
        echo "error:Cannot access repository"
        return $E_FILE_ERROR
    }
    
    # Get basic git information
    local current_branch
    local remote_url
    local last_commit
    local status_clean
    local ahead_behind
    
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    remote_url=$(git remote get-url origin 2>/dev/null || echo "unknown")
    last_commit=$(git log -1 --format="%h %s" 2>/dev/null || echo "unknown")
    
    # Check if working directory is clean
    if git diff --quiet && git diff --cached --quiet; then
        status_clean="clean"
    else
        status_clean="dirty"
    fi
    
    # Check ahead/behind status
    if git fetch origin >/dev/null 2>&1; then
        local ahead
        local behind
        ahead=$(git rev-list --count HEAD..origin/"$current_branch" 2>/dev/null || echo "0")
        behind=$(git rev-list --count origin/"$current_branch"..HEAD 2>/dev/null || echo "0")
        
        if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
            ahead_behind="up-to-date"
        elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
            ahead_behind="behind:$ahead"
        elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
            ahead_behind="ahead:$behind"
        else
            ahead_behind="diverged:$ahead:$behind"
        fi
    else
        ahead_behind="unknown"
    fi
    
    popd >/dev/null
    
    # Output status information
    status_info+=("branch:$current_branch")
    status_info+=("url:$remote_url")
    status_info+=("commit:$last_commit")
    status_info+=("status:$status_clean")
    status_info+=("sync:$ahead_behind")
    
    printf '%s\n' "${status_info[@]}"
    
    return $E_SUCCESS
}

# Check if repository needs update
repo_needs_update() {
    local repo_name="$1"
    local repo_dir
    local needs_update=false
    
    repo_dir=$(get_repo_dir "$repo_name")
    
    if [[ ! -d "$repo_dir/.git" ]]; then
        return 1
    fi
    
    pushd "$repo_dir" >/dev/null || return 1
    
    # Fetch latest information
    if git fetch origin >/dev/null 2>&1; then
        local current_branch
        local ahead
        
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        ahead=$(git rev-list --count HEAD..origin/"$current_branch" 2>/dev/null || echo "0")
        
        if [[ "$ahead" -gt 0 ]]; then
            needs_update=true
        fi
    fi
    
    popd >/dev/null
    
    if [[ "$needs_update" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Get repository information
get_repo_info() {
    local repo_name="$1"
    local repo_dir
    local metadata_file
    
    repo_dir=$(get_repo_dir "$repo_name")
    metadata_file=$(get_repo_metadata_file "$repo_name")
    
    # Read metadata if available
    if [[ -f "$metadata_file" ]]; then
        cat "$metadata_file"
    else
        echo "error:Metadata not found"
        return 1
    fi
    
    return 0
}

# Export functions
export -f check_git_available validate_git_url extract_repo_name
export -f clone_repository update_repository_git get_repo_status
export -f repo_needs_update get_repo_info