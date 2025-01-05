#!/usr/bin/env bash

# ==============================================================================
# Directory Tree Logger - macOS Installation Script
# Version: 1.0.0-2-beta
# Author: AI-Human Paired Programming Initiative
# License: MIT
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Script Constants
readonly VERSION="1.0.0-2-beta"
readonly MODULE_NAME="DirectoryTreeLogger"
readonly INSTALL_ROOT="/usr/local/opt/${MODULE_NAME}"
readonly MODULE_PATH="${INSTALL_ROOT}/module"
readonly CONFIG_PATH="${INSTALL_ROOT}/config"
readonly PLUGINS_PATH="${INSTALL_ROOT}/plugins"
readonly LOGS_PATH="${INSTALL_ROOT}/logs"
readonly COMPLETION_PATH="/usr/local/etc/bash_completion.d"
readonly MAN_PATH="/usr/local/share/man/man1"

# ANSI Color Codes
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[0;36m"    # Cyan
readonly COLOR_SUCCESS="\033[0;32m"  # Green
readonly COLOR_WARNING="\033[0;33m"  # Yellow
readonly COLOR_ERROR="\033[0;31m"    # Red

# Required Dependencies
readonly REQUIRED_PACKAGES=(
    "jq"
    "bash-completion"
    "pwsh"
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
    
    # Log to file if logs directory exists
    if [[ -d "$LOGS_PATH" ]]; then
        printf "[%s][%s] %s\n" "$timestamp" "$type" "$message" >> "${LOGS_PATH}/install.log"
    fi
}

# Check if running with sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_message "This script must be run with sudo" "ERROR"
        exit 1
    fi
}

# Check and install Homebrew
ensure_homebrew() {
    log_message "Checking Homebrew installation..." "INFO"
    
    if ! command -v brew &> /dev/null; then
        log_message "Homebrew not found. Installing..." "WARNING"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Update Homebrew
    brew update
    
    log_message "Homebrew is ready" "SUCCESS"
}

# Install package dependencies
install_dependencies() {
    log_message "Installing dependencies..." "INFO"
    
    # Install Homebrew packages
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! brew list "$package" &>/dev/null; then
            log_message "Installing $package..." "INFO"
            brew install "$package"
        else
            log_message "$package is already installed" "INFO"
        fi
    done
    
    log_message "Dependencies installed successfully" "SUCCESS"
}

# Validate PowerShell Core installation
validate_powershell() {
    log_message "Validating PowerShell Core installation..." "INFO"
    
    if ! command -v pwsh &> /dev/null; then
        log_message "PowerShell Core not found. Installing..." "WARNING"
        brew install --cask powershell
    fi
    
    # Verify PowerShell version
    local ps_version
    ps_version=$(pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()')
    if [[ "${ps_version%%.*}" -lt 7 ]]; then
        log_message "PowerShell 7 or higher required. Current version: $ps_version" "ERROR"
        exit 1
    fi
    
    log_message "PowerShell Core validation successful" "SUCCESS"
}

# Create directory structure
create_directory_structure() {
    log_message "Creating directory structure..." "INFO"
    
    local directories=(
        "$INSTALL_ROOT"
        "$MODULE_PATH"
        "$CONFIG_PATH"
        "$PLUGINS_PATH"
        "$LOGS_PATH"
        "${PLUGINS_PATH}/OutputFormatters"
        "${PLUGINS_PATH}/FilterProviders"
        "${PLUGINS_PATH}/LoggingProviders"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        log_message "Created directory: $dir" "INFO"
    done
    
    # Set appropriate permissions
    chown -R root:wheel "$INSTALL_ROOT"
    chmod -R 755 "$INSTALL_ROOT"
    
    log_message "Directory structure created successfully" "SUCCESS"
}

# Copy module files
copy_module_files() {
    log_message "Copying module files..." "INFO"
    
    local source_root
    source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    # Copy core module files
    cp "${source_root}/DirectoryTreeLogger.psm1" "$MODULE_PATH/"
    cp "${source_root}/DirectoryTreeLogger.psd1" "$MODULE_PATH/"
    cp "${source_root}/cross-platform-bridge.ps1" "$MODULE_PATH/"
    cp "${source_root}/directory-tree-logger.sh" "$MODULE_PATH/"
    
    # Copy configuration files
    cp -r "${source_root}/Config/"* "$CONFIG_PATH/"
    
    # Copy interface definitions
    cp -r "${source_root}/Interfaces/"* "$MODULE_PATH/"
    
    # Create symbolic link for shell script
    ln -sf "${MODULE_PATH}/directory-tree-logger.sh" "/usr/local/bin/dirtree"
    
    log_message "Module files copied successfully" "SUCCESS"
}

# Configure environment
configure_environment() {
    log_message "Configuring environment..." "INFO"
    
    # Add PowerShell module path
    local psmodule_path="/usr/local/share/powershell/Modules/${MODULE_NAME}"
    ln -sf "$MODULE_PATH" "$psmodule_path"
    
    # Create shell completion
    mkdir -p "$COMPLETION_PATH"
    cat > "${COMPLETION_PATH}/dirtree" <<EOF
_dirtree() {
    local cur prev opts
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    opts="--mode --include-info --max-size --output-format --exclude --include --max-depth --output --no-progress"
    
    case "\$prev" in
        --mode)
            COMPREPLY=( \$(compgen -W "CLEAN ALL_FILES ALL_FOLDERS FOLDERS EVERYTHING" -- "\$cur") )
            return 0
            ;;
        --output-format)
            COMPREPLY=( \$(compgen -W "text json xml html markdown" -- "\$cur") )
            return 0
            ;;
        *)
            COMPREPLY=( \$(compgen -W "\$opts" -- "\$cur") )
            return 0
            ;;
    esac
}
complete -F _dirtree dirtree
EOF
    
    # Create man page
    mkdir -p "$MAN_PATH"
    cat > "${MAN_PATH}/dirtree.1" <<EOF
