import { getContract, toHex, walletActions, publicActions } from 'viem'

import { abi as VVMintCollectionV1ABI } from './abi'


class VVMintCollectionV1Client {
  #viemClient = null
  #VVMintCollectionV1Address = null
  #VVMintCollectionV1Contract = null

  constructor(viemClient, VVMintCollectionV1Address) {
    this.#viemClient = viemClient.extend(publicActions).extend(walletActions)
    this.#VVMintCollectionV1Address = VVMintCollectionV1Address

    this.#VVMintCollectionV1Contract = getContract({
      address: this.#VVMintCollectionV1Address,
      abi: VVMintCollectionV1ABI,
      client: this.#viemClient,
    })
  }

  async getLatestTokenId() {
    return await this.#VVMintCollectionV1Contract.read.latestTokenId()
  }

  async getVersion() {
    return await this.#VVMintCollectionV1Contract.read.version()
  }

  async getTokenInfos(tokenId) {
    return await this.#VVMintCollectionV1Contract.read.get([tokenId])
  }

  async prepareCreateCollectionTokenTransactions(name, description, imageContentType, imageBinaryData) {
    // Name, description need " to be escaped
    // (The smart contract does not escape them when generating the JSON)
    // Trim them as well
    name = name.replace(/"/g, '\\"').trim()
    description = description.replace(/"/g, '\\"').trim()

    const artifactChunks = []
    // Prepare the image: Encode it as a base64 dataURL
    let binaryString = '';
    for (let i = 0; i < imageBinaryData.length; i++) {
      binaryString += String.fromCharCode(imageBinaryData[i]);
    }
    const imageBase64 = `data:${imageContentType};base64,${btoa(binaryString)}`
    // Split into chunks of STORE2 chunks of (0x6000-1) bytes
    
    for (let i = 0; i < imageBase64.length; i += 0x6000 - 1) {
      artifactChunks.push(toHex(imageBase64.slice(i, i + 0x6000 - 1)))
    }

    // If 3 or less chunks, we can make it into a single transaction
    let result = [];
    if(artifactChunks.length <= 3) {
      result = [{
        functionName: 'create',
        args: [ name, description, artifactChunks, 0n, 0n ],
      }]
    }
    // Otherwise first send the artifact separately, grouped by 3 chunks
    else {
      // First we need to determine the upcoming token ID
      const latestTokenId = await this.#VVMintCollectionV1Contract.read.latestTokenId()

      // Send the image in chunks of 3
      for (let i = 0; i < artifactChunks.length; i += 3) {
        const chunkedArtifact = artifactChunks.slice(i, i + 3)
        result.push({
          functionName: 'prepareArtifact',
          args: [ latestTokenId + 1n, chunkedArtifact, i == 0 ],
        })
      }

      // Then make the create transaction, without any artifact chunks
      result.push({
        functionName: 'create',
        args: [ name, description, [], 0n, 0n ],
      })
    }

    return result;
  }


  /**
   * Execute a transaction prepared by one of the prepare* methods
   */
  async executeTransaction(transaction) {
    const { request } = await this.#viemClient.simulateContract({
      address: this.#VVMintCollectionV1Address,
      abi: VVMintCollectionV1ABI,
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

export { VVMintCollectionV1Client };
