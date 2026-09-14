<template>
  <ModalDialog :title="$t('tag.edit_tag')" :width="600" @cancel="clickCancel">
    <section class="space-y-3">
      <div class="flex items-center gap-2">
        <div
          :class="[
            'grow h-8 flex items-center rounded-box overflow-hidden transition-colors bg-base-100',
            isSearchFocused
              ? 'border-2 border-primary'
              : 'border border-neutral-content/30 hover:border-neutral-content/70',
          ]"
        >
          <IconSearch class="ml-2 w-4 h-4 text-base-content/70" />
          <input
            ref="tagSearchInputRef"
            type="text"
            v-model="tagSearch"
            :placeholder="$t('menu.tag.search')"
            class="w-full bg-transparent border-none focus:ring-0 px-2 text-sm placeholder-base-content/30 focus:outline-none"
            @focus="onSearchFocus"
            @blur="onSearchBlur"
          />
          <button
            v-if="tagSearch"
            type="button"
            class="mr-1 p-1 rounded-box text-base-content/30 hover:text-base-content/70"
            @click="
              tagSearch = '';
              tagSearchInputRef?.focus();
            "
          >
            <IconClose class="w-4 h-4" />
          </button>
        </div>
        <div
          :class="[
            'w-1/2 h-8 flex items-center rounded-box overflow-hidden transition-colors bg-base-100',
            isNewTagFocused
              ? 'border-2 border-primary'
              : 'border border-neutral-content/30 hover:border-neutral-content/70',
          ]"
        >
          <input
            ref="newTagNameInputRef"
            type="text"
            v-model="newTagName"
            :placeholder="$t('tag.enter_new_tag_name')"
            class="w-full bg-transparent border-none focus:ring-0 px-2 text-sm placeholder-base-content/30 focus:outline-none"
            @focus="isNewTagFocused = true"
            @blur="isNewTagFocused = false"
            @keydown.enter="addNewTag"
          />
          <button
            v-if="newTagName"
            type="button"
            class="mr-1 p-1 rounded-box text-base-content/30 hover:text-base-content/70"
            @click="
              newTagName = '';
              newTagNameInputRef?.focus();
            "
          >
            <IconClose class="w-4 h-4" />
          </button>
        </div>
        <TButton
          :icon="IconAdd"
          :tooltip="$t('msgbox.new_tag.title')"
          :disabled="!canEditTags"
          @click="addNewTag"
        />
      </div>

      <label class="flex items-center gap-2 text-sm">
        {{ $t("menu.tag.new_tag_group") }}
        <select
          v-model="newTagGroupId"
          class="select select-sm select-bordered min-w-0"
          :aria-label="$t('menu.tag.new_tag_group')"
        >
          <option v-for="group in groups" :key="group.id" :value="group.id">
            {{ group.name }}
          </option>
        </select>
      </label>
      <p v-if="duplicateTag" class="text-sm text-base-content/60">
        {{ $t("menu.tag.exists_in", { group: duplicateTag.group_name }) }}
        <button class="text-primary" @click="locateDuplicate">
          {{ $t("menu.tag.locate") }}
        </button>
      </p>
      <div
        v-if="allTags.length"
        class="text-[10px] uppercase tracking-widest font-bold text-base-content/30 select-none"
      >
        {{ $t("tag.title") }} ({{ allTags.length }})
      </div>
      <div
        class="min-h-24 max-h-52 overflow-y-auto rounded-box p-1 bg-base-100/30 border border-base-content/5 flex"
        :class="visibleGroups.length === 0 ? 'items-center justify-center' : ''"
      >
        <div v-if="visibleGroups.length > 0" class="w-full">
          <template v-for="group in visibleGroups" :key="group.id">
            <button
              type="button"
              class="sidebar-item sidebar-item-hover w-full"
              :aria-expanded="expanded(group.id)"
              @click="toggleGroup(group.id)"
            >
              <IconRight
                class="p-1 w-6 h-6 shrink-0"
                :class="expanded(group.id) ? 'rotate-90' : ''"
              />
              <span class="sidebar-item-label text-left">{{ group.name }}</span>
            </button>
            <template v-if="expanded(group.id)">
              <div
                v-for="tag in group.tags"
                :id="`dialog-tag-${tag.id}`"
                :key="tag.id"
                :class="[
                  'group w-full pl-6 p-2 flex items-center gap-2 rounded-box text-left cursor-pointer transition-colors',
                  {
                    'text-primary': selectedTags.has(tag.id),
                    'bg-base-content/5':
                      intermediateTags.has(tag.id) && !selectedTags.has(tag.id),
                    'hover:bg-base-content/5':
                      !selectedTags.has(tag.id) &&
                      !intermediateTags.has(tag.id),
                    'ring-2 ring-primary ring-offset-1 ring-offset-base-100':
                      filteredTags[focusedTagIndex]?.id === tag.id,
                  },
                ]"
                @click="toggleTag(tag.id)"
              >
                <label
                  class="flex items-center cursor-pointer shrink-0"
                  @click.stop
                  @dblclick.stop
                >
                  <input
                    type="checkbox"
                    class="checkbox checkbox-xs"
                    :class="
                      selectedTags.has(tag.id)
                        ? 'checkbox-primary opacity-70'
                        : ''
                    "
                    :disabled="!canEditTags"
                    :checked="selectedTags.has(tag.id)"
                    :indeterminate="intermediateTags.has(tag.id)"
                    @change="toggleTag(tag.id)"
                  />
                </label>
                <IconTag class="w-4 h-4 shrink-0" />
                <input
                  v-if="renamingId === Number(tag.id)"
                  ref="renameInput"
                  v-model="renameValue"
                  class="input px-1 min-w-0 flex-1 text-sm"
                  maxlength="255"
                  @click.stop
                  @keydown.stop
                  @keydown.enter.prevent="commitRename(tag)"
                  @keydown.escape.prevent="cancelRename"
                  @blur="commitRename(tag)"
                />
                <span v-else class="min-w-0 flex-1 truncate">{{
                  tag.name
                }}</span>
                <span
                  v-if="
                    renamingId !== Number(tag.id) && Number(tag.count || 0) > 0
                  "
                  class="sidebar-item-count shrink-0 group-hover:hidden"
                  >{{ Number(tag.count || 0).toLocaleString() }}</span
                >
                <div
                  v-if="renamingId !== Number(tag.id)"
                  class="shrink-0 hidden group-hover:flex"
                >
                  <button
                    type="button"
                    class="p-1 text-base-content/40 hover:text-base-content cursor-pointer"
                    :title="$t('menu.tag.rename')"
                    @click.stop="startRename(tag)"
                  >
                    <IconEdit class="w-4 h-4" />
                  </button>
                  <button
                    type="button"
                    class="p-1 text-base-content/40 hover:text-error cursor-pointer"
                    :title="$t('tag.delete_tag')"
                    @click.stop="deleteTarget = tag"
                  >
                    <IconTrash class="w-4 h-4" />
                  </button>
                </div>
              </div>
              <div
                v-if="!group.tags.length"
                class="pl-8 py-2 text-xs text-base-content/40"
              >
                {{ $t("menu.tag.empty") }}
              </div>
            </template>
          </template>
        </div>
        <span v-else class="text-base-content/30">{{
          $t("tag.not_found")
        }}</span>
      </div>
      <div v-if="tagLoadFailed" class="text-sm text-error">
        {{ $t("tag.load_failed") }}
      </div>
    </section>

    <!-- cancel and OK buttons -->
    <div class="mt-4 flex justify-end space-x-4">
      <button class="t-button-default" @click="clickCancel">
        {{ $t("msgbox.cancel") }}
      </button>

      <button
        class="t-button-primary"
        :disabled="
          isLoadingTags || isLoadingCatalog || isApplyingTags || tagLoadFailed
        "
        @click="clickOk"
      >
        {{ $t("msgbox.ok") }}
      </button>
    </div>
  </ModalDialog>
  <MessageBox
    v-if="deleteTarget"
    :title="$t('msgbox.delete_tag.title')"
    :message="$t('msgbox.delete_tag.content', { tag: deleteTarget.name })"
    :OkText="$t('msgbox.delete_tag.ok')"
    :cancelText="$t('msgbox.cancel')"
    :warningOk="true"
    @ok="confirmDelete"
    @cancel="deleteTarget = null"
  />
