#!/bin/bash

# ui.sh - User interface utilities for qi
# Handles user interaction, prompts, and display formatting

# Display repository information
show_repository_info() {
    local repo_name="$1"
    local repo_info
    local status_info
    
    if ! repo_exists "$repo_name"; then
        error "Repository not found: $repo_name"
        return $E_NOT_FOUND
    fi
    
    echo "Repository: $repo_name"
    echo "===================="
    
    # Get repository metadata
    if repo_info=$(get_repo_info "$repo_name"); then
        while IFS='=' read -r key value; do
            case "$key" in
                name)
                    format_table_row "Name:" "$value"
                    ;;
                url)
                    format_table_row "URL:" "$value"
                    ;;
                added)
                    format_table_row "Added:" "$value"
                    ;;
                last_updated)
                    format_table_row "Last Updated:" "$value"
                    ;;
                script_count)
                    format_table_row "Scripts:" "$value"
                    ;;
                branch)
                    format_table_row "Branch:" "$value"
                    ;;
            esac
        done <<< "$repo_info"
    fi
    
    # Get git status
    if status_info=$(get_repo_status "$repo_name"); then
        echo
        echo "Git Status:"
        echo "-----------"
        
        while IFS=':' read -r key value; do
            case "$key" in
                branch)
                    format_table_row "Current Branch:" "$value"
                    ;;
                commit)
                    format_table_row "Last Commit:" "$value"
                    ;;
                status)
                    if [[ "$value" == "clean" ]]; then
                        format_table_row "Working Dir:" "${GREEN}Clean${NC}"
                    else
                        format_table_row "Working Dir:" "${YELLOW}Modified${NC}"
                    fi
                    ;;
                sync)
                    case "$value" in
                        up-to-date)
                            format_table_row "Sync Status:" "${GREEN}Up to date${NC}"
                            ;;
                        behind:*)
                            local count="${value#behind:}"
                            format_table_row "Sync Status:" "${YELLOW}Behind by $count commit(s)${NC}"
                            ;;
                        ahead:*)
                            local count="${value#ahead:}"
                            format_table_row "Sync Status:" "${BLUE}Ahead by $count commit(s)${NC}"
                            ;;
                        diverged:*)
                            local ahead_behind="${value#diverged:}"
                            IFS=':' read -r ahead behind <<< "$ahead_behind"
                            format_table_row "Sync Status:" "${RED}Diverged (ahead: $behind, behind: $ahead)${NC}"
                            ;;
                        *)
                            format_table_row "Sync Status:" "$value"
                            ;;
                    esac
                    ;;
            esac
        done <<< "$status_info"
    fi
    
    echo
}

# List all repositories with status
list_repositories() {
    local repos
    local repo_count
    
    debug "Listing all repositories"
    
    readarray -t repos < <(list_cached_repos)
    repo_count=${#repos[@]}
    
    if [[ $repo_count -eq 0 ]]; then
        info "No repositories found in cache"
        info "Use 'qi add <repository-url>' to add repositories"
        return 0
    fi
    
    echo "Cached Repositories:"
    echo "===================="
    format_table_row "Name" "URL" "Scripts"
    format_table_row "----" "---" "-------"
    
    for repo in "${repos[@]}"; do
        local url
        local script_count
        
        url=$(read_repo_metadata "$repo" "url" 2>/dev/null || echo "unknown")
        script_count=$(read_repo_metadata "$repo" "script_count" 2>/dev/null || echo "?")
        
        format_table_row "$repo" "$url" "$script_count"
    done
    
    echo
    echo "Total: $repo_count repository(ies)"
}

# Show cache status
show_cache_status() {
    local cache_stats
    local repo_count=0
    local total_size="0"
    local last_updated="Never"
    
    debug "Showing cache status"
    
    echo "qi Cache Status:"
    echo "================"
    
    # Get cache statistics
    readarray -t cache_stats < <(get_cache_stats)
    
    for stat in "${cache_stats[@]}"; do
        IFS=':' read -r key value <<< "$stat"
        case "$key" in
            repositories)
                repo_count="$value"
                ;;
            total_size)
                total_size="$value"
                ;;
            last_updated)
                last_updated="$value"
                ;;
        esac
    done
    
    format_table_row "Cache Directory:" "$QI_CACHE_DIR"
    format_table_row "Repositories:" "$repo_count"
    format_table_row "Total Size:" "$total_size"
    format_table_row "Last Updated:" "$last_updated"
    
    echo
    
    # Show repository status if any exist
    if [[ $repo_count -gt 0 ]]; then
        echo "Repository Status:"
        echo "------------------"
        format_table_row "Name" "Status" "Sync"
        format_table_row "----" "------" "----"
        
        local repos
        readarray -t repos < <(list_cached_repos)
        
        for repo in "${repos[@]}"; do
            local status_info
            local working_status="unknown"
            local sync_status="unknown"
            
            if status_info=$(get_repo_status "$repo" 2>/dev/null); then
                while IFS=':' read -r key value; do
                    case "$key" in
                        status)
                            working_status="$value"
                            ;;
                        sync)
                            sync_status="$value"
                            ;;
                    esac
                done <<< "$status_info"
            fi
            
            # Format status with colors
            case "$working_status" in
                clean)
                    working_status="${GREEN}Clean${NC}"
                    ;;
                dirty)
                    working_status="${YELLOW}Modified${NC}"
                    ;;
            esac
            
            case "$sync_status" in
                up-to-date)
                    sync_status="${GREEN}Up to date${NC}"
                    ;;
                behind:*)
                    sync_status="${YELLOW}Behind${NC}"
                    ;;
                ahead:*)
                    sync_status="${BLUE}Ahead${NC}"
                    ;;
                diverged:*)
                    sync_status="${RED}Diverged${NC}"
                    ;;
            esac
            
            format_table_row "$repo" "$working_status" "$sync_status"
        done
        
        echo
    fi
    
    # Show configuration
    echo "Configuration:"
    echo "--------------"
    format_table_row "Default Branch:" "$QI_DEFAULT_BRANCH"
    format_table_row "Auto Update:" "$QI_AUTO_UPDATE"
    format_table_row "Verbose Mode:" "${QI_VERBOSE:-false}"
    
    echo
}

