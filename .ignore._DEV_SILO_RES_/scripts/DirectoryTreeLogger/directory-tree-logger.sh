#!/usr/bin/env bash

# ==============================================================================
# Directory Tree Logger
# Version: 1.0.0-2-beta
# Author: AI-Human Paired Programming Initiative
# License: MIT
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Constants and Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="../../config/project.config.json"
readonly VERSION="1.0.0-2-beta"

# ANSI Color Codes
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[0;36m"    # Cyan
readonly COLOR_SUCCESS="\033[0;32m"  # Green
readonly COLOR_WARNING="\033[0;33m"  # Yellow
readonly COLOR_ERROR="\033[0;31m"    # Red

# Default Configuration
declare -A DEFAULT_CONFIG=(
    ["logging_mode"]="CLEAN"
    ["include_file_info"]="true"
    ["max_file_size"]="100"
    ["output_format"]="text"
    ["max_depth"]="-1"
    ["show_progress"]="true"
)

# Logging Functions
log_message() {
    local message="$1"
    local type="${2:-INFO}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    case "${type^^}" in
        "INFO")     local color="$COLOR_INFO" ;;
        "SUCCESS")  local color="$COLOR_SUCCESS" ;;
        "WARNING")  local color="$COLOR_WARNING" ;;
        "ERROR")    local color="$COLOR_ERROR" ;;
        *)          local color="$COLOR_RESET" ;;
    esac
    
    printf "%b[%s][%s] %s%b\n" "$color" "$timestamp" "$type" "$message" "$COLOR_RESET"
}

# Configuration Management
load_configuration() {
    local config_path="$SCRIPT_DIR/$CONFIG_FILE"
    
    if [[ -f "$config_path" ]] && command -v jq >/dev/null 2>&1; then
        if ! jq empty "$config_path" >/dev/null 2>&1; then
            log_message "Error parsing configuration file" "ERROR"
            return 1
        fi
        log_message "Configuration loaded successfully" "SUCCESS"
        return 0
    fi
    
    log_message "Using default configuration" "WARNING"
    return 1
}

# Validation Functions
validate_path() {
    local path="$1"
    
    if [[ ! -e "$path" ]]; then
        log_message "Path not found: $path" "ERROR"
        return 1
    fi
    
    if [[ ! -d "$path" ]]; then
        log_message "Path is not a directory: $path" "ERROR"
        return 1
    fi
    
    return 0
}

