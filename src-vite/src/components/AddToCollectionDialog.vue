<template>
  <ModalDialog :title="$t('collection.add_to_collection')" :width="600" @cancel="close">
    <section class="space-y-3">
      <div class="flex items-center gap-2">
        <div class="grow h-8 flex items-center rounded-box overflow-hidden bg-base-100 border border-neutral-content/30 focus-within:border-primary">
          <IconSearch class="ml-2 w-4 h-4 text-base-content/70" />
          <input ref="searchInput" v-model="query" :placeholder="$t('collection.search')" class="w-full bg-transparent border-none focus:ring-0 px-2 text-sm placeholder-base-content/30 focus:outline-none" />
          <button v-if="query" class="mr-1 p-1 text-base-content/30 hover:text-base-content/70" @click="query = ''">
            <IconClose class="w-4 h-4" />
          </button>
        </div>
        <div class="w-1/2 h-8 flex items-center rounded-box overflow-hidden bg-base-100 border border-neutral-content/30 focus-within:border-primary">
          <input
            ref="newCollectionNameInput"
            v-model="newCollectionName"
            :placeholder="$t('collection.enter_new_collection_name')"
            class="w-full bg-transparent border-none focus:ring-0 px-2 text-sm placeholder-base-content/30 focus:outline-none"
            @keydown.enter="addNewCollection"
          />
          <button v-if="newCollectionName" class="mr-1 p-1 text-base-content/30 hover:text-base-content/70" @click="newCollectionName = ''">
            <IconClose class="w-4 h-4" />
          </button>
        </div>
        <TButton :icon="IconAdd" :tooltip="$t('collection.add')" :disabled="creatingCollection || collections.length >= config.main.maxCollectionCount" @click="addNewCollection" />
      </div>
      <div v-if="collections.length" class="text-[10px] uppercase tracking-widest font-bold text-base-content/30 select-none">{{ $t('collection.title') }}</div>
      <div class="min-h-24 max-h-52 overflow-y-auto rounded-box p-1 bg-base-100/30 border border-base-content/5 select-none">
        <div
          v-for="collection in visibleCollections"
          :key="collection.id"
          :ref="element => setCollectionRowRef(Number(collection.id), element)"
          class="group w-full p-2 flex items-center gap-1 rounded-box text-left cursor-pointer hover:bg-base-content/5 transition-colors"
          :class="selectedIds.has(Number(collection.id)) ? 'text-primary' : ''"
          tabindex="0"
          @click="toggle(collection.id)"
          @keydown.enter.prevent="toggle(collection.id)"
          @keydown.space.prevent="toggle(collection.id)"
        >
          <label class="flex items-center cursor-pointer shrink-0" @click.stop @dblclick.stop>
            <input
              type="checkbox"
              class="checkbox checkbox-xs"
              :class="selectedIds.has(Number(collection.id)) ? 'checkbox-primary opacity-70' : ''"
              :checked="selectedIds.has(Number(collection.id))"
              @change="toggle(collection.id)"
            />
          </label>
          <IconBookmark class="w-4 h-4 shrink-0" />
          <input
            v-if="renamingId === Number(collection.id)"
            ref="renameInput"
            v-model="renameValue"
            class="input px-1 min-w-0 flex-1 text-sm"
            maxlength="64"
            @click.stop
            @mousedown.stop
            @keydown.stop
            @keydown.enter.prevent="commitRename(collection)"
            @keydown.escape.prevent="cancelRename"
            @blur="commitRename(collection)"
          />
          <span v-else class="min-w-0 flex-1 truncate">{{ collection.name }}</span>
          <span
            v-if="renamingId !== Number(collection.id) && Number(collection.count || 0) > 0"
            class="sidebar-item-count shrink-0"
            :class="selectedIds.has(Number(collection.id)) ? 'hidden' : 'group-hover:hidden'"
          >
            {{ Number(collection.count || 0).toLocaleString() }}
          </span>
          <div
            v-if="renamingId !== Number(collection.id)"
            class="shrink-0 hidden group-hover:flex"
          >
            <button type="button" class="p-1 text-base-content/40 hover:text-base-content cursor-pointer" :title="$t('collection.rename')" @click.stop="startRename(collection)">
              <IconEdit class="w-4 h-4" />
            </button>
            <button type="button" class="p-1 text-base-content/40 hover:text-error cursor-pointer" :title="$t('collection.delete')" @click.stop="deleteCollection(collection)">
              <IconTrash class="w-4 h-4 cursor-pointer" />
            </button>
          </div>
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
  <MessageBox
    v-if="deleteTarget"
    :title="$t('collection.delete_confirm_title')"
    :message="$t('collection.delete_confirm_message', { name: deleteTarget.name })"
    :OkText="$t('collection.delete_confirm_ok')"
    :cancelText="$t('msgbox.cancel')"
    :warningOk="true"
    @ok="confirmDelete"
    @cancel="deleteTarget = null"
  />
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import { emit as tauriEmit } from '@tauri-apps/api/event';
import { addFilesToCollection, createCollection, deleteCollection as deleteCollectionApi, listCollections, renameCollection } from '@/common/api';
import { IconAdd, IconBookmark, IconClose, IconEdit, IconSearch, IconTrash } from '@/common/icons';
import { config } from '@/common/config';
import MessageBox from '@/components/MessageBox.vue';
import ModalDialog from '@/components/ModalDialog.vue';
import TButton from '@/components/TButton.vue';
import { useUIStore } from '@/stores/uiStore';

