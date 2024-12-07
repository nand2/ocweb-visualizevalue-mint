<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useQuery, useQueryClient, useMutation } from '@tanstack/vue-query'
import { useAccount, useSwitchChain, useWriteContract, useWaitForTransactionReceipt, useConnectorClient } from '@wagmi/vue';

import { VVMintCollectionV1Client } from '../../lib/vvmint-collection-v1/client.js';
import { VisualizeValueMintPluginClient } from '../../lib/client.js';

const emit = defineEmits(['formCancelled', 'formExecuted'])

const props = defineProps({
  contractAddress: {
    type: String,
    required: true,
  },
  chainId: {
    type: Number,
    required: true,
  },
  websiteVersionIndex: {
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
  pluginInfos: {
    type: Object,
    required: true,
  },
})


const queryClient = useQueryClient()
const { data: viemClient, isSuccess: viemClientLoaded } = useConnectorClient({
  chainId: props.vvMintchainId
})
const { switchChainAsync, isPending: switchChainIsPending, error: switchChainError } = useSwitchChain()

const visualizeValueMintPluginClient = computed(() => {
  return viemClientLoaded.value ? new VisualizeValueMintPluginClient(viemClient.value, props.contractAddress, props.pluginInfos.plugin) : null;
})

// Prepare the VVMint collection client
const vvMintCollectionClient = computed(() => {
  return viemClientLoaded.value ? new VVMintCollectionV1Client(viemClient.value, props.collectionAddress) : null;
})

// Get the OCWebiste plugin config
const { data: config, isLoading: configLoading, isFetching: configFetching, isError: configIsError, error: configError, isSuccess: configLoaded } = useQuery({
  queryKey: ['OCWebsiteVersionPluginConfig', props.contractAddress, props.chainId, computed(() => props.websiteVersionIndex)],
  queryFn: async () => {
    const result = await visualizeValueMintPluginClient.value.getConfig(props.websiteVersionIndex);
    return result;
  },
  enabled: computed(() => visualizeValueMintPluginClient.value != null),
})

// Fetch infos about the collection
const { data: collectionInfos, isLoading: collectionInfosLoading, isFetching: collectionInfosFetching, isError: collectionInfosIsError, error: collectionInfosError, isSuccess: collectionInfosLoaded } = useQuery({
  queryKey: ['CollectionInfos', props.collectionAddress, props.vvMintchainId],
  queryFn: async () => {
    const response = await fetch(`web3://${props.collectionAddress}:${props.vvMintchainId}/contractURI?returns=(string)`)
    if (!response.ok) {
      throw new Error('Network response was not ok')
    }
    const decodedResponse = await response.json()
    console.log(decodedResponse[0])
    const contractURI = decodedResponse[0];
    
    // ContractURI is a JSON data URL. Decode it.
    const contractURIData = await fetch(contractURI)
    if (!contractURIData.ok) {
      throw new Error('Data URL decoding was not ok')
    }
    const result = await contractURIData.json()
    console.log(result)

    return result;
  },
  staleTime: 3600 * 1000,
})



// Vars
const name = ref('')
const description = ref('')

// Helper function to read the binary data of a file
const readFileData = (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      resolve(reader.result);
    };
    reader.onerror = (error) => {
      reject(error);
    };
    reader.readAsArrayBuffer(file);
  });
};

const imageBinaryData = ref(null)
const imageContentType = ref(null)
const estimatedTransactionCount = ref(0)
const recomputeImageContentTypeAndBinaryData = async () => {
  const files = document.getElementById('collection-image').files;
  const image = files ? files[0] : null;

  if (image) {
    imageContentType.value = image.type;
    imageBinaryData.value = new Uint8Array(await readFileData(image));

    // Estimate the number of transactions
    // We do not reuse the actual transactions, as they are not refreshed on title/description change
    const estimatedTransactions = await vvMintCollectionClient.value.prepareCreateCollectionTokenTransactions(name.value, description.value, imageContentType.value, imageBinaryData.value);
    estimatedTransactionCount.value = estimatedTransactions.length;
  } else {
    imageContentType.value = null;
    imageBinaryData.value = null;
    estimatedTransactionCount.value = 0;
  }
}


