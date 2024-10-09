#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to convert to uppercase
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Load environment variables from .env file
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
    echo ".env file found and loaded."
else
    echo ".env file not found in the current directory."
    exit 1
fi

# Debugging: Print loaded environment variables
echo "Loaded environment variables:"
echo "BASE_SEPOLIA_RPC_URL: $BASE_SEPOLIA_RPC_URL"
echo "NETWORK: $NETWORK"
echo "ACCOUNT: $ACCOUNT"
echo "SENDER: $SENDER"

# Path to your JSON file
JSON_FILE="deployments/baseSepolia.json"

# Check if JSON file exists
if [ -f "$JSON_FILE" ]; then
    echo "Parsing $JSON_FILE for deployment variables..."
    
    # Extract variables using jq and assign to bash variables
    REGISTRY_IMPL=$(jq -r '.REGISTRY_IMPL' "$JSON_FILE")
    REGISTRY_PROXY=$(jq -r '.REGISTRY_PROXY' "$JSON_FILE")
    CONTROLLER_IMPL=$(jq -r '.CONTROLLER_IMPL' "$JSON_FILE")
    CONTROLLER_PROXY=$(jq -r '.CONTROLLER_PROXY' "$JSON_FILE")
    ERC_6551_ACCOUNT_IMPL=$(jq -r '.ERC_6551_ACCOUNT_IMPL' "$JSON_FILE")
    ERC_6551_REGISTRY=$(jq -r '.ERC_6551_REGISTRY' "$JSON_FILE")
    NO_OP_IMPL=$(jq -r '.NO_OP_IMPL' "$JSON_FILE")
    ROUX_EDITION_BEACON=$(jq -r '.ROUX_EDITION_BEACON' "$JSON_FILE")
    ROUX_EDITION_FACTORY_IMPL=$(jq -r '.ROUX_EDITION_FACTORY_IMPL' "$JSON_FILE")
    ROUX_EDITION_FACTORY_PROXY=$(jq -r '.ROUX_EDITION_FACTORY_PROXY' "$JSON_FILE")
    SINGLE_EDITION_COLLECTION_IMPL=$(jq -r '.SINGLE_EDITION_COLLECTION_IMPL' "$JSON_FILE")
    SINGLE_EDITION_COLLECTION_BEACON=$(jq -r '.SINGLE_EDITION_COLLECTION_BEACON' "$JSON_FILE")
    MULTI_EDITION_COLLECTION_IMPL=$(jq -r '.MULTI_EDITION_COLLECTION_IMPL' "$JSON_FILE")
    MULTI_EDITION_COLLECTION_BEACON=$(jq -r '.MULTI_EDITION_COLLECTION_BEACON' "$JSON_FILE")
    COLLECTION_FACTORY_IMPL=$(jq -r '.COLLECTION_FACTORY_IMPL' "$JSON_FILE")
    COLLECTION_FACTORY_PROXY=$(jq -r '.COLLECTION_FACTORY_PROXY' "$JSON_FILE")
    ROUX_MINT_PORTAL_IMPL=$(jq -r '.ROUX_MINT_PORTAL_IMPL' "$JSON_FILE")
    ROUX_MINT_PORTAL_PROXY=$(jq -r '.ROUX_MINT_PORTAL_PROXY' "$JSON_FILE")
    USDC_BASE_SEPOLIA=$(jq -r '.USDC_BASE_SEPOLIA' "$JSON_FILE")
    
    echo "Parsed deployment variables from $JSON_FILE"
else
    echo "JSON file $JSON_FILE not found!"
    exit 1
fi

