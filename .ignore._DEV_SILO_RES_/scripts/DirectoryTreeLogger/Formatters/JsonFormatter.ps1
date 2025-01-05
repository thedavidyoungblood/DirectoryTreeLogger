using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Text.Json

<#
.SYNOPSIS
    JSON formatter for Directory Tree Logger.
    
.DESCRIPTION
    Provides sophisticated JSON-based formatting for directory tree structures,
    with support for customizable output and metadata inclusion.
    
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

class JsonFormatter : IOutputFormatter {
    # Required Properties
    [string]$Name = "JSON"
    [string]$Description = "Advanced JSON-based tree formatter"
    [string]$Version = "1.0.0"
    [hashtable]$Configuration
    [bool]$IsEnabled = $true
    
    # Constructor
    JsonFormatter() {
        $this.Configuration = $this.GetDefaultConfiguration()
    }
    
    # Required Methods
    [string] Format([FileSystemNode]$tree) {
        $jsonObject = @{
            metadata = $this.GetMetadata($tree)
            tree = $this.ConvertNodeToJson($tree)
        }
        
        if ($this.Configuration.IncludeStatistics) {
            $jsonObject.statistics = $this.GetStatistics($tree)
        }
        
        $jsonOptions = [System.Text.Json.JsonSerializerOptions]::new()
        $jsonOptions.WriteIndented = $this.Configuration.PrettyPrint
        
        return [System.Text.Json.JsonSerializer]::Serialize($jsonObject, $jsonOptions)
    }
    
    [string] FormatWithOptions([FileSystemNode]$tree, [hashtable]$options) {
        $originalConfig = $this.Configuration.Clone()
        try {
            foreach ($key in $options.Keys) {
                $this.Configuration[$key] = $options[$key]
            }
            return $this.Format($tree)
        }
        finally {
            $this.Configuration = $originalConfig
        }
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
        $requiredKeys = @(
            'PrettyPrint',
            'IncludeMetadata',
            'IncludeStatistics',
            'IncludePermissions',
            'MaxDepth',
            'DateTimeFormat'
        )
        
        foreach ($key in $requiredKeys) {
            if (-not $config.ContainsKey($key)) {
                return $false
            }
        }
        
        if ($config.MaxDepth -lt -1) {
            return $false
        }
        
        return $true
    }
    
    [hashtable] GetDefaultConfiguration() {
        return @{
            PrettyPrint = $true
            IncludeMetadata = $true
            IncludeStatistics = $true
            IncludePermissions = $false
            MaxDepth = -1
            DateTimeFormat = "yyyy-MM-dd HH:mm:ss"
            ExcludeProperties = @()
            IncludeProperties = @()
            NullValueHandling = "Include"  # Include, Exclude
            CaseStyle = "CamelCase"        # CamelCase, PascalCase, KebabCase, SnakeCase
        }
    }
    
    [string] GetContentType() {
        return "application/json"
    }
    
    [string] GetFileExtension() {
        return ".json"
    }
    
    # Helper Methods
    hidden [hashtable] ConvertNodeToJson([FileSystemNode]$node) {
        $nodeJson = @{
            name = $node.Name
            type = $node.Type.ToString()
            path = $node.FullPath
        }
        
        if ($node.Type -eq [NodeType]::File) {
            $nodeJson += @{
                size = $node.Size
                sizeFormatted = $node.GetFormattedSize()
                extension = $node.Extension
                creationTime = $node.CreationTime.ToString($this.Configuration.DateTimeFormat)
                lastWriteTime = $node.LastWriteTime.ToString($this.Configuration.DateTimeFormat)
                lastAccessTime = $node.LastAccessTime.ToString($this.Configuration.DateTimeFormat)
                isHidden = $node.IsHidden
                isSystem = $node.IsSystem
                isReadOnly = $node.IsReadOnly
            }
            
            if ($this.Configuration.IncludePermissions) {
                $nodeJson.permissions = $this.GetPermissions($node)
            }
        }
        
        if ($node.Children.Count -gt 0) {
            $nodeJson.children = @()
            foreach ($child in $node.Children) {
                $nodeJson.children += $this.ConvertNodeToJson($child)
            }
        }
        
        return $this.TransformPropertyNames($nodeJson)
    }
    
