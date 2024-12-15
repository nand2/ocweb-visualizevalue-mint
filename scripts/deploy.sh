#! /bin/bash

set -euo pipefail

# We need some infos
PRIVATE_KEY=${PRIVATE_KEY:-}
RPC_URL=${RPC_URL:-}
CHAIN_ID=${CHAIN_ID:-}
OCWEBSITE_FACTORY_ADDRESS=${OCWEBSITE_FACTORY_ADDRESS:-}
STATIC_FRONTEND_PLUGIN_ADDRESS=${STATIC_FRONTEND_PLUGIN_ADDRESS:-}
OCWEB_ADMIN_PLUGIN_ADDRESS=${OCWEB_ADMIN_PLUGIN_ADDRESS:-}
ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY:-}
if [ -z "$PRIVATE_KEY" ]; then
  echo "PRIVATE_KEY env var is not set"
  exit 1
fi
if [ -z "$RPC_URL" ]; then
  echo "RPC_URL env var is not set"
  exit 1
fi
if [ -z "$CHAIN_ID" ]; then
  echo "CHAIN_ID env var is not set"
  exit 1
fi
if [ -z "$OCWEBSITE_FACTORY_ADDRESS" ]; then
  echo "OCWEBSITE_FACTORY_ADDRESS env var is not set"
  exit 1
fi
if [ -z "$STATIC_FRONTEND_PLUGIN_ADDRESS" ]; then
  echo "STATIC_FRONTEND_PLUGIN_ADDRESS env var is not set"
  exit 1
fi
if [ -z "$OCWEB_ADMIN_PLUGIN_ADDRESS" ]; then
  echo "OCWEB_ADMIN_PLUGIN_ADDRESS env var is not set"
  exit 1
