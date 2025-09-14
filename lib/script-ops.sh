#!/bin/bash

# script-ops.sh - Script discovery and execution for qi
# Handles finding, indexing, and executing bash scripts from cached repositories

# Script index file in cache metadata
SCRIPT_INDEX_FILE=".qi-script-index"

# Find all bash scripts in cached repositories
discover_scripts() {
    local cache_dir="${1:-$CACHE_DIR}"
    local force_rebuild="${2:-false}"

    log "DEBUG" "Discovering scripts in cache: $cache_dir"

    # Check if cache directory exists
    if [[ ! -d "$cache_dir" ]]; then
        log "WARN" "Cache directory does not exist: $cache_dir"
        return 1
    fi

    local script_index_file="$cache_dir/.qi-meta/$SCRIPT_INDEX_FILE"

    # Check if index exists and is recent (unless force rebuild)
    if [[ "$force_rebuild" != "true" && -f "$script_index_file" ]]; then
        # Check if index is newer than 5 minutes
        local index_age
        index_age=$(($(date +%s) - $(stat -c %Y "$script_index_file" 2>/dev/null || echo 0)))
        if [[ $index_age -lt 300 ]]; then
            log "DEBUG" "Using cached script index (age: ${index_age}s)"
            return 0
        fi
    fi

    log "DEBUG" "Building script index..."

    # Create temporary file for atomic update
    local temp_index="$script_index_file.tmp"

    # Ensure metadata directory exists
    mkdir -p "$(dirname "$script_index_file")"

    # Clear temporary index
    true >"$temp_index"

    # Find all repositories
    local repos
    mapfile -t repos < <(list_cached_repos "$cache_dir")

    local total_scripts=0

    for repo_name in "${repos[@]}"; do
        local repo_dir
        repo_dir="$(get_repo_dir "$repo_name" "$cache_dir")"

        log "DEBUG" "Scanning repository: $repo_name"

        # Find all .bash files in the repository, but only in /qi directory from root
        local qi_dir="$repo_dir/qi"
        if [[ -d "$qi_dir" ]]; then
            while IFS= read -r -d '' script_path; do
                # Get relative path from repository root
                local rel_path="${script_path#"$repo_dir"/}"

                # Extract script name (without .bash extension)
                local script_name
                script_name="$(basename "$rel_path" .bash)"

                # Skip if script name is empty or invalid
                if [[ -z "$script_name" || "$script_name" == "." ]]; then
                    continue
                fi

                # Add to index: script_name|repo_name|relative_path|full_path
                echo "$script_name|$repo_name|$rel_path|$script_path" >>"$temp_index"
                ((total_scripts++))

                log "DEBUG" "Found script: $script_name in $repo_name ($rel_path)"

            done < <(find "$qi_dir" -name "*.bash" -type f -print0 2>/dev/null)
        else
            log "DEBUG" "No /qi directory found in repository: $repo_name"
        fi
    done

    # Sort index by script name for easier lookup
    sort "$temp_index" >"$temp_index.sorted"
    mv "$temp_index.sorted" "$temp_index"

    # Atomically replace the index file
    mv "$temp_index" "$script_index_file"

    log "DEBUG" "Script index built: $total_scripts scripts found"

    return 0
}

# Get script index file path
get_script_index_file() {
    local cache_dir="${1:-$CACHE_DIR}"
    echo "$cache_dir/.qi-meta/$SCRIPT_INDEX_FILE"
}

# Find scripts by name
find_scripts_by_name() {
    local script_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local script_index_file
    script_index_file="$(get_script_index_file "$cache_dir")"

    # Ensure script index is up to date
    if ! discover_scripts "$cache_dir"; then
        return 1
    fi

    # Check if index file exists
    if [[ ! -f "$script_index_file" ]]; then
        log "DEBUG" "Script index not found: $script_index_file"
        return 1
    fi

    # Search for exact script name matches
    grep "^$script_name|" "$script_index_file" 2>/dev/null
}