</template>

<script setup lang="ts">
import {
  ref,
  computed,
  watch,
  nextTick,
  onMounted,
  onBeforeUnmount,
} from "vue";
import { emit as tauriEmit, listen } from "@tauri-apps/api/event";
import { useI18n } from "vue-i18n";
import { useToast } from "@/common/toast";
import {
  getAllTags,
  getTagGroups,
  createTag,
  getTagSelectionCounts,
  applyTagsToFiles,
  deleteTag,
  renameTag,
} from "@/common/api";
import {
  IconAdd,
  IconClose,
  IconEdit,
  IconSearch,
  IconTag,
  IconTrash,
  IconRight,
} from "@/common/icons";
import { groupTags, type TagGroup } from "@/common/tagGroups";
import MessageBox from "./MessageBox.vue";
import TButton from "./TButton.vue";
import { libConfig } from "@/common/config";
import { useUIStore } from "@/stores/uiStore";
import ModalDialog from "@/components/ModalDialog.vue";

const props = defineProps({
  fileIds: {
    type: Array as () => number[],
    default: () => [],
  },
});

const emit = defineEmits(["ok", "cancel", "states-changed"]);
const uiStore = useUIStore();
const toast = useToast();
const { t } = useI18n();

const allTags = ref<any[]>([]);
const tagSearchInputRef = ref<HTMLInputElement | null>(null);
const newTagNameInputRef = ref<HTMLInputElement | null>(null);
const tagSearch = ref("");
const newTagName = ref("");
const isSearchFocused = ref(false);
const isNewTagFocused = ref(false);
const focusedTagIndex = ref(-1); // -1 = no tag focused
const isInTagList = ref(false); // true = keyboard focus is in tag list
const isLoadingTags = ref(true);
const isLoadingCatalog = ref(true);
const isApplyingTags = ref(false);
const catalogLoadFailed = ref(false);
const selectionLoadFailed = ref(false);
const tagLoadFailed = computed(() => catalogLoadFailed.value || selectionLoadFailed.value);
const canEditTags = computed(() =>
  !isLoadingCatalog.value && !isLoadingTags.value && !isApplyingTags.value && !tagLoadFailed.value,
);
const renamingId = ref<number | null>(null);
const renameValue = ref("");
const renameInput = ref<HTMLInputElement | HTMLInputElement[] | null>(null);
const deleteTarget = ref<any | null>(null);