# Function to deploy a contract
run() {
    local network="$1"
    local rpc_url_var="$2"
    local contract="$3"
    local args="$4"

    case $network in
        "local")
            echo "Running locally"
            forge script "$contract" --fork-url http://localhost:8545 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --broadcast -vvvv $args
            ;;
        "sepolia"|"mainnet"|"base_sepolia"|"base")
            local upper_network=$(to_upper "$network")
            local upper_rpc_url_var="${upper_network}_RPC_URL"
            local rpc_url="${!upper_rpc_url_var}"
            if [[ -z $rpc_url ]]; then
                echo "$upper_rpc_url_var is not set"
                exit 1
            fi
            echo "Running on $network"
            if [ ! -z $LEDGER_DERIVATION_PATH ]; then
                forge script "$contract" --rpc-url "$rpc_url" --ledger --hd-paths $LEDGER_DERIVATION_PATH --sender $LEDGER_ADDRESS --broadcast -vvvv $args
            elif [ ! -z $ACCOUNT ]; then
                echo "Running with account $ACCOUNT"
                # We use both --account and --sender to ensure the signing account and simulated sender are the same
                forge script "$contract" --rpc-url "$rpc_url" --account "$ACCOUNT" --sender "$SENDER" --broadcast -vvvv $args
            elif [ ! -z $PRIVATE_KEY ]; then
                echo "Running with private key"
                forge script "$contract" --rpc-url "$rpc_url" --private-key "$PRIVATE_KEY" --broadcast -vvvv $args
            else
                echo "No account specified. Please set ACCOUNT, PRIVATE_KEY, or configure a Ledger."
                exit 1
            fi
            ;;
        *)
            echo "Invalid NETWORK value"
            exit 1
            ;;
    esac
}

# usage, in deployment order
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy-registry"
    echo "  deploy-controller"
    echo "  deploy-erc6551-account"
    echo "  deploy-no-op"
    echo "  deploy-edition-beacon"
    echo "  deploy-edition-factory"
    echo "  deploy-single-edition-collection-impl"
    echo "  deploy-multi-edition-collection-impl"
    echo "  deploy-collection-factory"
    echo "  deploy-edition-impl"
    echo "  upgrade-edition-beacon <new_implementation>"
    echo "  deploy-mint-portal"
    echo "  upgrade-controller"
    echo "  upgrade-single-edition-collection"
    echo "  upgrade-multi-edition-collection"
    echo "  upgrade-collection-factory"
    echo ""
    echo "Options:"
    echo "  NETWORK: Set this environment variable to either 'local', 'sepolia', 'base_sepolia', 'base', or 'mainnet'"
}

### Deployment Manager ###

DEPLOYMENTS_FILE="deployments/${NETWORK}.json"

if [[ -z "$NETWORK" ]]; then
    echo "Error: Set NETWORK to 'local', 'sepolia', 'base_sepolia', 'base', or 'mainnet'."
    echo ""
    usage
    exit 1
fi

