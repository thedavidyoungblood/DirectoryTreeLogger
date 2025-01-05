using namespace System.Management.Automation

<#
.SYNOPSIS
    Interface definition for Directory Tree Logger output formatters.
    
.DESCRIPTION
    Defines the contract that all output formatters must implement to be compatible
    with the Directory Tree Logger system.
    
.NOTES
    Version:        1.0.0-2-beta
    Author:         AI-Human Paired Programming Initiative
    Creation Date:  2024-12-31
    License:        MIT
#>

# Interface definition for output formatters
class IOutputFormatter {
    # Required Properties
    [string]$Name
    [string]$Description
    [string]$Version
    [hashtable]$Configuration
    [bool]$IsEnabled
    
    # Required Methods
    [string] Format([FileSystemNode]$tree) { throw "Not Implemented" }
    [string] FormatWithOptions([FileSystemNode]$tree, [hashtable]$options) { throw "Not Implemented" }
    [void] Initialize([hashtable]$config) { throw "Not Implemented" }
    [bool] ValidateConfiguration([hashtable]$config) { throw "Not Implemented" }
    [hashtable] GetDefaultConfiguration() { throw "Not Implemented" }
    [string] GetContentType() { throw "Not Implemented" }
    [string] GetFileExtension() { throw "Not Implemented" }
}

# Export interface
Export-ModuleMember -Variable IOutputFormatter 