    hidden [hashtable] GetMetadata([FileSystemNode]$tree) {
        return @{
            generatedAt = (Get-Date).ToString($this.Configuration.DateTimeFormat)
            rootPath = $tree.FullPath
            formatVersion = $this.Version
            configuration = $this.Configuration
        }
    }
    
    hidden [hashtable] GetStatistics([FileSystemNode]$tree) {
        $stats = $tree.GetStatistics()
        return @{
            totalFiles = $stats.TotalFiles
            totalDirectories = $stats.TotalDirectories
            totalSize = $stats.TotalSize
            totalSizeFormatted = $this.FormatSize($stats.TotalSize)
            maxDepth = $stats.MaxDepth
            oldestFile = if ($stats.OldestFile) {
                @{
                    name = $stats.OldestFile.Name
                    path = $stats.OldestFile.FullPath
                    creationTime = $stats.OldestFile.CreationTime.ToString($this.Configuration.DateTimeFormat)
                }
            } else { $null }
            newestFile = if ($stats.NewestFile) {
                @{
                    name = $stats.NewestFile.Name
                    path = $stats.NewestFile.FullPath
                    creationTime = $stats.NewestFile.CreationTime.ToString($this.Configuration.DateTimeFormat)
                }
            } else { $null }
        }
    }
    
    hidden [hashtable] GetPermissions([FileSystemNode]$node) {
        $security = $node.Security
        $permissions = @{
            owner = $security.Owner
            group = $security.Group
            access = @()
        }
        
        foreach ($rule in $security.AccessToString -split "`n") {
            if ($rule.Trim()) {
                $permissions.access += $rule.Trim()
            }
        }
        
        return $permissions
    }
    
    hidden [string] FormatSize([long]$bytes) {
        if ($bytes -lt 1KB) {
            return "$bytes B"
        }
        elseif ($bytes -lt 1MB) {
            return "$([math]::Round($bytes / 1KB, 2)) KB"
        }
        elseif ($bytes -lt 1GB) {
            return "$([math]::Round($bytes / 1MB, 2)) MB"
        }
        else {
            return "$([math]::Round($bytes / 1GB, 2)) GB"
        }
    }
    
    hidden [hashtable] TransformPropertyNames([hashtable]$data) {
        $transformed = @{}
        
        foreach ($key in $data.Keys) {
            $newKey = switch ($this.Configuration.CaseStyle) {
                "CamelCase" { $key.Substring(0,1).ToLower() + $key.Substring(1) }
                "PascalCase" { $key.Substring(0,1).ToUpper() + $key.Substring(1) }
                "KebabCase" { $key -replace '([A-Z])', '-$1'.ToLower() -replace '^-' }
                "SnakeCase" { $key -replace '([A-Z])', '_$1'.ToLower() -replace '^_' }
                default { $key }
            }
            
            $value = $data[$key]
            
            if ($value -is [hashtable]) {
                $transformed[$newKey] = $this.TransformPropertyNames($value)
            }
            elseif ($value -is [array]) {
                $transformed[$newKey] = @($value | ForEach-Object {
                    if ($_ -is [hashtable]) {
                        $this.TransformPropertyNames($_)
                    }
                    else {
                        $_
                    }
                })
            }
            else {
                if ($null -eq $value -and $this.Configuration.NullValueHandling -eq "Exclude") {
                    continue
                }
                $transformed[$newKey] = $value
            }
        }
        
        return $transformed
    }
}

# Export formatter
Export-ModuleMember -Variable JsonFormatter
``` 