<script setup>
import { computed, ref, watch } from 'vue'
import { useQuery, useQueryClient, useMutation } from '@tanstack/vue-query'
import { useConnectorClient } from '@wagmi/vue';

import { useIsLocked } from 'ocweb/src/tanstack-vue.js';
import { useStaticFrontendPluginClient, useStaticFrontend, useStaticFrontendFileContent, invalidateStaticFrontendFileContentQuery } from 'ocweb/src/plugins/staticFrontend/tanstack-vue.js';

import PencilSquareIcon from './Icons/PencilSquareIcon.vue';
import { defaultConfig } from '../assets/defaultConfig';
import { VisualizeValueMintPluginClient } from '../lib/client.js';

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

const visualizeValueMintPluginClient = computed(() => {
  return viemClientLoaded.value ? new VisualizeValueMintPluginClient(viemClient.value, props.contractAddress, props.pluginInfos.plugin) : null;
})

// Get the lock status
const { data: isLocked, isLoading: isLockedLoading, isFetching: isLockedFetching, isError: isLockedIsError, error: isLockedError, isSuccess: isLockedLoaded } = useIsLocked(props.contractAddress, props.chainId)

// Get the available themes
const { data: availableThemes, isLoading: availableThemesLoading, isFetching: availableThemesFetching, isError: availableThemesIsError, error: availableThemesError, isSuccess: availableThemesLoaded } = useQuery({
  queryKey: ['PluginVVMintAvailableThemes', props.pluginInfos.plugin],
  queryFn: async () => {
    const result = await visualizeValueMintPluginClient.value.getThemes();
    return result;
  },
  staleTime: 3600 * 1000,
  enabled: computed(() => visualizeValueMintPluginClient.value != null),
})

// Get the config
const { data: config, isLoading: configLoading, isFetching: configFetching, isError: configIsError, error: configError, isSuccess: configLoaded } = useQuery({
  queryKey: ['OCWebsiteVersionPluginConfig', props.contractAddress, props.chainId, computed(() => props.websiteVersionIndex)],
  queryFn: async () => {
    const result = await visualizeValueMintPluginClient.value.getConfig(props.websiteVersionIndex);
    return result;
  },
  enabled: computed(() => visualizeValueMintPluginClient.value != null && availableThemesLoaded.value),
})

// Load the unserialized root path
const rootPathFieldValue = ref(configLoaded.value ? config.value.rootPath.join("/") : "")
watch(config, () => {
  rootPathFieldValue.value = config.value.rootPath.join("/")
})

// Load the theme
const themeFieldValue = ref(
  configLoaded.value ? 
    (config.value.theme != "0x0000000000000000000000000000000000000000" ? 
      config.value.theme : 
      (availableThemesLoaded.value && availableThemes.value.length > 0 ? 
        availableThemes.value[0].fileServer : 
        null)) 
    : null)
watch(config, () => {
  themeFieldValue.value = config.value.theme
  if(themeFieldValue.value == "0x0000000000000000000000000000000000000000" && availableThemesLoaded.value && availableThemes.value.length > 0) {
    themeFieldValue.value = availableThemes.value[0].fileServer
  }
})

const showForm = ref(false)

// Save the config
const { isPending: saveIsPending, isError: saveIsError, error: saveError, isSuccess: saveIsSuccess, mutate: saveMutate, reset: saveReset } = useMutation({
  mutationFn: async () => {
    // Prepare the transaction
    const transaction = await visualizeValueMintPluginClient.value.prepareSetConfigTransaction(props.websiteVersionIndex, { rootPath: rootPathFieldValue.value.split('/').filter(part => part != ""), theme: themeFieldValue.value });
    console.log(transaction)
    const hash = await visualizeValueMintPluginClient.value.executeTransaction(transaction);
  },
  onSuccess: () => {
    showForm.value = false

    queryClient.invalidateQueries(['OCWebsiteVersionPluginConfig', props.contractAddress, props.chainId, props.websiteVersionIndex])
  }
})
const save = async () => {
  // We process the root path: Remove invalid stuff
  rootPathFieldValue.value = rootPathFieldValue.value.split("#")[0].split("?")[0].split("/").map(part => part.trim()).filter(part => part != "").join("/");

  if(rootPathFieldValue.value == config.value.rootPath.join("/") && themeFieldValue.value == config.value.theme) {
    showForm.value = false
    return
  }

  saveMutate()
}

</script>

<template>
  <div class="admin">

    <div class="form-field">
      <label>Root path <small>Path where the app is served</small></label>

      <div style="font-size: 0.9em; display: flex; gap: 0.5em; align-items: center;">
        <span>
          <span class="text-muted">web3://{{ contractAddress }}{{ chainId > 1 ? ":" + chainId : "" }}</span>/<span v-show="showForm == false">{{ configLoaded ? config.rootPath.join("/") + (config.rootPath.length > 0 ? "/" : "") : "" }}
          </span>
        </span>

        <a v-if="isLockedLoaded && isLocked == false && websiteVersion.locked == false && showForm == false" @click.stop.prevent="showForm = true" class="white" style="line-height: 0em">
          <PencilSquareIcon />
        </a>

        <div style="display: flex; gap: 0.5em;" v-if="showForm">
          <input type="text" v-model="rootPathFieldValue" style="padding: 0.2em 0.5em;" placeholder="Root path" :disabled="saveIsPending" />
        </div>
      </div>
      
    </div>

    <div class="form-field">
      <label>Theme</label>
      <select v-model="themeFieldValue" class="form-select" :disabled="isLockedLoaded && isLocked || websiteVersion.locked || saveIsPending">
        <option v-for="availableTheme in availableThemes" :key="availableTheme.fileServer" :value="availableTheme.fileServer">{{ availableTheme.name }}</option>
      </select>
      
    </div>


    <div class="mutation-error text-80" v-if="saveIsError" style="margin-top: 0.5em;">
      Error saving the config: {{ saveError.shortMessage || saveError.message }}  <a @click.stop.prevent="saveReset()">Hide</a>
    </div>  

    <div class="buttons">
      <button @click="save()" :disabled="isLockedLoaded && isLocked || websiteVersion.locked || saveIsPending">
        <span v-if="saveIsPending">
          Saving in progress...
        </span>
        <span v-else>
          Save
        </span>
      </button>
    </div>

  </div>
</template>

<style scoped>

label {
  display: block;
  font-weight: bold;
  font-size: 0.9em;
}

label small {
  font-size: 0.8em;
  font-weight: normal;
  color: var(--color-text-muted);
}

.form-field {
  margin-bottom: 0.5em;
}

.buttons {
  display: flex;
  gap: 1em;
  justify-content: right;
}

</style>
