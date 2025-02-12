# GAINS & MigrateHLGToGAINS

This repository contains the **GAINS** omnichain token (built on [LayerZero's OFT standard](https://docs.layerzero.network/v2/developers/evm/oft/quickstart)) and the **MigrateHLGToGAINS** contract that facilitates a burn-and-mint migration from HLG (HolographUtilityToken) to GAINS on any chain where GAINS is deployed.

## Overview

- **GAINS**  
  An **Omnichain Fungible Token (OFT)** extending LayerZero's cross-chain token standard. GAINS tokens can be bridged between any supported LayerZero-enabled chain while maintaining a unified supply.

- **MigrateHLGToGAINS**  
  A migration contract that lets users burn their HLG tokens and receive newly minted GAINS 1:1 on the same chain. The user first approves the migration contract to spend HLG, then calls `migrate(amount)`, which:
  1. Burns the specified amount of HLG from the user's wallet.
  2. Mints an equivalent amount of GAINS tokens to the user's wallet.

Together, these contracts ensure a smooth transition from HLG to GAINS, preserving overall token holdings during the migration.

## Contracts

### GAINS

- **Location**: [`src/GAINS.sol`](./src/GAINS.sol)
- **Key Points**:
  - Inherits from [LayerZero's OFT](https://github.com/LayerZero-Labs/LayerZero-v2/tree/main/packages/layerzero-v2/evm/oapp/contracts/oft).
  - Maintains a unified global supply across all chains.
  - Uses OpenZeppelin's `Ownable` for ownership management; the owner is set via the constructor.
  - Contains a `migrationContract` address (settable only once) that is authorized to mint GAINS tokens during migration.

### MigrateHLGToGAINS

- **Location**: [`src/MigrateHLGToGAINS.sol`](./src/MigrateHLGToGAINS.sol)
- **Key Points**:
  - Accepts approved HLG tokens via `burnFrom`.
  - Calls GAINS's `mintForMigration` to mint new tokens 1:1.
  - Ownership is set via a constructor parameter (to avoid accidental ownership by a CREATE2 factory).
  - Provides functions to manage an allowlist (including a batch-add operation).

## Repository Structure

```
.
├── src
│   ├── GAINS.sol                     # GAINS Omnichain Fungible Token
│   ├── MigrateHLGToGAINS.sol        # HLG -> GAINS migration contract
│   └── interfaces                    # Interfaces (e.g., for HolographERC20)
├── script
│   ├── DeployMigrateHLGToGAINS.s.sol # Deterministic deployment via CREATE2 with versioning
│   ├── BridgeGAINS.s.sol             # Example bridging script for GAINS tokens
│   ├── SetPeers.s.sol          # Script to configure cross-chain peers
│   ├── ManageAllowlist.s.sol         # Script to manage the migration allowlist (uses batchAddToAllowlist)
│   ├── TransferOwnership.s.sol       # Script to transfer ownership to a new address (e.g., a Gnosis Safe)
│   └── ...
├── tests
│   └── ...                          # Unit and integration tests for the contracts
├── forge.toml                       # Foundry configuration
├── .env.example                     # Environment variable configuration template
└── README.md                        # This file
```

## Installation & Compilation

1. **Clone the repository**:

```bash
git clone https://github.com/YourOrg/GAINS.git
cd GAINS
```

2. **Install dependencies**:

Using Foundry and pnpm:

```bash
pnpm install
forge install
```

3. **Configure environment variables**:

Copy .env.example to .env and fill in your private keys, RPC URLs, and other addresses:

```ini
PRIVATE_KEY=0xabcd1234...
LZ_ENDPOINT=0x...
HLG_ADDRESS=0x...
GAINS_OWNER=0xYourOwnerAddress
GAINS_CONTRACT=0x...
MIGRATION_CONTRACT=0x...
GNOSIS_SAFE=0x...
DEPLOY_VERSION=V1  # Update this (e.g., "V2") when deploying a new version
```

4. **Compile**:

```bash
forge build
```

## Deployment

### DeployMigrateHLGToGAINS

This script uses CREATE2 for deterministic deployment with versioning. It enforces that either both GAINS and MigrateHLGToGAINS are deployed together for a given version or neither is. To deploy a new version, update the DEPLOY_VERSION variable (e.g., from V1 to V2).

```bash
forge script script/DeployMigrateHLGToGAINS.s.sol:DeployMigrateHLGToGAINS \
  --rpc-url <RPC> --broadcast --verify -vvvv
```

### BridgeGAINSScript

Demonstrates bridging GAINS tokens cross-chain.

```bash
forge script script/BridgeGAINS.s.sol:BridgeGAINSScript --rpc-url <RPC> --broadcast -vvvv
```

### SetPeers

Configures cross-chain peer relationships so GAINS contracts trust each other across different chains.

```bash
forge script script/SetPeers.s.sol:SetPeers --rpc-url <RPC> --broadcast -vvvv
```

### ManageAllowlist

Manages the allowlist in the MigrateHLGToGAINS contract using a JSON file.

Example JSON file allowlist.json:

```json
{
  "allowlist": [
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222"
  ]
}
```

Add addresses:

```bash
forge script script/ManageAllowlist.s.sol:ManageAllowlist \
  --sig "addAddressesFromJson(string,string)" "('./allowlist.json','allowlist')" \
  --rpc-url <RPC> --broadcast
```

Remove addresses:

```bash
forge script script/ManageAllowlist.s.sol:ManageAllowlist \
  --sig "removeAddressesFromJson(string,string)" "('./allowlist.json','allowlist')" \
  --rpc-url <RPC> --broadcast
```

Disable allowlist (if needed):

```bash
forge script script/ManageAllowlist.s.sol:ManageAllowlist \
  --sig "deactivateAllowlist()" \
  --rpc-url <RPC> --broadcast
```

### TransferOwnership

Transfers ownership of the GAINS and MigrateHLGToGAINS contracts to a new owner (e.g., a Gnosis Safe). Ensure your .env variables are set correctly.

```bash
source .env && forge script script/TransferOwnership.s.sol:TransferOwnership \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Usage

### Migrating HLG -> GAINS

Approve the migration contract to spend HLG tokens:

```solidity
HolographERC20Interface(hlgAddress).approve(migrationContract, amount);
```

Migrate tokens by calling:

```solidity
migration.migrate(amount); // Mints GAINS 1:1 after burning HLG
```

### Bridging GAINS

1. Approve GAINS for bridging (if required).
2. Call gains.send(...) with the appropriate parameters to move tokens cross-chain.

### Cross-Chain Configuration

Set peers on each chain so that GAINS contracts trust each other for cross-chain transfers:

```solidity
GAINS(chainA).setPeer(chainBId, bytes32(uint256(uint160(address(GAINS(chainB))))));
GAINS(chainB).setPeer(chainAId, bytes32(uint256(uint160(address(GAINS(chainA))))));
```

## Testing

Run tests with:

```bash
forge test -vv
```

## Generate ABIs

```
./scripts/generate-abis.sh
```

## License

This project is licensed under the MIT License.
