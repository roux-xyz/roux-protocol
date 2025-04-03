# Roux Protocol

The Roux Protocol is a decentralized platform for creating and administering NFT editions with built-in attribution, revenue sharing and distribution, as well as collection curation capabilities.
**The protocol is unaudited, use at your own risk.**

## Overview

Roux Protocol enables creators to:

- Mint NFT editions with customizable parameters
- Create derivative works with proper attribution to parent NFTs
- Curate collections of NFTs
- Automatically distribute revenue sharing to creators in the attribution chain

The protocol utilizes a modular architecture with core contracts handling the fundamental functionality and periphery contracts extending the system's capabilities.

## Core Architecture

### Key Components

1. **Registry** - Manages attribution relationships between NFTs
2. **Controller** - Handles fund distribution, revenue sharing, and fee collection
3. **RouxEdition** - Main contract for minting and managing NFT editions
4. **Collections** - Contracts for curating and bundling NFTs (SingleEditionCollection and MultiEditionCollection)
5. **MintPortal** - Periphery contract for simplified minting and fund management

## Technical Architecture

### Upgradeability

The protocol is upgradeable:

- **Core Contracts**: All core contracts (Registry, Controller) use the ERC1967 proxy pattern for upgradeability
- **Edition Contracts**: Editions use beacon proxies for gas-efficient deployment of multiple instances
- **Namespaced Storage Layout**: Contracts leverage ERC-7201 Namespaced Storage Layouts for safer upgrades

### Factory Pattern

The protocol uses factory contracts:

- **RouxEditionFactory**:

  - Deploys new RouxEdition instances
  - Initializes editions with proper configuration
  - Manages beacon proxy relationships
  - Supports both standard and community editions

- **CollectionFactory**:
  - Creates new collection contracts
  - Handles initialization of collection parameters
  - Manages token bound account creation
  - Supports both single and multi-edition collections

### Token Standards

The protocol implements multiple token standards for different use cases:

- **ERC1155**: Used by RouxEdition for efficient batch minting and management of editions
- **ERC721**: Implemented by Collections for unique collection NFTs
- **ERC6551**: Used for token bound accounts in collections, enabling:
  - Autonomous collection management
  - Direct asset ownership by collections
  - Programmable collection behavior

## Controller

The Controller is the central financial hub of the protocol, managing all fund flows and revenue distribution.

### Core Functions

1. **Fund Recording**

   - Records incoming funds from NFT mints
   - Handles USDC payments and approvals
   - Maintains balances for all recipients
   - Supports batch operations for efficiency

2. **Revenue Distribution**

   - Manages profit sharing between parent and child NFTs
   - Handles platform fees (configurable by admin)
   - Processes referral fees
   - Supports curator fees for collections

3. **Fund Withdrawal**
   - Enables recipients to withdraw their accumulated funds
   - Supports batch withdrawals for efficiency
   - Handles pending fund distribution
   - In practice, the withdraw typically is into a Splits wallet

### Fee Structure

The protocol implements a comprehensive fee system:

- **Platform Fee**: Fee collected by the protocol
- **Referral Fee**: Fee for ecosystem growth
- **Curator Fee**: Fee for collection curators
- **Profit Share**: Configurable percentage between parent and child NFTs

### Attribution Chain

The Controller handles complex attribution chains:

1. When an NFT is minted:

   - Funds are recorded in the Controller
   - Platform and referral fees are calculated and deducted
   - Remaining funds are distributed according to the attribution chain

2. For derivative works:

   - Child NFTs receive their configured profit share
   - Parent NFTs receive the remaining funds
   - This chain can extend multiple levels deep

3. For collections:
   - Collection fees are handled separately
   - Constituent NFT royalties are tracked
   - Curator fees are distributed appropriately

### Safety Features

The Controller includes several safety mechanisms:

- **Pausable**: All fund operations can be paused by admin
- **Upgradeable**: Contract can be upgraded for improvements
- **Access Control**: Strict permissions for admin functions
- **Batch Operations**: Gas-efficient for multiple operations

## Contract Details

### Core Contracts

#### Registry

The Registry maintains attribution data for all NFTs in the system, tracking the parent-child relationships. It's crucial for:

- Recording attribution between derivative works
- Providing a verifiable chain of provenance
- Enabling royalty distribution up the attribution chain

```solidity
function attribution(address edition, uint256 tokenId) external view returns (address, uint256, uint256);
function root(address edition, uint256 tokenId) external view returns (address, uint256, uint256);
function setRegistryData(uint256 tokenId, address parentEdition, uint256 parentTokenId, uint256 index) external;
```

#### Controller

The Controller manages all financial aspects of the protocol, including:

- Revenue sharing distribution
- Fee collection and management
- Fund tracking for creators and platform
- Configurable profit sharing between parent and child NFTs

```solidity
function disburse(address edition, uint256 id, uint256 amount, address referrer) external payable;
function recordFunds(address recipient, uint256 amount) external payable;
function distributePending(address edition, uint256 tokenId) external;
function withdraw(address recipient) external returns (uint256);
```