fi
if [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "ETHERSCAN_API_KEY env var is not set"
  exit 1
fi

# check that forge is installed
if ! command -v forge &> /dev/null
then
    echo "forge could not be found. Please install foundry (toolkit for Ethereum application development)"
    exit
fi

# Non-hardhat chain: Ask for confirmation
if [ "$CHAIN_ID" != "31337" ]; then
  echo "Please confirm that you want to deploy on chain $CHAIN_ID"
  read -p "Press enter to continue"
fi

# Compute the plugin root folder (which is the parent folder of this script)
ROOT_FOLDER=$(cd $(dirname $(readlink -f $0)) && cd .. && pwd)


#
# Local deployment: deploy the Mint Protocol factory
#

if [ "$CHAIN_ID" == "31337" ]; then
  echo "Deploying the Mint Protocol factory"
  exec 5>&1
  OUTPUT="$(forge script DeployVVMintScript --broadcast --private-key $PRIVATE_KEY --rpc-url $RPC_URL | tee >(cat - >&5))"
fi


#
# Create an OCWebsite
#

# If we are in local/testnet mode, if the OCWebsite was already minted, we reuse the OCWebsite
OCWEBSITE_ADDRESS=
if [ "$CHAIN_ID" == "31337" ] || [ "$CHAIN_ID" == "17000" ]; then
  exec 5>&1
  OUTPUT="$(PRIVATE_KEY=$PRIVATE_KEY \
    npx ocweb --rpc $RPC_URL list --factory-address $OCWEBSITE_FACTORY_ADDRESS $CHAIN_ID | tee >(cat - >&5))"

  # Get the address of the OCWebsite. Format is : "<ethereum-address> (token <number> subdomain vvmint)"
  OCWEBSITE_ADDRESS=$(echo "$OUTPUT" | grep "subdomain vvmint)" | grep -oP '0x\w+' || true)
fi

# If the OCWebsite was not minted, we mint it
if [ -z "$OCWEBSITE_ADDRESS" ]; then
  exec 5>&1
  OUTPUT="$(PRIVATE_KEY=$PRIVATE_KEY \
    npx ocweb --rpc $RPC_URL --skip-tx-validation mint --factory-address $OCWEBSITE_FACTORY_ADDRESS $CHAIN_ID vvmint | tee >(cat - >&5))"

  # Get the address of the OCWebsite
  OCWEBSITE_ADDRESS=$(echo "$OUTPUT" | grep -oP 'New OCWebsite smart contract: \K0x\w+')
fi


#
# Build and upload the admin frontend
#

# Go to the admin frontend folder
cd $ROOT_FOLDER/admin
# Build the admin frontend
npm run build

# Make a temporary folder where we prepare the upload
cd $ROOT_FOLDER
rm -Rf $ROOT_FOLDER/dist
mkdir -p dist
mkdir -p dist/admin
cp -R admin/dist/* dist/admin

# Upload the whole package to the OCWebsite
PRIVATE_KEY=$PRIVATE_KEY \
WEB3_ADDRESS=web3://$OCWEBSITE_ADDRESS:$CHAIN_ID \
npx ocweb --rpc $RPC_URL --skip-tx-validation upload dist/* / --sync


#
# Build the plugin
# 

FORGE_CREATE_OPTIONS=
if [ "$CHAIN_ID" != "31337" ]; then
  FORGE_CREATE_OPTIONS="--verify"
fi
exec 5>&1
OUTPUT="$(forge create --private-key $PRIVATE_KEY $FORGE_CREATE_OPTIONS \
--constructor-args $OCWEBSITE_ADDRESS $STATIC_FRONTEND_PLUGIN_ADDRESS $OCWEB_ADMIN_PLUGIN_ADDRESS \
--rpc-url $RPC_URL \
src/VisualizeValueMintPlugin.sol:VisualizeValueMintPlugin | tee >(cat - >&5))"

# Get the plugin address
PLUGIN_ADDRESS=$(echo "$OUTPUT" | grep -oP 'Deployed to: \K0x\w+')
echo "Plugin address: $PLUGIN_ADDRESS"



#
# Build and upload the themes
#

# Get all the folder names starting with mint-
THEMES=$(ls -d $ROOT_FOLDER/mint-* | xargs -n1 basename)
# If local : only test base theme
if [ "$CHAIN_ID" == "31337" ]; then
  THEMES="mint-base"
fi

# For each theme: mint an OCWebsite, build the theme, upload it
for THEME in $THEMES; do
  # If we are in local/testnet mode, if the OCWebsite was already minted, we reuse the OCWebsite
  THEME_OCWEBSITE_ADDRESS=
  if [ "$CHAIN_ID" == "31337" ] || [ "$CHAIN_ID" == "17000" ]; then
    exec 5>&1
    OUTPUT="$(PRIVATE_KEY=$PRIVATE_KEY \
      npx ocweb --rpc $RPC_URL list --factory-address $OCWEBSITE_FACTORY_ADDRESS $CHAIN_ID | tee >(cat - >&5))"

    # Get the address of the OCWebsite. Format is : "<ethereum-address> (token <number> subdomain vvmint)"
    THEME_OCWEBSITE_ADDRESS=$(echo "$OUTPUT" | grep "subdomain vv$THEME)" | grep -oP '0x\w+' || true)
  fi

  # If the OCWebsite was not minted, we mint it
  if [ -z "$THEME_OCWEBSITE_ADDRESS" ]; then
    exec 5>&1
    OUTPUT="$(PRIVATE_KEY=$PRIVATE_KEY \
      npx ocweb --rpc $RPC_URL --skip-tx-validation mint --factory-address $OCWEBSITE_FACTORY_ADDRESS $CHAIN_ID vv$THEME | tee >(cat - >&5))"

    # Get the address of the OCWebsite
    THEME_OCWEBSITE_ADDRESS=$(echo "$OUTPUT" | grep -oP 'New OCWebsite smart contract: \K0x\w+')
  fi

  # # Go to the theme folder
  # cd $ROOT_FOLDER/$THEME
  # # Build the theme
  # pnpm run generate

  # Temporary while we have a fork
  FORK_OUTPUT_FOLDER=
  if [ "$THEME" == "mint-base" ]; then
    cd $ROOT_FOLDER/../vizualizevalue-mint/
    pnpm --filter @visualizevalue/mint-app-base generate
    FORK_OUTPUT_FOLDER=$ROOT_FOLDER/../vizualizevalue-mint/app/base/.output/public
  elif [ "$THEME" == "mint-zinc" ]; then
    cd $ROOT_FOLDER/../vizualizevalue-mint/
    pnpm --filter @visualizevalue/mint-theme-zinc generate
    FORK_OUTPUT_FOLDER=$ROOT_FOLDER/../vizualizevalue-mint/app/themes/zinc/.playground/.output/public
  else
    echo "Unknown theme: $THEME"
    exit 1
  fi
  cd $ROOT_FOLDER
  rm -Rf $ROOT_FOLDER/dist
  mkdir -p dist
  cp -R $FORK_OUTPUT_FOLDER/* dist
  # End of temporary

  # # Make a temporary folder where we prepare the upload
  # cd $ROOT_FOLDER
  # rm -Rf $ROOT_FOLDER/dist
  # mkdir -p dist
  # cp -R $THEME/.output/public/* dist
  
  # In index.html, we find the first <script> tag, we extract its URL, and we remove the tag.
  # We inject the contents of assets/mint-index-patch.html into the base index.html, just before the </body> tag, and within the patch, we replace NUXT_ENTRYPOINT_FILE by the extracted URL of the script tag.
  node -e "
    const fs = require('fs');
    let indexHtml = fs.readFileSync('$ROOT_FOLDER/dist/index.html', 'utf8');

    const scriptTag = indexHtml.match(/<script type=\"module\" src=\"([^\"]+)\" crossorigin><\/script>/);
    const scriptUrl = scriptTag[1];
    indexHtml = indexHtml.replace(scriptTag[0], '')
    
    const patch = fs.readFileSync('$ROOT_FOLDER/assets/mint-index-patch.html', 'utf8').replace('NUXT_ENTRYPOINT_FILE', scriptUrl);
    fs.writeFileSync('$ROOT_FOLDER/dist/index.html', indexHtml.replace(/<\/body>/i, patch + '\n</body>'));
  "
  
  # Upload the theme to the OCWebsite
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=web3://$THEME_OCWEBSITE_ADDRESS:$CHAIN_ID \
  npx ocweb --rpc $RPC_URL --skip-tx-validation upload dist/* /  --sync

  # Prepare the human-readable name of the theme
  THEME_NAME=$(echo $THEME | sed 's/^mint-//g')
  # Mapping of names to human-readable names
  case $THEME_NAME in
    "base")
      THEME_HUMAN_NAME="Base"
      ;;
    "zinc")
      THEME_HUMAN_NAME="Zinc"
      ;;
    *)
      echo "Unknown theme name: $THEME_NAME"
      exit 1
      ;;
  esac

  # Add the theme to the plugin
  echo "Adding the theme to the plugin"
  cast send $PLUGIN_ADDRESS "addTheme(string,address)" $THEME_HUMAN_NAME $THEME_OCWEBSITE_ADDRESS --private-key ${PRIVATE_KEY} --rpc-url ${RPC_URL}
done




