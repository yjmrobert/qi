#!/bin/bash

# git-ops.sh - Git operations for qi
# Handles git clone, pull, status, and other repository operations

# Clone repository to cache
clone_repository() {
    local repo_url="$1"
    local repo_name="$2"
    local cache_dir="${3:-$CACHE_DIR}"
    local branch="${4:-$(get_config default_branch)}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    log "INFO" "Cloning repository: $repo_url"
    log "DEBUG" "Target directory: $repo_dir"
    log "DEBUG" "Branch: $branch"

    # Check if directory already exists
    if [[ -d "$repo_dir" ]]; then
        log "ERROR" "Repository directory already exists: $repo_dir"
        return 1
    fi

    # Validate git URL
    if ! validate_git_url "$repo_url"; then
        log "ERROR" "Invalid git repository URL: $repo_url"
        return 1
    fi

    # Normalize URL
    repo_url=$(normalize_git_url "$repo_url")

    # Create parent directory if needed
    local parent_dir
    parent_dir="$(dirname "$repo_dir")"
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi

    # Check network connectivity
    if ! check_network; then
        log "WARN" "Network connectivity issues detected, clone may fail"
    fi

    # Clone repository
    log "INFO" "Cloning $repo_url to $repo_dir..."

    local clone_cmd=("git" "clone")

    # Add branch specification if not default
    if [[ "$branch" != "main" && "$branch" != "master" ]]; then
        clone_cmd+=("--branch" "$branch")
    fi

    clone_cmd+=("$repo_url" "$repo_dir")

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would execute: ${clone_cmd[*]}"
        return 0
    fi

    # Execute clone command
    if "${clone_cmd[@]}" 2>&1 | while IFS= read -r line; do
        log "DEBUG" "git: $line"
    done; then
        print_success "Repository cloned successfully"

        # Create repository metadata
        create_repo_metadata "$repo_name" "$repo_url" "$repo_dir" ""

        return 0
    else
        local exit_code=$?
        log "ERROR" "Failed to clone repository: $repo_url"

        # Clean up partial clone if it exists
        if [[ -d "$repo_dir" ]]; then
            log "DEBUG" "Cleaning up partial clone: $repo_dir"
            rm -rf "$repo_dir"
        fi

        return $exit_code
    fi
}

