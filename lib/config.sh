#!/bin/bash

# config.sh - Configuration management for qi
# Handles environment variables, configuration files, and default settings

# Default configuration values
readonly DEFAULT_CACHE_DIR="$HOME/.qi/cache"
readonly DEFAULT_CONFIG_DIR="$HOME/.qi"
readonly DEFAULT_CONFIG_FILE="$HOME/.qi/config"
readonly DEFAULT_BRANCH="main"
readonly DEFAULT_AUTO_UPDATE="false"
readonly DEFAULT_VERBOSE="false"

# Global configuration variables
declare -g QI_CACHE_DIR
declare -g QI_CONFIG_DIR
declare -g QI_CONFIG_FILE
declare -g QI_DEFAULT_BRANCH
declare -g QI_AUTO_UPDATE

# Initialize configuration system
init_config() {
    debug "Initializing configuration system"
    
    # Set configuration directory and file paths
    QI_CONFIG_DIR="${QI_CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"
    QI_CONFIG_FILE="${QI_CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
    
    # Ensure configuration directory exists
    ensure_directory "$QI_CONFIG_DIR" || {
        error "Failed to create configuration directory: $QI_CONFIG_DIR"
        return $E_FILE_ERROR
    }
    
    # Load configuration from various sources (order matters - later sources override earlier ones)
    load_default_config
    load_config_file
    load_environment_config
    
    # Validate configuration
    validate_config || {
        error "Configuration validation failed"
        return $E_GENERAL_ERROR
    }
    
    debug "Configuration initialized successfully"
    debug "Cache directory: $QI_CACHE_DIR"
    debug "Default branch: $QI_DEFAULT_BRANCH"
    
    return $E_SUCCESS
}

# Load default configuration values
load_default_config() {
    debug "Loading default configuration"
    
    QI_CACHE_DIR="$DEFAULT_CACHE_DIR"
    QI_DEFAULT_BRANCH="$DEFAULT_BRANCH"
    QI_AUTO_UPDATE="$DEFAULT_AUTO_UPDATE"
    
    # Set verbose from global variable if available
    if [[ "${QI_VERBOSE:-}" == "true" ]]; then
        QI_VERBOSE="true"
    else
        QI_VERBOSE="$DEFAULT_VERBOSE"
    fi
}

# Load configuration from config file
load_config_file() {
    if [[ ! -f "$QI_CONFIG_FILE" ]]; then
        debug "Configuration file not found: $QI_CONFIG_FILE"
        return 0
    fi
    
    debug "Loading configuration from: $QI_CONFIG_FILE"
    
    local line_num=0
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        line=$(trim "$line")
        if [[ -z "$line" ]] || [[ "$line" =~ ^[#\;] ]]; then
            continue
        fi
        
        # Parse key=value pairs
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            key=$(trim "$key")
            value=$(trim "$value")
            
            # Remove quotes from value if present
            if [[ "$value" =~ ^[\"\'](.*)[\"\']+$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            
            case "$key" in
                cache_dir)
                    QI_CACHE_DIR="$value"
                    debug "Config: cache_dir = $value"
                    ;;
                default_branch)
                    QI_DEFAULT_BRANCH="$value"
                    debug "Config: default_branch = $value"
                    ;;
                auto_update)
                    QI_AUTO_UPDATE="$value"
                    debug "Config: auto_update = $value"
                    ;;
                verbose)
                    if [[ "${QI_VERBOSE:-false}" != "true" ]]; then
                        QI_VERBOSE="$value"
                        debug "Config: verbose = $value"
                    fi
                    ;;
                *)
                    warn "Unknown configuration key '$key' at line $line_num in $QI_CONFIG_FILE"
                    ;;
            esac
        else
            warn "Invalid configuration line $line_num in $QI_CONFIG_FILE: $line"
        fi
    done < "$QI_CONFIG_FILE"
}

# Load configuration from environment variables
load_environment_config() {
    debug "Loading environment configuration"
    
    if [[ -n "${QI_CACHE_DIR:-}" ]]; then
        debug "Environment: QI_CACHE_DIR = $QI_CACHE_DIR"
    fi
    
    if [[ -n "${QI_DEFAULT_BRANCH:-}" ]]; then
        QI_DEFAULT_BRANCH="$QI_DEFAULT_BRANCH"
        debug "Environment: QI_DEFAULT_BRANCH = $QI_DEFAULT_BRANCH"
    fi
    
    if [[ -n "${QI_AUTO_UPDATE:-}" ]]; then
        QI_AUTO_UPDATE="$QI_AUTO_UPDATE"
        debug "Environment: QI_AUTO_UPDATE = $QI_AUTO_UPDATE"
    fi
}

# Validate configuration values
validate_config() {
    debug "Validating configuration"
    
    # Expand tilde in cache directory
    QI_CACHE_DIR="${QI_CACHE_DIR/#\~/$HOME}"
    
    # Validate cache directory
    if [[ -z "$QI_CACHE_DIR" ]]; then
        error "Cache directory cannot be empty"
        return 1
    fi
    
    # Validate default branch
    if [[ -z "$QI_DEFAULT_BRANCH" ]]; then
        error "Default branch cannot be empty"
        return 1
    fi
    
    # Validate boolean values
    case "$QI_AUTO_UPDATE" in
        true|false|yes|no|1|0)
            ;;
        *)
            error "Invalid value for auto_update: $QI_AUTO_UPDATE (must be true/false)"
            return 1
            ;;
    esac
    
    case "$QI_VERBOSE" in
        true|false|yes|no|1|0)
            ;;
        *)
            error "Invalid value for verbose: $QI_VERBOSE (must be true/false)"
            return 1
            ;;
    esac
    
    return 0
}