check_dependencies() {
    local missing_deps=()
    
    # Required commands
    local deps=("stat" "date" "printf" "find")
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Optional but recommended
    if ! command -v jq >/dev/null 2>&1; then
        log_message "jq not found. JSON support will be limited." "WARNING"
    fi
    
    if ((${#missing_deps[@]} > 0)); then
        log_message "Missing required dependencies: ${missing_deps[*]}" "ERROR"
        return 1
    fi
    
    return 0
}

# File System Functions
get_file_info() {
    local path="$1"
    local include_info="$2"
    local size_mb
    local created
    local modified
    
    if [[ "$include_info" == "true" ]]; then
        # Handle different stat formats for GNU/BSD
        if stat --version 2>&1 | grep -q GNU; then
            # GNU stat
            size_mb=$(bc <<< "scale=2; $(stat -c%s "$path") / 1048576")
            created=$(stat -c%w "$path" 2>/dev/null || stat -c%W "$path")
            modified=$(stat -c%y "$path")
        else
            # BSD stat (macOS)
            size_mb=$(bc <<< "scale=2; $(stat -f%z "$path") / 1048576")
            created=$(stat -f%SB "$path")
            modified=$(stat -f%Sm "$path")
        fi
        printf " | Size: %.2fMB | Created: %s | Modified: %s" "$size_mb" "$created" "$modified"
    fi
}

generate_tree() {
    local path="$1"
    local depth="${2:-0}"
    local mode="${3:-CLEAN}"
    local include_info="${4:-false}"
    local max_depth="${5:--1}"
    local exclude_pattern="${6:-}"
    local include_pattern="${7:-}"
    local max_size="${8:-0}"
    
    # Check depth limit
    if [[ $max_depth -ne -1 ]] && [[ $depth -ge $max_depth ]]; then
        return
    fi
    
    local indent
    indent=$(printf "%*s" "$((depth * 4))" "")
    
    # Process current directory
    if [[ $depth -eq 0 ]]; then
        printf "%s|-- [Directory] %s\n" "$indent" "$(basename "$path")"
    fi
    
    # Find command construction
    local find_cmd="find \"$path\" -mindepth 1 -maxdepth 1"
    
    # Apply patterns
    [[ -n "$exclude_pattern" ]] && find_cmd+=" ! -name \"$exclude_pattern\""
    [[ -n "$include_pattern" ]] && find_cmd+=" -name \"$include_pattern\""
    
    # Execute find and process results
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        
        local name
        name=$(basename "$item")
        
        if [[ -d "$item" ]]; then
            case "$mode" in
                "CLEAN")
                    [[ -z "$(ls -A "$item")" ]] && continue
                    ;;
                "ALL_FILES")
                    continue
                    ;;
                "FOLDERS"|"ALL_FOLDERS")
                    [[ -z "$(ls -A "$item")" ]] && [[ "$mode" == "FOLDERS" ]] && continue
                    ;;
            esac
            
            printf "%s|-- [Directory] %s\n" "$indent" "$name"
            generate_tree "$item" "$((depth + 1))" "$mode" "$include_info" "$max_depth" \
                         "$exclude_pattern" "$include_pattern" "$max_size"
        else
            case "$mode" in
                "ALL_FOLDERS"|"FOLDERS")
                    continue
                    ;;
                "CLEAN")
                    [[ ! -s "$item" ]] && continue
                    ;;
            esac
            
            # Check file size
            if [[ $max_size -gt 0 ]]; then
                local size_mb
                size_mb=$(bc <<< "scale=2; $(stat -f%z "$item") / 1048576")
                (( $(echo "$size_mb > $max_size" | bc -l) )) && continue
            fi
            
            printf "%s|-- [File] %s%s\n" "$indent" "$name" "$(get_file_info "$item" "$include_info")"
        fi
    done < <(eval "$find_cmd" 2>/dev/null || true)
}

# Main Function
generate_directory_tree_log() {
    local path="$1"
    local options=("${@:2}")
    local mode="CLEAN"
    local include_info="false"
    local max_size=100
    local output_format="text"
    local exclude_pattern=""
    local include_pattern=""
    local max_depth=-1
    local output_path=""
    local show_progress="true"
    
    # Parse options
    for opt in "${options[@]}"; do
        case "$opt" in
            --mode=*)
                mode="${opt#*=}"
                ;;
            --include-info)
                include_info="true"
                ;;
            --max-size=*)
                max_size="${opt#*=}"
                ;;
            --output-format=*)
                output_format="${opt#*=}"
                ;;
            --exclude=*)
                exclude_pattern="${opt#*=}"
                ;;
            --include=*)
                include_pattern="${opt#*=}"
                ;;
            --max-depth=*)
                max_depth="${opt#*=}"
                ;;
            --output=*)
                output_path="${opt#*=}"
                ;;
            --no-progress)
                show_progress="false"
                ;;
            *)
                log_message "Unknown option: $opt" "WARNING"
                ;;
        esac
    done
    
    # Validate input
    if ! validate_path "$path"; then
        return 1
    fi
    
    # Generate tree
    log_message "Generating directory tree..." "INFO"
    local tree_output
    tree_output=$(generate_tree "$path" 0 "$mode" "$include_info" "$max_depth" \
                              "$exclude_pattern" "$include_pattern" "$max_size")
    
    # Handle output
    if [[ -n "$output_path" ]]; then
        printf "%s\n" "$tree_output" > "$output_path"
        log_message "Directory tree log saved to: $output_path" "SUCCESS"
    else
        printf "%s\n" "$tree_output"
    fi
    
    log_message "Directory Tree Logger completed" "SUCCESS"
}

# Script Initialization
main() {
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Load configuration
    load_configuration
    
    # Process command line arguments
    if [[ $# -lt 1 ]]; then
        log_message "Usage: $0 <path> [options]" "ERROR"
        exit 1
    fi
    
    generate_directory_tree_log "$@"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 