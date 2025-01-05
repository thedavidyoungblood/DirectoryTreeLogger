#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Installation script for Directory Tree Logger on Windows
.DESCRIPTION
    Comprehensive installation and configuration script for the Directory Tree Logger
    on Windows platforms. Includes dependency management, environment validation,
    and automatic configuration.
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

#Requires -Version 7.0
using namespace System.Management.Automation
using namespace System.Security.Principal
using namespace System.IO

# Set strict mode and error preferences
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script Constants
$script:VERSION = "1.0.0-2-beta"
$script:MODULE_NAME = "DirectoryTreeLogger"
$script:INSTALL_ROOT = Join-Path $env:ProgramFiles $MODULE_NAME
$script:MODULE_PATH = Join-Path $INSTALL_ROOT "Module"
$script:CONFIG_PATH = Join-Path $INSTALL_ROOT "Config"
$script:PLUGINS_PATH = Join-Path $INSTALL_ROOT "Plugins"
$script:LOGS_PATH = Join-Path $INSTALL_ROOT "Logs"
$script:REQUIRED_MODULES = @(
    @{Name = "Newtonsoft.Json"; MinimumVersion = "13.0.0"},
    @{Name = "Microsoft.PowerShell.SecretManagement"; MinimumVersion = "1.1.0"}
)

# ANSI Color Codes for Rich Console Output
$script:COLOR_RESET = "`e[0m"
$script:COLOR_INFO = "`e[36m"    # Cyan
$script:COLOR_SUCCESS = "`e[32m"  # Green
$script:COLOR_WARNING = "`e[33m"  # Yellow
$script:COLOR_ERROR = "`e[31m"    # Red

# Logging Function
function Write-InstallLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $colors = @{
        'Info' = $COLOR_INFO
        'Success' = $COLOR_SUCCESS
        'Warning' = $COLOR_WARNING
        'Error' = $COLOR_ERROR
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = $colors[$Type]
    Write-Host "$color[$timestamp][$Type] $Message$COLOR_RESET"
    
    # Log to file
    $logMessage = "[$timestamp][$Type] $Message"
    Add-Content -Path (Join-Path $LOGS_PATH "install.log") -Value $logMessage -ErrorAction SilentlyContinue
}

# Environment Validation
function Test-InstallationPrerequisites {
    Write-InstallLog "Validating installation prerequisites..." -Type Info
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7 or higher is required. Current version: $($PSVersionTable.PSVersion)"
    }
    
    # Check administrative privileges
    $identity = [WindowsPrincipal][WindowsIdentity]::GetCurrent()
    if (-not $identity.IsInRole([WindowsBuiltInRole]::Administrator)) {
        throw "Administrative privileges required for installation"
    }
    
    # Check .NET version
    $dotnetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
    if (-not $dotnetVersion.Contains(".NET 6.0") -and -not $dotnetVersion.Contains(".NET 7.0")) {
        throw ".NET 6.0 or higher required. Current version: $dotnetVersion"
    }
    
    Write-InstallLog "Prerequisites validation successful" -Type Success
}

# Module Management
function Install-RequiredModules {
    Write-InstallLog "Installing required PowerShell modules..." -Type Info
    
    foreach ($module in $REQUIRED_MODULES) {
        try {
            if (-not (Get-Module -ListAvailable -Name $module.Name | 
                     Where-Object { $_.Version -ge $module.MinimumVersion })) {
                Write-InstallLog "Installing $($module.Name) module..." -Type Info
                Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force -AllowClobber
            }
            Import-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force
            Write-InstallLog "Module $($module.Name) installed successfully" -Type Success
        }
        catch {
            Write-InstallLog "Failed to install module $($module.Name): $_" -Type Error
            throw
        }
    }
}

# Directory Structure Creation
function Initialize-DirectoryStructure {
    Write-InstallLog "Creating directory structure..." -Type Info
    
    $directories = @(
        $INSTALL_ROOT,
        $MODULE_PATH,
        $CONFIG_PATH,
        $PLUGINS_PATH,
        $LOGS_PATH,
        (Join-Path $PLUGINS_PATH "OutputFormatters"),
        (Join-Path $PLUGINS_PATH "FilterProviders"),
        (Join-Path $PLUGINS_PATH "LoggingProviders")
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-InstallLog "Created directory: $dir" -Type Info
        }
    }
    
    # Set appropriate permissions
    $acl = Get-Acl $INSTALL_ROOT
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "Users", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.AddAccessRule($accessRule)
    Set-Acl $INSTALL_ROOT $acl
    
    Write-InstallLog "Directory structure created successfully" -Type Success
}

