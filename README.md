# Dataset Bonding Curve Smart Contracts

This repository contains smart contracts implementing a bonding curve mechanism for dataset tokens. The system allows for the creation and pricing of dataset tokens using a bonding curve pricing model.

## Overview

The project consists of two main contracts:

1. **DatasetToken**: An ERC1155-based token contract for representing datasets
2. **DatasetBondingCurve**: A contract implementing the bonding curve pricing mechanism with the following features:
   - Initial price: 0.01 ETH
   - Price multiplier: 1.5x increase per token
   - Automated price calculation based on token supply

## Contract Functions

### DatasetToken Contract (`DeployDataset.sol`)

#### Core Functions
- `mintDatasetToken(OwnershipShare[], string, string, string, string, uint256, string[])`: Mints a new dataset token with multiple owners, metadata, and initial price
- `purchaseDataset(uint256)`: Allows users to purchase a dataset token at the current bonding curve price
- `setBondingCurve(address)`: Sets the bonding curve contract address (admin only)
- `updatePrice(uint256, uint256)`: Updates the price of a dataset (primary owner only)

#### View Functions
- `getTokensByTag(string)`: Returns all token IDs associated with a specific tag
- `getTokenTags(uint256)`: Returns all tags for a specific token
- `getTokenOwners(uint256)`: Returns ownership information for a token
- `getTotalTokens()`: Returns the total number of tokens minted
- `getTokensByOwner(address)`: Returns all token IDs owned by an address
- `getDatasetIPFSHash(uint256)`: Returns the IPFS hash for a purchased dataset

### DatasetBondingCurve Contract

#### Core Functions
- `setInitialPrice(uint256, uint256)`: Sets the initial price for a token's bonding curve
- `calculatePrice(uint256)`: Calculates the current price for a specific token
- `getCurrentPrice(uint256)`: View function to get the current price
- `recordPurchase(uint256)`: Records a purchase to update the bonding curve
- `updateDatasetTokenAddress(address)`: Updates the dataset token contract address

## User Workflow

### For Dataset Owners

1. **Creating a Dataset Token**
   ```solidity
   // Example ownership structure
   OwnershipShare[] shares = [
       OwnershipShare(owner1, 7000), // 70%
       OwnershipShare(owner2, 3000)  // 30%
   ];
   
   // Mint token with metadata
   datasetToken.mintDatasetToken(
       shares,
       "Dataset Name",
       "Description",
       "contentHash",
       "ipfsHash",
       initialPrice,
       ["tag1", "tag2"]
   );
   ```

2. **Managing Dataset**
   - Update price if needed using `updatePrice()`
   - Monitor ownership and sales through events
   - Add or remove tags as needed

### For Dataset Buyers

1. **Discovering Datasets**
   - Browse datasets by tags using `getTokensByTag()`
   - View dataset metadata and ownership information
   - Check current prices using `getCurrentPrice()`

2. **Purchasing a Dataset**
   ```solidity
   // Get current price
   uint256 price = bondingCurve.getCurrentPrice(tokenId);
   
   // Purchase dataset
   datasetToken.purchaseDataset{value: price}(tokenId);
   ```

3. **Accessing Dataset**
   - After purchase, retrieve IPFS hash using `getDatasetIPFSHash()`
   - Access dataset content through IPFS

### Price Mechanism

The bonding curve implements an automated market maker with the following characteristics:

1. **Initial Pricing**
   - Each dataset starts at its set initial price
   - Price increases by 1.5x after each purchase

2. **Price Calculation**
   ```
   Current Price = Initial Price * (1.5 ^ Number of Purchases)
   ```

3. **Revenue Distribution**
   - Sales revenue is automatically distributed to owners based on their ownership percentages
   - Payments are instant and trustless

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Ethereum wallet with some ETH for deployment
- Environment variables set up (see Configuration section)

## Installation

1. Clone the repository:
```shell
git clone <repository-url>
cd <repository-name>
```

2. Install dependencies:
```shell
forge install
```

## Configuration

Create a `.env` file in the root directory with the following variables:
```
PRIVATE_KEY=your_private_key
RPC_URL=your_rpc_url
```

## Building

To build the contracts:
```shell
forge build
```

## Testing

Run the test suite:
```shell
forge test
```

For more detailed test output:
```shell
forge test -vv
```

For gas reports:
```shell
forge test --gas-report
```

## Deployment

The deployment process involves two steps:

1. Deploy the DatasetToken contract
2. Deploy the DatasetBondingCurve contract

To deploy the contracts:
```shell
source .env
forge script script/DeployBondingCurve.s.sol:DeployBondingCurve --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Security

- The contracts use OpenZeppelin's standard implementations for security
- Ownership controls are in place for administrative functions
- Price calculations are done with proper decimal handling to prevent rounding errors
- Reentrancy protection is implemented for all state-changing functions
- Multi-owner support with percentage-based revenue distribution
