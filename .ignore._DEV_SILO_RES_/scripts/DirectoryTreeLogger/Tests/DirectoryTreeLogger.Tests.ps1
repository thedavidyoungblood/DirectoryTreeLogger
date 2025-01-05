BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot ".." "DirectoryTreeLogger.psm1"
    Import-Module $modulePath -Force
    
    # Create test directory structure
    $testRoot = Join-Path $TestDrive "TestDir"
    New-Item -Path $testRoot -ItemType Directory -Force
    
    # Create test files and directories
    $testStructure = @{
        "EmptyFolder" = $null
        "NonEmptyFolder" = @{
            "file1.txt" = "Content1"
            "file2.txt" = "Content2"
            "SubFolder" = @{
                "subfile1.txt" = "SubContent1"
            }
        }
        "root_file.txt" = "RootContent"
    }
    
    function Create-TestStructure {
        param (
            [string]$Path,
            [hashtable]$Structure
        )
        
        foreach ($key in $Structure.Keys) {
            $itemPath = Join-Path $Path $key
            
            if ($null -eq $Structure[$key]) {
                New-Item -Path $itemPath -ItemType Directory -Force
            }
            elseif ($Structure[$key] -is [hashtable]) {
                New-Item -Path $itemPath -ItemType Directory -Force
                Create-TestStructure -Path $itemPath -Structure $Structure[$key]
            }
            else {
                Set-Content -Path $itemPath -Value $Structure[$key]
            }
        }
    }
    
    Create-TestStructure -Path $testRoot -Structure $testStructure
}

Describe "DirectoryTreeLogger Module Tests" {
    Context "Module Loading" {
        It "Should import the module successfully" {
            Get-Module DirectoryTreeLogger | Should -Not -BeNull
        }
        
        It "Should export the New-DirectoryTreeLog function" {
            Get-Command New-DirectoryTreeLog -ErrorAction SilentlyContinue | Should -Not -BeNull
        }
    }
    
    Context "Basic Functionality" {
        It "Should generate a directory tree log in CLEAN mode" {
            $output = New-DirectoryTreeLog -Path $testRoot -Mode "CLEAN"
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "\[Directory\] NonEmptyFolder"
            $output | Should -Not -Match "\[Directory\] EmptyFolder"
        }
        
        It "Should include file information when specified" {
            $output = New-DirectoryTreeLog -Path $testRoot -Mode "CLEAN" -IncludeFileInfo
            $output | Should -Match "Size: \d+\.\d+MB \| Created: .* \| Modified: .*"
        }
        
        It "Should respect max depth parameter" {
            $output = New-DirectoryTreeLog -Path $testRoot -Mode "EVERYTHING" -MaxDepth 1
            $output | Should -Not -Match "subfile1.txt"
        }
    }
    
    Context "Logging Modes" {
        It "Should only include files in ALL_FILES mode" {
            $output = New-DirectoryTreeLog -Path $testRoot -Mode "ALL_FILES"
            $output | Should -Match "\[File\]"
            $output | Should -Not -Match "\[Directory\]"
        }
        
        It "Should only include folders in ALL_FOLDERS mode" {
            $output = New-DirectoryTreeLog -Path $testRoot -Mode "ALL_FOLDERS"
            $output | Should -Match "\[Directory\]"
            $output | Should -Not -Match "\[File\]"
        }
        
        It "Should include everything in EVERYTHING mode" {
            $output = New-DirectoryTreeLog -Path $testRoot -Mode "EVERYTHING"
            $output | Should -Match "\[Directory\] EmptyFolder"
            $output | Should -Match "\[File\] root_file.txt"
        }
    }
    
    Context "Error Handling" {
        It "Should handle non-existent paths gracefully" {
            { New-DirectoryTreeLog -Path "NonExistentPath" } | Should -Throw
        }
        
        It "Should handle invalid file paths gracefully" {
            $testFile = Join-Path $testRoot "root_file.txt"
            { New-DirectoryTreeLog -Path $testFile } | Should -Throw
        }
    }
    
    Context "Pattern Filtering" {
        It "Should exclude files matching exclude patterns" {
            $output = New-DirectoryTreeLog -Path $testRoot -Mode "EVERYTHING" -ExcludePatterns "*.txt"
            $output | Should -Not -Match "\.txt"
        }
        
        It "Should only include files matching include patterns" {
            $output = New-DirectoryTreeLog -Path $testRoot -Mode "EVERYTHING" -IncludePatterns "file*.txt"
            $output | Should -Match "file1\.txt"
            $output | Should -Not -Match "root_file\.txt"
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Module DirectoryTreeLogger -Force -ErrorAction SilentlyContinue
} 