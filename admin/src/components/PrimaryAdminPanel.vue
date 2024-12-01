<script setup>
import { computed, ref, watch } from 'vue'
import { useQuery, useQueryClient, useMutation } from '@tanstack/vue-query'
import { useConnectorClient } from '@wagmi/vue';

import { useIsLocked } from 'ocweb/src/tanstack-vue.js';
import { useStaticFrontendPluginClient, useStaticFrontend, useStaticFrontendFileContent, invalidateStaticFrontendFileContentQuery } from 'ocweb/src/plugins/staticFrontend/tanstack-vue.js';

import PlusLgIcon from './Icons/PlusLgIcon.vue';
import TrashIcon from './Icons/TrashIcon.vue';
import SaveIcon from './Icons/SaveIcon.vue';
import { defaultConfig } from '../assets/defaultConfig';
import { VVMintFactoryClient } from '../lib/vvmint-factory/client.js';

const props = defineProps({
  contractAddress: {
    type: String,
    required: true,
  },
  chainId: {
    type: Number,
    required: true,
  },
  websiteVersion: {
    type: Object,
    required: true
  },
  websiteVersionIndex: {
    type: Number,
    required: true,
  },
  websiteClient: {
    type: Object,
    required: true,
  },
  pluginsInfos: {
    type: Array,
    required: true,
  },
  pluginInfos: {
    type: Object,
    required: true,
  },
})

const queryClient = useQueryClient()
const { data: viemClient, isSuccess: viemClientLoaded } = useConnectorClient()

// Get the staticFrontendPlugin
const staticFrontendPlugin = computed(() => {
  return props.pluginsInfos.find(plugin => plugin.infos.name == 'staticFrontend')
})

// Get the staticFrontendPluginClient
const { data: staticFrontendPluginClient, isLoading: staticFrontendPluginClientLoading, isFetching: staticFrontendPluginClientFetching, isError: staticFrontendPluginClientIsError, error: staticFrontendPluginClientError, isSuccess: staticFrontendPluginClientLoaded } = useStaticFrontendPluginClient(props.contractAddress, staticFrontendPlugin.value.plugin)

// Get the staticFrontend
const { data: staticFrontend, isLoading: staticFrontendLoading, isFetching: staticFrontendFetching, isError: staticFrontendIsError, error: staticFrontendError, isSuccess: staticFrontendLoaded } = useStaticFrontend(queryClient, props.contractAddress, props.chainId, staticFrontendPlugin.value.plugin, computed(() => props.websiteVersionIndex))

// Get the existing config file infos
const configFileInfos = computed(() => {
  return staticFrontendLoaded.value ? staticFrontend.value.files.find(file => file.filePath == '.config/visualizevalue-mint/config.json') : null
})

// Fetch the config file content
const { data: fileContent, isLoading: fileContentLoading, isFetching: fileContentFetching, isError: fileContentIsError, error: fileContentError, isSuccess: fileContentLoaded } = useStaticFrontendFileContent(props.contractAddress, props.chainId, staticFrontendPlugin.value.plugin, computed(() => props.websiteVersionIndex), computed(() => configFileInfos.value))

// Decode and load the config
const decodeConfigFileContent = (fileContent) => {
  const decodedConfig = fileContent ? JSON.parse(new TextDecoder().decode(fileContent)) : {};
  return { ...defaultConfig, ...decodedConfig };
}
const config = ref(fileContent.value ? decodeConfigFileContent(fileContent.value) : defaultConfig)
// When the file content is fetched, set the text
watch(fileContent, (newValue) => {
  if(fileContentLoaded.value) {
    config.value = decodeConfigFileContent(newValue)
  }
});

// The list of available blockchains where VV Mint is deployed
const availableVVMintBlockchains = [{
  chainId: 1,
  name: "Ethereum mainnet",
  factory: "0xd717Fe677072807057B03705227EC3E3b467b670",
}, {
  chainId: 11155111,
  name: "Sepolia (testnet)",
  factory: "0x750C5a6CFD40C9CaA48C31D87AC2a26101Acd517",
}, {
  chainId: 31337,
  name: "Hardhat",
  factory: "0x870526b7973b56163a6997bB7C886F5E4EA53638",
}]

// Determine the VVMInt factory address
const vvmintFactoryAddress = computed(() => {
  return config.value ? availableVVMintBlockchains.find(blockchain => blockchain.chainId == config.value.chainId).factory : null;
})

// Prepare the VVMint factory client
const vvMintFactoryClient = computed(() => {
  return viemClientLoaded.value && vvmintFactoryAddress.value ? new VVMintFactoryClient(viemClient.value, vvmintFactoryAddress.value) : null;
})

// Fetch the list of collections of the creator
// Get the available themes
const { data: collections, isLoading: collectionsLoading, isFetching: collectionsFetching, isError: collectionsIsError, error: collectionsError, isSuccess: collectionsLoaded } = useQuery({
  queryKey: ['PluginVVMintcollections', props.pluginInfos.plugin, computed(() => config.value.chainId), computed(() => config.value.creatorAddress)],
  queryFn: async () => {
    // Non web3:// would require asking the user to switch chain, let's keep that when creating 
    // a collection
    // const result = await vvMintFactoryClient.value.getCreatorCollections(config.value.creatorAddress);
    
    const response = await fetch(`web3://${vvmintFactoryAddress.value}:${config.value.chainId}/getCreatorCollections/${config.value.creatorAddress}?returns=(address[])`)
    if (!response.ok) {
      throw new Error('Network response was not ok')
    }
    const decodedResponse = await response.json()
    console.log(decodedResponse)
    const result = decodedResponse[0];

    return result;
  },
  staleTime: 3600 * 1000,
  enabled: computed(() => vvMintFactoryClient.value != null && config.value.creatorAddress != null),
})

</script>

<template>
  <div>
   
    <div v-if="staticFrontendLoaded && configFileInfos == null" class="not-configured">
      The <strong>VV Mint Artist Platform</strong> plugin has not yet been configured and is the default creator address. <br /> Please go to the plugins tab to configure it with your own address.
    </div>

    <div v-else-if="staticFrontendLoaded">

      <div class="collections">
        <h3>My collections</h3>
        {{ collectionsError }}{{ collections }}
      </div>

      <div class="create-collection-form">

        <div v-if="hasFormErrors && showFormErrors" class="text-danger text-90">
          Please fix the errors in the form
        </div>

        <div v-if="prepareAddFilesIsError" class="mutation-error">
          <span>
            Error preparing the transaction to save the config: {{ prepareAddFilesError.shortMessage || prepareAddFilesError.message }} <a @click.stop.prevent="prepareAddFilesReset()">Hide</a>
          </span>
        </div>

        <div v-if="addFilesIsError" class="mutation-error">
          <span>
            Error saving the config: {{ addFilesError.shortMessage || addFilesError.message }} <a @click.stop.prevent="addFilesReset()">Hide</a>
          </span>
        </div>

        <div class="buttons">
          <button @click="prepareAddFilesTransactions" :disabled="isLockedLoaded && isLocked || websiteVersion.locked || prepareAddFilesIsPending || addFilesIsPending">
            <span v-if="prepareAddFilesIsPending || addFilesIsPending">
              <SaveIcon class="anim-pulse" />
              Saving in progress...
            </span>
            <span v-else>
              Save
            </span>
          </button>
        </div>

      </div>

    </div>

    

  </div>
</template>

<style scoped>

.not-configured {
  padding: 2em;
  text-align: center;
}


</style>
