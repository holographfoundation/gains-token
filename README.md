# GAINS & MigrateHLGToGAINS

This repository contains the **GAINS** omnichain token (built on [LayerZero's OFT standard](https://docs.layerzero.network/v2/developers/evm/oft/quickstart)) and a **MigrateHLGToGAINS** contract that facilitates a burn-and-mint migration from HLG (HolographUtilityToken) to GAINS on any chain where GAINS is deployed.

## Overview

- **GAINS**  
  An **Omnichain Fungible Token (OFT)** extending LayerZero's cross-chain token standard. GAINS tokens can be bridged between any supported LayerZero-enabled chain while maintaining a unified supply.

- **MigrateHLGToGAINS**  
  A migration contract that allows users to burn their HLG tokens and receive newly minted GAINS 1:1 on the same chain. The user first approves the migration contract to spend HLG, then calls `migrate(amount)`, which:
  1. Burns the specified amount of HLG from the user's wallet.
  2. Mints an equivalent amount of GAINS tokens to the user's wallet.

Together, these contracts enable a smooth transition from HLG to GAINS, ensuring users maintain the same overall token holdings during the switch.

## Contracts

### GAINS

- **Location**: [`src/GAINS.sol`](./src/GAINS.sol)
- **Key Points**:
  - Inherits from [LayerZero's OFT](https://github.com/LayerZero-Labs/LayerZero-v2/tree/main/packages/layerzero-v2/evm/oapp/contracts/oft).
  - Tracks a single global supply across all chains via `burn` and `mint` operations on each network.
  - Ownership is managed via OpenZeppelin's `Ownable`, with a constructor that sets an initial `_delegate` as the contract owner.
  - Integrates a `migrationContract` address which is allowed to mint new GAINS tokens for the HLG->GAINS migration process.

### MigrateHLGToGAINS

- **Location**: [`src/MigrateHLGToGAINS.sol`](./src/MigrateHLGToGAINS.sol)
- **Key Points**:
  - Accepts approved HLG tokens from users via `burnFrom`.
  - Issues newly minted GAINS tokens to the user 1:1 by calling `mintForMigration` on GAINS.
  - Restricted so only the GAINS owner can designate this contract as the `migrationContract`.

## Repository Structure

```
.
├── src
│   ├── GAINS.sol                    # GAINS Omnichain Fungible Token
│   ├── MigrateHLGToGAINS.sol       # HLG -> GAINS migration contract
│   └── interfaces                   # Interface for HolographERC20 (HLG)
├── script
│   ├── DeployMigrateHLGToGAINS.s.sol  # Foundry script for deterministic deployment
│   ├── BridgeGAINS.s.sol              # Example bridging script for sending GAINS cross-chain
│   ├── SetPeersScript.s.sol           # Script to set cross-chain peer relationships
│   └── ...
├── tests
│   └── ...                         # Unit and integration tests for GAINS & MigrateHLGToGAINS
├── forge.toml / hardhat.config.ts  # Build & test configuration
├── .env.example                    # Environment variables for private keys, RPCs, etc.
└── ...
```

## Installation & Compilation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/YourOrg/GAINS.git
   cd GAINS
   ```

2. **Install dependencies**:

   Foundry:

   ```bash
   forge install
   ```

   Hardhat or both:

   ```bash
   npm install
   # or yarn install / pnpm install
   ```

3. **Configure environment**:

   - Duplicate `.env.example` to `.env`.
   - Populate with your private key(s) and any relevant RPC URLs:

   ```ini
   PRIVATE_KEY=0xabcd1234...
   LZ_ENDPOINT=0x...
   HLG_ADDRESS=0x...
   GAINS_OWNER=0xYourOwnerAddress
   ```

4. **Compile**:

   Foundry:

   ```bash
   forge build
   ```

## Deployment

### Foundry Scripts

#### DeployMigrateHLGToGAINS

Uses CREATE2 for deterministic addresses and ties GAINS to MigrateHLGToGAINS.

```bash
forge script script/DeployMigrateHLGToGAINS.s.sol:DeployMigrateHLGToGAINS \
  --rpc-url <RPC> --broadcast --verify -vvvv
```

#### BridgeGAINSScript

Demonstrates bridging GAINS tokens cross-chain.

```bash
forge script script/BridgeGAINS.s.sol:BridgeGAINSScript --rpc-url <RPC> --broadcast -vvvv
```

#### SetPeersScript

Whitelists cross-chain peers so GAINS contracts trust each other on different endpoints.

```bash
forge script script/SetPeersScript.s.sol:SetPeersScript --rpc-url <RPC> --broadcast -vvvv
```

## Usage

### Migrating HLG -> GAINS

1. Approve the MigrateHLGToGAINS contract to spend HLG:

```solidity
HolographERC20Interface(hlgAddress).approve(migrationContract, amount);
```

2. Call `migration.migrate(amount)` to burn HLG and receive GAINS 1:1:

```solidity
migration.migrate(1e18); // Example: Migrate 1 HLG
```

### Bridging GAINS

1. Approve GAINS for bridging (if needed).
2. Call `gains.send(...)` with the desired SendParam to move tokens cross-chain.

### Cross-Chain Configuration

On each chain, set setPeer to tell GAINS which contract to trust for bridging:

```solidity
GAINS(chainA).setPeer(chainBId, bytes32(address(GAINS(chainB))));
GAINS(chainB).setPeer(chainAId, bytes32(address(GAINS(chainA))));
```

## Testing

Foundry:

```bash
forge test -vv
```

Combined: Add commands in package.json to run both if needed.

## License

This project is licensed under the MIT License.
