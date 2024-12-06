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
import CollectionCreationForm from './collection/CollectionCreationForm.vue';
import CollectionTokenCreationForm from './collection/CollectionTokenCreationForm.vue';
import Collection from './collection/Collection.vue';

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

const { data: viemClient, isSuccess: viemClientLoaded } = useConnectorClient({
  chainId: config.value.chainId,
  enabled: computed(() => config.value.chainId != null),
})


// Prepare the VVMint factory client
const vvMintFactoryClient = computed(() => {
  return viemClientLoaded.value && vvmintFactoryAddress.value ? new VVMintFactoryClient(viemClient.value, vvmintFactoryAddress.value) : null;
})

// Get the version of the factory
const { data: factoryVersion, isLoading: factoryVersionLoading, isFetching: factoryVersionFetching, isError: factoryVersionIsError, error: factoryVersionError, isSuccess: factoryVersionLoaded } = useQuery({
  queryKey: ['VVMintFactoryVersion', vvmintFactoryAddress.value, computed(() => config.value.chainId)],
  queryFn: async () => {
    const response = await fetch(`web3://${vvmintFactoryAddress.value}:${config.value.chainId}/version?returns=(uint256)`)
    if (!response.ok) {
      throw new Error('Network response was not ok')
    }
    const decodedResponse = await response.json()
    // console.log(decodedResponse[0])
    return Number(decodedResponse[0]);
  },
  staleTime: 3600 * 1000,
  enabled: computed(() => vvMintFactoryClient.value != null),
})

// Fetch the list of collections of the creator
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
    // console.log(decodedResponse)
    const result = decodedResponse[0];

    return result;
  },
  staleTime: 3600 * 1000,
  enabled: computed(() => vvMintFactoryClient.value != null && config.value.creatorAddress != null),
})

// Do we show the collection creation form?
const showCollectionCreationForm = ref(false)
// Do we show the collection token creation form?
const showCollectionTokenCreationForm = ref(false)
const collectionOfCollectionTokenCreationForm = ref(null)

</script>

<template>
  <div>
    
    <div class="collection-index" v-if="showCollectionCreationForm == false && showCollectionTokenCreationForm == false">
   
      <div v-if="staticFrontendLoaded && configFileInfos == null" class="not-configured text-90">
        The <strong>VV Mint Artist Platform</strong> plugin has not yet been configured and is showing the default creator. <br /> Please go to the plugins tab to configure it with your own address.
      </div>

      <div v-else-if="staticFrontendLoaded">

        <div class="collections">
          <h3>My 24h open edition collections</h3>

          <div v-if="collectionsLoading">
            Loading collections...
          </div>

          <div v-else-if="collectionsIsError" class="text-danger">
            Failed to load collections: {{ collectionsError }}
          </div>

          <div v-else-if="collectionsLoaded && collections.length == 0">
            You have no collections yet.
          </div>

          <div v-else-if="collectionsLoaded && collections.length > 0">
            <div
              v-for="collection in collections"
              :key="collection"
              class="collection"
              >
              <Collection
                :chainId
                :vvMintchainId="config.chainId"
                :collectionAddress="collection"
                :vvMintFactoryClient
                @show-collection-token-creation-form="showCollectionTokenCreationForm = true; collectionOfCollectionTokenCreationForm = collection;"
                />
            </div>
          </div>

          <div class="operations">
            <div class="op-add-new-collection" v-if="vvMintFactoryClient && factoryVersionLoaded && factoryVersion == 1">
              <div class="button-area">
                <span class="button-text" @click="showCollectionCreationForm = true;">
                  <PlusLgIcon /> Add new collection
                </span>
              </div>
            </div>
          </div>
        </div>



      </div>
    </div>

    <div v-else-if="showCollectionCreationForm" class="collection-creation-form">    
      <CollectionCreationForm
        :chainId
        :vvMintchainId="config.chainId"
        :creatorAddress="config.creatorAddress"
        :pluginInfos
        :vvMintFactoryClient
        @form-cancelled="showCollectionCreationForm = false;"
        @form-executed="showCollectionCreationForm = false;"
        />
    </div>

    <div v-else-if="showCollectionTokenCreationForm" class="collection-token-creation-form">
      <CollectionTokenCreationForm
        :contractAddress
        :chainId
        :websiteVersionIndex
        :vvMintchainId="config.chainId"
        :collectionAddress="collectionOfCollectionTokenCreationForm"
        :pluginInfos
        @form-cancelled="showCollectionTokenCreationForm = false;"
        @form-executed="showCollectionTokenCreationForm = false;"
        />
      </div>

  </div>
</template>

<style scoped>

.not-configured {
  padding: 2em;
  text-align: center;
}

.collections {
  margin: 1em;
}

.collection {
  margin: 1em 0;
  padding-bottom: 1em;
  border-bottom: 1px solid var(--color-divider-secondary);
}

.collection:last-child {
  padding-bottom: 0;
  border-bottom: none;
}

</style>