# List all available scripts
list_all_scripts() {
    local cache_dir="${1:-$CACHE_DIR}"
    local format="${2:-name}" # name, full, repo

    local script_index_file
    script_index_file="$(get_script_index_file "$cache_dir")"

    # Ensure script index is up to date
    if ! discover_scripts "$cache_dir"; then
        return 1
    fi

    # Check if index file exists
    if [[ ! -f "$script_index_file" ]]; then
        return 0
    fi

    case "$format" in
        "name")
            # Just script names, unique
            cut -d'|' -f1 "$script_index_file" | sort -u
            ;;
        "full")
            # Full information: script_name repo_name path
            while IFS='|' read -r script_name repo_name rel_path full_path; do
                echo "$script_name ($repo_name: $rel_path)"
            done <"$script_index_file"
            ;;
        "repo")
            # Grouped by repository
            local current_repo=""
            while IFS='|' read -r script_name repo_name rel_path full_path; do
                if [[ "$repo_name" != "$current_repo" ]]; then
                    echo ""
                    echo "$repo_name:"
                    current_repo="$repo_name"
                fi
                echo "  $script_name ($rel_path)"
            done < <(sort -t'|' -k2,2 -k1,1 "$script_index_file")
            ;;
        *)
            log "ERROR" "Invalid format: $format"
            return 1
            ;;
    esac
}

# Get script count
get_script_count() {
    local cache_dir="${1:-$CACHE_DIR}"

    local script_index_file
    script_index_file="$(get_script_index_file "$cache_dir")"

    if [[ -f "$script_index_file" ]]; then
        wc -l <"$script_index_file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get unique script count (scripts with unique names)
get_unique_script_count() {
    local cache_dir="${1:-$CACHE_DIR}"

    local script_index_file
    script_index_file="$(get_script_index_file "$cache_dir")"

    if [[ -f "$script_index_file" ]]; then
        cut -d'|' -f1 "$script_index_file" | sort -u | wc -l 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Check if script exists
script_exists() {
    local script_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local matches
    matches=$(find_scripts_by_name "$script_name" "$cache_dir")

    [[ -n "$matches" ]]
}

# Get script conflicts (multiple scripts with same name)
get_script_conflicts() {
    local script_name="$1"
    local cache_dir="${2:-$CACHE_DIR}"

    local matches
    matches=$(find_scripts_by_name "$script_name" "$cache_dir")

    if [[ -z "$matches" ]]; then
        return 1
    fi

    local count
    count=$(echo "$matches" | wc -l)

    if [[ $count -gt 1 ]]; then
        echo "$matches"
        return 0
    else
        return 1
    fi
}

# Execute script by name
execute_script() {
    local script_name="$1"
    shift
    local script_args=("$@")
    local cache_dir="${CACHE_DIR}"

    log "DEBUG" "Executing script: $script_name"

    # Find scripts with the given name
    local matches
    matches=$(find_scripts_by_name "$script_name" "$cache_dir")

    if [[ -z "$matches" ]]; then
        log "ERROR" "Script not found: $script_name"
        log "INFO" "Use 'qi list' to see available scripts"
        return 1
    fi

    # Count matches
    local match_count
    match_count=$(echo "$matches" | wc -l)

    local selected_script=""

    if [[ $match_count -eq 1 ]]; then
        # Single match - use it directly
        selected_script="$matches"
        log "DEBUG" "Single script match found"
    else
        # Multiple matches - let user choose
        log "INFO" "Multiple scripts found with name '$script_name':"

        local options=()
        local i=1

        while IFS='|' read -r sname repo_name rel_path full_path; do
            echo "$i. $repo_name ($rel_path)"
            options+=("$sname|$repo_name|$rel_path|$full_path")
            ((i++))
        done <<<"$matches"

        echo ""

        # In non-interactive mode, use first match
        if [[ ! -t 0 ]]; then
            log "WARN" "Non-interactive mode: using first match"
            selected_script=$(echo "$matches" | head -n1)
        else
            # Interactive selection
            while true; do
                read -rp "Select repository [1-$match_count]: " choice

                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le $match_count ]]; then
                    selected_script="${options[$((choice - 1))]}"
                    break
                else
                    echo "Please enter a number between 1 and $match_count"
                fi
            done
        fi
    fi

    # Parse selected script information
    local sname repo_name rel_path full_path
    IFS='|' read -r sname repo_name rel_path full_path <<<"$selected_script"

    log "INFO" "Executing $sname from $repo_name repository..."
    log "DEBUG" "Script path: $full_path"

    # Check if script file exists
    if [[ ! -f "$full_path" ]]; then
        log "ERROR" "Script file not found: $full_path"
        log "INFO" "Try updating the repository: qi update $repo_name"
        return 1
    fi

    # Check if script is executable
    if [[ ! -x "$full_path" ]]; then
        log "WARN" "Script is not executable, making it executable: $full_path"
        chmod +x "$full_path" || {
            log "ERROR" "Failed to make script executable: $full_path"
            return 1
        }
    fi

    # Dry run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would execute: $full_path ${script_args[*]}"
        log "INFO" "Script content preview:"
        echo "----------------------------------------"
        head -20 "$full_path" | nl -ba
        if [[ $(wc -l <"$full_path") -gt 20 ]]; then
            echo "... (truncated, $(wc -l <"$full_path") total lines)"
        fi
        echo "----------------------------------------"
        return 0
    fi

    # Change to script directory for execution
    local script_dir
    script_dir="$(dirname "$full_path")"
    local original_dir="$PWD"

    cd "$script_dir" || {
        log "ERROR" "Cannot change to script directory: $script_dir"
        return 1
    }

    # Execute script
    local start_time
    start_time=$(date +%s)

    if [[ "$BACKGROUND" == "true" ]]; then
        log "INFO" "Running script in background..."
        nohup bash "$full_path" "${script_args[@]}" >"/tmp/qi-$script_name-$$.log" 2>&1 &
        local bg_pid=$!
        echo "Background process started with PID: $bg_pid"
        echo "Log file: /tmp/qi-$script_name-$$.log"
        cd "$original_dir" || return
        return 0
    else
        log "DEBUG" "Executing: bash $full_path ${script_args[*]}"

        # Execute script with arguments
        bash "$full_path" "${script_args[@]}"
        local exit_code=$?

        local end_time
        end_time=$(date +%s)
        local duration
        duration=$(time_diff "$start_time" "$end_time")

        cd "$original_dir" || return

        if [[ $exit_code -eq 0 ]]; then
            log "DEBUG" "Script completed successfully in $duration"
        else
            log "ERROR" "Script failed with exit code $exit_code (duration: $duration)"
        fi

        return $exit_code
    fi
}