// Sets to track tag states
const selectedTags = ref<Set<number>>(new Set()); // Tags present on ALL selected files
const intermediateTags = ref<Set<number>>(new Set()); // Tags present on SOME selected files
const initialSelectedTags = ref<Set<number>>(new Set());
const initialIntermediateTags = ref<Set<number>>(new Set());
const tagChanges = ref<Map<number, "add" | "remove">>(new Map());

const groups = ref<TagGroup[]>([]);
const newTagGroupId = ref<number | null>(null);
const collapsed = ref<number[]>([]);
const duplicateTag = ref<any>(null);
const visibleGroups = computed(() =>
  groupTags(groups.value, allTags.value, tagSearch.value),
);
const expanded = (id: number) =>
  !!tagSearch.value.trim() || !collapsed.value.includes(id);
function toggleGroup(id: number) {
  if (tagSearch.value.trim()) return;
  collapsed.value = expanded(id)
    ? [...collapsed.value, id]
    : collapsed.value.filter((value) => value !== id);
}
const filteredTags = computed(() =>
  visibleGroups.value.flatMap((group) =>
    expanded(group.id) ? group.tags : [],
  ),
);
async function locateDuplicate() {
  const tag = duplicateTag.value;
  if (!tag) return;
  tagSearch.value = "";
  collapsed.value = collapsed.value.filter((id) => id !== tag.group_id);
  await nextTick();
  document
    .getElementById(`dialog-tag-${tag.id}`)
    ?.scrollIntoView({ block: "nearest" });
  focusedTagIndex.value = filteredTags.value.findIndex(
    (item) => item.id === tag.id,
  );
}
let unlisten: (() => void) | undefined;
let disposed = false;
let loadRequest = 0;