const props = defineProps<{ fileIds: number[] }>();
const emit = defineEmits(['applied', 'cancel']);
const collections = ref<any[]>([]);
const query = ref('');
const selectedIds = ref(new Set<number>());
const applying = ref(false);
const creatingCollection = ref(false);
const searchInput = ref<HTMLInputElement | null>(null);
const newCollectionNameInput = ref<HTMLInputElement | null>(null);
const newCollectionName = ref('');
const renamingId = ref<number | null>(null);
const renameValue = ref('');
const renameInput = ref<HTMLInputElement | HTMLInputElement[] | null>(null);
const deleteTarget = ref<any | null>(null);
const collectionRowRefs = new Map<number, Element>();
const uiStore = useUIStore();

const matchingCollections = computed(() => {
  const normalized = query.value.trim().toLocaleLowerCase();
  return normalized ? collections.value.filter(c => String(c.name).toLocaleLowerCase().includes(normalized)) : collections.value;
});
const visibleCollections = computed(() => matchingCollections.value);

onMounted(async () => {
  window.addEventListener('keydown', handleKeyDown);
  uiStore.pushInputHandler('AddToCollectionDialog');
  await loadCollections();
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

async function toggle(id: number) {
  const normalized = Number(id);
  const next = new Set(selectedIds.value);
  next.has(normalized) ? next.delete(normalized) : next.add(normalized);
  selectedIds.value = next;
  await nextTick();
  collectionRowRefs.get(normalized)?.scrollIntoView({ block: 'nearest' });
}

function setCollectionRowRef(id: number, element: Element | null) {
  if (element) collectionRowRefs.set(id, element);
  else collectionRowRefs.delete(id);
}

async function loadCollections() {
  collections.value = (await listCollections()) || [];
}

async function addNewCollection() {
  const name = newCollectionName.value.trim();
  if (!name || creatingCollection.value || collections.value.length >= config.main.maxCollectionCount) return;
  creatingCollection.value = true;
  try {
    const collection = await createCollection(name);
    if (!collection?.id) return;
    await loadCollections();
    const next = new Set(selectedIds.value);
    next.add(Number(collection.id));
    selectedIds.value = next;
    newCollectionName.value = '';
    query.value = '';
    await nextTick();
    newCollectionNameInput.value?.focus();
    await tauriEmit('collections-changed');
  } finally {
    creatingCollection.value = false;
  }
}

async function startRename(collection: any) {
  renamingId.value = Number(collection.id);
  renameValue.value = String(collection.name || '');
  await nextTick();
  const input = Array.isArray(renameInput.value) ? renameInput.value[0] : renameInput.value;
  input?.focus({ preventScroll: true });
  input?.select();
}

function cancelRename() {
  renamingId.value = null;
  renameValue.value = '';
}

async function commitRename(collection: any) {
  if (renamingId.value !== Number(collection.id)) return;
  const name = renameValue.value.trim();
  if (name && name !== collection.name) {
    await renameCollection(Number(collection.id), name);
    await loadCollections();
    await tauriEmit('collections-changed');
  }
  cancelRename();
}

function deleteCollection(collection: any) {
  deleteTarget.value = collection;
}

async function confirmDelete() {
  const target = deleteTarget.value;
  if (!target) return;
  deleteTarget.value = null;
  await deleteCollectionApi(Number(target.id));
  const next = new Set(selectedIds.value);
  next.delete(Number(target.id));
  selectedIds.value = next;
  await loadCollections();
  await tauriEmit('collections-changed');
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