# Update repository
update_repository() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"
    local force="${3:-false}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    log "INFO" "Updating repository: $repo_name"
    log "DEBUG" "Repository directory: $repo_dir"

    # Check if repository exists
    if [[ ! -d "$repo_dir" ]]; then
        log "ERROR" "Repository not found: $repo_name"
        return 1
    fi

    # Check if it's a valid git repository
    if [[ ! -d "$repo_dir/.git" ]]; then
        log "ERROR" "Invalid git repository: $repo_dir"
        return 1
    fi

    # Change to repository directory
    local original_dir="$PWD"
    cd "$repo_dir" || {
        log "ERROR" "Cannot access repository directory: $repo_dir"
        return 1
    }

    # Check for local changes
    local has_changes=false
    if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        has_changes=true
        log "WARN" "Repository has local changes: $repo_name"
    fi

    # Check for untracked files
    local untracked_files
    untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    if [[ $untracked_files -gt 0 ]]; then
        log "WARN" "Repository has $untracked_files untracked files: $repo_name"
    fi

    # Handle local changes
    if [[ "$has_changes" == "true" && "$force" != "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "INFO" "DRY RUN: Would handle local changes in $repo_name"
            cd "$original_dir" || return
            return 0
        fi

        log "WARN" "Repository has local changes that would be overwritten"

        # In interactive mode, ask user what to do
        if [[ -t 0 ]]; then
            echo "Options:"
            echo "1. Stash changes and update"
            echo "2. Skip update (keep local changes)"
            echo "3. Show diff"
            echo "4. Force update (discard changes)"

            while true; do
                read -rp "Select option [1-4]: " choice
                case "$choice" in
                    1)
                        log "INFO" "Stashing local changes..."
                        if git stash push -m "qi auto-stash $(date)" >/dev/null 2>&1; then
                            print_success "Local changes stashed"
                            break
                        else
                            log "ERROR" "Failed to stash changes"
                            cd "$original_dir" || return
                            return 1
                        fi
                        ;;
                    2)
                        log "INFO" "Skipping update for $repo_name"
                        cd "$original_dir" || return
                        return 0
                        ;;
                    3)
                        echo "Local changes:"
                        git diff --stat
                        echo ""
                        continue
                        ;;
                    4)
                        log "WARN" "Discarding local changes..."
                        if git reset --hard HEAD >/dev/null 2>&1 && git clean -fd >/dev/null 2>&1; then
                            print_success "Local changes discarded"
                            break
                        else
                            log "ERROR" "Failed to discard changes"
                            cd "$original_dir" || return
                            return 1
                        fi
                        ;;
                    *)
                        echo "Please select 1-4"
                        continue
                        ;;
                esac
            done
        else
            # Non-interactive mode: skip update
            log "WARN" "Skipping update due to local changes (use --force to override)"
            cd "$original_dir" || return
            return 1
        fi
    fi

    # Check network connectivity
    if ! check_network; then
        log "WARN" "Network connectivity issues detected, update may fail"
    fi

    # Get current commit hash
    local old_commit
    old_commit=$(git rev-parse HEAD 2>/dev/null)

    # Perform git pull
    log "INFO" "Pulling latest changes..."

    # Get current branch name
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    if [[ -z "$current_branch" ]]; then
        log "WARN" "Unable to determine current branch, using default branch"
        current_branch=$(get_config default_branch)
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would execute: git pull origin $current_branch"
        cd "$original_dir" || return
        return 0
    fi

    local pull_output
    if pull_output=$(git pull origin "$current_branch" 2>&1); then
        local new_commit
        new_commit=$(git rev-parse HEAD 2>/dev/null)

        if [[ "$old_commit" != "$new_commit" ]]; then
            local commit_count
            commit_count=$(git rev-list --count "$old_commit..$new_commit" 2>/dev/null || echo "unknown")
            print_success "Repository updated ($commit_count new commits)"

            # Update metadata
            update_repo_metadata "$repo_name" "last_updated" "$(get_timestamp)"
        else
            log "INFO" "Repository already up-to-date"
        fi

        cd "$original_dir" || return
        return 0
    else
        log "ERROR" "Failed to update repository: $repo_name"
        log "DEBUG" "Git output: $pull_output"
        cd "$original_dir" || return
        return 1
    fi
}

