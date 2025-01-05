using module "..\Models\FileSystemNode.psm1"
using module "..\Formatters\TextFormatter.psm1"
using module "..\Formatters\JsonFormatter.psm1"
using module "..\Formatters\XmlFormatter.psm1"

BeforeAll {
    # Create mock data for testing
    function New-MockFileSystemNode {
        param (
            [string]$name,
            [string]$path,
            [NodeType]$type,
            [long]$size = 0,
            [datetime]$creationTime = (Get-Date),
            [datetime]$lastWriteTime = (Get-Date),
            [datetime]$lastAccessTime = (Get-Date),
            [bool]$isHidden = $false,
            [bool]$isSystem = $false,
            [bool]$isReadOnly = $false,
            [array]$children = @()
        )
        
        $node = [FileSystemNode]::new()
        $node.Name = $name
        $node.FullPath = $path
        $node.Type = $type
        $node.Size = $size
        $node.CreationTime = $creationTime
        $node.LastWriteTime = $lastWriteTime
        $node.LastAccessTime = $lastAccessTime
        $node.IsHidden = $isHidden
        $node.IsSystem = $isSystem
        $node.IsReadOnly = $isReadOnly
        $node.Children = $children
        
        return $node
    }
    
    # Create a mock directory structure
    $mockRoot = New-MockFileSystemNode -name "root" -path "C:\root" -type Directory
    $mockDir1 = New-MockFileSystemNode -name "dir1" -path "C:\root\dir1" -type Directory
    $mockFile1 = New-MockFileSystemNode -name "file1.txt" -path "C:\root\dir1\file1.txt" -type File -size 1024
    $mockFile2 = New-MockFileSystemNode -name "file2.txt" -path "C:\root\dir1\file2.txt" -type File -size 2048
    $mockDir1.Children = @($mockFile1, $mockFile2)
    $mockRoot.Children = @($mockDir1)
}

Describe "TextFormatter Tests" {
    BeforeAll {
        $textFormatter = [TextFormatter]::new()
    }
    
    It "Should initialize with default configuration" {
        $config = $textFormatter.GetDefaultConfiguration()
        $config | Should -Not -BeNullOrEmpty
        $config.PrettyPrint | Should -BeTrue
        $config.IncludeMetadata | Should -BeTrue
    }
    
    It "Should format a simple directory structure" {
        $result = $textFormatter.Format($mockRoot)
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match "root"
        $result | Should -Match "dir1"
        $result | Should -Match "file1.txt"
        $result | Should -Match "file2.txt"
    }
    
    It "Should respect configuration options" {
        $options = @{
            PrettyPrint = $true
            IncludeMetadata = $false
            IncludeStatistics = $false
            ShowFileSize = $true
        }
        $result = $textFormatter.FormatWithOptions($mockRoot, $options)
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match "1.00 KB"
        $result | Should -Match "2.00 KB"
    }
}

Describe "JsonFormatter Tests" {
    BeforeAll {
        $jsonFormatter = [JsonFormatter]::new()
    }
    
    It "Should initialize with default configuration" {
        $config = $jsonFormatter.GetDefaultConfiguration()
        $config | Should -Not -BeNullOrEmpty
        $config.PrettyPrint | Should -BeTrue
        $config.IncludeMetadata | Should -BeTrue
    }
    
    It "Should format a simple directory structure" {
        $result = $jsonFormatter.Format($mockRoot)
        $result | Should -Not -BeNullOrEmpty
        $resultObj = $result | ConvertFrom-Json
        $resultObj.tree | Should -Not -BeNullOrEmpty
        $resultObj.tree.name | Should -Be "root"
        $resultObj.tree.children[0].name | Should -Be "dir1"
    }
    
    It "Should include statistics when configured" {
        $options = @{
            PrettyPrint = $true
            IncludeMetadata = $true
            IncludeStatistics = $true
        }
        $result = $jsonFormatter.FormatWithOptions($mockRoot, $options)
        $resultObj = $result | ConvertFrom-Json
        $resultObj.statistics | Should -Not -BeNullOrEmpty
        $resultObj.statistics.totalFiles | Should -Be 2
        $resultObj.statistics.totalDirectories | Should -Be 2
    }
    
    It "Should handle different case styles" {
        $options = @{
            CaseStyle = "snake_case"
            PrettyPrint = $true
        }
        $result = $jsonFormatter.FormatWithOptions($mockRoot, $options)
        $resultObj = $result | ConvertFrom-Json
        $resultObj.tree.full_path | Should -Not -BeNullOrEmpty
    }
}