# Create default configuration file
create_default_config() {
    debug "Creating default configuration file: $QI_CONFIG_FILE"
    
    cat > "$QI_CONFIG_FILE" << EOF
# qi configuration file
# This file contains default settings for the qi tool
# Lines starting with # are comments and are ignored

# Cache directory for storing repositories
# Default: ~/.qi/cache
cache_dir=$DEFAULT_CACHE_DIR

# Default branch to checkout when cloning repositories
# Default: main
default_branch=$DEFAULT_BRANCH

# Automatically update repositories when executing scripts
# Default: false
auto_update=$DEFAULT_AUTO_UPDATE

# Enable verbose output by default
# Default: false
verbose=$DEFAULT_VERBOSE
EOF
    
    success "Created default configuration file: $QI_CONFIG_FILE"
}

# Get configuration value
get_config() {
    local key="$1"
    
    case "$key" in
        cache_dir)
            echo "$QI_CACHE_DIR"
            ;;
        default_branch)
            echo "$QI_DEFAULT_BRANCH"
            ;;
        auto_update)
            echo "$QI_AUTO_UPDATE"
            ;;
        verbose)
            echo "$QI_VERBOSE"
            ;;
        config_dir)
            echo "$QI_CONFIG_DIR"
            ;;
        config_file)
            echo "$QI_CONFIG_FILE"
            ;;
        *)
            error "Unknown configuration key: $key"
            return 1
            ;;
    esac
}

# Set configuration value (runtime only, doesn't persist)
set_config() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        cache_dir)
            QI_CACHE_DIR="$value"
            ;;
        default_branch)
            QI_DEFAULT_BRANCH="$value"
            ;;
        auto_update)
            QI_AUTO_UPDATE="$value"
            ;;
        verbose)
            QI_VERBOSE="$value"
            ;;
        *)
            error "Unknown configuration key: $key"
            return 1
            ;;
    esac
    
    debug "Configuration updated: $key = $value"
}

# Show current configuration
show_config() {
    echo "qi Configuration:"
    echo "=================="
    format_table_row "Cache Directory:" "$QI_CACHE_DIR"
    format_table_row "Config Directory:" "$QI_CONFIG_DIR"
    format_table_row "Config File:" "$QI_CONFIG_FILE"
    format_table_row "Default Branch:" "$QI_DEFAULT_BRANCH"
    format_table_row "Auto Update:" "$QI_AUTO_UPDATE"
    format_table_row "Verbose:" "$QI_VERBOSE"
    echo
    
    if [[ -f "$QI_CONFIG_FILE" ]]; then
        echo "Configuration file exists: $QI_CONFIG_FILE"
    else
        echo "Configuration file not found: $QI_CONFIG_FILE"
        echo "Run 'qi config --init' to create a default configuration file."
    fi
}

# Export configuration variables and functions
export QI_CACHE_DIR QI_CONFIG_DIR QI_CONFIG_FILE QI_DEFAULT_BRANCH QI_AUTO_UPDATE
export -f init_config load_default_config load_config_file load_environment_config
export -f validate_config create_default_config get_config set_config show_config