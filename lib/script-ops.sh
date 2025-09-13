#!/bin/bash

# script-ops.sh - Script discovery and execution for qi
# Handles finding .bash files and executing them

# Find all bash scripts in a repository
find_repo_scripts() {
    local repo_name="$1"
    local repo_dir
    local scripts=()
    
    repo_dir=$(get_repo_dir "$repo_name")
    
    if [[ ! -d "$repo_dir" ]]; then
        debug "Repository directory not found: $repo_dir"
        return 1
    fi
    
    debug "Finding scripts in repository: $repo_name"
    
    # Find all .bash files recursively
    while IFS= read -r -d '' script_path; do
        local script_name
        local relative_path
        
        # Get script name without extension
        script_name=$(basename "$script_path" .bash)
        
        # Get path relative to repository root
        relative_path=${script_path#"$repo_dir"/}
        
        scripts+=("$script_name:$relative_path:$repo_name")
        debug "Found script: $script_name in $repo_name ($relative_path)"
    done < <(find "$repo_dir" -name "*.bash" -type f -print0 2>/dev/null)
    
    printf '%s\n' "${scripts[@]}"
    
    return 0
}

# Find all bash scripts across all repositories
find_all_scripts() {
    local all_scripts=()
    local repos
    
    debug "Finding all scripts across repositories"
    
    readarray -t repos < <(list_cached_repos)
    
    for repo in "${repos[@]}"; do
        local repo_scripts
        readarray -t repo_scripts < <(find_repo_scripts "$repo")
        
        all_scripts+=("${repo_scripts[@]}")
    done
    
    printf '%s\n' "${all_scripts[@]}"
    
    return 0
}

# Find scripts by name
find_scripts_by_name() {
    local script_name="$1"
    local matching_scripts=()
    local all_scripts
    
    debug "Finding scripts with name: $script_name"
    
    readarray -t all_scripts < <(find_all_scripts)
    
    for script_info in "${all_scripts[@]}"; do
        local name
        local path
        local repo
        
        IFS=':' read -r name path repo <<< "$script_info"
        
        if [[ "$name" == "$script_name" ]]; then
            matching_scripts+=("$script_info")
            debug "Found matching script: $name in $repo ($path)"
        fi
    done
    
    printf '%s\n' "${matching_scripts[@]}"
    
    return 0
}

# Get script count for a repository
get_repo_script_count() {
    local repo_name="$1"
    local scripts
    local count=0
    
    readarray -t scripts < <(find_repo_scripts "$repo_name")
    count=${#scripts[@]}
    
    echo "$count"
}

# Update script count in repository metadata
update_script_count() {
    local repo_name="$1"
    local count
    
    count=$(get_repo_script_count "$repo_name")
    update_repo_metadata "$repo_name" "script_count" "$count"
    update_repo_metadata "$repo_name" "last_script_scan" "$(date -Iseconds)"
    
    debug "Updated script count for $repo_name: $count"
}

# Validate script file
validate_script_file() {
    local script_path="$1"
    
    # Check if file exists
    if [[ ! -f "$script_path" ]]; then
        error "Script file not found: $script_path"
        return $E_NOT_FOUND
    fi
    
    # Check if file is readable
    if [[ ! -r "$script_path" ]]; then
        error "Script file not readable: $script_path"
        return $E_PERMISSION_ERROR
    fi
    
    # Check if file is executable (make it executable if not)
    if [[ ! -x "$script_path" ]]; then
        debug "Making script executable: $script_path"
        chmod +x "$script_path" 2>/dev/null || {
            error "Cannot make script executable: $script_path"
            return $E_PERMISSION_ERROR
        }
    fi
    
    return $E_SUCCESS
}

# Execute a script
execute_script_file() {
    local script_path="$1"
    shift
    local script_args=("$@")
    local script_dir
    local execution_result
    
    script_dir=$(dirname "$script_path")
    
    debug "Executing script: $script_path"
    debug "Script arguments: ${script_args[*]}"
    debug "Working directory: $script_dir"
    
    # Validate script file
    validate_script_file "$script_path" || return $?
    
    if [[ "${QI_DRY_RUN:-false}" == "true" ]]; then
        info "[DRY RUN] Would execute: $script_path ${script_args[*]}"
        return $E_SUCCESS
    fi
    
    # Change to script directory
    pushd "$script_dir" >/dev/null || {
        error "Failed to change to script directory: $script_dir"
        return $E_FILE_ERROR
    }
    
    info "Executing script: $(basename "$script_path")"
    
    # Execute the script
    if bash "$script_path" "${script_args[@]}"; then
        execution_result=$E_SUCCESS
        success "Script executed successfully"
    else
        execution_result=$?
        error "Script execution failed with exit code: $execution_result"
    fi
    
    popd >/dev/null
    
    return $execution_result
}

# Execute script by name
execute_script_by_name() {
    local script_name="$1"
    shift
    local script_args=("$@")
    local matching_scripts
    local script_count
    
    debug "Looking for script: $script_name"
    
    readarray -t matching_scripts < <(find_scripts_by_name "$script_name")
    script_count=${#matching_scripts[@]}
    
    if [[ $script_count -eq 0 ]]; then
        error "No script found with name: $script_name"
        info "Use 'qi list' to see available scripts"
        return $E_NOT_FOUND
    elif [[ $script_count -eq 1 ]]; then
        # Single match - execute directly
        local script_info="${matching_scripts[0]}"
        local name path repo
        local repo_dir script_path
        
        IFS=':' read -r name path repo <<< "$script_info"
        
        repo_dir=$(get_repo_dir "$repo")
        script_path="$repo_dir/$path"
        
        info "Found script '$script_name' in repository '$repo'"
        execute_script_file "$script_path" "${script_args[@]}"
    else
        # Multiple matches - show selection menu
        select_and_execute_script "$script_name" "${matching_scripts[@]}" -- "${script_args[@]}"
    fi
}

# Show script selection menu and execute chosen script
select_and_execute_script() {
    local script_name="$1"
    shift
    
    local matching_scripts=()
    local script_args=()
    local found_separator=false
    
    # Parse arguments to separate scripts from script arguments
    for arg in "$@"; do
        if [[ "$arg" == "--" ]]; then
            found_separator=true
            continue
        fi
        
        if [[ "$found_separator" == "true" ]]; then
            script_args+=("$arg")
        else
            matching_scripts+=("$arg")
        fi
    done
    
    local script_count=${#matching_scripts[@]}
    
    echo "Multiple scripts found with name '$script_name':"
    echo
    
    # Display options
    for i in "${!matching_scripts[@]}"; do
        local script_info="${matching_scripts[$i]}"
        local name path repo url
        
        IFS=':' read -r name path repo <<< "$script_info"
        
        # Get repository URL from metadata
        url=$(read_repo_metadata "$repo" "url" 2>/dev/null || echo "unknown")
        
        format_list_item "$((i + 1))." "$repo ($path)"
        if [[ "$url" != "unknown" ]]; then
            format_list_item "   " "URL: $url"
        fi
    done
    
    echo
    
    # Get user selection
    local selection
    while true; do
        read -p "Select repository [1-$script_count]: " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 && "$selection" -le $script_count ]]; then
            break
        else
            warn "Invalid selection. Please enter a number between 1 and $script_count."
        fi
    done
    
    # Execute selected script
    local selected_script="${matching_scripts[$((selection - 1))]}"
    local name path repo
    local repo_dir script_path
    
    IFS=':' read -r name path repo <<< "$selected_script"
    
    repo_dir=$(get_repo_dir "$repo")
    script_path="$repo_dir/$path"
    
    echo
    info "Executing '$script_name' from repository '$repo'"
    execute_script_file "$script_path" "${script_args[@]}"
}

# List all available scripts
list_all_scripts() {
    local all_scripts
    local script_groups=()
    
    debug "Listing all available scripts"
    
    readarray -t all_scripts < <(find_all_scripts)
    
    if [[ ${#all_scripts[@]} -eq 0 ]]; then
        info "No scripts found in cached repositories"
        info "Use 'qi add <repository-url>' to add repositories with scripts"
        return 0
    fi
    
    # Group scripts by name
    declare -A script_names
    
    for script_info in "${all_scripts[@]}"; do
        local name path repo
        IFS=':' read -r name path repo <<< "$script_info"
        
        if [[ -z "${script_names[$name]}" ]]; then
            script_names[$name]="$repo:$path"
        else
            script_names[$name]="${script_names[$name]}|$repo:$path"
        fi
    done
    
    echo "Available Scripts:"
    echo "=================="
    
    # Sort and display scripts
    for script_name in $(printf '%s\n' "${!script_names[@]}" | sort); do
        local locations="${script_names[$script_name]}"
        
        if [[ "$locations" == *"|"* ]]; then
            # Multiple locations
            echo "  $script_name (multiple locations):"
            
            IFS='|' read -ra location_array <<< "$locations"
            for location in "${location_array[@]}"; do
                IFS=':' read -r repo path <<< "$location"
                format_list_item "    -" "$repo ($path)"
            done
        else
            # Single location
            IFS=':' read -r repo path <<< "$locations"
            format_list_item "  $script_name" "$repo ($path)"
        fi
    done
    
    echo
    echo "Total: $(printf '%s\n' "${!script_names[@]}" | wc -l) unique script(s) found"
}

# List scripts in a specific repository
list_repo_scripts() {
    local repo_name="$1"
    local scripts
    
    debug "Listing scripts in repository: $repo_name"
    
    if ! repo_exists "$repo_name"; then
        error "Repository not found: $repo_name"
        return $E_NOT_FOUND
    fi
    
    readarray -t scripts < <(find_repo_scripts "$repo_name")
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        info "No scripts found in repository: $repo_name"
        return 0
    fi
    
    echo "Scripts in repository '$repo_name':"
    echo "===================================="
    
    for script_info in "${scripts[@]}"; do
        local name path
        IFS=':' read -r name path _ <<< "$script_info"
        format_list_item "  $name" "$path"
    done
    
    echo
    echo "Total: ${#scripts[@]} script(s) found"
}

# Main script execution function (called from main qi script)
execute_script() {
    local script_name="$1"
    shift
    local script_args=("$@")
    
    # Validate script name
    if [[ -z "$script_name" ]]; then
        error "Script name cannot be empty"
        return $E_INVALID_USAGE
    fi
    
    if ! validate_name "$script_name"; then
        error "Invalid script name: $script_name"
        return $E_INVALID_USAGE
    fi
    
    # Execute script by name
    execute_script_by_name "$script_name" "${script_args[@]}"
}

# Main script listing function (called from main qi script)
list_scripts() {
    list_all_scripts
}

# Export functions
export -f find_repo_scripts find_all_scripts find_scripts_by_name
export -f get_repo_script_count update_script_count validate_script_file
export -f execute_script_file execute_script_by_name select_and_execute_script
export -f list_all_scripts list_repo_scripts execute_script list_scripts