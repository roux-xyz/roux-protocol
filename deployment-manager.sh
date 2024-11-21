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

# function parse json key
parse_json_key() {
    local key="$1"
    jq -r ".$key" "$JSON_FILE"
}

# debug mode
if [[ "$DEBUG" == "true" ]]; then
    echo "Executing: forge script $contract with args $args"
fi


# Debugging: Print loaded environment variables
echo "Loaded environment variables:"
echo "BASE_RPC_URL: $BASE_RPC_URL"
echo "BASE_SEPOLIA_RPC_URL: $BASE_SEPOLIA_RPC_URL"
echo "NETWORK: $NETWORK"
echo "ACCOUNT: $ACCOUNT"
echo "SENDER: $SENDER"
echo "KEYSTORE: $KEYSTORE"
echo "USDC_BASE: $USDC_BASE"

# Path to your JSON file
JSON_FILE="deployments/$NETWORK.json"

# Check if JSON file exists
if [ -f "$JSON_FILE" ]; then
    echo "Parsing $JSON_FILE for deployment variables..."
    
    # Extract variables using jq and assign to bash variables
    REGISTRY_IMPL=$(parse_json_key "REGISTRY_IMPL")
    REGISTRY_PROXY=$(parse_json_key "REGISTRY_PROXY")
    CONTROLLER_IMPL=$(parse_json_key "CONTROLLER_IMPL")
    CONTROLLER_PROXY=$(parse_json_key "CONTROLLER_PROXY")
    ERC_6551_ACCOUNT_IMPL=$(parse_json_key "ERC_6551_ACCOUNT_IMPL")
    ERC_6551_REGISTRY=$(parse_json_key "ERC_6551_REGISTRY")
    NO_OP_IMPL=$(parse_json_key "NO_OP_IMPL")
    ROUX_EDITION_BEACON=$(parse_json_key "ROUX_EDITION_BEACON")
    ROUX_EDITION_FACTORY_IMPL=$(parse_json_key "ROUX_EDITION_FACTORY_IMPL")
    ROUX_EDITION_FACTORY_PROXY=$(parse_json_key "ROUX_EDITION_FACTORY_PROXY")
    ROUX_COMMUNITY_EDITION_BEACON=$(parse_json_key "ROUX_COMMUNITY_EDITION_BEACON")
    SINGLE_EDITION_COLLECTION_IMPL=$(parse_json_key "SINGLE_EDITION_COLLECTION_IMPL")
    SINGLE_EDITION_COLLECTION_BEACON=$(parse_json_key "SINGLE_EDITION_COLLECTION_BEACON")
    MULTI_EDITION_COLLECTION_IMPL=$(parse_json_key "MULTI_EDITION_COLLECTION_IMPL")
    MULTI_EDITION_COLLECTION_BEACON=$(parse_json_key "MULTI_EDITION_COLLECTION_BEACON")
    COLLECTION_FACTORY_IMPL=$(parse_json_key "COLLECTION_FACTORY_IMPL")
    COLLECTION_FACTORY_PROXY=$(parse_json_key "COLLECTION_FACTORY_PROXY")
    ROUX_MINT_PORTAL_IMPL=$(parse_json_key "ROUX_MINT_PORTAL_IMPL")
    ROUX_MINT_PORTAL_PROXY=$(parse_json_key "ROUX_MINT_PORTAL_PROXY")
    USDC_BASE=$(parse_json_key "USDC_BASE")
    
    echo "Parsed deployment variables from $JSON_FILE"
    echo "USDC_BASE: $USDC_BASE"
else
    echo "JSON file $JSON_FILE not found!"
    exit 1
fi

