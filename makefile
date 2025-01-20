# ---------------------------------------------------------------------------- #
#                                   Variables                                  #
# ---------------------------------------------------------------------------- #

GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

# ---------------------------------------------------------------------------- #
#                                    Targets                                   #
# ---------------------------------------------------------------------------- #

.PHONY: all fmt build test deploy

## all: Build + Test
all: build test

## fmt: Format code (optional)
fmt:
	@echo "$(YELLOW)✍  Formatting code...$(NC)"
	forge fmt
	@echo "\n$(GREEN)✅ Formatting code completed successfully!$(NC)\n"

# build: Builds the project using Foundry.
build:
	@echo "\n$(YELLOW)🔨 Building the project...$(NC)\n"
	forge build
	@echo "\n$(GREEN)✅ Build completed successfully!$(NC)\n"

## build: Build the contracts
clean:
	@echo "$(YELLOW)🔨 Cleaning contracts...$(NC)"
	forge build
	@echo "\n$(GREEN)✅ Cleaning completed successfully!$(NC)\n"

## test: Run all tests
test: build
	@echo "$(YELLOW)🧪 Running tests...$(NC)"
	forge test -vvv

## deploy: Deploy using Foundry script + CREATE2
deploy:
	@echo "$(YELLOW)🚀 Deploying MigrateHLGToGAINS + GAINS via CREATE2...$(NC)"
	if [ -z "$(RPC_URL)" ]; then \
		echo "$(RED)❌ RPC_URL is not set. Please set it in your environment or .env.$(NC)"; \
		exit 1; \
	else \
		forge script script/DeployMigrateHLGToGAINS.s.sol:DeployMigrateHLGToGAINS \
			--rpc-url $(RPC_URL) \
			--broadcast \
			--verify \
			-vvvv; \
	fi
