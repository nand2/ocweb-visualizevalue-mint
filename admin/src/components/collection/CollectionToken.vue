<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useQuery, useQueryClient, useMutation } from '@tanstack/vue-query'
import { useConnectorClient, useAccount, useSwitchChain, useWriteContract, useWaitForTransactionReceipt } from '@wagmi/vue';

import { VVMintCollectionV1Client } from '../../lib/vvmint-collection-v1/client.js';
import PlusLgIcon from '../Icons/PlusLgIcon.vue';


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
  vvMintCollectionClient: {
    type: Object,
    required: true,
  },
  tokenId: {
    type: Number,
    required: true,
  },
})

const { data: viemClient, isSuccess: viemClientLoaded } = useConnectorClient()


// Load the token infos
const { data: tokenInfos, isLoading: tokenInfosLoading, isFetching: tokenInfosFetching, isError: tokenInfosIsError, error: tokenInfosError, isSuccess: tokenInfosLoaded } = useQuery({
  queryKey: ['TokenInfos', props.collectionAddress, props.vvMintchainId, props.tokenId],
  queryFn: async () => {
    // Load the token infos
    const response = await fetch(`web3://${props.collectionAddress}:${props.vvMintchainId}/get/${props.tokenId}?returns=(string,string,address[],uint32,uint32,uint64,uint128)`)
    if (!response.ok) {
      throw new Error('Network response was not ok')
    }
    const resultArray = await response.json();
    let result = {
      name: resultArray[0],
      description: resultArray[1],
      artifact: resultArray[2],
      renderer: Number(resultArray[3]),
      mintedBlock: Number(resultArray[4]),
      closedAt: Number(resultArray[5]),
      data: Number(resultArray[6]),
    };
    
    
    // Load the token URI
    const uriResponse = await fetch(`web3://${props.collectionAddress}:${props.vvMintchainId}/uri/${props.tokenId}?returns=(string)`)
    if (!uriResponse.ok) {
      throw new Error('Network response was not ok')
    }
    const decodedUriResponse = await uriResponse.json()
    const tokenURI = decodedUriResponse[0];

    // tokenURI is a JSON data URL. Decode it.
    const tokenURIData = await fetch(tokenURI)
    if (!tokenURIData.ok) {
      throw new Error('Data URL decoding was not ok')
    }
    const tokenURIDecodedResponse = await tokenURIData.json()
    // console.log(tokenURIDecodedResponse)
    
    // Add the tokenURI to the result
    result.tokenURI = tokenURIDecodedResponse;

    return result;
  },
  staleTime: 3600 * 1000,
})

// Determine if the token is mintable
const isMintable = computed(() => {
  return tokenInfosLoaded.value && tokenInfos.value.closedAt > Date.now() / 1000;
})
// If mintable, determine how much time is left (in XX hours XX minutes format)
const timeLeft = computed(() => {
  if (isMintable.value) {
    const timeLeft = tokenInfos.value.closedAt - Date.now() / 1000;
    const hours = Math.floor(timeLeft / 3600);
    const minutes = Math.floor((timeLeft % 3600) / 60);
    return `${hours} hours ${minutes} minutes`;
  } else {
    return null;
  }
})


</script>

<template>
  <div v-if="tokenInfosLoading">
    ...
  </div>
  <div v-else-if="tokenInfosIsError" class="text-danger">
    !
  </div>
  <div v-else-if="tokenInfosLoaded" class="token">
    
    <div class="token-line">
      <img :src="tokenInfos.tokenURI.image" />    
      <div>
        <div class="title">
          {{ tokenInfos.tokenURI.name }}
        </div>
        <div>
          {{ tokenInfos.tokenURI.description }}
        </div>
        <div v-if="isMintable" class="text-90">
          Mintable, closes in in {{ timeLeft }}
        </div>
        <div v-else>
          Minting closed
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.token-line {
  display: flex;
  align-items: center;
  gap: 1em;
  font-size: 0.9em;
}

.token-line img {
  max-width: 150px;
  max-height: 150px;
}

.token-line .title {
  font-weight: bold;
}
</style>