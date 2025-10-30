.PHONY: install uninstall check test refresh help

INSTALL_PATH := /usr/local/bin/token
SCRIPT_PATH := $(CURDIR)/token.sh

help:
	@echo "Token CLI - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make check      - Check if dependencies are installed"
	@echo "  make install    - Install token command globally"
	@echo "  make uninstall  - Remove token command"
	@echo "  make refresh    - Update token list from web"
	@echo "  make test       - Run example searches"
	@echo "  make help       - Show this help message"

check:
	@echo "Checking dependencies..."
	@command -v jq >/dev/null 2>&1 || { echo "❌ jq is not installed. Run: brew install jq"; exit 1; }
	@echo "✓ jq is installed"
	@command -v curl >/dev/null 2>&1 || { echo "❌ curl is not installed. Run: brew install curl"; exit 1; }
	@echo "✓ curl is installed"
	@test -f "$(SCRIPT_PATH)" || { echo "❌ token.sh not found"; exit 1; }
	@echo "✓ token.sh found"
	@echo "✓ All dependencies are satisfied"

install: check
	@echo "Installing token command..."
	@chmod +x "$(SCRIPT_PATH)"
	@ln -sf "$(SCRIPT_PATH)" "$(INSTALL_PATH)"
	@echo "✓ Installed to $(INSTALL_PATH)"
	@echo ""
	@echo "You can now use: token 1 USDC"

uninstall:
	@echo "Uninstalling token command..."
	@rm -f "$(INSTALL_PATH)"
	@echo "✓ Removed $(INSTALL_PATH)"

refresh: check
	@echo "Updating token list..."
	@./token.sh --refresh
	@echo ""

test: check
	@echo "Running test queries..."
	@echo ""
	@echo "Test 1: Find USDC on Ethereum (chainId 1)"
	@./token.sh 1 USDC | head -5
	@echo ""
	@echo "Test 2: Find WETH across all chains"
	@./token.sh WETH | head -10
	@echo ""
	@echo "✓ Tests completed"