onMounted(async () => {
  window.addEventListener("keydown", handleKeyDown);
  uiStore.pushInputHandler("TaggingDialog");

  await nextTick();
  tagSearchInputRef.value?.focus();

  const stop = await listen("tags-changed", async () => {
    await loadAllTags();
    if (!disposed) await loadExistingTagsForFiles(true);
  });
  if (disposed) {
    stop();
    return;
  }
  unlisten = stop;
  loadAllTags();
  loadExistingTagsForFiles();
});

onBeforeUnmount(() => {
  disposed = true;
  loadRequest++;
  unlisten?.();
  window.removeEventListener("keydown", handleKeyDown);
  uiStore.removeInputHandler("TaggingDialog");
});

// load all tags
async function loadAllTags() {
  const request = ++loadRequest;
  isLoadingCatalog.value = true;
  const library = libConfig._libraryId;
  try {
    const [tags, allGroups] = await Promise.all([
      getAllTags(0),
      getTagGroups(),
    ]);
    if (disposed || request !== loadRequest || library !== libConfig._libraryId)
      return;
    if (!tags) throw new Error("load failed");
    catalogLoadFailed.value = false;
    groups.value = allGroups;
    if (!groups.value.some((group) => group.id === newTagGroupId.value))
      newTagGroupId.value =
        groups.value.find((group) => group.is_default)?.id || null;
    const sidebarCounts = libConfig.tag.counts || {};
    allTags.value = tags.map((tag: any) => ({
      ...tag,
      count: Number(sidebarCounts[String(tag.id)] || 0),
    }));
    const ids = new Set(tags.map((tag: any) => tag.id));
    for (const id of tagChanges.value.keys())
      if (!ids.has(id)) tagChanges.value.delete(id);
  } catch {
    if (!disposed && request === loadRequest && library === libConfig._libraryId)
      catalogLoadFailed.value = true;
  } finally {
    if (!disposed && request === loadRequest) isLoadingCatalog.value = false;
  }
}

let selectionRequest = 0;
async function loadExistingTagsForFiles(preserveChanges = false) {
  const request = ++selectionRequest;
  const library = libConfig._libraryId;
  isLoadingTags.value = true;
  try {
    const counts = props.fileIds.length
      ? await getTagSelectionCounts(props.fileIds)
      : [];
    if (
      disposed ||
      request !== selectionRequest ||
      library !== libConfig._libraryId
    )
      return;
    if (counts === null) {
      selectionLoadFailed.value = true;
      return;
    }
    selectionLoadFailed.value = false;
    const selected = new Set<number>();
    const intermediate = new Set<number>();
    for (const entry of counts) {
      const tagId = Number(entry.tag_id);
      if (Number(entry.count) === props.fileIds.length) selected.add(tagId);
      else if (Number(entry.count) > 0) intermediate.add(tagId);
    }
    initialSelectedTags.value = new Set(selected);
    initialIntermediateTags.value = new Set(intermediate);
    selectedTags.value = selected;
    intermediateTags.value = intermediate;
    if (!preserveChanges) tagChanges.value.clear();
    for (const [id, change] of tagChanges.value)
      setTagVisualState(id, change === "add" ? "selected" : "none");
  } finally {
    if (!disposed && request === selectionRequest) isLoadingTags.value = false;
  }
}

