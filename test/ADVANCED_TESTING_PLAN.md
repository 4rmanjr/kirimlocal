# LocalSend CLI - Advanced Test Suite

## Directory Structure
```
test/
├── integration/
│   ├── test_send_receive.bats
│   ├── test_encryption.bats
│   └── test_compression.bats
├── unit/
│   ├── test_helpers.bats
│   ├── test_validation.bats
│   ├── test_ui.bats
│   └── test_network.bats
├── fixtures/
│   ├── sample.txt
│   └── sample.bin
├── lib/
│   └── assert.bash
└── run_tests.sh
```

## Features
- Unit tests for individual functions
- Integration tests for end-to-end workflows
- Mock network environments
- Comprehensive assertion library
- Parallel test execution
- Coverage reporting
- Continuous integration ready

## Setup
The test suite uses bats-core with additional libraries for advanced testing capabilities.