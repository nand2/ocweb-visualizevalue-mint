<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useQueryClient, useMutation } from '@tanstack/vue-query'
import { useAccount, useSwitchChain, useWriteContract, useWaitForTransactionReceipt } from '@wagmi/vue';


const emit = defineEmits(['formCancelled', 'formExecuted'])

const props = defineProps({
  chainId: {
    type: Number,
    required: true,
  },
  creatorAddress: {
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
  vvMintFactoryClient: {
    type: Object,
    required: true,
  },
})


const queryClient = useQueryClient()
const { switchChainAsync, isPending: switchChainIsPending, error: switchChainError } = useSwitchChain()

// Vars
const name = ref('')
const symbol = ref('')
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
const recomputeImageContentTypeAndBinaryData = async () => {
  const files = document.getElementById('collection-image').files;
  const image = files ? files[0] : null;

  if (image) {
    imageContentType.value = image.type;
    imageBinaryData.value = new Uint8Array(await readFileData(image));
  } else {
    imageContentType.value = null;
    imageBinaryData.value = null;
  }
}


// Save the collection
const { isPending: createCollectionIsPending, isError: createCollectionIsError, error: createCollectionError, isSuccess: createCollectionIsSuccess, mutate: createCollectionMutate, reset: createCollectionReset } = useMutation({
  mutationFn: async () => {

    // Prepare the transaction
    const transaction = await props.vvMintFactoryClient.prepareCreateCollectionTransaction(name.value, symbol.value, description.value, imageContentType.value, imageBinaryData.value);
    console.log(transaction);

    // Switch the network to the VVMint chain
    await switchChainAsync({ chainId: props.vvMintchainId })

    const hash = await props.vvMintFactoryClient.executeTransaction(transaction);
    console.log(hash);

    // Wait for the transaction to be mined
    return await props.vvMintFactoryClient.waitForTransactionReceipt(hash);
  },
  scope: {
    // This scope will make the mutations run serially
    id: 'createCollection'
  },
  onSuccess: async (data) => {
    // Switch back to the original network
    await switchChainAsync({ chainId: props.chainId })

    // Refresh the collection list
    await queryClient.invalidateQueries({ queryKey: ['PluginVVMintcollections', props.pluginInfos.plugin, props.vvMintchainId, props.creatorAddress] })

    // Emit the event when the transaction is done
    emit('formExecuted')
  },
})
const executePreparedcreateCollectionTransactions = async () => {
    createCollectionMutate()
}

</script>

<template>
  <div class="form">
    <h3 class="title">
      <span>New collection</span>
    </h3>

    <div style="margin-bottom: 1em">
      This will create an ERC-1155 NFT collection, in which you will be able to create NFTs.
    </div>

    <div style="margin-bottom: 1em; display: grid; gap: 1em; grid-template-columns: 1fr 200px;">
      <div>
        <label>Collection name</label>
        <input type="text" v-model="name" placeholder="Name" />
      </div>
      <div>
        <label>Collection symbol</label>
        <input type="text" v-model="symbol" placeholder="e.g. MNC, ABC, 3PL, ..." />
        <div class="text-80" style="margin-top: 0.5em;">
          Short identifier for your collection. It can only contain letters and numbers.
        </div>
      </div>
    </div>

    <div style="margin-bottom: 1em; display: grid; gap: 1em; grid-template-columns: 1fr 1fr;">
      <div>
        <label>Description <small>Optional</small></label>
        <input type="text" v-model="description" placeholder="" />
      </div>
      <div>
        <label>Image <small>Optional</small></label>
        <input type="file" id="collection-image" accept="image/*" @change="recomputeImageContentTypeAndBinaryData()" />
      </div>
    </div>

    <div v-if="createCollectionIsError" class="mutation-error">
      <span>
        Error creating the collection: {{ createCollectionError.shortMessage || createCollectionError.message }} <a @click.stop.prevent="createCollectionReset()">Hide</a>
      </span>
    </div>

    <div class="buttons">
      <button @click="$emit('formCancelled')" :disabled="createCollectionIsPending">Cancel</button>
      <button @click="executePreparedcreateCollectionTransactions" :disabled="name == '' || symbol == '' ||  createCollectionIsPending">Save</button>
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