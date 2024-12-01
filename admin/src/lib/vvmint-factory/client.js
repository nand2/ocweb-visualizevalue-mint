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

  async createCollection(name, symbol, description, imageData) {
    // TODO split img
    imageDataChunks = []

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
