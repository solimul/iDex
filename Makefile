include .env

SEPOLIA_RPC                 := https://eth-sepolia.g.alchemy.com/v2/SjLdkEhHuQOTcbPmu57Q_B12M8_smC-I
SEPOLIA_CHAIN               := 11155111
SEPOLIA_API_KEY             := TC2ICV8GXTZTI8XACVKMJRVGUF4P7VUIEZ
SEPOLIA_ETH                 := 0xdd13E55209Fd76AfE204dBda4007C227904f0a81
SEPOLIA_USDC                := 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

ANVIL_RPC                   := http://127.0.0.1:8545
ANVIL_CHAIN                 := 31337

DEPLOYMENT_SCRIPT           := DeployIDex.s.sol

# Format: CONTRACT_TO_LIBS = "contract1:lib1,lib2 contract2:lib3 contract3:"
CONTRACT_TO_LIBS := \
	"LiquidityProvision:BabylonianLib" \
	"IDex:" \
	"Pool:" \
	"ProtocolReward:" \
	"NetworkConfig:" \
	"Shared:"

CONTRACT_TO_PATH := \
	"BabylonianLib:src/libs/BabylonianLib.sol" \
	"LiquidityProvision:src/LiquidityProvision.sol" \
	"IDex:src/IDex.sol" \
	"Pool:src/Pool.sol" \
	"ProtocolReward:src/ProtocolReward.sol" \
	"NetworkConfig:src/NetworkConfig.sol" \
	"Shared:src/Shared.sol"

# ---------------- chain selection ----------------
CHAIN ?= anvil

ifeq ($(CHAIN),anvil)
  RPC         := $(ANVIL_RPC)
  PRIVATE_KEY ?= $(ANVIL_PRIVATE_KEY)
  PRIVATE_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  API_KEY     :=
  ETH         :=
  USDC        :=
else ifeq ($(CHAIN),sepolia)
  RPC         := $(SEPOLIA_RPC)
  PRIVATE_KEY := $(SEPOLIA_PRIVATE_KEY)
  API_KEY     := $(SEPOLIA_API_KEY)
  ETH         := $(SEPOLIA_ETH)
  USDC        := $(SEPOLIA_USDC)
endif

# ---------------- targets ----------------
.PHONY: deploy verify libs all anvil sepolia

deploy:
	forge script script/$(DEPLOYMENT_SCRIPT):DeployIDex \
	  --rpc-url $(RPC) \
	  --private-key $(PRIVATE_KEY) \
	  --broadcast

libs:
ifeq ($(CHAIN),anvil)
	@echo Skipping libs on anvil
else
	@echo Deploying and verifying libraries...
	# deploy_libs.sh expects: RPC PRIVATE_KEY ETHERSCAN_API_KEY
	bash ./deploy_libs.sh "$(RPC)" "$(PRIVATE_KEY)" "$(API_KEY)"
endif

verify:
ifeq ($(CHAIN),anvil)
	@echo Skipping verify on anvil
else
	@echo Verifying contracts on Sepolia Etherscan...
	bash ./verify.sh $(API_KEY) $(SEPOLIA_CHAIN) $(DEPLOYMENT_SCRIPT) $(PRIVATE_KEY) $(USDC) $(ETH) $(CONTRACT_TO_LIBS)
endif

all: deploy libs verify
	@echo Deploy and verify complete

anvil:
	$(MAKE) CHAIN=anvil all

sepolia:
	$(MAKE) CHAIN=sepolia all
