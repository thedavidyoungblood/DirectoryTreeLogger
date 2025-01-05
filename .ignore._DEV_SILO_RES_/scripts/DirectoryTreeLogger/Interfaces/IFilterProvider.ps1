using namespace System.Management.Automation
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Interface definition for Directory Tree Logger filter providers.
    
.DESCRIPTION
    Defines the contract that all filter providers must implement to provide
    consistent filtering capabilities across different filter types.
    
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

# Interface Definition
class IFilterProvider {
    # Required Properties
    [string]$Name
    [string]$Description
    [string]$Version
    [hashtable]$Configuration
    [bool]$IsEnabled
    
    # Constructor
    IFilterProvider() {
        throw "Interface cannot be instantiated directly"
    }
    
    # Required Methods
    [bool] ShouldInclude([FileSystemNode]$node) {
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
    [void] PreProcess([FileSystemNode]$root) {
        # Default implementation: no pre-processing
    }
    
    [void] PostProcess([FileSystemNode]$root) {
        # Default implementation: no post-processing
    }
    
    [string[]] GetSupportedPatterns() {
        return @("*")
    }
    
    [bool] SupportsRecursion() {
        return $true
    }
    
    [int] GetPriority() {
        return 100
    }
}

# Example Implementation Template
class ExampleFilterProvider : IFilterProvider {
    ExampleFilterProvider() {
        $this.Name = "Example"
        $this.Description = "Example filter provider implementation"
        $this.Version = "1.0.0"
        $this.IsEnabled = $true
        $this.Configuration = $this.GetDefaultConfiguration()
    }
    
    [bool] ShouldInclude([FileSystemNode]$node) {
        if (-not $this.IsEnabled) {
            return $true
        }
        
        # Example filtering logic
        $maxSize = $this.Configuration.MaxSizeMB * 1MB
        $excludePatterns = $this.Configuration.ExcludePatterns
        $includePatterns = $this.Configuration.IncludePatterns
        
        # Check size limit
        if ($node.Type -eq [NodeType]::File -and $node.Size -gt $maxSize) {
            return $false
        }
        
        # Check exclude patterns
        foreach ($pattern in $excludePatterns) {
            if ($node.MatchesPattern($pattern)) {
                return $false
            }
        }
        
        # Check include patterns
        if ($includePatterns.Count -gt 0) {
            $included = $false
            foreach ($pattern in $includePatterns) {
                if ($node.MatchesPattern($pattern)) {
                    $included = $true
                    break
                }
            }
            return $included
        }
        
        return $true
    }
    
    [void] Initialize([hashtable]$config) {
        if ($this.ValidateConfiguration($config)) {
            $this.Configuration = $config
        }
        else {
            throw "Invalid configuration provided"
        }
    }
    
    [bool] ValidateConfiguration([hashtable]$config) {
        # Add validation logic here
        return $true
    }
    
    [hashtable] GetDefaultConfiguration() {
        return @{
            MaxSizeMB = 100
            ExcludePatterns = @("*.tmp", "*.temp", "*.log")
            IncludePatterns = @()
            IgnoreHidden = $true
            IgnoreSystem = $true
        }
    }
    
    [string[]] GetSupportedPatterns() {
        return @("*.*", "*.txt", "*.log")
    }
    
    [bool] SupportsRecursion() {
        return $true
    }
    
    [int] GetPriority() {
        return 100
    }
}

# Export Interface and Example Implementation
Export-ModuleMember -Variable IFilterProvider
Export-ModuleMember -Variable ExampleFilterProvider 