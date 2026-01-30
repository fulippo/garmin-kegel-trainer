# Kegel Trainer Makefile
# Garmin Connect IQ Build Configuration

# Configuration - Update these paths for your system
DEVICE ?= fenix7
PRIVATE_KEY ?= $(HOME)/Workspace/connectIQ/developer_key
APP_NAME = KegelTrainer
SDK_HOME ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc

# Tool paths (adjust if SDK is in different location)
MONKEYC = "$(SDK_HOME)/bin/monkeyc"
MONKEYDO = "$(SDK_HOME)/bin/monkeydo"
CONNECTIQ = "$(SDK_HOME)/bin/connectiq"

# Build output directory
BIN_DIR = bin

.PHONY: all build run simulator release clean help

# Default target
all: build

# Create bin directory
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Build debug version
build: $(BIN_DIR)
	$(MONKEYC) \
		--jungles ./monkey.jungle \
		--device $(DEVICE) \
		--output $(BIN_DIR)/$(APP_NAME).prg \
		--private-key $(PRIVATE_KEY) \
		--warn

# Start the Connect IQ simulator
simulator:
	$(CONNECTIQ) &

# Build and run in simulator
run: build
	$(MONKEYDO) $(BIN_DIR)/$(APP_NAME).prg $(DEVICE)

# Build release version (.iq file for distribution)
release: $(BIN_DIR)
	$(MONKEYC) \
		--jungles ./monkey.jungle \
		--output $(BIN_DIR)/$(APP_NAME).iq \
		--private-key $(PRIVATE_KEY) \
		--package-app \
		--release

# Clean build artifacts
clean:
	rm -rf $(BIN_DIR)

# Show help
help:
	@echo "Kegel Trainer Build Commands"
	@echo ""
	@echo "Usage: make [target] [DEVICE=device_name]"
	@echo ""
	@echo "Targets:"
	@echo "  build      - Compile debug version (default)"
	@echo "  run        - Build and run in simulator"
	@echo "  simulator  - Start the Connect IQ simulator"
	@echo "  release    - Compile release version (.iq file)"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  DEVICE      - Target device (default: fenix7)"
	@echo "  PRIVATE_KEY - Path to developer key"
	@echo "  SDK_HOME    - Path to Connect IQ SDK"
	@echo ""
	@echo "Examples:"
	@echo "  make build DEVICE=venu2"
	@echo "  make run DEVICE=fenix7"
	@echo "  make release"
