# Visualizevalue Mint Frontend plugin for OCWebsite

This project is a plugin for [OCWebsites](https://github.com/nand2/ocweb) (a `web3://` onchain CMS, homepage at `web3://ocweb.eth`)

It allows the user to have a [Mint protocol artist frontend](https://docs.mint.vv.xyz), where he can show his collections from the Mint protocol.

The main settings are : 
- The theme
- The creator ethereum address
- The site title and subtitle

## Technical overview

The whole thing is made of several components : 
- An OCWebsite per theme. The contents of the OCWebsite is the theme configured with default values. [Some javascript](https://github.com/nand2/ocweb-visualizevalue-mint/blob/main/assets/mint-index-patch.html) has been injected so that the configuration can be overriden by a JSON file at `/.config/visualizevalue-mint/config.json`.
- The plugin smart contract, which act as a router to the theme selected by the user.
- An OCWebsite, whose contents are the files of admin panels for the OCWebsite admin interface. They will write most settings at `/.config/visualizevalue-mint/config.json`. Some settings (theme, root path) are saved directly in the smart contract.

## Setup

These instructions are approximate, they will be improved later:

- Have the [OCWeb](https://github.com/nand2/ocweb) project locally installed.
- Clone this project, so that the `ocweb` and `ocweb-visualizevalue-mint` are in the same folder.
- Enter the `ocweb-visualizevalue-mint` folder, run `npm ci`
- Go to each `mint-*` folder, run `pnpm install`
- In `ocweb`, run the `./scripts/deploy.sh` script (which will deploy locally on an forge anvil node)