# deploy contract
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

            if [[ $network == "base" && ! -z $KEYSTORE ]]; then
                echo "Running with keystore $KEYSTORE on base network"
                forge script "$contract" --rpc-url "$rpc_url" --keystore "$KEYSTORE" --sender "$SENDER" --broadcast --verify -vvvv $args
            elif [[ $network == "base_sepolia" && ! -z $ACCOUNT ]]; then
                echo "Running with account $ACCOUNT on base_sepolia network"
                forge script "$contract" --rpc-url "$rpc_url" --account "$ACCOUNT" --sender "$SENDER" --broadcast -vvvv $args
            elif [ ! -z $PRIVATE_KEY ]; then
                echo "Running with private key"
                forge script "$contract" --rpc-url "$rpc_url" --private-key "$PRIVATE_KEY" --broadcast -vvvv $args
            else
                echo "No valid credentials specified for $network. Please set appropriate values for KEYSTORE, ACCOUNT, or PRIVATE_KEY."
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
    echo "  deploy-community-edition-beacon"
    echo "  deploy-edition-factory"
    echo "  deploy-single-edition-collection-impl"
    echo "  deploy-multi-edition-collection-impl"
    echo "  deploy-collection-factory"
    echo "  deploy-edition-impl"
    echo "  deploy-community-edition-impl"
    echo "  upgrade-edition-beacon <new_implementation>"
    echo "  upgrade-community-edition-beacon <new_implementation>"
    echo "  deploy-mint-portal"
    echo "  upgrade-controller"
    echo "  upgrade-single-edition-collection"
    echo "  upgrade-multi-edition-collection"
    echo "  upgrade-roux-edition-factory"
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
        if [ -z "$REGISTRY_PROXY" ] || [ -z "$USDC_BASE" ]; then
            echo "Error: REGISTRY_PROXY or USDC_BASE is not set."
            exit 1
        fi

        echo "Deploying Controller"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployController.s.sol:DeployController" "--sig run(address,address) $REGISTRY_PROXY $USDC_BASE"
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

        if [[ -z "$NO_OP_IMPL" ]]; then
            echo "Error: NO_OP_IMPL is not set."
            exit 1
        fi

        echo "Deploying Edition Beacon"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionBeacon.s.sol:DeployEditionBeacon" "--sig run(address) $NO_OP_IMPL"
        ;;

    "deploy-community-edition-beacon")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-community-edition-beacon"
            exit 1
        fi

        if [[ -z "$NO_OP_IMPL" ]]; then
            echo "Error: NO_OP_IMPL is not set."
            exit 1
        fi

        echo "Deploying CommunityEdition Beacon"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployCommunityEditionBeacon.s.sol:DeployCommunityEditionBeacon" "--sig run(address) $NO_OP_IMPL"
        ;;

    "deploy-edition-factory")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-edition-factory"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$ROUX_EDITION_BEACON" ] || [ -z "$ROUX_COMMUNITY_EDITION_BEACON" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Deploying EditionFactory"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionFactory.s.sol:DeployEditionFactory" "--sig run(address,address) $ROUX_EDITION_BEACON $ROUX_COMMUNITY_EDITION_BEACON"
        ;;

    "deploy-single-edition-collection-impl")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-single-edition-collection-impl"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$ROUX_EDITION_BEACON" ] || [ -z "$ERC_6551_REGISTRY" ] || [ -z "$ERC_6551_ACCOUNT_IMPL" ] || [ -z "$ROUX_EDITION_FACTORY_PROXY" ] || [ -z "$CONTROLLER_PROXY" ]; then
            echo "Error: Required variables are not set."
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

        # ensure required variables are set
        if [ -z "$ERC_6551_REGISTRY" ] || [ -z "$ERC_6551_ACCOUNT_IMPL" ] || [ -z "$ROUX_EDITION_FACTORY_PROXY" ] || [ -z "$CONTROLLER_PROXY" ]; then
            echo "Error: Required variables are not set."
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

        # ensure required variables are set
        if [ -z "$SINGLE_EDITION_COLLECTION_BEACON" ] || [ -z "$MULTI_EDITION_COLLECTION_BEACON" ]; then
            echo "Error: Required variables are not set."
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

        # ensure required variables are set
        if [ -z "$USDC_BASE" ] || [ -z "$ROUX_EDITION_FACTORY_PROXY" ] || [ -z "$COLLECTION_FACTORY_PROXY" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Deploying MintPortal"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployMintPortal.s.sol:DeployMintPortal" "--sig run(address,address,address) $USDC_BASE $ROUX_EDITION_FACTORY_PROXY $COLLECTION_FACTORY_PROXY"
        ;;

    "deploy-edition-impl")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-edition-impl"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$ROUX_EDITION_FACTORY_PROXY" ] || [ -z "$COLLECTION_FACTORY_PROXY" ] || [ -z "$CONTROLLER_PROXY" ] || [ -z "$REGISTRY_PROXY" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Deploying Edition Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionImpl.s.sol:DeployEditionImpl" "--sig run(address,address,address,address) $ROUX_EDITION_FACTORY_PROXY $COLLECTION_FACTORY_PROXY $CONTROLLER_PROXY $REGISTRY_PROXY"
        ;;

    "deploy-community-edition-impl")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 deploy-community-edition-impl"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$ROUX_EDITION_FACTORY_PROXY" ] || [ -z "$COLLECTION_FACTORY_PROXY" ] || [ -z "$CONTROLLER_PROXY" ] || [ -z "$REGISTRY_PROXY" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Deploying Community Edition Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployCommunityEditionImpl.s.sol:DeployCommunityEditionImpl" "--sig run(address,address,address,address) $ROUX_EDITION_FACTORY_PROXY $COLLECTION_FACTORY_PROXY $CONTROLLER_PROXY $REGISTRY_PROXY"
        ;;

    "upgrade-edition-beacon")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 upgrade-edition-beacon <new_implementation>"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$ROUX_EDITION_BEACON" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Upgrading Edition Beacon"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeEditionBeacon.s.sol:UpgradeEditionBeacon" "--sig run(address,address) $ROUX_EDITION_BEACON $2"
        ;;

    "upgrade-community-edition-beacon")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 upgrade-community-edition-beacon <new_implementation>"
            exit 1
            fi
        
        # ensure required variables are set
        if [ -z "$ROUX_COMMUNITY_EDITION_BEACON" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Upgrading CommunityEdition Beacon"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeCommunityEditionBeacon.s.sol:UpgradeCommunityEditionBeacon" "--sig run(address,address) $ROUX_COMMUNITY_EDITION_BEACON $2"
        ;;

    "upgrade-controller")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 upgrade-controller"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$CONTROLLER_PROXY" ] || [ -z "$REGISTRY_PROXY" ] || [ -z "$USDC_BASE" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Upgrading Controller Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeController.s.sol:UpgradeController" "--sig run(address,address,address) $CONTROLLER_PROXY $REGISTRY_PROXY $USDC_BASE"
        ;;

    "upgrade-single-edition-collection")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 upgrade-single-edition-collection"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$SINGLE_EDITION_COLLECTION_BEACON" ] || [ -z "$ERC_6551_REGISTRY" ] || [ -z "$ERC_6551_ACCOUNT_IMPL" ] || [ -z "$ROUX_EDITION_FACTORY_PROXY" ] || [ -z "$CONTROLLER_PROXY" ]; then
            echo "Error: Required variables are not set."
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

        # ensure required variables are set
        if [ -z "$MULTI_EDITION_COLLECTION_BEACON" ] || [ -z "$ERC_6551_REGISTRY" ] || [ -z "$ERC_6551_ACCOUNT_IMPL" ] || [ -z "$ROUX_EDITION_FACTORY_PROXY" ] || [ -z "$CONTROLLER_PROXY" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Upgrading MultiEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeMultiEditionCollection.s.sol:UpgradeMultiEditionCollection" "--sig run(address,address,address,address,address) $MULTI_EDITION_COLLECTION_BEACON $ERC_6551_REGISTRY $ERC_6551_ACCOUNT_IMPL $ROUX_EDITION_FACTORY_PROXY $CONTROLLER_PROXY"
        ;;

    "upgrade-roux-edition-factory")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 upgrade-roux-edition-factory"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$ROUX_EDITION_FACTORY_PROXY" ] || [ -z "$ROUX_EDITION_BEACON" ] || [ -z "$ROUX_COMMUNITY_EDITION_BEACON" ]; then
            echo "Error: Required variables are not set."
            exit 1
        fi

        echo "Upgrading RouxEditionFactory Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeRouxEditionFactory.s.sol:UpgradeRouxEditionFactory" "--sig run(address,address,address) $ROUX_EDITION_FACTORY_PROXY $ROUX_EDITION_BEACON $ROUX_COMMUNITY_EDITION_BEACON"
        ;;

    "upgrade-collection-factory")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 upgrade-collection-factory"
            exit 1
        fi

        # ensure required variables are set
        if [ -z "$COLLECTION_FACTORY_PROXY" ] || [ -z "$SINGLE_EDITION_COLLECTION_BEACON" ] || [ -z "$MULTI_EDITION_COLLECTION_BEACON" ]; then
            echo "Error: Required variables are not set."
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
