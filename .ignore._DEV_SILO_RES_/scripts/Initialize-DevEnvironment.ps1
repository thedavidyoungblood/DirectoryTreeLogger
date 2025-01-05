<#
.SYNOPSIS
    One-click development environment setup script for Directory Tree Logger project.

.DESCRIPTION
    Automates the setup of development environment including directory structure,
    documentation, and initial configuration for the Directory Tree Logger project.

.NOTES
    Version: 1.0.0
    Author: AI Assistant
    Date: 2024-12-30
#>

# Enable strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-StatusMessage {
    param(
        [string]$Message,
        [string]$Type = 'Info'
    )
    
    $colors = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    
    Write-Host "[$Type] $Message" -ForegroundColor $colors[$Type]
}

function Test-Prerequisites {
    Write-StatusMessage "Checking prerequisites..." "Info"
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7 or later is required. Current version: $($PSVersionTable.PSVersion)"
    }
    
    # Check if running with appropriate permissions
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-StatusMessage "Warning: Script is not running with administrator privileges. Some features may be limited." "Warning"
    }
}

function Initialize-ProjectStructure {
    param(
        [string]$BasePath
    )
    
    Write-StatusMessage "Creating project directory structure..." "Info"
    
    $directories = @(
        '.ignore._DEV_SILO_RES_',
        '.ignore._DEV_SILO_RES_\docs',
        '.ignore._DEV_SILO_RES_\scripts',
        '.ignore._DEV_SILO_RES_\._AIPP_TOOLbin',
        '.ignore._DEV_SILO_RES_\._AIPP_TOOLbin\._AI._Sourced_Content',
        '.ignore._DEV_SILO_RES_\._HUM-PP_TOOLbin',
        '.ignore._DEV_SILO_RES_\._HUM-PP_TOOLbin\._HUM._Sourced_Content',
        '.ignore._DEV_SILO_RES_\archived'
    )
    
    foreach ($dir in $directories) {
        $path = Join-Path $BasePath $dir
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            Write-StatusMessage "Created directory: $dir" "Success"
        }
        else {
            Write-StatusMessage "Directory already exists: $dir" "Info"
        }
    }
}

function Initialize-GitConfiguration {
    param(
        [string]$BasePath
    )
    
    Write-StatusMessage "Configuring Git settings..." "Info"
    
    $gitignorePath = Join-Path $BasePath ".gitignore"
    $gitignoreContent = @"
# Development Environment
.ignore._DEV_SILO_RES_/
.vscode/
.idea/

# Build outputs
bin/
obj/
out/

# Logs and temporary files
*.log
*.tmp
*~

# OS-specific files
.DS_Store
Thumbs.db
"@
    
    Set-Content -Path $gitignorePath -Value $gitignoreContent -Force
    Write-StatusMessage "Created .gitignore file" "Success"
}

function Initialize-Documentation {
    param(
        [string]$BasePath
    )
    
    Write-StatusMessage "Setting up documentation..." "Info"
    
    $docsPath = Join-Path $BasePath ".ignore._DEV_SILO_RES_\docs"
    
    # Create README template
    $readmePath = Join-Path $BasePath "README.md"
    $readmeContent = @"
# Directory Tree Logger

A cross-platform directory tree logging utility with support for Windows PowerShell, Linux/Unix Bash, and macOS environments.

## Features

- Cross-platform compatibility
- Customizable logging options
- Self-replication capability
- User preference management

## Installation

### Windows
\`\`\`powershell
# Installation instructions for Windows
\`\`\`

### Linux/Unix
\`\`\`bash
# Installation instructions for Linux/Unix
\`\`\`

### macOS
\`\`\`bash
# Installation instructions for macOS
\`\`\`

## Usage

[Documentation and usage examples]

## Contributing

[Contributing guidelines]

## License

MIT License
"@
    
    Set-Content -Path $readmePath -Value $readmeContent -Force
    Write-StatusMessage "Created README.md" "Success"
}

function Initialize-DevTools {
    param(
        [string]$BasePath
    )
    
    Write-StatusMessage "Setting up development tools..." "Info"
    
    # Create VSCode workspace settings
    $vscodePath = Join-Path $BasePath ".vscode"
    if (-not (Test-Path $vscodePath)) {
        New-Item -Path $vscodePath -ItemType Directory -Force | Out-Null
        
        $settingsPath = Join-Path $vscodePath "settings.json"
        $settingsContent = @"
{
    "files.exclude": {
        "**/.git": true,
        "**/.DS_Store": true,
        "**/Thumbs.db": true
    },
    "powershell.codeFormatting.preset": "OTBS",
    "powershell.scriptAnalysis.enable": true
}
"@
        Set-Content -Path $settingsPath -Value $settingsContent -Force
        Write-StatusMessage "Created VSCode settings" "Success"
    }
}

function Initialize-Configuration {
    param(
        [string]$BasePath
    )
    
    Write-StatusMessage "Setting up configuration files..." "Info"
    
    $configPath = Join-Path $BasePath ".ignore._DEV_SILO_RES_\config"
    if (-not (Test-Path $configPath)) {
        New-Item -Path $configPath -ItemType Directory -Force | Out-Null
        
        $defaultConfig = @{
            TargetDirectory = $BasePath
            OutputDirectory = Join-Path $BasePath "logs"
            LoggingMode = "CLEAN"
            IncludeFileInfo = $true
            MaxFileSize = 100
        }
        
        $configFile = Join-Path $configPath "DirectoryTreeLoggerConfig.json"
        $defaultConfig | ConvertTo-Json | Set-Content -Path $configFile -Force
        Write-StatusMessage "Created default configuration" "Success"
    }
}

function Start-Setup {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $PWD "setup_log_$timestamp.txt"
    
    try {
        Start-Transcript -Path $logFile
        
        Write-StatusMessage "Starting development environment setup..." "Info"
        Write-StatusMessage "Workspace root: $PWD" "Info"
        
        # Run setup steps
        Test-Prerequisites
        Initialize-ProjectStructure -BasePath $PWD
        Initialize-GitConfiguration -BasePath $PWD
        Initialize-Documentation -BasePath $PWD
        Initialize-DevTools -BasePath $PWD
        Initialize-Configuration -BasePath $PWD
        
        Write-StatusMessage "Setup completed successfully!" "Success"
    }
    catch {
        Write-StatusMessage "Error during setup: $_" "Error"
        throw $_
    }
    finally {
        Stop-Transcript
    }
}

# Execute setup
Start-Setup 