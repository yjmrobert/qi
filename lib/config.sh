#!/bin/bash

# config.sh - Configuration management for qi
# Handles environment variables, config files, and default settings

# Configuration variables with defaults
declare -A QI_CONFIG
QI_CONFIG[cache_dir]="${QI_CACHE_DIR:-$HOME/.qi/cache}"
QI_CONFIG[config_file]="${QI_CONFIG_FILE:-$HOME/.qi/config}"
QI_CONFIG[default_branch]="${QI_DEFAULT_BRANCH:-main}"
QI_CONFIG[auto_update]="${QI_AUTO_UPDATE:-false}"
QI_CONFIG[verbose]="${QI_VERBOSE:-false}"
QI_CONFIG[max_cache_size]="${QI_MAX_CACHE_SIZE:-1G}"

# Load configuration from file
load_config() {
    local config_file="${1:-${QI_CONFIG[config_file]}}"
    
    if [[ ! -f "$config_file" ]]; then
        log "DEBUG" "Config file not found: $config_file"
        return 0
    fi
    
    log "DEBUG" "Loading configuration from: $config_file"
    
    # Read config file line by line
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Remove quotes from value if present
        if [[ "$value" =~ ^\".*\"$ ]] || [[ "$value" =~ ^\'.*\'$ ]]; then
            value="${value:1:-1}"
        fi
        
        # Set configuration value
        case "$key" in
            cache_dir|config_file|default_branch|auto_update|verbose|max_cache_size)
                QI_CONFIG[$key]="$value"
                log "DEBUG" "Config loaded: $key=$value"
                ;;
            *)
                log "WARN" "Unknown configuration key: $key"
                ;;
        esac
    done < "$config_file"
}

# Save configuration to file
save_config() {
    local config_file="${1:-${QI_CONFIG[config_file]}}"
    local config_dir
    config_dir="$(dirname "$config_file")"
    
    # Create config directory if it doesn't exist
    if [[ ! -d "$config_dir" ]]; then
        log "INFO" "Creating config directory: $config_dir"
        mkdir -p "$config_dir"
    fi
    
    log "INFO" "Saving configuration to: $config_file"
    
    # Write configuration file
    cat > "$config_file" << EOF
# qi configuration file
# Generated on $(date)

# Cache directory for repositories
cache_dir=${QI_CONFIG[cache_dir]}

# Default git branch to use
default_branch=${QI_CONFIG[default_branch]}

# Auto-update repositories when executing scripts
auto_update=${QI_CONFIG[auto_update]}

# Enable verbose output by default
verbose=${QI_CONFIG[verbose]}

# Maximum cache size (e.g., 1G, 500M)
max_cache_size=${QI_CONFIG[max_cache_size]}
EOF
    
    log "INFO" "Configuration saved successfully"
}

# Get configuration value
get_config() {
    local key="$1"
    local default_value="${2:-}"
    
    if [[ -n "${QI_CONFIG[$key]:-}" ]]; then
        echo "${QI_CONFIG[$key]}"
    else
        echo "$default_value"
    fi
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    local save="${3:-false}"
    
    QI_CONFIG[$key]="$value"
    log "DEBUG" "Config set: $key=$value"
    
    if [[ "$save" == "true" ]]; then
        save_config
    fi
}

# Validate configuration
validate_config() {
    local errors=0
    
    # Validate cache directory
    local cache_dir="${QI_CONFIG[cache_dir]}"
    if [[ -n "$cache_dir" ]]; then
        # Create parent directory if it doesn't exist
        local parent_dir
        parent_dir="$(dirname "$cache_dir")"
        if [[ ! -d "$parent_dir" ]]; then
            log "INFO" "Creating cache parent directory: $parent_dir"
            if ! mkdir -p "$parent_dir"; then
                log "ERROR" "Failed to create cache parent directory: $parent_dir"
                ((errors++))
            fi
        elif [[ ! -w "$parent_dir" ]]; then
            log "ERROR" "Cache directory parent is not writable: $parent_dir"
            ((errors++))
        fi
    else
        log "ERROR" "Cache directory not configured"
        ((errors++))
    fi
    
    # Validate default branch
    local default_branch="${QI_CONFIG[default_branch]}"
    if [[ -z "$default_branch" ]]; then
        log "WARN" "Default branch not configured, using 'main'"
        QI_CONFIG[default_branch]="main"
    fi
    
    # Validate boolean values
    for key in auto_update verbose; do
        local value="${QI_CONFIG[$key]}"
        if [[ -n "$value" && "$value" != "true" && "$value" != "false" ]]; then
            log "WARN" "Invalid boolean value for $key: $value, using 'false'"
            QI_CONFIG[$key]="false"
        fi
    done
    
    # Validate cache size
    local max_cache_size="${QI_CONFIG[max_cache_size]}"
    if [[ -n "$max_cache_size" && ! "$max_cache_size" =~ ^[0-9]+[KMGT]?$ ]]; then
        log "WARN" "Invalid cache size format: $max_cache_size, using '1G'"
        QI_CONFIG[max_cache_size]="1G"
    fi
    
    return $errors
}

