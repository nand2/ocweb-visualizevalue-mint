<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useQuery, useQueryClient, useMutation } from '@tanstack/vue-query'
import { useConnectorClient, useAccount, useSwitchChain, useWriteContract, useWaitForTransactionReceipt } from '@wagmi/vue';

import { VVMintCollectionV1Client } from '../../lib/vvmint-collection-v1/client.js';
import PlusLgIcon from '../Icons/PlusLgIcon.vue';
import CollectionToken from './CollectionToken.vue';


const emit = defineEmits(['showCollectionTokenCreationForm'])

const props = defineProps({
  chainId: {
    type: Number,
    required: true,
  },
  collectionAddress: {
    type: String,
    required: true,
  },
  vvMintchainId: {
    type: Number,
    required: true,
  },
  vvMintFactoryClient: {
    type: Object,
    required: true,
  },
})

const { data: viemClient, isSuccess: viemClientLoaded } = useConnectorClient()
const { switchChainAsync, isPending: switchChainIsPending, error: switchChainError } = useSwitchChain()

// Fetch infos about the collection
const { data: collectionInfos, isLoading: collectionInfosLoading, isFetching: collectionInfosFetching, isError: collectionInfosIsError, error: collectionInfosError, isSuccess: collectionInfosLoaded } = useQuery({
  queryKey: ['CollectionInfos', props.collectionAddress, props.vvMintchainId],
  queryFn: async () => {
    const response = await fetch(`web3://${props.collectionAddress}:${props.vvMintchainId}/contractURI?returns=(string)`)
    if (!response.ok) {
      throw new Error('Network response was not ok')
    }
    const decodedResponse = await response.json()
    // console.log(decodedResponse[0])
    const contractURI = decodedResponse[0];
    
    // ContractURI is a JSON data URL. Decode it.
    const contractURIData = await fetch(contractURI)
    if (!contractURIData.ok) {
      throw new Error('Data URL decoding was not ok')
    }
    const result = await contractURIData.json()
    // console.log(result)

    return result;
  },
  staleTime: 3600 * 1000,
})

// Get the latest token id
const { data: latestTokenId, isLoading: latestTokenIdLoading, isFetching: latestTokenIdFetching, isError: latestTokenIdIsError, error: latestTokenIdError, isSuccess: latestTokenIdLoaded } = useQuery({
  queryKey: ['CollectionLatestTokenId', props.collectionAddress, props.vvMintchainId],
  queryFn: async () => {
    const response = await fetch(`web3://${props.collectionAddress}:${props.vvMintchainId}/latestTokenId?returns=(uint256)`)
    if (!response.ok) {
      throw new Error('Network response was not ok')
    }
    const decodedResponse = await response.json()
    // console.log(decodedResponse[0])
    return decodedResponse[0];
  },
  staleTime: 3600 * 1000,
})

// Get the version of the collection
const { data: collectionVersion, isLoading: collectionVersionLoading, isFetching: collectionVersionFetching, isError: collectionVersionIsError, error: collectionVersionError, isSuccess: collectionVersionLoaded } = useQuery({
  queryKey: ['CollectionVersion', props.collectionAddress, props.vvMintchainId],
  queryFn: async () => {
    const response = await fetch(`web3://${props.collectionAddress}:${props.vvMintchainId}/version?returns=(uint256)`)
    if (!response.ok) {
      throw new Error('Network response was not ok')
    }
    const decodedResponse = await response.json()
    // console.log(decodedResponse[0])
    return Number(decodedResponse[0]);
  },
  staleTime: 3600 * 1000,
})

// Prepare the VVMint collection client
const vvMintCollectionClient = computed(() => {
  return viemClientLoaded.value ? new VVMintCollectionV1Client(viemClient.value, props.collectionAddress) : null;
})

// Mutation to withdraw the funds from the collection
const { isPending: withdrawFundsIsPending, isError: withdrawFundsIsError, error: withdrawFundsError, isSuccess: withdrawFundsIsSuccess, mutate: withdrawFundsMutate, reset: withdrawFundsReset } = useMutation({
  mutationFn: async () => {

    // Prepare the transaction
    const transaction = await vvMintCollectionClient.value.prepareWithdrawFundsTransaction();

    // Switch the network to the VVMint chain
    await switchChainAsync({ chainId: props.vvMintchainId })

    const hash = await vvMintCollectionClient.value.executeTransaction(transaction);
    console.log(hash);

    // Wait for the transaction to be mined
    return await vvMintCollectionClient.value.waitForTransactionReceipt(hash);
  },
  onSuccess: async (data) => {
    // Switch back to the original network
    await switchChainAsync({ chainId: props.chainId })
  },
  onError: async (error) => {
    // Switch back to the original network
    await switchChainAsync({ chainId: props.chainId })
  }
})

</script>

<template>
  <div v-if="collectionInfosLoading" class="text-90">
    Loading collection infos...
  </div>
  <div v-else-if="collectionInfosIsError" class="text-danger text-90">
    Failed to load collection infos: {{ collectionInfosError }}
  </div>
  <div v-else-if="collectionInfosLoaded" class="collection-entry">
    <div class="collection-line">
      <img v-if="collectionInfos.image" :src="collectionInfos.image" />    
      <div>
        <div class="title">
          {{ collectionInfos.name }}
        </div>
        <div style="white-space: pre-line;">
          {{ collectionInfos.description }}
        </div>
      </div>
    </div>

    <div class="collection-body">
      <div v-if="latestTokenIdLoaded && latestTokenId > 0" class="token-list">
        <CollectionToken 
          v-for="tokenId in Array.from({length: latestTokenId}).map((_, i) => i + 1)"
          :key="tokenId"
          :chainId="chainId"
          :collectionAddress="collectionAddress"
          :vvMintchainId="vvMintchainId"
          :vvMintCollectionClient="vvMintCollectionClient"
          :tokenId="tokenId"
          />
      </div>
      <div v-else-if="latestTokenIdLoaded && latestTokenId == 0" class="text-muted text-90">
        No token in this collection yet.
      </div>

      <div class="operations"  v-if="vvMintFactoryClient && collectionVersionLoaded && collectionVersion == 1">
        <div class="op-add-new-collection">
          <div class="button-area">
            <span class="button-text" @click="$emit('showCollectionTokenCreationForm')">
              <PlusLgIcon /> Add new token
            </span>
          </div>
        </div>

        <div class="op-add-new-collection" v-if="latestTokenIdLoaded && latestTokenId > 0">
          <div class="button-area">
            <span class="button-text" @click="withdrawFundsMutate">
              Withdraw sale funds
            </span>
          </div>
        </div>
      </div>
    </div>
    

  </div>
</template>

<style scoped>
.collection-line {
  display: flex;
  align-items: center;
  gap: 1em;
  font-size: 0.9em;
}

.collection-line img {
  max-width: 100px;
  max-height: 100px;
}

.collection-line .title {
  font-weight: bold;
}

.collection-body {
  margin: 1em 0em 0em 2em;
}

.token-list {
  display: flex;
  flex-direction: column;
  gap: 1em;
}

.operations {
  font-size: 0.8em;
}
</style>