Describe "XmlFormatter Tests" {
    BeforeAll {
        $xmlFormatter = [XmlFormatter]::new()
    }
    
    It "Should initialize with default configuration" {
        $config = $xmlFormatter.GetDefaultConfiguration()
        $config | Should -Not -BeNullOrEmpty
        $config.PrettyPrint | Should -BeTrue
        $config.IncludeMetadata | Should -BeTrue
    }
    
    It "Should format a simple directory structure" {
        $result = $xmlFormatter.Format($mockRoot)
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match "<DirectoryTree>"
        $result | Should -Match "<Node type=`"Directory`" name=`"root`""
        $result | Should -Match "<Node type=`"File`" name=`"file1.txt`""
    }
    
    It "Should include statistics when configured" {
        $options = @{
            PrettyPrint = $true
            IncludeMetadata = $true
            IncludeStatistics = $true
        }
        $result = $xmlFormatter.FormatWithOptions($mockRoot, $options)
        $result | Should -Match "<Statistics>"
        $result | Should -Match "<TotalFiles>2</TotalFiles>"
        $result | Should -Match "<TotalDirectories>2</TotalDirectories>"
    }
    
    It "Should handle XML special characters" {
        $mockFileWithSpecialChars = New-MockFileSystemNode -name "test & file.txt" -path "C:\root\test & file.txt" -type File
        $result = $xmlFormatter.Format($mockFileWithSpecialChars)
        $result | Should -Match "test &amp; file.txt"
    }
}

Describe "Cross-Formatter Consistency Tests" {
    BeforeAll {
        $textFormatter = [TextFormatter]::new()
        $jsonFormatter = [JsonFormatter]::new()
        $xmlFormatter = [XmlFormatter]::new()
    }
    
    It "Should maintain consistent file counts across formatters" {
        $textResult = $textFormatter.Format($mockRoot)
        $jsonResult = $jsonFormatter.Format($mockRoot) | ConvertFrom-Json
        [xml]$xmlResult = $xmlFormatter.Format($mockRoot)
        
        $textFileCount = ($textResult -split "`n" | Select-String -Pattern "file\d\.txt").Count
        $jsonFileCount = ($jsonResult.tree | ConvertTo-Json -Depth 10 | Select-String -Pattern "file\d\.txt").Count
        $xmlFileCount = ($xmlResult.OuterXml | Select-String -Pattern "file\d\.txt").Count
        
        $textFileCount | Should -Be 2
        $jsonFileCount | Should -Be 2
        $xmlFileCount | Should -Be 2
    }
    
    It "Should maintain consistent file sizes across formatters" {
        $options = @{
            ShowFileSize = $true
            IncludeStatistics = $true
        }
        
        $textResult = $textFormatter.FormatWithOptions($mockRoot, $options)
        $jsonResult = $jsonFormatter.FormatWithOptions($mockRoot, $options) | ConvertFrom-Json
        [xml]$xmlResult = $xmlFormatter.FormatWithOptions($mockRoot, $options)
        
        $textResult | Should -Match "1.00 KB"
        $jsonResult.tree.children[0].children[0].sizeFormatted | Should -Be "1.00 KB"
        $xmlResult.SelectNodes("//Node[@type='File']")[0].SizeFormatted | Should -Be "1.00 KB"
    }
} 