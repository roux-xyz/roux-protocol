## Roux Protocol

### Setup

run `foundryup`

run `forge install` to install dependencies

### Deployment

`chmod +x deployment-manager.sh`

`export NETWORK=<network>`

**If local:**

run `anvil` in a different terminal window

**If not local:**

`export ${CHAIN}_RPC_URL=<chain-url>`

`export PRIVATE_KEY=<private-key>`

`./deployment-manager.sh <command> <args>`

### Print ABI:

`jq '.abi' ./out/<Contract>.sol/<Contract>.json`

### erc6551 registry

`0x000000006551c19487814612e58FE06813775758`

### Using cast to make calls

**Set up Contract Address env vars**

1. `export $CONTRACT_FACTORY=0x...`
2. `export $COL_FACTORY=0x...`

**Create RouxCreator from RouxCreatorFactory**

---

1. ABI-encode `params`: `cast abi-encode "f(address)" <ownerAddress>`
2. Send txn: `cast send --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL $CONTRACT_FACTORY "create(bytes)" <params>`

**Add Recipe Token**

1. export contract instance created in `create` call above to env var $CREATOR
2. `cast send --private-key $PK --rpc-url $SEPOLIA_RPC_URL $CREATOR "add(uint64,uint128,uint40,uint32,string)" <maxSupply> <price>  <mintStart> <mintDuration> <uri>`
3. e.g. `cast send --private-key $PK --rpc-url $SEPOLIA_RPC_URL $CREATOR "add(uint256,uint256,string)" 10000 50000000000000000 1711956272 31536000 https://test-token-creator-1.com`

**Mint Recipe Token**

_Note --value flag i.e. how much eth is being sent with transaction_

1. `cast send --private-key $PK_USER --rpc-url $SEPOLIA_RPC_URL --value <value>  $CREATOR "mint(address,uint256,uint256)" <to> <tokenId> <quantity>`
2. e.g. `cast send --private-key $PK_USER --rpc-url $SEPOLIA_RPC_URL --value 0.05ether  $CREATOR "mint(address,uint256,uint256)" 0xCCd88E7DFA55EA54667A52e9B54664fB21075bE5 1 1`

**Create Collection**

1. ABI-encode `params`: `cast abi-encode "f(address,string,address[],uint256[])" <baseURI> "[<creatorAddr1>, <creatorAddr2>, ..., <creatorAddrN>]" "[<tokenId1>, <tokenId2>, ..., <tokenIdN>]"`
2. e.g. `cast abi-encode "f(address,address[],uint256[])" http://example.com "[0xa8f6658ecfae3e1531470efa5b00d78082c0050e]" "[1]"`
3. `cast send --private-key $PK_CREATOR --rpc-url $SEPOLIA_RPC_URL $COL_FACTORY "create(bytes)" <params>`

**Mint Collection**

1. export contract instance created above to env var $COLLECTION
2. `cast send --private-key $PK_USER --rpc-url $SEPOLIA_RPC_URL --value 0.05ether $COLLECTION "mint()"`