case $1 in

    "deploy-registry")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-registry"
            exit 1
        fi

        echo "Deploying Registry"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployRegistry.s.sol:DeployRegistry" "--sig run()"
        ;;

    "deploy-controller")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-controller"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$REGISTRY_PROXY" ] || [ -z "$USDC_BASE_SEPOLIA" ]; then
            echo "Error: REGISTRY_PROXY or USDC_BASE_SEPOLIA is not set."
            exit 1
        fi

        echo "Deploying Controller"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployController.s.sol:DeployController" "--sig run(address,address) $REGISTRY_PROXY $USDC_BASE_SEPOLIA"
        ;;

    "deploy-erc6551-account")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-erc6551-account"
            exit 1
        fi

        echo "Deploying ERC6551Account"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployERC6551Account.s.sol:DeployERC6551Account" "--sig run()"
        ;;

    "deploy-no-op")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-no-op"
            exit 1
        fi

        echo "Deploying NoOp Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployNoOp.s.sol:DeployNoOp" "--sig run()"
        ;;

    "deploy-edition-beacon")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-edition-beacon"
            exit 1
        fi

        echo "Deploying Edition Beacon"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionBeacon.s.sol:DeployEditionBeacon" "--sig run(address) $NO_OP_IMPL"
        ;;

    "deploy-edition-factory")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-edition-factory"
            exit 1
        fi

        echo "Deploying EditionFactory"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionFactory.s.sol:DeployEditionFactory" "--sig run(address) $ROUX_EDITION_BEACON"
        ;;

    "deploy-single-edition-collection-impl")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-single-edition-collection-impl"
            exit 1
        fi

        echo "Deploying SingleEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeploySingleEditionCollectionImpl.s.sol:DeploySingleEditionCollectionImpl" "--sig run(address,address,address,address) $ERC_6551_REGISTRY $ERC_6551_ACCOUNT_IMPL $ROUX_EDITION_FACTORY_PROXY $CONTROLLER_PROXY"
        ;;

    "deploy-multi-edition-collection-impl")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-multi-edition-collection-impl"
            exit 1
        fi

        echo "Deploying MultiEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployMultiEditionCollectionImpl.s.sol:DeployMultiEditionCollectionImpl" "--sig run(address,address,address,address) $ERC_6551_REGISTRY $ERC_6551_ACCOUNT_IMPL $ROUX_EDITION_FACTORY_PROXY $CONTROLLER_PROXY"
        ;;

    "deploy-collection-factory")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-collection-factory"
            exit 1
        fi

        echo "Deploying CollectionFactory"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployCollectionFactory.s.sol:DeployCollectionFactory" "--sig run(address,address) $SINGLE_EDITION_COLLECTION_BEACON $MULTI_EDITION_COLLECTION_BEACON"
        ;;

    "deploy-mint-portal")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-mint-portal"
            exit 1
        fi

        echo "Deploying MintPortal"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployMintPortal.s.sol:DeployMintPortal" "--sig run(address,address,address) $USDC_BASE_SEPOLIA $ROUX_EDITION_FACTORY_PROXY $COLLECTION_FACTORY_PROXY"
        ;;

    "deploy-edition-impl")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-edition-impl"
            exit 1
        fi

        echo "Deploying Edition Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionImpl.s.sol:DeployEditionImpl" "--sig run(address,address,address,address) $ROUX_EDITION_FACTORY_PROXY $COLLECTION_FACTORY_PROXY $CONTROLLER_PROXY $REGISTRY_PROXY"
        ;;

    "upgrade-edition-beacon")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 upgrade-edition-beacon <new_implementation>"
            exit 1
        fi

        echo "Upgrading Edition Beacon"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeEditionBeacon.s.sol:UpgradeEditionBeacon" "--sig run(address,address) $ROUX_EDITION_BEACON $2"
        ;;

    "upgrade-controller")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 upgrade-controller"
            exit 1
        fi

        echo "Upgrading Controller Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeController.s.sol:UpgradeController" "--sig run(address,address,address) $CONTROLLER_PROXY $REGISTRY_PROXY $USDC_BASE_SEPOLIA"
        ;;

    "upgrade-single-edition-collection")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 upgrade-single-edition-collection"
            exit 1
        fi

        echo "Upgrading SingleEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeSingleEditionCollection.s.sol:UpgradeSingleEditionCollection" "--sig run(address,address,address,address,address) $SINGLE_EDITION_COLLECTION_BEACON $ERC_6551_REGISTRY $ERC_6551_ACCOUNT_IMPL $ROUX_EDITION_FACTORY_PROXY $CONTROLLER_PROXY"
        ;;

    "upgrade-multi-edition-collection")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 upgrade-multi-edition-collection"
            exit 1
        fi

        echo "Upgrading MultiEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeMultiEditionCollection.s.sol:UpgradeMultiEditionCollection" "--sig run(address,address,address,address,address) $MULTI_EDITION_COLLECTION_BEACON $ERC_6551_REGISTRY $ERC_6551_ACCOUNT_IMPL $ROUX_EDITION_FACTORY_PROXY $CONTROLLER_PROXY"
        ;;

    "upgrade-collection-factory")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 upgrade-collection-factory"
            exit 1
        fi

        echo "Upgrading CollectionFactory Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeCollectionFactory.s.sol:UpgradeCollectionFactory" "--sig run(address,address,address) $COLLECTION_FACTORY_PROXY $SINGLE_EDITION_COLLECTION_BEACON $MULTI_EDITION_COLLECTION_BEACON"
        ;;

    *)
        echo "Invalid command"
        usage
        exit 1
        ;;
esac