#### RouxEdition

RouxEdition is the primary NFT contract that implements ERC1155 for editions. Key features:

- Creation of new NFT editions with customizable parameters
- Support for derivative works with attribution
- Integration with the Registry and Controller
- Extensible with custom mint logic

```solidity
function add(EditionData.AddParams calldata p) external returns (uint256);
function mint(address to, uint256 id, uint256 quantity, address referrer, address extension, bytes calldata data) external payable;
function batchMint(address to, uint256[] memory ids, uint256[] memory quantities, address[] memory extensions, address referrer, bytes calldata data) external payable;
```

#### RouxCommunityEdition

An extension of RouxEdition with features focused on community-driven creation:

- Allowlist management for contributors
- Time-windowed contribution phases
- Caps on per-address contributions

#### Collections

Collections enable curation of NFTs, available in two types:

1. **SingleEditionCollection** - Bundles multiple NFTs from a single edition
2. **MultiEditionCollection** - Combines NFTs from multiple editions

Collections use ERC721 and ERC6551 (Token Bound Accounts) to:

- Create a new NFT representing the collection
- Handle minting and royalty distribution for constituent NFTs
- Provide customizable pricing and gating functionality

```solidity
function mint(address to, address extension, address referrer, bytes calldata data) external returns (uint256);
function collection() external view returns (address[] memory itemTargets, uint256[] memory itemIds);
```

### Factories

The protocol implements factory patterns for secure deployment:

1. **RouxEditionFactory** - Deploys and initializes RouxEdition contracts
2. **CollectionFactory** - Creates and initializes Collection contracts with proper configuration

### Periphery Contracts

#### RouxMintPortal

A user-friendly entry point for interacting with the protocol:

- Simplified minting interface
- Stablecoin deposits mint non-transferable credits
- Supports credit card purchases (with integration)
- Support for batch operations
- Handling of promotional tokens and redemptions
- Integration with underlying stablecoin for payment

```solidity
function mintEdition(address to, IRouxEdition edition, uint256 id, uint256 quantity, address extension, address referrer, bytes calldata data) external;
function mintCollection(address to, ICollection collection, address extension, address referrer, bytes calldata data) external;
```

#### Extensions (IExtension)

The protocol supports custom extensions that can modify the minting behavior:

- Custom pricing logic
- Access control and gating
- Special mint conditions and behaviors

## Security Considerations

The protocol is unaudited, use at your own risk

## Deployments

The protocol is deployed on Base. Below are the contract addresses:

| Contract                               | Address                                    |
| -------------------------------------- | ------------------------------------------ |
| Registry Implementation                | 0x662Fb7a45890fA944C539E4592db33a6B940EA1b |
| Registry Proxy                         | 0xc92dfE3B63403ccd4dd71eabADa479b924A92FE7 |
| Controller Implementation              | 0x9E076be14e3eb3D6ff9f975Df6E44A53dDEB1281 |
| Controller Proxy                       | 0x51C95eC7a08ac2CE169108CC7a7635d4b5B9a454 |
| ERC6551 Account Implementation         | 0x2C675c5513Ad3F7148F8C53222cAd3b547791e1f |
| No-Op Implementation                   | 0x902DF152A98fF0EC1a36fc9221a40601e5b2AcA9 |
| RouxEdition Beacon                     | 0x5864dd2EC245552513379aC938Fa0ca8345d7deb |
| RouxEdition Factory Implementation     | 0xfB7C715F90b91a074FfFE64296037F7F5F016e3A |
| RouxEdition Factory Proxy              | 0xa5F8ABe0BaF9a9E95Eeaf3112DAD77dF4962e3D6 |
| SingleEditionCollection Implementation | 0xd00f2287878259a7b96306Efb123128F488B9B3F |
| SingleEditionCollection Beacon         | 0x2970aEc597e4cea66A119C2daB1026D0319BD654 |
| MultiEditionCollection Implementation  | 0xF1A13E7457258cb248FcB762EAd139Fc275E9958 |
| MultiEditionCollection Beacon          | 0x1521a98ACc258e2A6283d348BD121F79F39FA45b |
| Collection Factory Implementation      | 0x07740659E23f6FAf0FAe21BEc63Ea5a13BDf58b9 |
| Collection Factory Proxy               | 0xb1D4b1Dd092FfdDaFF428666c059CA3D6A543e41 |
| RouxEdition Implementation             | 0xcEA0ea58c9734d4B009c7a6741Dafa55e80aed1F |
| RouxMintPortal Implementation          | 0x812fF80d448d6dF86BB870E63B2E72A6C34886b6 |
| RouxMintPortal Proxy                   | 0xc234A25403ADdDD23e0fe76a35bdCD8721d2258D |
| RouxCommunityEdition Implementation    | 0xB0f2c15ad6b8b89c84bCDaC825A1D645D3E07365 |
| RouxCommunityEdition Beacon            | 0xd14eF02bbFD8dB599Fdc29a772A4c6B41f03AfEa |
