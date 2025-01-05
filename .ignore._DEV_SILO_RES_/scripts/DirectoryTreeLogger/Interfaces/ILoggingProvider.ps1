using namespace System.Management.Automation
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Interface definition for Directory Tree Logger logging providers.
    
.DESCRIPTION
    Defines the contract that all logging providers must implement to provide
    consistent logging capabilities across different output destinations.
    
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

# Log Level Enumeration
enum LogLevel {
    Debug
    Info
    Warning
    Error
    Critical
}

# Interface Definition
class ILoggingProvider {
    # Required Properties
    [string]$Name
    [string]$Description
    [string]$Version
    [hashtable]$Configuration
    [bool]$IsEnabled
    [LogLevel]$MinimumLogLevel
    
    # Constructor
    ILoggingProvider() {
        throw "Interface cannot be instantiated directly"
    }
    
    # Required Methods
    [void] Log([string]$message, [LogLevel]$level) {
        throw "Method not implemented"
    }
    
    [void] LogError([string]$message, [System.Exception]$exception) {
        throw "Method not implemented"
    }
    
    [void] Initialize([hashtable]$config) {
        throw "Method not implemented"
    }
    
    [bool] ValidateConfiguration([hashtable]$config) {
        throw "Method not implemented"
    }
    
    [hashtable] GetDefaultConfiguration() {
        throw "Method not implemented"
    }
    
    # Optional Methods with Default Implementations
    [void] BeginScope([string]$scopeName) {
        # Default implementation: no scope handling
    }
    
    [void] EndScope() {
        # Default implementation: no scope handling
    }
    
    [void] Flush() {
        # Default implementation: no buffering
    }
    
    [bool] IsEnabled([LogLevel]$level) {
        return $level -ge $this.MinimumLogLevel
    }
    
    [string] FormatMessage([string]$message, [LogLevel]$level) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        return "[$timestamp][$level] $message"
    }
}

# Example Implementation Template
class ExampleLoggingProvider : ILoggingProvider {
    # Private members
    hidden [System.Collections.Generic.Stack[string]]$_scopes
    hidden [string]$_logFile
    
    ExampleLoggingProvider() {
        $this.Name = "Example"
        $this.Description = "Example logging provider implementation"
        $this.Version = "1.0.0"
        $this.IsEnabled = $true
        $this.MinimumLogLevel = [LogLevel]::Info
        $this.Configuration = $this.GetDefaultConfiguration()
        $this._scopes = [System.Collections.Generic.Stack[string]]::new()
    }
    
    [void] Log([string]$message, [LogLevel]$level) {
        if (-not $this.IsEnabled -or -not $this.IsEnabled($level)) {
            return
        }
        
        $scopePrefix = if ($this._scopes.Count -gt 0) {
            "[$($this._scopes.Peek())] "
        } else { "" }
        
        $formattedMessage = $this.FormatMessage("$scopePrefix$message", $level)
        
        if ($this.Configuration.WriteToFile) {
            Add-Content -Path $this._logFile -Value $formattedMessage
        }
        
        if ($this.Configuration.WriteToConsole) {
            $color = switch ($level) {
                ([LogLevel]::Debug) { "Gray" }
                ([LogLevel]::Info) { "White" }
                ([LogLevel]::Warning) { "Yellow" }
                ([LogLevel]::Error) { "Red" }
                ([LogLevel]::Critical) { "DarkRed" }
                default { "White" }
            }
            Write-Host $formattedMessage -ForegroundColor $color
        }
    }
    
    [void] LogError([string]$message, [System.Exception]$exception) {
        $errorMessage = "$message`nException: $($exception.GetType().Name)`nMessage: $($exception.Message)"
        if ($this.Configuration.IncludeStackTrace) {
            $errorMessage += "`nStack Trace: $($exception.StackTrace)"
        }
        $this.Log($errorMessage, [LogLevel]::Error)
    }
    
    [void] Initialize([hashtable]$config) {
        if ($this.ValidateConfiguration($config)) {
            $this.Configuration = $config
            if ($this.Configuration.WriteToFile) {
                $this._logFile = $this.Configuration.LogFilePath
                if (-not (Test-Path $this._logFile)) {
                    New-Item -Path $this._logFile -ItemType File -Force | Out-Null
                }
            }
        }
        else {
            throw "Invalid configuration provided"
        }
    }
    
    [bool] ValidateConfiguration([hashtable]$config) {
        if ($config.WriteToFile -and -not $config.LogFilePath) {
            return $false
        }
        return $true
    }
    
    [hashtable] GetDefaultConfiguration() {
        return @{
            WriteToConsole = $true
            WriteToFile = $false
            LogFilePath = Join-Path $env:TEMP "DirectoryTreeLogger.log"
            IncludeStackTrace = $true
            MaxLogSize = 10MB
            MaxLogFiles = 5
            LogRotationEnabled = $true
        }
    }
    
    [void] BeginScope([string]$scopeName) {
        $this._scopes.Push($scopeName)
    }
    
    [void] EndScope() {
        if ($this._scopes.Count -gt 0) {
            $this._scopes.Pop() | Out-Null
        }
    }
    
    [void] Flush() {
        if ($this.Configuration.WriteToFile) {
            # Implement log rotation if enabled
            if ($this.Configuration.LogRotationEnabled) {
                $logFile = Get-Item $this._logFile
                if ($logFile.Length -gt $this.Configuration.MaxLogSize) {
                    $this.RotateLogs()
                }
            }
        }
    }
    
    # Helper method for log rotation
    hidden [void] RotateLogs() {
        $directory = Split-Path $this._logFile -Parent
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($this._logFile)
        $extension = [System.IO.Path]::GetExtension($this._logFile)
        
        # Rotate existing log files
        for ($i = $this.Configuration.MaxLogFiles - 1; $i -ge 1; $i--) {
            $oldFile = Join-Path $directory "$baseName.$i$extension"
            $newFile = Join-Path $directory "$baseName.$($i + 1)$extension"
            if (Test-Path $oldFile) {
                Move-Item -Path $oldFile -Destination $newFile -Force
            }
        }
        
        # Move current log file
        $firstBackup = Join-Path $directory "$baseName.1$extension"
        Move-Item -Path $this._logFile -Destination $firstBackup -Force
        
        # Create new log file
        New-Item -Path $this._logFile -ItemType File -Force | Out-Null
    }
}

# Export Interface, Enum, and Example Implementation
Export-ModuleMember -Variable ILoggingProvider
Export-ModuleMember -Variable LogLevel
Export-ModuleMember -Variable ExampleLoggingProvider
``` 