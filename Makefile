# Makefile for KirimLocal CLI Testing

# Default target
.PHONY: test unit integration all clean

# Variables
TEST_DIR = test
UNIT_DIR = $(TEST_DIR)/unit
INTEGRATION_DIR = $(TEST_DIR)/integration
LIB_DIR = $(TEST_DIR)/lib

# Test targets
test: unit integration

unit:
	@echo "Running unit tests..."
	@chmod +x $(UNIT_DIR)/*.sh
	@for test in $(UNIT_DIR)/*.sh; do \
		echo "Running $$test"; \
		bash "$$test" || exit 1; \
	done
	@echo "All unit tests passed!"

integration:
	@echo "Running integration tests..."
	@chmod +x $(INTEGRATION_DIR)/*.sh
	@for test in $(INTEGRATION_DIR)/*.sh; do \
		echo "Running $$test"; \
		bash "$$test" || exit 1; \
	done
	@echo "All integration tests passed!"

all: test

# Advanced test runner
advanced-test:
	@echo "Running advanced test suite..."
	@chmod +x $(TEST_DIR)/run_tests.sh
	@bash $(TEST_DIR)/run_tests.sh

# Clean temporary files
clean:
	@echo "Cleaning test artifacts..."
	@rm -rf /tmp/kirimlocal_test_* 2>/dev/null || true
	@rm -f ~/.kirimlocal_history 2>/dev/null || true
	@[ -f ~/.kirimlocal_history ] && echo "Removed ~/.kirimlocal_history" || echo "~/.kirimlocal_history not found"
	@echo "Clean complete."

# Help target
help:
	@echo "KirimLocal CLI Test Suite"
	@echo "========================="
	@echo "make test           - Run all tests (unit + integration)"
	@echo "make unit           - Run unit tests only"
	@echo "make integration    - Run integration tests only"
	@echo "make advanced-test  - Run the advanced test suite"
	@echo "make all            - Same as 'make test'"
	@echo "make clean          - Clean test artifacts"
	@echo "make help           - Show this help message"