// Save the collection token
const { isPending: createCollectionTokenIsPending, isError: createCollectionTokenIsError, error: createCollectionTokenError, isSuccess: createCollectionTokenIsSuccess, mutate: createCollectionTokenMutate, reset: createCollectionTokenReset } = useMutation({
  mutationFn: async () => {

    // Switch the network to the VVMint chain
    await switchChainAsync({ chainId: props.vvMintchainId })

    // Prepare the transactions
    const transactions = await vvMintCollectionClient.value.prepareCreateCollectionTokenTransactions(name.value, description.value, imageContentType.value, imageBinaryData.value);
    console.log(transactions);

    // For each transaction, execute it
    for (let i = 0; i < transactions.length; i++) {
      const transaction = transactions[i];
      console.log(transaction);
      const hash = await vvMintCollectionClient.value.executeTransaction(transaction);
      console.log(hash);

      // Wait for the transaction to be mined
      await vvMintCollectionClient.value.waitForTransactionReceipt(hash);
    }
  },
  onSuccess: async (data) => {
    // Switch back to the original network
    await switchChainAsync({ chainId: props.chainId })

    // Refresh the collection
    await queryClient.invalidateQueries({ queryKey: ['CollectionLatestTokenId', props.collectionAddress, props.vvMintchainId] })

    // Emit the event when the transaction is done
    emit('formExecuted')
  },
  onError: async (error) => {
    // Switch back to the original network
    await switchChainAsync({ chainId: props.chainId })
  }
})
const executePreparedcreateCollectionTokenTransactions = async () => {
    createCollectionTokenMutate()
}

</script>

<template>
  <div class="form">
    <h3 class="title">
      <span>New 24h open edition token</span>
    </h3>

    <div class="text-90" style="margin-bottom: 1em">
      This will create a new token in the collection <strong>{{ collectionInfosLoaded ? collectionInfos.name : '...' }}</strong>, and it will be immediately mintable for 24 hours without any limit. <br />
      The mint price is <a href="https://docs.mint.vv.xyz/guide/how-it-works" target="_blank">twice the mint network gas cost</a> : the minter pay 50% to the network and 50% to the collection creator. <br />
      This form support raw images upload. For more advanced renderers (p5.js, ...), use the <a :href="'web3://' + contractAddress + ':' + chainId + '/' + (configLoaded && config.rootPath.length > 0 ? config.rootPath.join('/') + '/' : '') + '#/' + collectionAddress" target="_blank">form provided by the frontend</a>.
    </div>

    <div style="margin-bottom: 1em; display: grid; gap: 1em; grid-template-columns: 1fr 1fr;">
      <div>
        <label>Name</label>
        <input type="text" v-model="name" placeholder="Name" />
      </div>
    </div>

    <div style="margin-bottom: 1em; display: grid; gap: 1em; grid-template-columns: 2fr 1fr;">
      <div>
        <label>Description</label>
        <input type="text" v-model="description" placeholder="" rows="5" />
      </div>
    </div>

    <div style="margin-bottom: 1em; display: grid; gap: 1em; grid-template-columns: 1fr;">
      <div>
        <label>Image</label>
        <input type="file" id="collection-image" accept="image/*" @change="recomputeImageContentTypeAndBinaryData()" />
      </div>
    </div>

    <div v-if="createCollectionTokenIsError" class="mutation-error">
      <span>
        Error creating the token {{ createCollectionTokenError.shortMessage || createCollectionTokenError.message }} <a @click.stop.prevent="createCollectionTokenReset()">Hide</a>
      </span>
    </div>

    <div v-if="estimatedTransactionCount > 1" class="text-warning text-90" style="margin-bottom: 1em; text-align: right;" >
      <strong>Number of transactions needed: {{ estimatedTransactionCount }}</strong>
      <br />
      Try reducing the image size.
    </div>

    <div class="buttons">
      <button @click="$emit('formCancelled')" :disabled="createCollectionTokenIsPending">Cancel</button>
      <button @click="executePreparedcreateCollectionTokenTransactions" :disabled="name == '' || description == '' || imageBinaryData == null || createCollectionTokenIsPending">Save</button>
    </div>
      


  </div>
</template>

<style scoped>
.form {
  padding: 0em 1em 1em 1em;
  font-size: 0.9em;
}

.title {
  margin-bottom: 0.5em;
  font-size: 1.25em;
}

label {
  display: block;
  font-weight: bold;
  margin-bottom: 0.2em;
}

label small {
  font-size: 0.8em;
  font-weight: normal;
  color: var(--color-text-muted);
}

.form input, .form textarea {
  width: 100%; 
  box-sizing: border-box;
}


.buttons {
  display: flex;
  gap: 0.5em;
  justify-content: flex-end;
}
</style>