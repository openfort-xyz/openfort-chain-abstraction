#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e 

# Load environment variables
source .env

# Deploy to each chain
for chain in "mantle" "optimism" "base" "polygon"; do
  echo "Deploying to $chain..."

  case "$chain" in
    "optimism")
      TOKENS="[0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A,0xd926e338e047aF920F59390fF98A3114CCDcab4a]"
      RPC_URL="https://sepolia.optimism.io"
      API_KEY=$OPTIMISM_API_KEY
      ;;
    "base")
      TOKENS="[0xfF3311cd15aB091B00421B23BcB60df02EFD8db7,0xa9a0179e045cF39C5F4d914583dc3648DfBDeeF1]"
      RPC_URL="https://sepolia.base.org"
      API_KEY=$BASE_API_KEY
      ;;
    "mantle")
      TOKENS="[0x4855090BbFf14397E1d48C9f4Cd7F111618F071a,0x76501186fB44d508b9aeC50899037F33C6FF4A36]"
      RPC_URL="https://rpc.sepolia.mantle.xyz"
      API_KEY=$MANTLE_API_KEY
      ;;
    "polygon")
      TOKENS="[0x8d59703E60051792396Da5C495215B25748d291f,0xEd01Aa1e63abdB90e5eA3a66c720483a318c4749]"
      RPC_URL="https://rpc-amoy.polygon.technology"
      API_KEY=$POLYGON_API_KEY
      ;;
  esac

  # Add special options for Mantle chain
  if [ "$chain" == "mantle" ]; then
    EXTRA_OPTIONS="--skip-simulation --block-gas-limit 250000000000000 --priority-gas-price 0"
  else
    EXTRA_OPTIONS=""
  fi
 
  # Create log directory if it doesn't exist
  mkdir -p logs
  # Define log file with timestamp
  LOG_FILE="logs/deploy_${chain}_$(date +%Y%m%d_%H%M%S).log"
  
  # Run the deployment script and capture output to both log file and screen
  forge script script/deployChainAbstractionSetup.s.sol:DeployChainAbstractionSetup "$TOKENS" \
    --sig "run(address[])" \
    --private-key=$PK_DEPLOYER \
    --rpc-url $RPC_URL \
    --broadcast \
    --etherscan-api-key=$API_KEY \
    --verify \
    $EXTRA_OPTIONS | tee -a "$LOG_FILE"
  
  echo "Deployment log saved to $LOG_FILE"
  echo "Deployment to $chain completed"
  echo "-----------------------------------"
done