.TH DIRTREE 1 "$(date +"%B %Y")" "Directory Tree Logger ${VERSION}" "User Commands"
.SH NAME
dirtree \- Advanced directory tree logging utility
.SH SYNOPSIS
.B dirtree
[\fIOPTIONS\fR] \fIPATH\fR
.SH DESCRIPTION
.B dirtree
is a cross-platform directory tree logging utility that provides comprehensive
directory structure visualization with advanced filtering and output options.
.SH OPTIONS
.TP
.BR \-\-mode=\fIMODE\fR
Specify logging mode (CLEAN, ALL_FILES, ALL_FOLDERS, FOLDERS, EVERYTHING)
.TP
.BR \-\-include\-info
Include detailed file information
.TP
.BR \-\-max\-size=\fISIZE\fR
Maximum file size in MB to include
.TP
.BR \-\-output\-format=\fIFORMAT\fR
Output format (text, json, xml, html, markdown)
.SH AUTHOR
Written by AI-Human Paired Programming Initiative.
.SH COPYRIGHT
Copyright © 2024 Open Source Community.
Licensed under MIT License.
EOF
    
    # Update man database
    /usr/libexec/makewhatis
    
    # Configure shell integration
    local shell_rc
    if [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bash_profile"
    elif [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        if ! grep -q "source ${COMPLETION_PATH}/dirtree" "$shell_rc"; then
            echo "source ${COMPLETION_PATH}/dirtree" >> "$shell_rc"
        fi
    fi
    
    log_message "Environment configured successfully" "SUCCESS"
}

# Test installation
test_installation() {
    log_message "Testing installation..." "INFO"
    
    # Test shell script
    if ! command -v dirtree &> /dev/null; then
        log_message "Shell script installation failed" "ERROR"
        return 1
    fi
    
    # Test PowerShell module
    if ! pwsh -NoProfile -Command "Import-Module ${MODULE_NAME} -ErrorAction Stop; Get-Command -Module ${MODULE_NAME}" &> /dev/null; then
        log_message "PowerShell module installation failed" "ERROR"
        return 1
    fi
    
    # Test basic functionality
    if ! dirtree --mode=CLEAN --max-depth=1 /tmp &> /dev/null; then
        log_message "Basic functionality test failed" "ERROR"
        return 1
    fi
    
    log_message "Installation tests passed successfully" "SUCCESS"
    return 0
}

# Main installation function
main() {
    local start_time
    start_time=$(date +%s)
    local success=false
    
    log_message "Starting Directory Tree Logger installation..." "INFO"
    log_message "Version: ${VERSION}" "INFO"
    
    trap 'handle_error $?' ERR
    
    # Installation steps
    check_sudo
    ensure_homebrew
    install_dependencies
    validate_powershell
    create_directory_structure
    copy_module_files
    configure_environment
    
    if test_installation; then
        success=true
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_message "Installation completed successfully in ${duration} seconds" "SUCCESS"
    else
        log_message "Installation validation failed" "ERROR"
        exit 1
    fi
}

# Error handler
handle_error() {
    local exit_code=$1
    
    log_message "Installation failed with error code: ${exit_code}" "ERROR"
    log_message "Rolling back changes..." "WARNING"
    
    # Rollback logic
    if [[ -d "$INSTALL_ROOT" ]]; then
        rm -rf "$INSTALL_ROOT"
    fi
    if [[ -L "/usr/local/bin/dirtree" ]]; then
        rm -f "/usr/local/bin/dirtree"
    fi
    if [[ -f "${COMPLETION_PATH}/dirtree" ]]; then
        rm -f "${COMPLETION_PATH}/dirtree"
    fi
    if [[ -f "${MAN_PATH}/dirtree.1" ]]; then
        rm -f "${MAN_PATH}/dirtree.1"
        /usr/libexec/makewhatis
    fi
    
    exit "${exit_code}"
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 