async function addNewTag() {
  if (!canEditTags.value || !newTagGroupId.value) return;
  const trimmedName = newTagName.value.trim();
  if (trimmedName) {
    const existingTag = allTags.value.find(
      (tag) => tag.name.toLowerCase() === trimmedName.toLowerCase(),
    );
    if (existingTag) {
      duplicateTag.value = existingTag;
      return;
    } else {
      const newTag = await createTag(trimmedName, newTagGroupId.value);
      if (newTag) {
        duplicateTag.value = null;
        tagSearch.value = "";
        collapsed.value = collapsed.value.filter(
          (id) => id !== newTag.group_id,
        );
        allTags.value.push(newTag);
        toggleTag(newTag.id);
        await tauriEmit("tags-changed");
        await nextTick();
        document
          .getElementById(`dialog-tag-${newTag.id}`)
          ?.scrollIntoView({ block: "nearest" });
      } else {
        toast.error(t("tag.name_save_failed"));
      }
    }
    newTagName.value = ""; // Clear input
  }
}

function toggleTag(tagId: number) {
  if (!canEditTags.value) return;
  const normalized = Number(tagId);
  const next = new Map(tagChanges.value);
  const current = next.get(normalized);
  const initialState = initialSelectedTags.value.has(normalized)
    ? "selected"
    : initialIntermediateTags.value.has(normalized)
      ? "intermediate"
      : "none";

  if (current === "add") {
    if (initialState === "none") {
      next.delete(normalized);
    } else {
      next.set(normalized, "remove");
    }
    setTagVisualState(normalized, "none");
  } else if (current === "remove") {
    next.delete(normalized);
    setTagVisualState(normalized, initialState);
  } else if (selectedTags.value.has(normalized)) {
    next.set(normalized, "remove");
    setTagVisualState(normalized, "none");
  } else {
    next.set(normalized, "add");
    setTagVisualState(normalized, "selected");
  }
  tagChanges.value = next;
}

function setTagVisualState(
  tagId: number,
  state: "selected" | "intermediate" | "none",
) {
  const selected = new Set(selectedTags.value);
  const intermediate = new Set(intermediateTags.value);
  selected.delete(tagId);
  intermediate.delete(tagId);
  if (state === "selected") selected.add(tagId);
  if (state === "intermediate") intermediate.add(tagId);
  selectedTags.value = selected;
  intermediateTags.value = intermediate;
}

async function startRename(tag: any) {
  renamingId.value = Number(tag.id);
  renameValue.value = String(tag.name || "");
  await nextTick();
  const input = Array.isArray(renameInput.value)
    ? renameInput.value[0]
    : renameInput.value;
  input?.focus({ preventScroll: true });
  input?.select();
}

function cancelRename() {
  renamingId.value = null;
  renameValue.value = "";
}

async function commitRename(tag: any) {
  if (renamingId.value !== Number(tag.id)) return;
  const name = renameValue.value.trim();
  if (name && name !== tag.name) {
    const duplicate = allTags.value.some(
      (item) =>
        Number(item.id) !== Number(tag.id) &&
        String(item.name).toLocaleLowerCase() === name.toLocaleLowerCase(),
    );
    if (duplicate) {
      toast.error(t("tag.name_exists"));
      cancelRename();
      return;
    }
    if (await renameTag(Number(tag.id), name)) {
      tag.name = name;
      await tauriEmit("tags-changed");
    } else {
      toast.error(t("tag.name_save_failed"));
    }
  }
  cancelRename();
}

async function confirmDelete() {
  const tag = deleteTarget.value;
  if (!tag) return;
  deleteTarget.value = null;
  if (!(await deleteTag(Number(tag.id)))) return;
  const tagId = Number(tag.id);
  allTags.value = allTags.value.filter((item) => Number(item.id) !== tagId);
  selectedTags.value.delete(tagId);
  intermediateTags.value.delete(tagId);
  initialSelectedTags.value.delete(tagId);
  initialIntermediateTags.value.delete(tagId);
  tagChanges.value.delete(tagId);
  const states = await applyTagsToFiles(props.fileIds, [], []);
  if (states !== null) emit("states-changed", states);
  await tauriEmit("tags-changed");
}

