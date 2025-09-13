#!/bin/bash

# commands.sh - Main command implementations for qi
# Contains the high-level command functions called from the main script

# Add repository command
add_repository() {
    local repo_url="$1"
    local custom_name="$2"
    local repo_name
    local extracted_name
    
    debug "Adding repository: $repo_url"
    
    # Validate URL
    validate_git_url "$repo_url" || return $?
    
    # Extract repository name from URL
    extracted_name=$(extract_repo_name "$repo_url") || return $?
    
    # Use custom name if provided, otherwise use extracted name
    repo_name="${custom_name:-$extracted_name}"
    
    # Validate repository name
    if ! validate_name "$repo_name"; then
        error "Invalid repository name: $repo_name"
        error "Repository names must contain only letters, numbers, dashes, and underscores"
        return $E_INVALID_USAGE
    fi
    
    # Check if repository already exists
    if repo_exists "$repo_name"; then
        error "Repository already exists: $repo_name"
        info "Use 'qi remove $repo_name' to remove it first, or choose a different name"
        return $E_CONFLICT
    fi
    
    info "Adding repository '$repo_name' from $repo_url"
    
    # Clone the repository
    if clone_repository "$repo_url" "$repo_name"; then
        success "Repository '$repo_name' added successfully"
        
        # Update script count
        update_script_count "$repo_name"
        
        # Show repository information
        echo
        show_repository_info "$repo_name"
        
        return $E_SUCCESS
    else
        error "Failed to add repository: $repo_name"
        return $E_GIT_ERROR
    fi
}

# Remove repository command
remove_repository() {
    local repo_name="$1"
    
    debug "Removing repository: $repo_name"
    
    # Validate repository name
    if ! validate_name "$repo_name"; then
        error "Invalid repository name: $repo_name"
        return $E_INVALID_USAGE
    fi
    
    # Check if repository exists
    if ! repo_exists "$repo_name"; then
        error "Repository not found: $repo_name"
        info "Use 'qi list-repos' to see available repositories"
        return $E_NOT_FOUND
    fi
    
    # Show repository information before removal
    echo "Repository to be removed:"
    echo "========================="
    show_repository_info "$repo_name"
    
    # Confirm removal
    if ! confirm_action "Are you sure you want to remove repository '$repo_name'?" "n"; then
        info "Repository removal cancelled"
        return $E_SUCCESS
    fi
    
    info "Removing repository: $repo_name"
    
    # Remove repository from cache
    if remove_repo_from_cache "$repo_name"; then
        success "Repository '$repo_name' removed successfully"
        return $E_SUCCESS
    else
        error "Failed to remove repository: $repo_name"
        return $E_FILE_ERROR
    fi
}

# Update repository command
update_repository() {
    local repo_name="$1"
    local update_result
    
    debug "Updating repository: $repo_name"
    
    # Validate repository name
    if ! validate_name "$repo_name"; then
        error "Invalid repository name: $repo_name"
        return $E_INVALID_USAGE
    fi
    
    # Check if repository exists
    if ! repo_exists "$repo_name"; then
        error "Repository not found: $repo_name"
        info "Use 'qi list-repos' to see available repositories"
        return $E_NOT_FOUND
    fi
    
    info "Updating repository: $repo_name"
    
    # Update the repository
    if update_repository_git "$repo_name"; then
        update_result=$E_SUCCESS
        
        # Update script count after successful update
        update_script_count "$repo_name"
        
        success "Repository '$repo_name' updated successfully"
        
        # Show update summary
        echo
        show_repository_info "$repo_name"
        
    else
        update_result=$E_GIT_ERROR
        error "Failed to update repository: $repo_name"
    fi
    
    return $update_result
}

# Update all repositories command
update_all_repositories() {
    local repos
    local results=()
    local overall_result=$E_SUCCESS
    
    debug "Updating all repositories"
    
    readarray -t repos < <(list_cached_repos)
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        info "No repositories found in cache"
        info "Use 'qi add <repository-url>' to add repositories"
        return $E_SUCCESS
    fi
    
    info "Updating ${#repos[@]} repository(ies)..."
    echo
    
    for repo in "${repos[@]}"; do
        info "Updating repository: $repo"
        
        if update_repository_git "$repo"; then
            results+=("$repo:success:Updated successfully")
            success "✓ $repo"
            
            # Update script count
            update_script_count "$repo"
        else
            results+=("$repo:error:Update failed")
            error "✗ $repo"
            overall_result=$E_GIT_ERROR
        fi
        
        echo
    done
    
    # Show summary
    show_update_results "${results[@]}"
    
    return $overall_result
}

# Source all required libraries for commands
source_command_dependencies() {
    local script_dir
    script_dir=$(get_script_directory)
    
    # Source required library files if not already loaded
    if ! declare -f validate_git_url >/dev/null; then
        source "$script_dir/git-ops.sh"
    fi
    
    if ! declare -f show_repository_info >/dev/null; then
        source "$script_dir/ui.sh"
    fi
    
    if ! declare -f remove_repo_from_cache >/dev/null; then
        source "$script_dir/cache.sh"
    fi
}

# Initialize command system
init_commands() {
    debug "Initializing command system"
    
    # Ensure all dependencies are loaded
    source_command_dependencies
    
    debug "Command system initialized"
    return $E_SUCCESS
}

# Export functions
export -f add_repository remove_repository update_repository
export -f update_all_repositories source_command_dependencies init_commands