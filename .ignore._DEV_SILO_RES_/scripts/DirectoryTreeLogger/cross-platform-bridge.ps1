#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Cross-Platform Integration Bridge for Directory Tree Logger
    
.DESCRIPTION
    This module provides seamless integration between PowerShell and Bash
    implementations of the Directory Tree Logger, enabling consistent
    functionality across Windows, Linux, and macOS platforms.
    
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

#Requires -Version 7.0

using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.IO

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module Constants
$script:MODULE_ROOT = $PSScriptRoot
$script:POWERSHELL_SCRIPT = Join-Path $MODULE_ROOT "DirectoryTreeLogger.psm1"
$script:BASH_SCRIPT = Join-Path $MODULE_ROOT "directory-tree-logger.sh"
$script:CONFIG_PATH = Join-Path $MODULE_ROOT "../../config/project.config.json"

# Platform Detection
enum Platform {
    Windows
    Linux
    MacOS
    Unknown
}

function Get-CurrentPlatform {
    if ($IsWindows) { return [Platform]::Windows }
    elseif ($IsLinux) { return [Platform]::Linux }
    elseif ($IsMacOS) { return [Platform]::MacOS }
    else { return [Platform]::Unknown }
}

# Logging Function
function Write-CrossPlatformLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Type = 'Info'
    )
    
    $colors = @{
        'Info' = 'Cyan'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Success' = 'Green'
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Type] $Message" -ForegroundColor $colors[$Type]
}

# Platform-specific Command Generation
function ConvertTo-PlatformCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [ValidateSet('CLEAN', 'ALL_FILES', 'ALL_FOLDERS', 'FOLDERS', 'EVERYTHING')]
        [string]$Mode = 'CLEAN',
        
        [switch]$IncludeFileInfo,
        
        [int]$MaxFileSize = 100,
        
        [ValidateSet('Text', 'JSON', 'XML', 'HTML', 'Markdown')]
        [string]$OutputFormat = 'Text',
        
        [string[]]$ExcludePatterns,
        
        [string[]]$IncludePatterns,
        
        [int]$MaxDepth = -1,
        
        [string]$OutputPath,
        
        [switch]$ShowProgress
    )
    
    $platform = Get-CurrentPlatform
    $command = [System.Text.StringBuilder]::new()
    
    switch ($platform) {
        'Windows' {
            [void]$command.Append("Import-Module '$POWERSHELL_SCRIPT'; ")
            [void]$command.Append("New-DirectoryTreeLog -Path '$Path' ")
            [void]$command.Append("-Mode '$Mode' ")
            if ($IncludeFileInfo) { [void]$command.Append("-IncludeFileInfo ") }
            [void]$command.Append("-MaxFileSize $MaxFileSize ")
            [void]$command.Append("-OutputFormat '$OutputFormat' ")
            if ($ExcludePatterns) { [void]$command.Append("-ExcludePatterns @('$($ExcludePatterns -join "','")') ") }
            if ($IncludePatterns) { [void]$command.Append("-IncludePatterns @('$($IncludePatterns -join "','")') ") }
            [void]$command.Append("-MaxDepth $MaxDepth ")
            if ($OutputPath) { [void]$command.Append("-OutputPath '$OutputPath' ") }
            if (-not $ShowProgress) { [void]$command.Append("-ShowProgress:$false") }
        }
        { $_ -in 'Linux','MacOS' } {
            [void]$command.Append("bash '$BASH_SCRIPT' ")
            [void]$command.Append("""$Path"" ")
            [void]$command.Append("--mode=$Mode ")
            if ($IncludeFileInfo) { [void]$command.Append("--include-info ") }
            [void]$command.Append("--max-size=$MaxFileSize ")
            [void]$command.Append("--output-format=$($OutputFormat.ToLower()) ")
            foreach ($pattern in $ExcludePatterns) {
                [void]$command.Append("--exclude=""$pattern"" ")
            }
            foreach ($pattern in $IncludePatterns) {
                [void]$command.Append("--include=""$pattern"" ")
            }
            [void]$command.Append("--max-depth=$MaxDepth ")
            if ($OutputPath) { [void]$command.Append("--output=""$OutputPath"" ") }
            if (-not $ShowProgress) { [void]$command.Append("--no-progress") }
        }
        default {
            throw "Unsupported platform: $platform"
        }
    }
    
    return $command.ToString()
}

# Cross-Platform Directory Tree Logger Function
function Invoke-DirectoryTreeLogger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [ValidateSet('CLEAN', 'ALL_FILES', 'ALL_FOLDERS', 'FOLDERS', 'EVERYTHING')]
        [string]$Mode = 'CLEAN',
        
        [switch]$IncludeFileInfo,
        
        [int]$MaxFileSize = 100,
        
        [ValidateSet('Text', 'JSON', 'XML', 'HTML', 'Markdown')]
        [string]$OutputFormat = 'Text',
        
        [string[]]$ExcludePatterns,
        
        [string[]]$IncludePatterns,
        
        [int]$MaxDepth = -1,
        
        [string]$OutputPath,
        
        [switch]$ShowProgress
    )
    
    try {
        Write-CrossPlatformLog "Initializing Cross-Platform Directory Tree Logger..." -Type Info
        
        # Validate path
        if (-not (Test-Path -Path $Path -PathType Container)) {
            throw "Path not found or is not a directory: $Path"
        }
        
        # Generate platform-specific command
        $command = ConvertTo-PlatformCommand @PSBoundParameters
        
        # Execute command
        Write-CrossPlatformLog "Executing on platform: $(Get-CurrentPlatform)" -Type Info
        
        if ((Get-CurrentPlatform) -eq 'Windows') {
            $result = Invoke-Expression $command
        }
        else {
            $result = bash -c $command
        }
        
        # Handle output
        if ($OutputPath) {
            Write-CrossPlatformLog "Directory tree log saved to: $OutputPath" -Type Success
        }
        else {
            return $result
        }
        
        Write-CrossPlatformLog "Directory Tree Logger completed successfully" -Type Success
    }
    catch {
        Write-CrossPlatformLog "Error: $_" -Type Error
        throw
    }
}

# Export Functions
Export-ModuleMember -Function Invoke-DirectoryTreeLogger
``` 