async function clickOk() {
  if (
    isLoadingTags.value ||
    isLoadingCatalog.value ||
    isApplyingTags.value ||
    tagLoadFailed.value
  )
    return;
  isApplyingTags.value = true;
  const addTagIds = Array.from(tagChanges.value)
    .filter(([, change]) => change === "add")
    .map(([tagId]) => tagId);
  const removeTagIds = Array.from(tagChanges.value)
    .filter(([, change]) => change === "remove")
    .map(([tagId]) => tagId);
  const result = await applyTagsToFiles(props.fileIds, addTagIds, removeTagIds);
  if (result !== null) {
    await tauriEmit("tags-changed");
    emit("ok", result);
  } else {
    isApplyingTags.value = false;
  }
}

function clickCancel() {
  emit("cancel");
}

// Reset tag focus when search results change
watch(filteredTags, () => {
  focusedTagIndex.value = -1;
  isInTagList.value = false;
});

function onSearchFocus() {
  isSearchFocused.value = true;
  isInTagList.value = false;
  focusedTagIndex.value = -1;
}

function onSearchBlur() {
  isSearchFocused.value = false;
}

function enterTagList() {
  if (filteredTags.value.length > 0) {
    isInTagList.value = true;
    focusedTagIndex.value = 0;
    tagSearchInputRef.value?.blur();
    newTagNameInputRef.value?.blur();
  }
}

function exitTagList() {
  isInTagList.value = false;
  focusedTagIndex.value = -1;
  tagSearchInputRef.value?.focus();
}

// Keyboard: ArrowDown→tag list, Space→toggle, Enter→OK, Escape→back/close
const handleKeyDown = (e: KeyboardEvent) => {
  if (!uiStore.isInputActive("TaggingDialog")) return;

  const { key } = e;
  const active = document.activeElement;
  if (
    active instanceof HTMLSelectElement ||
    (active instanceof HTMLButtonElement && !isInTagList.value)
  )
    return;
  const isInAnyInput =
    active === tagSearchInputRef.value || active === newTagNameInputRef.value;

  if (key === "Tab" && active === newTagNameInputRef.value && !e.shiftKey) {
    e.preventDefault();
    if (filteredTags.value.length > 0) {
      enterTagList();
    } else {
      tagSearchInputRef.value?.focus();
    }
    return;
  }

  // Escape: tag list → search input → close dialog
  if (key === "Escape") {
    if (isInTagList.value) {
      exitTagList();
    } else {
      clickCancel();
    }
    return;
  }

  // ArrowDown → enter tag list (from any state, unless already navigating)
  if (key === "ArrowDown" && !isInTagList.value) {
    e.preventDefault();
    enterTagList();
    return;
  }

  // Tag list keyboard navigation
  if (isInTagList.value && filteredTags.value.length > 0) {
    const lastIndex = filteredTags.value.length - 1;

    if (key === "ArrowRight") {
      e.preventDefault();
      focusedTagIndex.value =
        focusedTagIndex.value >= lastIndex ? 0 : focusedTagIndex.value + 1;
    } else if (key === "ArrowLeft") {
      e.preventDefault();
      focusedTagIndex.value =
        focusedTagIndex.value <= 0 ? lastIndex : focusedTagIndex.value - 1;
    } else if (key === "ArrowUp") {
      e.preventDefault();
      exitTagList();
    } else if (key === " ") {
      e.preventDefault();
      const tag = filteredTags.value[focusedTagIndex.value];
      if (tag) toggleTag(tag.id);
    } else if (key === "Enter") {
      e.preventDefault();
      clickOk();
    } else if (key === "Tab") {
      e.preventDefault();
      if (e.shiftKey) {
        isInTagList.value = false;
        focusedTagIndex.value = -1;
        newTagNameInputRef.value?.focus();
      } else {
        exitTagList(); // Tab → back to search input (keep focus inside dialog)
      }
    }
    return;
  }

  // Enter → confirm dialog (when not typing in any input)
  if (key === "Enter" && !isInAnyInput) {
    e.preventDefault();
    clickOk();
  }
};
</script>