# File Copy and Configuration
function Copy-ModuleFiles {
    Write-InstallLog "Copying module files..." -Type Info
    
    $sourceRoot = Split-Path -Parent $PSScriptRoot
    
    # Core module files
    Copy-Item -Path (Join-Path $sourceRoot "DirectoryTreeLogger.psm1") -Destination $MODULE_PATH -Force
    Copy-Item -Path (Join-Path $sourceRoot "DirectoryTreeLogger.psd1") -Destination $MODULE_PATH -Force
    Copy-Item -Path (Join-Path $sourceRoot "cross-platform-bridge.ps1") -Destination $MODULE_PATH -Force
    
    # Configuration files
    Copy-Item -Path (Join-Path $sourceRoot "Config\*") -Destination $CONFIG_PATH -Recurse -Force
    
    # Interface definitions
    Copy-Item -Path (Join-Path $sourceRoot "Interfaces\*") -Destination $MODULE_PATH -Recurse -Force
    
    Write-InstallLog "Module files copied successfully" -Type Success
}

# Environment Configuration
function Set-EnvironmentConfiguration {
    Write-InstallLog "Configuring environment..." -Type Info
    
    # Add module path to PSModulePath
    $modulePaths = $env:PSModulePath -split ';'
    if ($modulePaths -notcontains $INSTALL_ROOT) {
        $env:PSModulePath = "$INSTALL_ROOT;$env:PSModulePath"
        [Environment]::SetEnvironmentVariable(
            "PSModulePath",
            $env:PSModulePath,
            [EnvironmentVariableTarget]::Machine
        )
    }
    
    # Create PowerShell profile if it doesn't exist
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -ItemType File -Force | Out-Null
    }
    
    # Add module import to profile
    $importCommand = "Import-Module $MODULE_NAME"
    if (-not (Get-Content $profilePath | Select-String -SimpleMatch $importCommand)) {
        Add-Content -Path $profilePath -Value "`n# Directory Tree Logger`n$importCommand"
    }
    
    Write-InstallLog "Environment configured successfully" -Type Success
}

# Validation and Testing
function Test-Installation {
    Write-InstallLog "Validating installation..." -Type Info
    
    try {
        # Test module import
        Import-Module $MODULE_NAME -Force
        
        # Test basic functionality
        $testPath = $env:TEMP
        $result = New-DirectoryTreeLog -Path $testPath -Mode "CLEAN" -MaxDepth 1
        
        if ($null -eq $result) {
            throw "Module functionality test failed"
        }
        
        Write-InstallLog "Installation validation successful" -Type Success
        return $true
    }
    catch {
        Write-InstallLog "Installation validation failed: $_" -Type Error
        return $false
    }
}

# Main Installation Function
function Install-DirectoryTreeLogger {
    $startTime = Get-Date
    $success = $false
    
    try {
        Write-InstallLog "Starting Directory Tree Logger installation..." -Type Info
        Write-InstallLog "Version: $VERSION" -Type Info
        
        # Installation steps
        Test-InstallationPrerequisites
        Install-RequiredModules
        Initialize-DirectoryStructure
        Copy-ModuleFiles
        Set-EnvironmentConfiguration
        
        if (Test-Installation) {
            $success = $true
            $duration = (Get-Date) - $startTime
            Write-InstallLog "Installation completed successfully in $($duration.TotalSeconds) seconds" -Type Success
        }
        else {
            throw "Installation validation failed"
        }
    }
    catch {
        Write-InstallLog "Installation failed: $_" -Type Error
        Write-InstallLog "Rolling back changes..." -Type Warning
        
        # Rollback logic
        if (Test-Path $INSTALL_ROOT) {
            Remove-Item -Path $INSTALL_ROOT -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        throw
    }
    finally {
        if ($success) {
            Write-InstallLog "Installation completed successfully" -Type Success
            Write-InstallLog "Module installed at: $MODULE_PATH" -Type Info
            Write-InstallLog "Configuration at: $CONFIG_PATH" -Type Info
            Write-InstallLog "Logs available at: $LOGS_PATH" -Type Info
        }
    }
}

# Script Entry Point
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Install-DirectoryTreeLogger
    }
    catch {
        Write-InstallLog "Critical installation error: $_" -Type Error
        exit 1
    }
} 