# Rebuild script index
rebuild_script_index() {
    local cache_dir="${1:-$CACHE_DIR}"

    log "INFO" "Rebuilding script index..."
    discover_scripts "$cache_dir" true

    local script_count
    script_count=$(get_script_count "$cache_dir")

    log "INFO" "Script index rebuilt: $script_count scripts indexed"
}

# Validate script file
validate_script_file() {
    local script_path="$1"

    # Check if file exists
    if [[ ! -f "$script_path" ]]; then
        return 1
    fi

    # Check if it's a bash script (has shebang or .bash extension)
    if [[ "$script_path" =~ \.bash$ ]]; then
        return 0
    fi

    # Check for bash shebang
    local first_line
    first_line=$(head -n1 "$script_path" 2>/dev/null)
    if [[ "$first_line" =~ ^#!.*bash ]]; then
        return 0
    fi

    return 1
}

# Get script metadata
get_script_metadata() {
    local script_path="$1"

    if [[ ! -f "$script_path" ]]; then
        return 1
    fi

    local size permissions modified
    size=$(stat -c%s "$script_path" 2>/dev/null || echo "unknown")
    permissions=$(stat -c%A "$script_path" 2>/dev/null || echo "unknown")
    modified=$(stat -c%Y "$script_path" 2>/dev/null || echo "unknown")

    if [[ "$modified" != "unknown" ]]; then
        modified=$(date -d "@$modified" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$modified")
    fi

    echo "Size: $(format_size "$size")"
    echo "Permissions: $permissions"
    echo "Modified: $modified"

    # Try to extract description from script comments
    local description
    description=$(grep -E "^#.*[Dd]escription:" "$script_path" | head -n1 | sed 's/^#.*[Dd]escription:[[:space:]]*//' 2>/dev/null)
    if [[ -n "$description" ]]; then
        echo "Description: $description"
    fi

    # Check for usage information
    if grep -q "usage\|Usage\|USAGE" "$script_path" 2>/dev/null; then
        echo "Has usage info: yes"
    else
        echo "Has usage info: no"
    fi
}
