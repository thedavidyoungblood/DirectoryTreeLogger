#!/usr/bin/env bats

# Load the script
SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
load "${SCRIPT_DIR}/directory-tree-logger.sh"

# Setup test environment
setup() {
    TEST_DIR="$(mktemp -d)"
    
    # Create test directory structure
    mkdir -p "${TEST_DIR}/EmptyFolder"
    mkdir -p "${TEST_DIR}/NonEmptyFolder/SubFolder"
    
    # Create test files
    echo "Content1" > "${TEST_DIR}/NonEmptyFolder/file1.txt"
    echo "Content2" > "${TEST_DIR}/NonEmptyFolder/file2.txt"
    echo "SubContent1" > "${TEST_DIR}/NonEmptyFolder/SubFolder/subfile1.txt"
    echo "RootContent" > "${TEST_DIR}/root_file.txt"
}

# Cleanup test environment
teardown() {
    rm -rf "${TEST_DIR}"
}

# Test module loading and basic functionality
@test "Script loads successfully" {
    source "${SCRIPT_DIR}/directory-tree-logger.sh"
}

@test "Check required dependencies" {
    run check_dependencies
    [ "$status" -eq 0 ]
}

@test "Validate directory path" {
    run validate_path "${TEST_DIR}"
    [ "$status" -eq 0 ]
}

@test "Reject non-existent path" {
    run validate_path "/nonexistent/path"
    [ "$status" -eq 1 ]
}

@test "Reject file path" {
    run validate_path "${TEST_DIR}/root_file.txt"
    [ "$status" -eq 1 ]
}

# Test different logging modes
@test "Generate tree in CLEAN mode" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=CLEAN"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "NonEmptyFolder" ]]
    [[ ! "${output}" =~ "EmptyFolder" ]]
}

@test "Generate tree in ALL_FILES mode" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=ALL_FILES"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "[File]" ]]
    [[ ! "${output}" =~ "[Directory]" ]]
}

@test "Generate tree in ALL_FOLDERS mode" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=ALL_FOLDERS"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "[Directory]" ]]
    [[ ! "${output}" =~ "[File]" ]]
}

@test "Generate tree in EVERYTHING mode" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=EVERYTHING"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "EmptyFolder" ]]
    [[ "${output}" =~ "root_file.txt" ]]
}

# Test file information and filtering
@test "Include file information" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=CLEAN" "--include-info"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "Size:" ]]
    [[ "${output}" =~ "Created:" ]]
    [[ "${output}" =~ "Modified:" ]]
}

@test "Respect max depth parameter" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=EVERYTHING" "--max-depth=1"
    [ "$status" -eq 0 ]
    [[ ! "${output}" =~ "subfile1.txt" ]]
}

@test "Apply exclude pattern" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=EVERYTHING" "--exclude=*.txt"
    [ "$status" -eq 0 ]
    [[ ! "${output}" =~ ".txt" ]]
}

@test "Apply include pattern" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=EVERYTHING" "--include=file*.txt"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "file1.txt" ]]
    [[ ! "${output}" =~ "root_file.txt" ]]
}

# Test output handling
@test "Save output to file" {
    OUTPUT_FILE="${TEST_DIR}/tree.log"
    run generate_directory_tree_log "${TEST_DIR}" "--output=${OUTPUT_FILE}"
    [ "$status" -eq 0 ]
    [ -f "${OUTPUT_FILE}" ]
    [[ "$(cat "${OUTPUT_FILE}")" =~ "NonEmptyFolder" ]]
}

# Test error handling
@test "Handle invalid mode gracefully" {
    run generate_directory_tree_log "${TEST_DIR}" "--mode=INVALID"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "Unknown option" ]]
}

@test "Handle missing path argument" {
    run main
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "Usage:" ]]
}

# Test configuration management
@test "Load default configuration when config file is missing" {
    run load_configuration
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "Using default configuration" ]]
}

# Test progress indication
@test "Show progress by default" {
    run generate_directory_tree_log "${TEST_DIR}"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "Generating directory tree..." ]]
    [[ "${output}" =~ "Directory Tree Logger completed" ]]
}

@test "Hide progress when requested" {
    run generate_directory_tree_log "${TEST_DIR}" "--no-progress"
    [ "$status" -eq 0 ]
    [[ ! "${output}" =~ "Generating directory tree..." ]]
} 