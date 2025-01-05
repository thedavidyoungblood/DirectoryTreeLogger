using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Text

<#
.SYNOPSIS
    Text formatter for Directory Tree Logger.
    
.DESCRIPTION
    Provides sophisticated text-based formatting for directory tree structures,
    with support for customizable output and metadata inclusion.
    
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

class TextFormatter : IOutputFormatter {
    # Required Properties
    [string]$Name = "Text"
    [string]$Description = "Advanced text-based tree formatter"
    [string]$Version = "1.0.0"
    [hashtable]$Configuration
    [bool]$IsEnabled = $true
    
    # Private fields
    hidden [string]$IndentChar = "│"
    hidden [string]$BranchChar = "├"
    hidden [string]$LastBranchChar = "└"
    hidden [string]$HorizontalChar = "─"
    hidden [string]$EmptyIndentChar = " "
    hidden [ConsoleColor]$DefaultForegroundColor = [ConsoleColor]::White
    hidden [ConsoleColor]$DefaultBackgroundColor = [ConsoleColor]::Black
    
    # Constructor
    TextFormatter() {
        $this.Configuration = $this.GetDefaultConfiguration()
    }
    
    # Required Methods
    [string] Format([FileSystemNode]$tree) {
        $sb = [StringBuilder]::new()
        
        if ($this.Configuration.IncludeMetadata) {
            $this.AppendMetadata($sb, $tree)
        }
        
        $this.AppendNode($sb, $tree, "", $true)
        
        if ($this.Configuration.IncludeStatistics) {
            $this.AppendStatistics($sb, $tree)
        }
        
        return $sb.ToString()
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
            'ShowFileSize',
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
            ShowFileSize = $true
            MaxDepth = -1
            DateTimeFormat = "yyyy-MM-dd HH:mm:ss"
            ColorizeOutput = $true
            DirectoryColor = [ConsoleColor]::Blue
            FileColor = [ConsoleColor]::White
            MetadataColor = [ConsoleColor]::Gray
            StatisticsColor = [ConsoleColor]::Yellow
            IndentSize = 2
            ShowHiddenFiles = $false
            ShowSystemFiles = $false
            ShowPermissions = $false
            ShowLastWriteTime = $true
            ShowCreationTime = $false
            ShowLastAccessTime = $false
            ShowAttributes = $true
            ShowLineCount = $true
        }
    }
    
    [string] GetContentType() {
        return "text/plain"
    }
    
    [string] GetFileExtension() {
        return ".txt"
    }
    
    # Helper Methods
    hidden [void] AppendNode([StringBuilder]$sb, [FileSystemNode]$node, [string]$indent, [bool]$isLast) {
        $line = [StringBuilder]::new()
        
        # Add indentation
        $line.Append($indent)
        
        # Add branch character
        if ($indent.Length -gt 0) {
            $line.Append($(if ($isLast) { $this.LastBranchChar } else { $this.BranchChar }))
            $line.Append($this.HorizontalChar * $this.Configuration.IndentSize)
        }
        
        # Add node name with optional size
        $nodeName = $node.Name
        if ($node.Type -eq [NodeType]::File -and $this.Configuration.ShowFileSize) {
            $nodeName += " ($($node.GetFormattedSize()))"
        }
        $line.Append($nodeName)
        
        # Add timestamps if configured
        if ($this.Configuration.ShowLastWriteTime) {
            $line.Append(" [Modified: ")
            $line.Append($node.LastWriteTime.ToString($this.Configuration.DateTimeFormat))
            $line.Append("]")
        }
        
        if ($this.Configuration.ShowCreationTime) {
            $line.Append(" [Created: ")
            $line.Append($node.CreationTime.ToString($this.Configuration.DateTimeFormat))
            $line.Append("]")
        }
        
        if ($this.Configuration.ShowLastAccessTime) {
            $line.Append(" [Accessed: ")
            $line.Append($node.LastAccessTime.ToString($this.Configuration.DateTimeFormat))
            $line.Append("]")
        }
        
        # Add attributes if configured
        if ($this.Configuration.ShowAttributes) {
            $attrs = @()
            if ($node.IsHidden) { $attrs += "Hidden" }
            if ($node.IsSystem) { $attrs += "System" }
            if ($node.IsReadOnly) { $attrs += "ReadOnly" }
            if ($attrs.Count -gt 0) {
                $line.Append(" [")
                $line.Append($attrs -join ", ")
                $line.Append("]")
            }
        }
        
        # Add permissions if configured
        if ($this.Configuration.ShowPermissions -and $node.Security) {
            $line.Append(" [")
            $line.Append($node.Security.Owner)
            $line.Append("]")
        }
        
        $sb.AppendLine($line.ToString())
        
        # Process children
        if ($node.Children.Count -gt 0) {
            $newIndent = $indent
            if ($indent.Length -gt 0) {
                $newIndent += $(if ($isLast) { $this.EmptyIndentChar } else { $this.IndentChar })
                $newIndent += " " * $this.Configuration.IndentSize
            }
            
            for ($i = 0; $i -lt $node.Children.Count; $i++) {
                $this.AppendNode($sb, $node.Children[$i], $newIndent, ($i -eq $node.Children.Count - 1))
            }
        }
    }
    
    hidden [void] AppendMetadata([StringBuilder]$sb, [FileSystemNode]$tree) {
        $sb.AppendLine("=== Directory Tree Logger ===")
        $sb.AppendLine("Generated: $((Get-Date).ToString($this.Configuration.DateTimeFormat))")
        $sb.AppendLine("Root Path: $($tree.FullPath)")
        $sb.AppendLine("Formatter: $($this.Name) v$($this.Version)")
        $sb.AppendLine("Configuration:")
        foreach ($key in $this.Configuration.Keys | Sort-Object) {
            $sb.AppendLine("  $key = $($this.Configuration[$key])")
        }
        $sb.AppendLine("===========================")
        $sb.AppendLine()
    }
    
    hidden [void] AppendStatistics([StringBuilder]$sb, [FileSystemNode]$tree) {
        $stats = $tree.GetStatistics()
        
        $sb.AppendLine()
        $sb.AppendLine("=== Statistics ===")
        $sb.AppendLine("Total Files: $($stats.TotalFiles)")
        $sb.AppendLine("Total Directories: $($stats.TotalDirectories)")
        $sb.AppendLine("Total Size: $($this.FormatSize($stats.TotalSize))")
        $sb.AppendLine("Maximum Depth: $($stats.MaxDepth)")
        
        if ($stats.OldestFile) {
            $sb.AppendLine("Oldest File: $($stats.OldestFile.Name)")
            $sb.AppendLine("  Created: $($stats.OldestFile.CreationTime.ToString($this.Configuration.DateTimeFormat))")
        }
        
        if ($stats.NewestFile) {
            $sb.AppendLine("Newest File: $($stats.NewestFile.Name)")
            $sb.AppendLine("  Created: $($stats.NewestFile.CreationTime.ToString($this.Configuration.DateTimeFormat))")
        }
        
        $sb.AppendLine("================")
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
}

# Export formatter
Export-ModuleMember -Variable TextFormatter 