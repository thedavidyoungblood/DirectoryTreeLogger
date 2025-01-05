using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.IO

<#
.SYNOPSIS
    FileSystemNode class for Directory Tree Logger.
    
.DESCRIPTION
    Represents a node in the file system tree, containing information about
    files and directories with their properties and relationships.
    
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

# Node Type Enumeration
enum NodeType {
    File
    Directory
}

# File System Node Class
class FileSystemNode {
    # Required Properties
    [string]$Name
    [string]$FullPath
    [NodeType]$Type
    [long]$Size
    [datetime]$CreationTime
    [datetime]$LastWriteTime
    [datetime]$LastAccessTime
    [System.Collections.Generic.List[FileSystemNode]]$Children
    [FileSystemNode]$Parent
    [int]$Depth
    [bool]$IsHidden
    [bool]$IsSystem
    [bool]$IsReadOnly
    [string]$Extension
    [System.Security.AccessControl.FileSystemSecurity]$Security
    
    # Constructor for creating from path
    FileSystemNode([string]$path) {
        $item = Get-Item -LiteralPath $path -Force
        $this.Initialize($item)
    }
    
    # Constructor for creating from FileSystemInfo
    FileSystemNode([System.IO.FileSystemInfo]$item) {
        $this.Initialize($item)
    }
    
    # Private initialization method
    hidden [void] Initialize([System.IO.FileSystemInfo]$item) {
        $this.Name = $item.Name
        $this.FullPath = $item.FullName
        $this.Type = if ($item -is [System.IO.DirectoryInfo]) { [NodeType]::Directory } else { [NodeType]::File }
        $this.Size = if ($item -is [System.IO.FileInfo]) { $item.Length } else { 0 }
        $this.CreationTime = $item.CreationTime
        $this.LastWriteTime = $item.LastWriteTime
        $this.LastAccessTime = $item.LastAccessTime
        $this.Children = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this.Parent = $null
        $this.Depth = 0
        $this.IsHidden = $item.Attributes.HasFlag([System.IO.FileAttributes]::Hidden)
        $this.IsSystem = $item.Attributes.HasFlag([System.IO.FileAttributes]::System)
        $this.IsReadOnly = $item.Attributes.HasFlag([System.IO.FileAttributes]::ReadOnly)
        $this.Extension = $item.Extension
        $this.Security = $item.GetAccessControl()
    }
    
    # Method to add child node
    [void] AddChild([FileSystemNode]$child) {
        $child.Parent = $this
        $child.Depth = $this.Depth + 1
        $this.Children.Add($child)
    }
    
    # Method to remove child node
    [void] RemoveChild([FileSystemNode]$child) {
        $this.Children.Remove($child)
        $child.Parent = $null
        $child.Depth = 0
    }
    
    # Method to get all descendants
    [System.Collections.Generic.List[FileSystemNode]] GetDescendants() {
        $descendants = [System.Collections.Generic.List[FileSystemNode]]::new()
        foreach ($child in $this.Children) {
            $descendants.Add($child)
            $descendants.AddRange($child.GetDescendants())
        }
        return $descendants
    }
    
    # Method to get path relative to root
    [string] GetRelativePath([string]$rootPath) {
        return $this.FullPath.Substring($rootPath.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
    }
    
    # Method to check if node matches pattern
    [bool] MatchesPattern([string]$pattern) {
        return $this.Name -like $pattern
    }
    
    # Method to get formatted size string
    [string] GetFormattedSize() {
        if ($this.Type -eq [NodeType]::Directory) {
            return "N/A"
        }
        
        if ($this.Size -lt 1KB) {
            return "$($this.Size) B"
        }
        elseif ($this.Size -lt 1MB) {
            return "$([math]::Round($this.Size / 1KB, 2)) KB"
        }
        elseif ($this.Size -lt 1GB) {
            return "$([math]::Round($this.Size / 1MB, 2)) MB"
        }
        else {
            return "$([math]::Round($this.Size / 1GB, 2)) GB"
        }
    }
    
    # Method to get node statistics
    [hashtable] GetStatistics() {
        $stats = @{
            TotalFiles = 0
            TotalDirectories = 0
            TotalSize = 0
            MaxDepth = $this.Depth
            OldestFile = $null
            NewestFile = $null
        }
        
        if ($this.Type -eq [NodeType]::File) {
            $stats.TotalFiles = 1
            $stats.TotalSize = $this.Size
            $stats.OldestFile = $this
            $stats.NewestFile = $this
        }
        else {
            foreach ($child in $this.GetDescendants()) {
                if ($child.Type -eq [NodeType]::File) {
                    $stats.TotalFiles++
                    $stats.TotalSize += $child.Size
                    
                    if ($null -eq $stats.OldestFile -or $child.CreationTime -lt $stats.OldestFile.CreationTime) {
                        $stats.OldestFile = $child
                    }
                    if ($null -eq $stats.NewestFile -or $child.CreationTime -gt $stats.NewestFile.CreationTime) {
                        $stats.NewestFile = $child
                    }
                }
                else {
                    $stats.TotalDirectories++
                }
                
                if ($child.Depth -gt $stats.MaxDepth) {
                    $stats.MaxDepth = $child.Depth
                }
            }
        }
        
        return $stats
    }
    
    # Override ToString method
    [string] ToString() {
        $type = $this.Type.ToString()
        $size = $this.GetFormattedSize()
        return "[$type] $($this.Name) ($size)"
    }
}

# Export the class and enum
Export-ModuleMember -Variable FileSystemNode
Export-ModuleMember -Variable NodeType
``` 