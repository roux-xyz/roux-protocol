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

        "sepolia"|"mainnet"|"base_sepolia")
            local rpc_url="${!rpc_url_var}"
            if [[ -z $rpc_url ]]; then
                echo "$rpc_url_var is not set"
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
    echo "  deploy-controller <registry>"
    echo "  deploy-edition-minter <controller>"
    echo "  deploy-default-edition-minter <controller>"
    echo "  deploy-free-edition-minter <controller>"
    echo "  deploy-edition-impl <controller> <registry> <minters>"
    echo "  deploy-edition-factory <beacon>"
    echo "  upgrade-edition-impl <beacon> <controller> <registry> <minters>"
    echo "  upgrade-controller-impl <controller-proxy> <registry>"
    echo ""
    echo "Options:"
    echo "  NETWORK: Set this environment variable to either 'local', 'sepolia', or 'mainnet'"
}

### deployment manager ###

DEPLOYMENTS_FILE="deployments/${NETWORK}.json"

if [[ -z "$NETWORK" ]]; then
    echo "Error: Set NETWORK to 'local', 'sepolia', 'base_sepolia', or 'mainnet'."
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
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployRegistry.s.sol:DeployRegistry" "--sig run()"
        ;;

    "deploy-controller")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <registry>"
            exit 1
        fi

        echo "Deploying Controller"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployController.s.sol:DeployController" "--sig run(address) $2"
        ;;

    "deploy-edition-minter")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <controller>"
            exit 1
        fi

        echo "Deploying Edition Minter"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployEditionMinter.s.sol:DeployEditionMinter" "--sig run(address) $2"
        ;;

    "deploy-default-edition-minter")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <controller>"
            exit 1
        fi

        echo "Deploying Default Edition Minter"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployDefaultEditionMinter.s.sol:DeployDefaultEditionMinter" "--sig run(address) $2"
        ;;

    "deploy-free-edition-minter")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <controller>"
            exit 1
        fi

        echo "Deploying Free Edition Minter"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployFreeEditionMinter.s.sol:DeployFreeEditionMinter" "--sig run(address) $2"
        ;;

    "deploy-edition-impl")
        if [ "$#" -ne 3 ]; then
            echo "Invalid param count; Usage: $0 <command> <controller> <registry>"
            exit 1
        fi

        echo "Deploying Edition Implementation"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployEditionImpl.s.sol:DeployEditionImpl" "--sig run(address,address) $2 $3"
        ;;

    "deploy-edition-factory")
        if [ "$#" -ne 2 ]; then
            echo "Invalid param count; Usage: $0 <command> <beacon>"
            exit 1
        fi

        echo "Deploying EditionFactory"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/DeployEditionFactory.s.sol:DeployEditionFactory" "--sig run(address) $2"
        ;;

    "upgrade-edition-impl")
        if [ "$#" -ne 4 ]; then
            echo "Invalid param count; Usage: $0 <command> <beacon> <controller> <registry>"
            exit 1
        fi

        echo "Upgrading Edition Implementation"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/UpgradeEditionImpl.s.sol:UpgradeEditionImpl" "--sig run(address,address,address) $2 $3 $4"
        ;;

    "upgrade-controller-impl")
        if [ "$#" -ne 3 ]; then
            echo "Invalid param count; Usage: $0 <command> <controller-proxy> <registry>"
            exit 1
        fi

        echo "Upgrading Controller Implementation"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/UpgradeController.s.sol:UpgradeController" "--sig run(address,address) $2 $3"
        ;;

     "upgrade-edition-minter-impl")
        if [ "$#" -ne 3 ]; then
            echo "Invalid param count; Usage: $0 <command> <edition-minter-proxy> <controller>"
            exit 1
        fi

        echo "Upgrading Edition Minter Implementation"
        run "$NETWORK" "${NETWORK^^}_RPC_URL" "script/UpgradeEditionMinter.s.sol:UpgradeEditionMinter" "--sig run(address,address) $2 $3"
        ;;

esac