<template>
  <ModalDialog :title="$t('collection.add_to_collection')" :width="600" @cancel="close">
    <section class="space-y-3">
      <div class="h-8 flex items-center rounded-box overflow-hidden bg-base-100 border border-neutral-content/30 focus-within:border-primary">
        <IconSearch class="ml-2 w-4 h-4 text-base-content/70" />
        <input ref="searchInput" v-model="query" :placeholder="$t('collection.search')" class="w-full bg-transparent border-none focus:ring-0 px-2 text-sm placeholder-base-content/30 focus:outline-none" />
        <button v-if="query" class="mr-1 p-1 text-base-content/30 hover:text-base-content/70" @click="query = ''">
          <IconClose class="w-4 h-4" />
        </button>
      </div>
      <div v-if="!query && recentCollections.length" class="text-[10px] uppercase tracking-widest font-bold text-base-content/30">{{ $t('collection.recent') }}</div>
      <div class="min-h-24 max-h-96 overflow-y-auto rounded-box p-1 bg-base-100/30 border border-base-content/5">
        <div
          v-for="collection in visibleCollections"
          :key="collection.id"
          class="w-full mb-1 px-2 py-2 flex items-center gap-2 rounded-box text-left cursor-pointer hover:bg-base-content/10"
          :class="selectedIds.has(Number(collection.id)) ? 'bg-primary/15 text-primary' : ''"
          tabindex="0"
          @click="toggle(collection.id)"
          @keydown.enter.prevent="toggle(collection.id)"
          @keydown.space.prevent="toggle(collection.id)"
        >
          <label class="flex items-center cursor-pointer shrink-0" @click.stop @dblclick.stop>
            <input
              type="checkbox"
              class="checkbox checkbox-xs"
              :checked="selectedIds.has(Number(collection.id))"
              @change="toggle(collection.id)"
            />
          </label>
          <IconBookmark class="w-4 h-4 shrink-0" />
          <span class="min-w-0 flex-1 truncate">{{ collection.name }}</span>
          <span v-if="Number(collection.count || 0) > 0" class="sidebar-item-count shrink-0">{{ Number(collection.count || 0).toLocaleString() }}</span>
        </div>
        <div v-if="visibleCollections.length === 0" class="min-h-24 flex items-center justify-center text-sm text-base-content/30">
          {{ $t('collection.not_found') }}
        </div>
      </div>
    </section>
    <div class="mt-4 flex justify-end gap-3">
      <button class="t-button-default" @click="close">{{ $t('msgbox.cancel') }}</button>
      <button class="t-button-primary" :disabled="selectedIds.size === 0 || applying" @click="apply">{{ $t('collection.drop_action') }}</button>
    </div>
  </ModalDialog>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import { addFilesToCollection, listCollections } from '@/common/api';
import { IconBookmark, IconClose, IconSearch } from '@/common/icons';
import ModalDialog from '@/components/ModalDialog.vue';
import { useUIStore } from '@/stores/uiStore';

const props = defineProps<{ fileIds: number[] }>();
const emit = defineEmits(['applied', 'cancel']);
const collections = ref<any[]>([]);
const query = ref('');
const selectedIds = ref(new Set<number>());
const applying = ref(false);
const searchInput = ref<HTMLInputElement | null>(null);
const uiStore = useUIStore();

const matchingCollections = computed(() => {
  const normalized = query.value.trim().toLocaleLowerCase();
  return normalized ? collections.value.filter(c => String(c.name).toLocaleLowerCase().includes(normalized)) : collections.value;
});
const recentCollections = computed(() => [...collections.value]
  .sort((a, b) => Number(b.updatedAt ?? b.updated_at ?? 0) - Number(a.updatedAt ?? a.updated_at ?? 0))
  .slice(0, 5));
const visibleCollections = computed(() => query.value.trim() ? matchingCollections.value : recentCollections.value);

onMounted(async () => {
  window.addEventListener('keydown', handleKeyDown);
  uiStore.pushInputHandler('AddToCollectionDialog');
  collections.value = (await listCollections()) || [];
  await nextTick();
  searchInput.value?.focus();
});

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleKeyDown);
  uiStore.removeInputHandler('AddToCollectionDialog');
});

function close() {
  if (!applying.value) emit('cancel');
}

function handleKeyDown(event: KeyboardEvent) {
  if (event.key === 'Escape' && uiStore.isInputActive('AddToCollectionDialog')) {
    event.preventDefault();
    close();
  }
}

function toggle(id: number) {
  const normalized = Number(id);
  const next = new Set(selectedIds.value);
  next.has(normalized) ? next.delete(normalized) : next.add(normalized);
  selectedIds.value = next;
}

async function apply() {
  const fileIds = [...new Set(props.fileIds.map(Number).filter(id => id > 0))];
  if (!fileIds.length || !selectedIds.value.size || applying.value) return;
  applying.value = true;
  try {
    const settled = await Promise.allSettled([...selectedIds.value].map(collectionId => addFilesToCollection(collectionId, fileIds)));
    const results = settled
      .filter((result): result is PromiseFulfilledResult<any> => result.status === 'fulfilled')
      .map(result => result.value);
    emit('applied', { fileIds, results, failed: settled.length - results.length });
  } finally {
    applying.value = false;
  }
}
</script>
