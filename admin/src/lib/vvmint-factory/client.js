import { getContract, toHex, walletActions, publicActions } from 'viem'

import { abi as VVMintFactoryABI } from './abi'


class VVMintFactoryClient {
  #viemClient = null
  #vvMintFactoryAddress = null
  #vvMintFactoryContract = null

  constructor(viemClient, vvMintFactoryAddress) {
    this.#viemClient = viemClient.extend(publicActions).extend(walletActions)
    this.#vvMintFactoryAddress = vvMintFactoryAddress

    this.#vvMintFactoryContract = getContract({
      address: this.#vvMintFactoryAddress,
      abi: VVMintFactoryABI,
      client: this.#viemClient,
    })
  }

  async getCreatorCollections(creatorAddress) {
    return await this.#vvMintFactoryContract.read.getCreatorCollections([creatorAddress])
  }

  async prepareCreateCollectionTransaction(name, symbol, description, imageContentType, imageBinaryData) {
    // Name, symbol, description need " to be escaped
    // (The smart contract does not escape them when generating the JSON)
    // Trim them as well
    name = name.replace(/"/g, '\\"').trim()
    symbol = symbol.replace(/"/g, '\\"').trim()
    description = description.replace(/"/g, '\\"').trim()

    const imageDataChunks = []
    if(imageBinaryData) {
      // Prepare the image: Encode it as a base64 dataURL
      const imageBase64 = `data:${imageContentType};base64,${btoa(String.fromCharCode(...imageBinaryData))}`
      // Split into chunks of STORE2 chunks of (0x6000-1) bytes
      
      for (let i = 0; i < imageBase64.length; i += 0x6000 - 1) {
        imageDataChunks.push(toHex(imageBase64.slice(i, i + 0x6000 - 1)))
      }
    }

    return {
      functionName: 'create',
      args: [ name, symbol, description, imageDataChunks ],
    }
  }


  /**
   * Execute a transaction prepared by one of the prepare* methods
   */
  async executeTransaction(transaction) {
    const { request } = await this.#viemClient.simulateContract({
      address: this.#vvMintFactoryAddress,
      abi: VVMintFactoryABI,
      functionName: transaction.functionName,
      args: transaction.args,
    })

    const hash = await this.#viemClient.writeContract(request)

    return hash
  }

  async waitForTransactionReceipt(hash) {
    return await this.#viemClient.waitForTransactionReceipt({
      hash
    })
  }

}

export { VVMintFactoryClient };
