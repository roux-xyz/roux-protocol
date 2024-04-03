#!/usr/bin/env bash

set -e

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

        "sepolia"|"mainnet")
            local rpc_url="${!rpc_url_var}"
            if [[ -z $rpc_url ]]; then
                echo "$rpc_url_var is not set"
                exit 1
            fi
            echo "Running on $network"
            if [ ! -z $LEDGER_DERIVATION_PATH ]; then
                forge script "$contract" --rpc-url "$rpc_url" --ledger --hd-paths $LEDGER_DERIVATION_PATH --sender $LEDGER_ADDRESS --broadcast -vvvv $args
            else
                echo "Running with private key $PRIVATE_KEY"
                forge script "$contract" --rpc-url "$rpc_url" --private-key $PRIVATE_KEY --broadcast -vvvv $args
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
    echo "  deploy-creator-impl"
    echo "  deploy-creator-factory <implementation>"
    echo "  deploy-erc6551-account <erc6551Registry>"
    echo "  deploy-collection-impl <erc6551Registry> <erc6551AccountImpl>"
    echo "  deploy-collection-factory <collectionImpl>"
    echo "  create-creator <creatorFactory> <user>"
    echo ""
    echo "Options:"
    echo "  NETWORK: Set this environment variable to either 'local', 'sepolia', or 'mainnet'"
}

### deployment manager ###

DEPLOYMENTS_FILE="deployments/${NETWORK}.json"

if [[ -z "$NETWORK" ]]; then
    echo "Error: Set NETWORK to 'local', 'sepolia', or 'mainnet'."
    echo ""
    usage
    exit 1
fi

case $1 in

    "deploy-creator-impl")
        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 <command>"
            exit 1
        fi

        echo "Deploying Creator Implementation"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployCreatorImpl.s.sol:DeployCreatorImpl" "--sig run()"
        ;;

    "deploy-creator-factory")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <beacon>"
            exit 1
        fi

        echo "Deploying CreatorFactory"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployCreatorFactory.s.sol:DeployCreatorFactory" "--sig run(address) $2"
        ;;

    "deploy-erc6551-registry")
        if [ "$NETWORK" != "local" ]; then
            echo "Error: This command can only be run with NETWORK set to 'local'."
            exit 1
        fi

        if [ "$#" -ne 1 ]; then
            echo "Invalid param count; Usage: $0 <command>"
            exit 1
        fi

        echo "Deploying ERC6551Account"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/local/DeployERC6551Registry.local.s.sol:DeployERC6551Registry" "--sig run()"
        ;;

    "deploy-erc6551-account-impl")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <erc6551Registry>"
            exit 1
        fi

        echo "Deploying ERC6551Account Implementation"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployERC6551Account.s.sol:DeployERC6551Account" "--sig run(address) $2"
        ;;
    
    "deploy-collection-impl")
        if [ "$#" -ne 3 ]; then
            echo "Invalid param count; Usage: $0 <command> <erc6551Registry> <erc6551AccountImpl>"
            exit 1
        fi

        echo "Deploying Collection Implementation"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployCollectionImpl.s.sol:DeployCollectionImpl" "--sig run(address,address) $2 $3"
        ;;

    "deploy-collection-factory")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <collectionImpl>"
            exit 1
        fi

        echo "Deploying Collection Factory"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployCollectionFactory.s.sol:DeployCollectionFactory" "--sig run(address) $2"
        ;;
esac