# Initialize configuration system
init_config() {
    log "DEBUG" "Initializing configuration system"
    
    # Load configuration from file if it exists
    load_config
    
    # Override with environment variables if set
    [[ -n "${QI_CACHE_DIR:-}" ]] && QI_CONFIG[cache_dir]="$QI_CACHE_DIR"
    [[ -n "${QI_DEFAULT_BRANCH:-}" ]] && QI_CONFIG[default_branch]="$QI_DEFAULT_BRANCH"
    [[ -n "${QI_AUTO_UPDATE:-}" ]] && QI_CONFIG[auto_update]="$QI_AUTO_UPDATE"
    [[ -n "${QI_VERBOSE:-}" ]] && QI_CONFIG[verbose]="$QI_VERBOSE"
    [[ -n "${QI_MAX_CACHE_SIZE:-}" ]] && QI_CONFIG[max_cache_size]="$QI_MAX_CACHE_SIZE"
    
    # Apply verbose setting to global variable
    if [[ "${QI_CONFIG[verbose]}" == "true" ]]; then
        VERBOSE=true
    fi
    
    # Validate configuration
    if ! validate_config; then
        log "ERROR" "Configuration validation failed"
        return 1
    fi
    
    # Update global variables
    CACHE_DIR="${QI_CONFIG[cache_dir]}"
    CONFIG_FILE="${QI_CONFIG[config_file]}"
    
    log "DEBUG" "Configuration initialized successfully"
    log "DEBUG" "Cache directory: $CACHE_DIR"
    log "DEBUG" "Config file: $CONFIG_FILE"
    log "DEBUG" "Default branch: ${QI_CONFIG[default_branch]}"
}

# Show current configuration
show_config() {
    echo "qi Configuration:"
    echo "=================="
    echo "Cache directory:    ${QI_CONFIG[cache_dir]}"
    echo "Config file:        ${QI_CONFIG[config_file]}"
    echo "Default branch:     ${QI_CONFIG[default_branch]}"
    echo "Auto update:        ${QI_CONFIG[auto_update]}"
    echo "Verbose:            ${QI_CONFIG[verbose]}"
    echo "Max cache size:     ${QI_CONFIG[max_cache_size]}"
    echo ""
    
    # Show environment variable overrides
    echo "Environment Variables:"
    echo "====================="
    echo "QI_CACHE_DIR:       ${QI_CACHE_DIR:-<not set>}"
    echo "QI_DEFAULT_BRANCH:  ${QI_DEFAULT_BRANCH:-<not set>}"
    echo "QI_AUTO_UPDATE:     ${QI_AUTO_UPDATE:-<not set>}"
    echo "QI_VERBOSE:         ${QI_VERBOSE:-<not set>}"
    echo "QI_MAX_CACHE_SIZE:  ${QI_MAX_CACHE_SIZE:-<not set>}"
}

# Create default configuration file
create_default_config() {
    local config_file="${1:-${QI_CONFIG[config_file]}}"
    
    if [[ -f "$config_file" ]]; then
        log "INFO" "Configuration file already exists: $config_file"
        return 0
    fi
    
    log "INFO" "Creating default configuration file: $config_file"
    save_config "$config_file"
}

# Convert size string to bytes (for cache size validation)
size_to_bytes() {
    local size="$1"
    local number="${size%[KMGT]}"
    local unit="${size: -1}"
    
    case "$unit" in
        K|k) echo $((number * 1024)) ;;
        M|m) echo $((number * 1024 * 1024)) ;;
        G|g) echo $((number * 1024 * 1024 * 1024)) ;;
        T|t) echo $((number * 1024 * 1024 * 1024 * 1024)) ;;
        *) echo "$number" ;;
    esac
}