# Update all repositories
update_all_repositories() {
    local cache_dir="${1:-$CACHE_DIR}"
    local force="${2:-false}"

    log "INFO" "Updating all cached repositories"

    local repos
    mapfile -t repos < <(list_cached_repos "$cache_dir")

    if [[ ${#repos[@]} -eq 0 ]]; then
        log "INFO" "No repositories found in cache"
        return 0
    fi

    local updated=0
    local failed=0
    local skipped=0

    for repo_name in "${repos[@]}"; do
        log "INFO" "Processing repository: $repo_name"

        if update_repository "$repo_name" "$cache_dir" "$force"; then
            ((updated++))
        else
            local exit_code=$?
            if [[ $exit_code -eq 1 ]]; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi

        echo "" # Add spacing between repositories
    done

    # Summary
    log "INFO" "Update summary: $updated updated, $skipped skipped, $failed failed"

    if [[ $failed -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Get repository status
get_repository_status() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    if [[ ! -d "$repo_dir" ]]; then
        echo "not_found"
        return 1
    fi

    if [[ ! -d "$repo_dir/.git" ]]; then
        echo "invalid"
        return 1
    fi

    # Change to repository directory
    local original_dir="$PWD"
    cd "$repo_dir" || {
        echo "inaccessible"
        return 1
    }

    # Check git status
    local status_output
    status_output=$(git status --porcelain 2>/dev/null)

    # Try to get ahead/behind count using multiple methods
    local ahead_behind

    # First try with origin/HEAD
    ahead_behind=$(git rev-list --left-right --count origin/HEAD...HEAD 2>/dev/null)

    # If that fails, try with the current branch's upstream
    if [[ -z "$ahead_behind" ]]; then
        local upstream
        upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            ahead_behind=$(git rev-list --left-right --count "$upstream"...HEAD 2>/dev/null)
        fi
    fi

    # If still no result, try with origin/main or origin/master
    if [[ -z "$ahead_behind" ]]; then
        for branch in main master; do
            if git rev-parse "origin/$branch" >/dev/null 2>&1; then
                ahead_behind=$(git rev-list --left-right --count "origin/$branch"...HEAD 2>/dev/null)
                break
            fi
        done
    fi

    # Default to "0	0" if all methods fail
    ahead_behind="${ahead_behind:-0	0}"

    local ahead behind
    behind=$(echo "$ahead_behind" | cut -f1)
    ahead=$(echo "$ahead_behind" | cut -f2)

    cd "$original_dir" || return

    # Determine status
    if [[ -n "$status_output" ]]; then
        echo "modified"
    elif [[ $ahead -gt 0 ]]; then
        echo "ahead"
    elif [[ $behind -gt 0 ]]; then
        echo "behind"
    else
        echo "clean"
    fi

    return 0
}

# Check if repository is up to date
is_repository_up_to_date() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local status
    status=$(get_repository_status "$repo_name" "$cache_dir")

    [[ "$status" == "clean" ]]
}

# Get repository URL from git remote
get_repository_url() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    if [[ ! -d "$repo_dir/.git" ]]; then
        return 1
    fi

    # Change to repository directory
    local original_dir="$PWD"
    cd "$repo_dir" || return 1

    local url
    url=$(git remote get-url origin 2>/dev/null)

    cd "$original_dir" || return

    if [[ -n "$url" ]]; then
        echo "$url"
        return 0
    else
        return 1
    fi
}

# Get repository branch
get_repository_branch() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    if [[ ! -d "$repo_dir/.git" ]]; then
        return 1
    fi

    # Change to repository directory
    local original_dir="$PWD"
    cd "$repo_dir" || return 1

    local branch
    branch=$(git branch --show-current 2>/dev/null)

    cd "$original_dir" || return

    if [[ -n "$branch" ]]; then
        echo "$branch"
        return 0
    else
        return 1
    fi
}

# Get repository last commit info
get_repository_last_commit() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"
    local format="${3:-%H %s %an %ad}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    if [[ ! -d "$repo_dir/.git" ]]; then
        return 1
    fi

    # Change to repository directory
    local original_dir="$PWD"
    cd "$repo_dir" || return 1

    local commit_info
    commit_info=$(git log -1 --pretty=format:"$format" 2>/dev/null)

    cd "$original_dir" || return

    if [[ -n "$commit_info" ]]; then
        echo "$commit_info"
        return 0
    else
        return 1
    fi
}

# Verify repository integrity
verify_repository() {
    local repo_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local repo_dir
    repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

    log "DEBUG" "Verifying repository: $repo_name"

    # Check if directory exists
    if [[ ! -d "$repo_dir" ]]; then
        log "ERROR" "Repository directory not found: $repo_dir"
        return 1
    fi

    # Check if .git directory exists
    if [[ ! -d "$repo_dir/.git" ]]; then
        log "ERROR" "Not a git repository: $repo_dir"
        return 1
    fi

    # Change to repository directory
    local original_dir="$PWD"
    cd "$repo_dir" || {
        log "ERROR" "Cannot access repository directory: $repo_dir"
        return 1
    }

    # Check git repository integrity
    if ! git fsck --quiet >/dev/null 2>&1; then
        log "ERROR" "Git repository integrity check failed: $repo_name"
        cd "$original_dir" || return
        return 1
    fi

    # Check if remote origin exists
    if ! git remote get-url origin >/dev/null 2>&1; then
        log "ERROR" "Remote origin not configured: $repo_name"
        cd "$original_dir" || return
        return 1
    fi

    cd "$original_dir" || return

    log "DEBUG" "Repository verification passed: $repo_name"
    return 0
}
