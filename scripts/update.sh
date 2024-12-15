#! /bin/bash

set -euo pipefail

# We need some infos
PRIVATE_KEY=${PRIVATE_KEY:-}
RPC_URL=${RPC_URL:-}
CHAIN_ID=${CHAIN_ID:-}
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
if [ "$CHAIN_ID" != "31337" ] && [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "ETHERSCAN_API_KEY env var is not set"
  exit 1
fi
# Section.
SECTION=${1:-}
if [ "$SECTION" != "admin-files" ] && [ "$SECTION" != "theme-files" ]; then
  echo "Invalid section: $SECTION"
  exit 1
fi


# Setup cleanup
function cleanup {
  echo "Exiting, cleaning up..."
  # rm -rf dist
}
trap cleanup EXIT

# Go to the root folder
ROOT_FOLDER=$(cd $(dirname $(readlink -f $0)); cd ..; pwd)
cd $ROOT_FOLDER

# Non-hardhat chain: Ask for confirmation
if [ "$CHAIN_ID" != "31337" ]; then
  echo "Please confirm that you want to deploy on chain $CHAIN_ID"
  read -p "Press enter to continue"
fi

# Extra args for ocweb CLI
OCWEB_CLI_EXTRA_ARGS=
if [ "$CHAIN_ID" == "31337" ]; then
  OCWEB_CLI_EXTRA_ARGS="--skip-tx-validation"
fi

# Get the plugin address
if [ "$CHAIN_ID" == "10" ] || [ "$CHAIN_ID" == "17000" ]; then
  PLUGIN_ADDRESS=$(npx ocweb factory-infos ${CHAIN_ID} | grep 'visualizeValueMint' |  awk '{print $1}')
else
  OCWEBSITE_FACTORY_ADDRESS=$(cat ../ocweb/contracts/broadcast/OCWebsiteFactory.s.sol/${CHAIN_ID}/run-latest.json | jq -r '[.transactions[] | select(.contractName == "ERC1967Proxy" and .transactionType == "CREATE")][0].contractAddress')
  PLUGINS_INFOS_CALL_RESULT=$(cast call --rpc-url $RPC_URL --chain ${CHAIN_ID} $OCWEBSITE_FACTORY_ADDRESS "getWebsitePlugins(bytes4[])" "[]")
  PLUGINS_INFOS=$(cast abi-decode "getWebsitePlugins(bytes4[])((address,(string,string,address,uint8),bool,bool)[])" $PLUGINS_INFOS_CALL_RESULT)
  # cast abi-decode --json fails, so we need to do a dirty fetching of the plugin address
  PLUGIN_ADDRESS=$(echo $PLUGINS_INFOS | awk '{for (i=2; i<=NF; i++) if ($i == "(\"visualizeValueMint\",") print $(i-1)}' | sed 's/^.\(.*\).$/\1/')
fi

# Update files in the admin frontend
if [ "$SECTION" == "admin-files" ]; then
  NEW_VERSION_MESSAGE="${@:2}"
  if [ "$NEW_VERSION_MESSAGE" == "" ]; then
    echo "Please provide a message for the new version"
    exit 1
  fi

  # Get the frontend address
  PLUGIN_ADMIN_CALL_RESULT=$(cast call --rpc-url $RPC_URL --chain ${CHAIN_ID} $PLUGIN_ADDRESS "frontend()")
  PLUGIN_ADMIN_ADDRESS=$(cast abi-decode "frontend()(address)" $PLUGIN_ADMIN_CALL_RESULT)
  PLUGIN_ADMIN_WEB3_ADDRESS="web3://${PLUGIN_ADMIN_ADDRESS}:${CHAIN_ID}"

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

  echo "Updating files on frontend ${PLUGIN_ADMIN_WEB3_ADDRESS} ..."

  # First create a new website version
  echo "Creating a new website version..."
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=${PLUGIN_ADMIN_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS version-add "$NEW_VERSION_MESSAGE"

  sleep 1

  # Get the number of the newly created version
  echo "Fetching the number of the new website version..."
  WEBSITE_VERSION_INDEX=$(WEB3_ADDRESS=${PLUGIN_ADMIN_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS version-ls | tail -n1 | awk '{print $1}')
  echo "New website version number: $WEBSITE_VERSION_INDEX"

  # Make it viewable
  echo "Making the new website version viewable..."
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=${PLUGIN_ADMIN_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS --website-version $WEBSITE_VERSION_INDEX version-set-viewable true

  # Upload the files to the new website version
  echo "Uploading files to the new website version..."
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=${PLUGIN_ADMIN_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS --website-version $WEBSITE_VERSION_INDEX \
  upload dist/* / --sync

  # Set the new website version live
  echo "Setting the new website version live..."
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=${PLUGIN_ADMIN_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS version-set-live $WEBSITE_VERSION_INDEX
fi

# Update files in the theme
if [ "$SECTION" == "theme-files" ]; then
  THEME_NAME=${2:-}
  if [ "$THEME_NAME" == "" ]; then
    echo "Please provide a theme name"
    exit 1
  fi
  NEW_VERSION_MESSAGE="${@:3}"
  if [ "$NEW_VERSION_MESSAGE" == "" ]; then
    echo "Please provide a message for the new version"
    exit 1
  fi

  # Prepare the theme folder
  THEME=mint-$THEME_NAME

  # Prepare the human-readable name of the theme
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

  PLUGIN_THEME_ADDRESS=$(npx web3curl "web3://${PLUGIN_ADDRESS}:${CHAIN_ID}/getThemes?returns=((string,address)[])" | jq -r ".[0][] | select(.[0] == \"$THEME_HUMAN_NAME\") | .[1]")
  if [ "$PLUGIN_THEME_ADDRESS" == "" ]; then
    echo "Theme not found"
    exit 1
  fi
  PLUGIN_THEME_WEB3_ADDRESS="web3://${PLUGIN_THEME_ADDRESS}:${CHAIN_ID}"

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

  echo "Updating files on theme ${PLUGIN_THEME_WEB3_ADDRESS} ..."

  # First create a new website version
  echo "Creating a new website version..."
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=${PLUGIN_THEME_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS version-add "$NEW_VERSION_MESSAGE"

  sleep 1

  # Get the number of the newly created version
  echo "Fetching the number of the new website version..."
  WEBSITE_VERSION_INDEX=$(WEB3_ADDRESS=${PLUGIN_THEME_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS version-ls | tail -n1 | awk '{print $1}')
  echo "New website version number: $WEBSITE_VERSION_INDEX"

  # Make it viewable
  echo "Making the new website version viewable..."
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=${PLUGIN_THEME_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS --website-version $WEBSITE_VERSION_INDEX version-set-viewable true

  # Upload the files to the new website version
  echo "Uploading files to the new website version..."
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=${PLUGIN_THEME_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS --website-version $WEBSITE_VERSION_INDEX \
  upload dist/* / --sync

  # Set the new website version live
  echo "Setting the new website version live..."
  PRIVATE_KEY=$PRIVATE_KEY \
  WEB3_ADDRESS=${PLUGIN_THEME_WEB3_ADDRESS} \
  npx ocweb --rpc $RPC_URL $OCWEB_CLI_EXTRA_ARGS version-set-live $WEBSITE_VERSION_INDEX
fi