# LocalSend CLI - Advanced Test Suite

This directory contains the comprehensive test suite for LocalSend CLI, following industry-standard testing practices.

## Directory Structure

```
test/
├── integration/
│   └── test_basic_integration.sh          # Basic integration tests
├── unit/
│   ├── test_helpers_unit.sh              # Helper functions unit tests
│   ├── test_validation_unit.sh           # Validation functions unit tests
│   ├── test_ui_unit.sh                   # UI functions unit tests
│   └── test_network_unit.sh              # Network functions unit tests
├── lib/
│   └── assert.bash                       # Assertion library
├── run_tests.sh                          # Advanced test runner
├── fixtures/                             # Test data files
│   ├── sample.txt
│   └── sample.bin
└── ADVANCED_TESTING_PLAN.md              # Testing strategy document
```

## Testing Features

- **Unit Tests**: Individual function testing
- **Integration Tests**: End-to-end workflow testing
- **Validation Tests**: Input/output validation
- **UI Tests**: Interface component testing
- **Network Tests**: Network functionality testing
- **Advanced Test Runner**: Comprehensive test execution

## Running Tests

### Using Make (Recommended)
```bash
# Run all tests
make test

# Run unit tests only
make unit

# Run integration tests only
make integration

# Run advanced test suite
make advanced-test

# Clean test artifacts
make clean

# Show help
make help
```

### Direct Execution
```bash
# Run the advanced test suite directly
bash test/run_tests.sh

# Run specific test files
bash test/unit/test_helpers_unit.sh
bash test/integration/test_basic_integration.sh
```

## Test Categories

### Unit Tests
- Test individual functions in isolation
- Validate function inputs and outputs
- Check edge cases and error conditions

### Integration Tests
- Test workflows spanning multiple functions
- Validate end-to-end functionality
- Check system behavior under realistic conditions

### Validation Tests
- Verify input validation functions
- Test boundary conditions
- Ensure data integrity

## Test Philosophy

Our testing approach follows these principles:

1. **Comprehensive Coverage**: Test all major functions and workflows
2. **Isolation**: Unit tests focus on individual components
3. **Realism**: Integration tests simulate real usage scenarios
4. **Automation**: All tests can be run automatically
5. **Maintainability**: Clear, readable test code

## Continuous Integration Ready

The test suite is designed to work with CI/CD pipelines:
- Consistent exit codes (0 for pass, non-zero for fail)
- Clear output formatting
- Minimal external dependencies
- Fast execution times

## Adding New Tests

To add new tests:

1. For unit tests, add to the `test/unit/` directory
2. For integration tests, add to the `test/integration/` directory
3. Follow the existing naming convention: `test_<category>_<specificity>.sh`
4. Use the assertion library from `test/lib/assert.bash`
5. Update the Makefile if needed

## Assertion Library

The test suite includes a basic assertion library in `test/lib/assert.bash` with functions like:
- `assert_equal(expected, actual)`
- `assert_success(exit_code)`
- `assert_failure(exit_code)`
- `assert_contains(string, substring)`
- `assert_file_exists(file)`
- `assert_file_not_exists(file)`