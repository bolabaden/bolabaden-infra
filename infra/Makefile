.PHONY: help build test clean validate config-init config-tool install

# Default target
help:
	@echo "Infrastructure Configuration System - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make build          - Build all binaries"
	@echo "  make test           - Run all tests"
	@echo "  make validate       - Validate configuration files"
	@echo "  make config-init     - Run configuration wizard"
	@echo "  make config-tool     - Build configuration tool"
	@echo "  make install        - Install tools to /usr/local/bin"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make docs           - Generate documentation"
	@echo ""

# Build all binaries
build:
	@echo "Building binaries..."
	@mkdir -p bin
	go build -o bin/config-tool ./cmd/config
	go build -o bin/config-init ./cmd/config-init
	@echo "✓ Build complete"

# Run all tests
test:
	@echo "Running tests..."
	go test ./... -v
	@echo "✓ Tests complete"

# Validate configuration
validate: config-tool
	@echo "Validating configurations..."
	@if [ -f config.yaml ]; then \
		./bin/config-tool -config config.yaml -validate; \
	else \
		echo "No config.yaml found. Run 'make config-init' to create one."; \
	fi

# Run configuration wizard
config-init:
	@echo "Running configuration wizard..."
	go run ./cmd/config-init

# Build configuration tool
config-tool:
	@echo "Building config-tool..."
	@mkdir -p bin
	go build -o bin/config-tool ./cmd/config
	@echo "✓ config-tool built"

# Install tools
install: build
	@echo "Installing tools..."
	sudo cp bin/config-tool /usr/local/bin/
	sudo cp bin/config-init /usr/local/bin/ 2>/dev/null || true
	@echo "✓ Tools installed to /usr/local/bin"

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -rf bin/
	go clean ./...
	@echo "✓ Clean complete"

# Generate documentation (placeholder for future doc generation)
docs:
	@echo "Documentation is in docs/ directory"
	@echo "See docs/QUICK_START.md for getting started"
	@echo "See docs/BEST_PRACTICES.md for best practices"

# Quick validation of example configs
validate-examples:
	@echo "Validating example configurations..."
	@for file in config/examples/*.yaml config/templates/*.yaml; do \
		if [ -f "$$file" ]; then \
			echo "Validating $$file..."; \
			./bin/config-tool -config "$$file" -validate || exit 1; \
		fi \
	done
	@echo "✓ All example configs are valid"

# Show configuration summary
show-config:
	@if [ -f config.yaml ]; then \
		./bin/config-tool -config config.yaml; \
	else \
		echo "No config.yaml found. Run 'make config-init' to create one."; \
	fi

# Compare configurations
diff-config:
	@if [ -z "$(DIFF)" ]; then \
		echo "Usage: make diff-config DIFF=other-config.yaml"; \
	else \
		./bin/config-tool -config config.yaml -diff $(DIFF); \
	fi

# Export configuration
export-config:
	@if [ -f config.yaml ]; then \
		./bin/config-tool -config config.yaml -export; \
	else \
		echo "No config.yaml found."; \
	fi

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	@if [ ! -f config.yaml ]; then \
		cp config/templates/development.yaml config.yaml; \
		echo "✓ Created config.yaml from development template"; \
	fi
	@make build
	@make validate
	@echo "✓ Development environment ready"

# Production setup
prod-setup:
	@echo "Setting up production configuration..."
	@if [ ! -f config.production.yaml ]; then \
		cp config/templates/production.yaml config.production.yaml; \
		echo "✓ Created config.production.yaml from production template"; \
		echo "⚠ Remember to edit config.production.yaml with your values"; \
	fi

# Run linter (if golangci-lint is installed)
lint:
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "golangci-lint not installed. Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

# Format code
fmt:
	@echo "Formatting code..."
	go fmt ./...
	@echo "✓ Code formatted"

# Check for common issues
check:
	@echo "Checking for common issues..."
	@go vet ./...
	@go fmt -d . | grep -q . && echo "⚠ Code needs formatting. Run 'make fmt'" || echo "✓ Code is formatted"
	@echo "✓ Checks complete"