# Confirm action with user
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    local response
    
    if [[ "${QI_FORCE:-false}" == "true" ]]; then
        debug "Force mode enabled, skipping confirmation"
        return 0
    fi
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$message [Y/n]: " response
            response="${response:-y}"
        else
            read -p "$message [y/N]: " response
            response="${response:-n}"
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                warn "Please answer yes or no."
                ;;
        esac
    done
}

# Show progress indicator
show_progress() {
    local message="$1"
    local pid="$2"
    local delay=0.1
    local spinstr='|/-\'
    
    if [[ "${QI_VERBOSE:-false}" == "true" ]]; then
        # Don't show spinner in verbose mode
        return 0
    fi
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    
    printf "    \r"
}

# Display update results
show_update_results() {
    local results=("$@")
    local success_count=0
    local error_count=0
    local skip_count=0
    
    echo "Update Results:"
    echo "==============="
    
    for result in "${results[@]}"; do
        IFS=':' read -r repo status message <<< "$result"
        
        case "$status" in
            success)
                format_list_item "${GREEN}✓${NC}" "$repo: $message"
                ((success_count++))
                ;;
            error)
                format_list_item "${RED}✗${NC}" "$repo: $message"
                ((error_count++))
                ;;
            skip)
                format_list_item "${YELLOW}⚠${NC}" "$repo: $message"
                ((skip_count++))
                ;;
            *)
                format_list_item "-" "$repo: $message"
                ;;
        esac
    done
    
    echo
    echo "Summary: $success_count updated, $error_count errors, $skip_count skipped"
}

# Display help for specific command
show_command_help() {
    local command="$1"
    
    case "$command" in
        add)
            cat << EOF
qi add - Add a git repository to the cache

USAGE:
    qi add <repository-url> [name]

ARGUMENTS:
    <repository-url>    Git repository URL (HTTPS or SSH)
    [name]              Optional custom name for the repository

EXAMPLES:
    qi add https://github.com/user/scripts.git
    qi add git@github.com:user/tools.git devtools
    qi add https://gitlab.com/group/project.git

The repository will be cloned to the cache directory and its scripts
will become available for execution with the 'qi <script-name>' command.
EOF
            ;;
        remove)
            cat << EOF
qi remove - Remove a repository from the cache

USAGE:
    qi remove <repository-name>

ARGUMENTS:
    <repository-name>   Name of the repository to remove

EXAMPLES:
    qi remove scripts
    qi remove devtools

This will completely remove the repository and all its scripts from
the cache. Use with caution as this action cannot be undone.
EOF
            ;;
        update)
            cat << EOF
qi update - Update cached repositories

USAGE:
    qi update [repository-name]

ARGUMENTS:
    [repository-name]   Optional name of specific repository to update
                       If not provided, all repositories are updated

OPTIONS:
    --force            Force update even with local changes (will stash them)
    --dry-run          Show what would be updated without doing it

EXAMPLES:
    qi update                    # Update all repositories
    qi update scripts            # Update only 'scripts' repository
    qi update --force scripts    # Force update with local changes
EOF
            ;;
        list)
            cat << EOF
qi list - List available scripts

USAGE:
    qi list

Shows all available scripts from all cached repositories. Scripts with
the same name in multiple repositories will be grouped together.

Use 'qi list-repos' to see available repositories.
EOF
            ;;
        *)
            error "No help available for command: $command"
            return 1
            ;;
    esac
}

# Export functions
export -f show_repository_info list_repositories show_cache_status
export -f confirm_action show_progress show_update_results show_command_help