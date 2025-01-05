using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Xml
using namespace System.Xml.Linq
using namespace System.Text

<#
.SYNOPSIS
    XML formatter for Directory Tree Logger.
    
.DESCRIPTION
    Provides sophisticated XML-based formatting for directory tree structures,
    with support for customizable output and metadata inclusion.
    
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

class XmlFormatter : IOutputFormatter {
    # Required Properties
    [string]$Name = "XML"
    [string]$Description = "Advanced XML-based tree formatter"
    [string]$Version = "1.0.0"
    [hashtable]$Configuration
    [bool]$IsEnabled = $true
    
    # Constructor
    XmlFormatter() {
        $this.Configuration = $this.GetDefaultConfiguration()
    }
    
    # Required Methods
    [string] Format([FileSystemNode]$tree) {
        $doc = [XDocument]::new()
        $root = [XElement]::new("DirectoryTree")
        $doc.Add($root)
        
        # Add metadata
        if ($this.Configuration.IncludeMetadata) {
            $metadata = $this.GetMetadataElement($tree)
            $root.Add($metadata)
        }
        
        # Add tree structure
        $treeElement = $this.ConvertNodeToXml($tree)
        $root.Add($treeElement)
        
        # Add statistics
        if ($this.Configuration.IncludeStatistics) {
            $stats = $this.GetStatisticsElement($tree)
            $root.Add($stats)
        }
        
        # Format the XML output
        $settings = [XmlWriterSettings]::new()
        $settings.Indent = $this.Configuration.PrettyPrint
        $settings.IndentChars = "    "
        $settings.Encoding = [UTF8Encoding]::new($false)
        
        $sb = [StringBuilder]::new()
        $writer = [XmlWriter]::Create($sb, $settings)
        $doc.WriteTo($writer)
        $writer.Flush()
        $writer.Close()
        
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
            ExcludeAttributes = @()
            IncludeAttributes = @()
            NullValueHandling = "Include"  # Include, Exclude
            XmlNamespace = ""
        }
    }
    
    [string] GetContentType() {
        return "application/xml"
    }
    
    [string] GetFileExtension() {
        return ".xml"
    }
    
    # Helper Methods
    hidden [XElement] ConvertNodeToXml([FileSystemNode]$node) {
        $element = [XElement]::new(
            "Node",
            [XAttribute]::new("type", $node.Type.ToString()),
            [XAttribute]::new("name", $node.Name),
            [XAttribute]::new("path", $node.FullPath)
        )
        
        if ($node.Type -eq [NodeType]::File) {
            $element.Add([XElement]::new("Size", $node.Size))
            $element.Add([XElement]::new("SizeFormatted", $node.GetFormattedSize()))
            $element.Add([XElement]::new("Extension", $node.Extension))
            $element.Add([XElement]::new("CreationTime", 
                $node.CreationTime.ToString($this.Configuration.DateTimeFormat)))
            $element.Add([XElement]::new("LastWriteTime", 
                $node.LastWriteTime.ToString($this.Configuration.DateTimeFormat)))
            $element.Add([XElement]::new("LastAccessTime", 
                $node.LastAccessTime.ToString($this.Configuration.DateTimeFormat)))
            $element.Add([XElement]::new("IsHidden", $node.IsHidden))
            $element.Add([XElement]::new("IsSystem", $node.IsSystem))
            $element.Add([XElement]::new("IsReadOnly", $node.IsReadOnly))
            
            if ($this.Configuration.IncludePermissions) {
                $element.Add($this.GetPermissionsElement($node))
            }
        }
        
        if ($node.Children.Count -gt 0) {
            $children = [XElement]::new("Children")
            foreach ($child in $node.Children) {
                $children.Add($this.ConvertNodeToXml($child))
            }
            $element.Add($children)
        }
        
        return $element
    }
    
    hidden [XElement] GetMetadataElement([FileSystemNode]$tree) {
        return [XElement]::new(
            "Metadata",
            [XElement]::new("GeneratedAt", 
                (Get-Date).ToString($this.Configuration.DateTimeFormat)),
            [XElement]::new("RootPath", $tree.FullPath),
            [XElement]::new("FormatVersion", $this.Version),
            [XElement]::new("Configuration", 
                ($this.Configuration | ConvertTo-Json -Depth 10))
        )
    }
    
    hidden [XElement] GetStatisticsElement([FileSystemNode]$tree) {
        $stats = $tree.GetStatistics()
        $element = [XElement]::new("Statistics")
        
        $element.Add([XElement]::new("TotalFiles", $stats.TotalFiles))
        $element.Add([XElement]::new("TotalDirectories", $stats.TotalDirectories))
        $element.Add([XElement]::new("TotalSize", $stats.TotalSize))
        $element.Add([XElement]::new("TotalSizeFormatted", 
            $this.FormatSize($stats.TotalSize)))
        $element.Add([XElement]::new("MaxDepth", $stats.MaxDepth))
        
        if ($stats.OldestFile) {
            $oldest = [XElement]::new("OldestFile")
            $oldest.Add([XElement]::new("Name", $stats.OldestFile.Name))
            $oldest.Add([XElement]::new("Path", $stats.OldestFile.FullPath))
            $oldest.Add([XElement]::new("CreationTime", 
                $stats.OldestFile.CreationTime.ToString($this.Configuration.DateTimeFormat)))
            $element.Add($oldest)
        }
        
        if ($stats.NewestFile) {
            $newest = [XElement]::new("NewestFile")
            $newest.Add([XElement]::new("Name", $stats.NewestFile.Name))
            $newest.Add([XElement]::new("Path", $stats.NewestFile.FullPath))
            $newest.Add([XElement]::new("CreationTime", 
                $stats.NewestFile.CreationTime.ToString($this.Configuration.DateTimeFormat)))
            $element.Add($newest)
        }
        
        return $element
    }
    
    hidden [XElement] GetPermissionsElement([FileSystemNode]$node) {
        $security = $node.Security
        $permissions = [XElement]::new("Permissions")
        
        $permissions.Add([XElement]::new("Owner", $security.Owner))
        $permissions.Add([XElement]::new("Group", $security.Group))
        
        $access = [XElement]::new("Access")
        foreach ($rule in $security.AccessToString -split "`n") {
            if ($rule.Trim()) {
                $access.Add([XElement]::new("Rule", $rule.Trim()))
            }
        }
        $permissions.Add($access)
        
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
}

# Export formatter
Export-ModuleMember -Variable XmlFormatter 