# Directory Tree Logger

A sophisticated PowerShell-based directory tree logging solution with cross-platform support, multiple output formats, and extensive customization options.

## Features

- **Multiple Output Formats**: Support for Text, JSON, and XML output formats
- **Cross-Platform Compatibility**: Works on Windows, Linux, and macOS
- **Extensive Customization**: Configurable filters, formatters, and output options
- **Plugin Architecture**: Extensible design supporting custom formatters and providers
- **Comprehensive Metadata**: Detailed file and directory information
- **Security-Focused**: Path validation, output sanitization, and permission handling
- **Performance Optimized**: Parallel processing and memory management
- **User-Friendly**: Clear progress indicators and error handling

## Installation

### Prerequisites

- PowerShell 7.0 or later
- .NET Core 3.1 or later

### Windows Installation

```powershell
# Clone the repository
git clone https://github.com/user/directory-tree-logger
cd directory-tree-logger

# Run the installation script
.\scripts\DirectoryTreeLogger\Install\install-windows.ps1
```

### Linux Installation

```bash
# Clone the repository
git clone https://github.com/user/directory-tree-logger
cd directory-tree-logger

# Make the installation script executable
chmod +x ./scripts/DirectoryTreeLogger/Install/install-linux.sh

# Run the installation script
./scripts/DirectoryTreeLogger/Install/install-linux.sh
```

### macOS Installation

```bash
# Clone the repository
git clone https://github.com/user/directory-tree-logger
cd directory-tree-logger

# Make the installation script executable
chmod +x ./scripts/DirectoryTreeLogger/Install/install-macos.sh

# Run the installation script
./scripts/DirectoryTreeLogger/Install/install-macos.sh
```

## Quick Start

```powershell
# Import the module
Import-Module DirectoryTreeLogger

# Generate a simple directory tree
Get-DirectoryTree -Path "C:\Projects"

# Generate a detailed JSON report
Get-DirectoryTree -Path "C:\Projects" -Format "JSON" -ShowPermissions -OutputFile "tree.json"

# Generate a filtered tree
Get-DirectoryTree -Path "C:\Projects" `
    -ExcludePattern "node_modules","bin","obj" `
    -MaxDepth 3 `
    -NoFileSize `
    -Format "XML" `
    -OutputFile "tree.xml"
```

## Configuration

The Directory Tree Logger can be configured through:

1. The configuration file (`project.config.json`)
2. Command-line parameters
3. The `Set-DirectoryTreeLoggerConfig` function

### Example Configuration

```powershell
# Set global configuration
Set-DirectoryTreeLoggerConfig -DefaultFormatter "JSON" `
    -MaxDepth 5 `
    -ShowHiddenFiles $true `
    -ShowPermissions $true

# Get current configuration
Get-DirectoryTreeLoggerConfig

# List available formatters
Get-DirectoryTreeLoggerFormatters
```

## Output Formats

### Text Format

```
├── Projects
│   ├── Project1
│   │   ├── src
│   │   │   ├── main.cs (2.5 MB)
│   │   │   └── utils.cs (1.2 MB)
│   │   └── tests
│   └── Project2
```

### JSON Format

```json
{
    "metadata": {
        "generatedAt": "2024-12-31 12:00:00",
        "rootPath": "C:\\Projects"
    },
    "tree": {
        "name": "Projects",
        "type": "Directory",
        "children": [...]
    },
    "statistics": {
        "totalFiles": 42,
        "totalDirectories": 12,
        "totalSize": "128.5 MB"
    }
}
```

### XML Format

```xml
<DirectoryTree>
    <Metadata>
        <GeneratedAt>2024-12-31 12:00:00</GeneratedAt>
        <RootPath>C:\Projects</RootPath>
    </Metadata>
    <Node type="Directory" name="Projects">
        <Children>...</Children>
    </Node>
    <Statistics>
        <TotalFiles>42</TotalFiles>
        <TotalDirectories>12</TotalDirectories>
        <TotalSize>128.5 MB</TotalSize>
    </Statistics>
</DirectoryTree>
```

## Plugin Development

The Directory Tree Logger supports plugins for:

1. Output Formatters
2. Filter Providers
3. Logging Providers

### Creating a Custom Formatter

```powershell
class CustomFormatter : IOutputFormatter {
    [string]$Name = "Custom"
    [string]$Description = "Custom formatter example"
    [string]$Version = "1.0.0"
    [hashtable]$Configuration
    [bool]$IsEnabled = $true
    
    CustomFormatter() {
        $this.Configuration = $this.GetDefaultConfiguration()
    }
    
    [string] Format([FileSystemNode]$tree) {
        # Implementation here
    }
    
    # Additional required methods...
}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- AI-Human Paired Programming Initiative
- PowerShell Community
- Open Source Contributors

## Support

For support, please:

1. Check the [documentation](docs/)
2. Search [existing issues](https://github.com/user/directory-tree-logger/issues)
3. Create a new issue if needed

## Roadmap

- [ ] Additional output formats (HTML, Markdown)
- [ ] Enhanced filtering capabilities
- [ ] Real-time monitoring mode
- [ ] Web-based user interface
- [ ] Cloud storage integration
- [ ] Performance optimizations
``` 