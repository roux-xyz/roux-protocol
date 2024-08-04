#!/usr/bin/env bash

set -e

# Function to convert to uppercase
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# deploy a contract
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
            else
                echo "Running with account $ACCOUNT"
                forge script "$contract" --rpc-url "$rpc_url" --account $ACCOUNT --sender $SENDER --broadcast -vvvv $args
            fi
            ;;

        *)
            echo "Invalid NETWORK value"
            exit 1
            ;;
    esac
}

usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy-registry"
    echo "  deploy-controller <registry> <currency>"
    echo "  deploy-erc6551-account"
    echo "  deploy-no-op"
    echo "  deploy-edition-beacon <no-op-impl>"
    echo "  deploy-edition-factory <edition-beacon>"
    echo "  deploy-edition-impl <edition-factory> <collection-factory> <controller> <registry>"
    echo "  upgrade-edition-beacon <edition-beacon> <new-implementation>"
    echo "  deploy-single-edition-collection-impl <erc6551registry> <accountImplementation> <editionFactory> <controller>"
    echo "  deploy-multi-edition-collection-impl <erc6551registry> <accountImplementation> <editionFactory> <controller>"
    echo "  deploy-collection-factory <singleEditionCollectionBeacon> <multiEditionCollectionBeacon>"
    echo "  upgrade-controller <proxyAddress> <registry> <currency>"
    echo "  upgrade-single-edition-collection <singleEditionCollectionBeacon> <erc6551registry> <accountImplementation> <editionFactory> <controller>"
    echo "  upgrade-multi-edition-collection <multiEditionCollectionBeacon> <erc6551registry> <accountImplementation> <editionFactory> <controller>"
    echo ""
    echo "Options:"
    echo "  NETWORK: Set this environment variable to either 'local', 'sepolia', 'base_sepolia', 'base', or 'mainnet'"
}

### deployment manager ###

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
            echo "Invalid param count; Usage: $0 <command>"
            exit 1
        fi

        echo "Deploying Registry"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployRegistry.s.sol:DeployRegistry" "--sig run()"
        ;;

    "deploy-controller")
        if [ "$#" -ne 3 ]; then
            echo "Invalid param count; Usage: $0 <command> <registry> <currency>"
            exit 1
        fi

        echo "Deploying Controller"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployController.s.sol:DeployController" "--sig run(address,address) $2 $3"
        ;;

    "deploy-erc6551-account")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 <command>"
            exit 1
        fi

        echo "Deploying ERC6551Account"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployERC6551Account.s.sol:DeployERC6551Account" "--sig run()"
        ;;

    "deploy-no-op")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 <command>"
            exit 1
        fi

        echo "Deploying NoOp Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployNoOp.s.sol:DeployNoOp" "--sig run()"
        ;;

    "deploy-edition-beacon")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <no-op-impl>"
            exit 1
        fi

        echo "Deploying Edition Beacon"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionBeacon.s.sol:DeployEditionBeacon" "--sig run(address) $2"
        ;;

    "deploy-edition-factory")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <edition-beacon>"
            exit 1
        fi

        echo "Deploying EditionFactory"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionFactory.s.sol:DeployEditionFactory" "--sig run(address) $2"
        ;;

    "deploy-edition-impl")
        if [ "$#" -ne 5 ]; then
            echo "Invalid param count; Usage: $0 <command> <edition-factory> <collection-factory> <controller> <registry>"
            exit 1
        fi

        echo "Deploying Edition Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployEditionImpl.s.sol:DeployEditionImpl" "--sig run(address,address,address,address) $2 $3 $4 $5"
        ;;

    "upgrade-edition-beacon")
        if [ "$#" -ne 3 ]; then
            echo "Invalid param count; Usage: $0 <command> <edition-beacon> <new-implementation>"
            exit 1
        fi

        echo "Upgrading Edition Beacon"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeEditionBeacon.s.sol:UpgradeEditionBeacon" "--sig run(address,address) $2 $3"
        ;;

    "deploy-single-edition-collection-impl")
        if [ "$#" -ne 5 ]; then
            echo "Invalid param count; Usage: $0 <command> <erc6551registry> <accountImplementation> <editionFactory> <controller>"
            exit 1
        fi

        echo "Deploying SingleEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeploySingleEditionCollectionImpl.s.sol:DeploySingleEditionCollectionImpl" "--sig run(address,address,address,address) $2 $3 $4 $5"
        ;;

    "deploy-multi-edition-collection-impl")
        if [ "$#" -ne 5 ]; then
            echo "Invalid param count; Usage: $0 <command> <erc6551registry> <accountImplementation> <editionFactory> <controller>"
            exit 1
        fi

        echo "Deploying MultiEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployMultiEditionCollectionImpl.s.sol:DeployMultiEditionCollectionImpl" "--sig run(address,address,address,address) $2 $3 $4 $5"
        ;;

    "deploy-collection-factory")
        if [ "$#" -ne 3 ]; then
            echo "Invalid param count; Usage: $0 <command> <singleEditionCollectionBeacon> <multiEditionCollectionBeacon>"
            exit 1
        fi

        echo "Deploying CollectionFactory"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/deploy/DeployCollectionFactory.s.sol:DeployCollectionFactory" "--sig run(address,address) $2 $3"
        ;;

    "upgrade-controller")
        if [ "$#" -ne 4 ]; then
            echo "Invalid param count; Usage: $0 <command> <proxyAddress> <registry> <currency>"
            exit 1
        fi

        echo "Upgrading Controller Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeController.s.sol:UpgradeController" "--sig run(address,address,address) $2 $3 $4"
        ;;

    "upgrade-single-edition-collection")
        if [ "$#" -ne 6 ]; then
            echo "Invalid param count; Usage: $0 <command> <singleEditionCollectionBeacon> <erc6551registry> <accountImplementation> <editionFactory> <controller>"
            exit 1
        fi

        echo "Upgrading SingleEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeSingleEditionCollection.s.sol:UpgradeSingleEditionCollection" "--sig run(address,address,address,address,address) $2 $3 $4 $5 $6"
        ;;

    "upgrade-multi-edition-collection")
        if [ "$#" -ne 6 ]; then
            echo "Invalid param count; Usage: $0 <command> <multiEditionCollectionBeacon> <erc6551registry> <accountImplementation> <editionFactory> <controller>"
            exit 1
        fi

        echo "Upgrading MultiEditionCollection Implementation"
        run "$NETWORK" "${NETWORK}_RPC_URL" "script/upgrade/UpgradeMultiEditionCollection.s.sol:UpgradeMultiEditionCollection" "--sig run(address,address,address,address,address) $2 $3 $4 $5 $6"
        ;;

    *)
        echo "Invalid command"
        usage
        exit 1
        ;;
esac