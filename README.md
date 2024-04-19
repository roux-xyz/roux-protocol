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

**Create RouxEdition from RouxEditionFactory**

`cast send --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL $CONTRACT_FACTORY "create()"`

**Add Recipe Token**

1. export contract instance created in `create` call above to env var $EDTIION
2. `cast send --private-key $PK --rpc-url $SEPOLIA_RPC_URL $EDITION "add(uint64,uint128,uint40,uint40,string)" <maxSupply> <price>  <mintStart> <mintDuration> <uri>`
3. e.g. `cast send --private-key $PK --rpc-url $SEPOLIA_RPC_URL $CREATOR "add(uint256,uint256,string)" 10000 50000000000000000 1711956272 31536000 https://test-token-edition-1.com`

**Mint Recipe Token**

_Note --value flag i.e. how much eth is being sent with transaction_

1. `cast send --private-key $PK_USER --rpc-url $SEPOLIA_RPC_URL --value <value>  $CREATOR "mint(address,uint256,uint256)" <to> <tokenId> <quantity>`
2. e.g. `cast send --private-key $PK_USER --rpc-url $SEPOLIA_RPC_URL --value 0.05ether  $CREATOR "mint(address,uint256,uint256)" 0xCCd88E7DFA55EA54667A52e9B54664fB21075bE5 1 1`
