<template>
  <div class="sidebar-panel">
    <div class="sidebar-panel-header">
      <span class="sidebar-panel-header-title flex-1"
        >{{ $t("tag.title")
        }}<template v-if="tags.length">
          ({{ tags.length.toLocaleString() }})</template
        ></span
      >
      <TButton
        :icon="IconAdd"
        buttonSize="small"
        :tooltip="$t('menu.tag.new_group')"
        @click="editGroup()"
      />
    </div>
    <div class="mx-1 mb-2 px-1 shrink-0">
      <div
        :class="[
          'h-8 flex items-center rounded-box transition-colors bg-base-100/40',
          isSearchFocused ? 'border-2 border-primary' : 'border border-base-content/10 hover:border-base-content/30',
        ]"
        @click="searchInputRef?.focus()"
      >
        <IconSearch
          class="ml-2 w-4 h-4 shrink-0"
          :class="isSearchFocused ? 'text-primary/70' : 'text-base-content/30'"
        />
        <input
          ref="searchInputRef"
          type="text"
          v-model="search"
          :placeholder="$t('menu.tag.search')"
          class="w-full min-w-0 bg-transparent border-none focus:ring-0 px-2 text-sm placeholder-base-content/30 focus:outline-none"
          maxlength="255"
          @focus="isSearchFocused = true"
          @blur="isSearchFocused = false"
        />
        <button
          v-if="search"
          type="button"
          :title="$t('menu.tag.clear_search')"
          class="mr-1 p-1 rounded-box text-base-content/30 hover:text-base-content/70"
          @click.stop="search = ''; searchInputRef?.focus()"
        >
          <IconClose class="w-4 h-4" />
        </button>
      </div>
    </div>
    <div class="grow overflow-y-auto overflow-x-hidden">
      <VueDraggable
        v-model="groups"
        tag="ul"
        :animation="200"
        handle=".tag-group-drag-handle"
        :disabled="
          Boolean(search.trim()) ||
          editor !== null ||
          renaming !== null ||
          reorderingGroupId === null ||
          savingOrder
        "
        :onMove="canMoveGroup"
        @start="onReorderStart"
        @end="onReorderEnd"
        @drop.stop
      >
        <li
          v-for="group in visibleGroups"
          :key="group.id"
          :id="`tag-group-${group.id}`"
          :data-default-group="group.is_default ? 'true' : undefined"
          :data-reordering-group="
            reorderingGroupId === group.id ? 'true' : undefined
          "
        >
          <div
            class="sidebar-item group"
            :class="
              libConfig.tag.groupId === group.id && !isRenaming('group', group.id)
                ? 'sidebar-item-selected'
                : 'sidebar-item-hover'
            "
            @click="selectGroup(group)"
            @contextmenu.prevent.stop="
              (event: MouseEvent) =>
                groupMenus[group.id]?.open(event.clientX, event.clientY)
            "
          >
            <IconDragHandle
              v-if="reorderingGroupId === group.id"
              class="tag-group-drag-handle p-1 w-6 h-6 shrink-0 cursor-move text-base-content/70 hover:text-base-content"
              :title="$t('collection.reorder')"
            />
            <span
              v-else-if="reorderingGroupId !== null"
              class="p-1 w-6 h-6 shrink-0"
            />
            <button
              :aria-label="group.name"
              :aria-expanded="expanded(group.id)"
              @click.stop="toggleGroup(group.id)"
            >
              <IconRight
                class="p-1 w-6 h-6 shrink-0 transition-transform"
                :class="expanded(group.id) ? 'rotate-90' : ''"
              />
            </button>
            <input
                  v-if="isRenaming('group', group.id)"
                  :ref="(el: any) => { if (el) renameInput = el; }"
                  v-model="renaming!.name"
                  type="text"
                  maxlength="255"
                  :aria-label="$t('menu.tag.rename')"
                  class="input px-1 w-full min-w-0 text-base"
                  :readonly="savingRename"
                  @click.stop
                  @mousedown.stop
                  @keydown.stop
                  @keydown.enter.prevent="!$event.isComposing && saveRename()"
                  @keydown.esc.prevent="cancelRename"
                  @blur="saveRename"
                />
                <span v-else class="sidebar-item-label">{{ group.name }}</span>
            <span
              v-if="!isRenaming('group', group.id) && !expanded(group.id) && selectedTag?.group_id === group.id"
              class="text-primary text-xs"
              :title="$t('menu.tag.active_tag')"
              >•</span
            >
            <div
              v-if="!isRenaming('group', group.id)"
                  class="ml-auto flex flex-row items-center text-base-content/30"
            >
              <span
                v-if="group.count > 0"
                class="sidebar-item-count shrink-0"
                >{{ group.count.toLocaleString() }}</span
              >
              <div
                :class="
                  libConfig.tag.groupId === group.id
                    ? ''
                    : 'hidden group-hover:block'
                "
                @click.stop
              >
                <ContextMenu
                  :ref="
                    (el: any) => {
                      if (el) groupMenus[group.id] = el;
                    }
                  "
                  :iconMenu="IconMore"
                  :menuItems="() => groupMenu(group)"
                  :smallIcon="true"
                />
              </div>
            </div>
          </div>
          <ul v-if="expanded(group.id)">
            <li
              v-for="tag in group.tags"
              :key="tag.id"
              :id="`tag-${tag.id}`"
              class="pl-4"
            >
              <div
                class="sidebar-item sidebar-item-compact ml-2 group"
                :class="
                  libConfig.tag.id === tag.id && !isRenaming('tag', tag.id)
                    ? 'sidebar-item-selected'
                    : 'sidebar-item-hover'
                "
                @click="selectTag(tag)"
                @contextmenu.prevent.stop="
                  (event: MouseEvent) =>
                    tagMenus[tag.id]?.open(event.clientX, event.clientY)
                "
              >
                <IconTag class="mx-1 w-4 h-4 shrink-0" />
                <input
                  v-if="isRenaming('tag', tag.id)"
                  :ref="(el: any) => { if (el) renameInput = el; }"
                  v-model="renaming!.name"
                  type="text"
                  maxlength="255"
                  :aria-label="$t('menu.tag.rename')"
                  class="input px-1 w-full min-w-0 text-base"
                  :readonly="savingRename"
                  @click.stop
                  @mousedown.stop
                  @keydown.stop
                  @keydown.enter.prevent="!$event.isComposing && saveRename()"
                  @keydown.esc.prevent="cancelRename"
                  @blur="saveRename"
                />
                <span v-else class="sidebar-item-label">{{ tag.name }}</span>
                <div
                  v-if="!isRenaming('tag', tag.id)"
                  class="ml-auto flex flex-row items-center text-base-content/30"
                >
                  <span
                    v-if="getTagCount(tag) > 0"
                    class="sidebar-item-count shrink-0"
                    >{{ getTagCount(tag).toLocaleString() }}</span
                  >
                  <div
                    :class="
                      libConfig.tag.id === tag.id
                        ? ''
                        : 'hidden group-hover:block'
                    "
                    @click.stop
                  >
                    <ContextMenu
                      :ref="
                        (el: any) => {
                          if (el) tagMenus[tag.id] = el;
                        }
                      "
                      :iconMenu="IconMore"
                      :menuItems="() => tagMenu(tag)"
                      :smallIcon="true"
                    />
                  </div>
                </div>
              </div>
            </li>
            <li
              v-if="!group.tags.length"
              class="pl-10 py-2 text-xs text-base-content/40"
            >
              {{ $t("menu.tag.empty") }}
            </li>
          </ul>
        </li>
      </VueDraggable>
      <div
        v-if="!loading && !visibleGroups.length"
        class="sidebar-empty text-sm"
      >
        {{ failed ? $t("tag.load_failed") : $t("tag.not_found") }}
      </div>
    </div>
  </div>
  <ModalDialog
    v-if="editor"
    :title="
      editor.kind === 'group'
        ? $t('menu.tag.new_group')
        : $t('msgbox.new_tag.title')
    "
    :width="400"
    @cancel="editor = null"
  >
    <form
      class="space-y-4"
      @submit.prevent="saveEditor"
      @keydown.stop
      @keydown.esc.prevent="editor = null"
    >
      <input
        ref="nameInput"
        v-model="editor.name"
        maxlength="255"
        :aria-label="$t('menu.tag.name')"
        class="input input-bordered w-full"
        autofocus
      />
      <p v-if="editorError" class="text-sm text-error">{{ editorError }}</p>
      <button
        v-if="duplicateTag"
        type="button"
        class="text-primary text-sm"
        @click="locateDuplicate"
      >
        {{ $t("menu.tag.locate") }}
      </button>
      <div class="flex justify-end gap-3">
        <button type="button" class="t-button-default" @click="editor = null">
          {{ $t("msgbox.cancel") }}</button
        ><button
          type="submit"
          class="t-button-primary"
          :disabled="saving || !editor.name.trim()"
        >
          {{ $t("msgbox.ok") }}
        </button>
      </div>
    </form>
  </ModalDialog>
  <MessageBox
    v-if="deleteTarget"
    :title="
      $t(
        deleteTarget.kind === 'group'
          ? 'menu.tag.delete_group'
          : 'msgbox.delete_tag.title',
      )
    "
    :message="
      deleteTarget.kind === 'group'
        ? $t('menu.tag.delete_message', { name: deleteTarget.name })
        : $t('msgbox.delete_tag.content', { tag: deleteTarget.name })
    "
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
  nextTick,
  watch,
  onMounted,
  onBeforeUnmount,
} from "vue";
import { VueDraggable } from "vue-draggable-plus";
import { emit as emitEvent, listen } from "@tauri-apps/api/event";
import { useI18n } from "vue-i18n";
import { useToast } from "@/common/toast";
import { config, libConfig } from "@/common/config";
import { useUIStore } from "@/stores/uiStore";
import { SIDEBAR } from "@/common/constants";
import {
  getAllTags,
  getTagCounts,
  getTagGroups,
  createTag,
  renameTag,
  deleteTag,
  saveTagGroup,
  reorderTagGroups,
  deleteTagGroup,
  moveTagsToGroup,
} from "@/common/api";
import { groupTags, type TagGroup, type LibraryTag } from "@/common/tagGroups";
import {
  IconAdd,
  IconClose,
  IconMore,
  IconSearch,
  IconTag,
  IconTagAdd,
  IconRight,
  IconEdit,
  IconOrder,
  IconTrash,
  IconDragHandle,
  IconFolderMoveTo,
} from "@/common/icons";
import ContextMenu from "./ContextMenu.vue";
import TButton from "./TButton.vue";
import ModalDialog from "./ModalDialog.vue";
import MessageBox from "./MessageBox.vue";

defineProps<{ titlebar: string }>();
defineEmits(["editDataChanged"]);
const { t } = useI18n();
const toast = useToast();
const uiStore = useUIStore();
const tags = ref<LibraryTag[]>([]);
const groups = ref<TagGroup[]>([]);
const search = ref("");
const searchInputRef = ref<HTMLInputElement | null>(null);
const isSearchFocused = ref(false);
const loading = ref(true);
const failed = ref(false);
const saving = ref(false);
const reorderingGroupId = ref<number | null>(null);
const savingOrder = ref(false);
let draggingGroup = false;
const getTagCount = (tag: LibraryTag) =>
  Number(libConfig.tag.counts?.[String(tag.id)] || 0);
const tagMenus = ref<Record<number, any>>({});
const groupMenus = ref<Record<number, any>>({});
const nameInput = ref<HTMLInputElement>();
const editor = ref<{
  kind: "group" | "tag";
  name: string;
  groupId?: number;
} | null>(null);
const renameInput = ref<HTMLInputElement>();
const renaming = ref<{ kind: "group" | "tag"; id: number; name: string; originalName: string } | null>(null);
const savingRename = ref(false);
const isRenaming = (kind: "group" | "tag", id: number) =>
  renaming.value?.kind === kind && renaming.value.id === id;
async function startRename(kind: "group" | "tag", item: TagGroup | LibraryTag) {
  if (savingRename.value) return;
  reorderingGroupId.value = null;
  renaming.value = { kind, id: item.id, name: item.name, originalName: item.name };
  uiStore.removeInputHandler("TagRename");
  uiStore.pushInputHandler("TagRename");
  await nextTick();
  renameInput.value?.focus();
}
function cancelRename() {
  if (savingRename.value) return;
  finishRename();
}
function finishRename() {
  renaming.value = null;
  renameInput.value = undefined;
  uiStore.removeInputHandler("TagRename");
}
async function saveRename() {
  const target = renaming.value;
  if (!target || savingRename.value) return;
  const name = target.name.trim();
  if (!name || name === target.originalName) {
    cancelRename();
    return;
  }
  const items = target.kind === "group" ? groups.value : tags.value;
  if (items.some(item => item.id !== target.id && item.name.toLocaleLowerCase() === name.toLocaleLowerCase())) {
    toast.error(t(target.kind === "tag" ? "tag.name_exists" : "menu.tag.name_exists"));
    await nextTick();
    if (renaming.value === target) renameInput.value?.focus();
    return;
  }
  savingRename.value = true;
  try {
    if (target.kind === "group") await saveTagGroup(target.id, name);
    else if (!(await renameTag(target.id, name))) throw new Error("rename failed");
    if (renaming.value === target) {
      finishRename();
    }
    await load();
    await changed();
  } catch {
    toast.error(t("tag.name_save_failed"));
    if (renaming.value === target) {
      await nextTick();
      if (renaming.value === target) renameInput.value?.focus();
    }
  } finally {
    savingRename.value = false;
  }
}
const editorError = ref("");
const duplicateTag = ref<LibraryTag | null>(null);
const deleteTarget = ref<{
  kind: "group" | "tag";
  id: number;
  name: string;
} | null>(null);
const selectedTag = computed(() =>
  tags.value.find((tag) => tag.id === libConfig.tag.id),
);
const visibleGroups = computed(() =>
  groupTags(groups.value, tags.value, search.value),
);
const expanded = (id: number) =>
  !!search.value.trim() ||
  !(libConfig.tag.collapsedGroupIds || []).includes(id);
watch(
  () => {
    const target = renaming.value;
    if (!target) return true;
    return visibleGroups.value.some((group) =>
      target.kind === "group"
        ? group.id === target.id
        : expanded(group.id) && group.tags.some((tag) => tag.id === target.id),
    );
  },
  (visible) => {
    // A pending save can finish even after its input has disappeared.
    if (!visible) finishRename();
  },
);
function expand(id: number) {
  libConfig.tag.collapsedGroupIds = (
    libConfig.tag.collapsedGroupIds || []
  ).filter((value: number) => value !== id);
}
function toggleGroup(id: number) {
  if (search.value.trim()) return;
  libConfig.tag.collapsedGroupIds = expanded(id)
    ? [...(libConfig.tag.collapsedGroupIds || []), id]
    : (libConfig.tag.collapsedGroupIds || []).filter(
        (value: number) => value !== id,
      );
}
function selectGroup(group: TagGroup) {
  libConfig.tag.id = null;
  libConfig.tag.groupId = group.id;
}
function selectTag(tag: LibraryTag) {
  libConfig.tag.groupId = null;
  libConfig.tag.id = tag.id;
}
async function locate(tag: LibraryTag) {
  search.value = "";
  expand(tag.group_id);
  selectTag(tag);
  await nextTick();
  document
    .getElementById(`tag-${tag.id}`)
    ?.scrollIntoView({ block: "nearest" });
}
function locateDuplicate() {
  if (duplicateTag.value) {
    void locate(duplicateTag.value);
    editor.value = null;
  }
}
watch(editor, async (value, previous) => {
  if (value && !previous) uiStore.pushInputHandler("TagEditor");
  if (!value && previous) uiStore.removeInputHandler("TagEditor");
  editorError.value = "";
  duplicateTag.value = null;
  await nextTick();
  nameInput.value?.focus();
  nameInput.value?.select();
});
function editGroup() {
  editor.value = { kind: "group", name: "" };
}
function clickAddTag(groupId?: number) {
  editor.value = {
    kind: "tag",
    name: "",
    groupId: groupId || groups.value.find((g) => g.is_default)?.id,
  };
}
function groupMenu(group: TagGroup) {
  return [
    {
      label: t("msgbox.new_tag.title"),
      icon: IconTagAdd,
      action: () => clickAddTag(group.id),
    },
    { label: "-", action: null },
    {
      label: t("menu.tag.rename"),
      icon: IconEdit,
      disabled: group.is_default,
      action: () => {
        if (!group.is_default) startRename("group", group);
      },
    },
    {
      label: t("collection.reorder"),
      icon: IconOrder,
      disabled: group.is_default || savingOrder.value,
      action: () => {
        if (group.is_default || savingOrder.value) return;
        search.value = "";
        reorderingGroupId.value =
          reorderingGroupId.value === group.id ? null : group.id;
      },
    },
    { label: "-", action: null },
    {
      label: t("menu.tag.delete"),
      icon: IconTrash,
      disabled: group.is_default,
      action: () => {
        if (!group.is_default) deleteTarget.value = { kind: "group", ...group };
      },
    },
  ];
}
function canMoveGroup(event: {
  related: HTMLElement;
  willInsertAfter: boolean;
}) {
  return (
    event.related?.dataset.defaultGroup !== "true" || event.willInsertAfter
  );
}
function handleReorderOutside(event: PointerEvent) {
  if (event.button !== 0 || draggingGroup) return;
  if (
    event.target instanceof Element &&
    event.target.closest('[data-reordering-group="true"]')
  )
    return;
  reorderingGroupId.value = null;
}
function onReorderStart() {
  draggingGroup = true;
  request++;
  uiStore.pushInputHandler("TagGroupDrag");
}
async function onReorderEnd() {
  draggingGroup = false;
  uiStore.removeInputHandler("TagGroupDrag");
  savingOrder.value = true;
  try {
    await reorderTagGroups(groups.value.map((group) => group.id));
    await changed();
  } catch {
    toast.error(t("tag.name_save_failed"));
  } finally {
    savingOrder.value = false;
    await load();
  }
}
function tagMenu(tag: LibraryTag) {
  return [
    {
      label: t("menu.tag.rename"),
      icon: IconEdit,
      action: () => {
        startRename("tag", tag);
      },
    },
    {
      label: t("menu.tag.move_to"),
      children: groups.value
        .filter((g) => g.id !== tag.group_id)
        .map((group) => ({
          label: group.name,
          action: () => moveTag(tag, group.id),
        })),
    },
    { label: "-", action: null },
    {
      label: t("tag.delete_tag"),
      icon: IconTrash,
      action: () => {
        deleteTarget.value = { kind: "tag", ...tag };
      },
    },
  ];
}
async function changed() {
  await emitEvent("tags-changed");
}
async function moveTag(tag: LibraryTag, groupId: number) {
  try {
    await moveTagsToGroup([tag.id], groupId);
    await load();
    if (libConfig.tag.id === tag.id)
      await locate({ ...tag, group_id: groupId });
    await changed();
  } catch {
    toast.error(t("tag.name_save_failed"));
  }
}
async function saveEditor() {
  if (!editor.value || saving.value) return;
  const value = { ...editor.value, name: editor.value.name.trim() };
  editorError.value = "";
  duplicateTag.value = null;
  const duplicate =
    value.kind === "tag" &&
    tags.value.find(
      (tag) =>
        tag.name.toLocaleLowerCase() === value.name.toLocaleLowerCase(),
    );
  if (duplicate) {
    duplicateTag.value = duplicate;
    editorError.value = t("menu.tag.exists_in", {
      group: duplicate.group_name,
    });
    return;
  }
  if (
    value.kind === "group" &&
    groups.value.some(
      (g) =>
        g.name.toLocaleLowerCase() === value.name.toLocaleLowerCase(),
    )
  ) {
    editorError.value = t("menu.tag.name_exists");
    return;
  }
  saving.value = true;
  try {
    if (value.kind === "group") {
      const id = await saveTagGroup(null, value.name);
      expand(id);
      search.value = "";
      await load();
      await nextTick();
      document
        .getElementById(`tag-group-${id}`)
        ?.scrollIntoView({ block: "nearest" });
    } else {
      const result = await createTag(value.name, value.groupId);
      if (!result) throw new Error("save failed");
      await load();
      const tag = tags.value.find((tag) => tag.id === result.id);
      if (tag) await locate(tag);
    }
    editor.value = null;
    await changed();
  } catch {
    editorError.value = t("tag.name_save_failed");
  } finally {
    saving.value = false;
  }
}
async function confirmDelete() {
  const target = deleteTarget.value;
  if (!target || saving.value) return;
  saving.value = true;
  try {
    if (target.kind === "group") await deleteTagGroup(target.id);
    else if (!(await deleteTag(target.id))) throw new Error("delete failed");
    deleteTarget.value = null;
    await load();
    await changed();
  } catch {
    toast.error(t("tag.name_save_failed"));
  } finally {
    saving.value = false;
  }
}
let request = 0;
let disposed = false;
let unlisten: (() => void) | undefined;
async function load() {
  if (draggingGroup || savingOrder.value) return;
  const current = ++request;
  const library = libConfig._libraryId;
  try {
    const [allTags, counts, allGroups] = await Promise.all([
      getAllTags(config.settings.categorySort),
      getTagCounts(),
      getTagGroups(),
    ]);
    if (disposed || current !== request || library !== libConfig._libraryId)
      return;
    if (!allTags || !counts) throw new Error("load failed");
    const previousGroupId = selectedTag.value?.group_id;
    tags.value = allTags;
    groups.value = allGroups;
    if (
      selectedTag.value &&
      previousGroupId &&
      selectedTag.value.group_id !== previousGroupId
    ) {
      expand(selectedTag.value.group_id);
      const id = selectedTag.value.id;
      void nextTick(() =>
        document
          .getElementById(`tag-${id}`)
          ?.scrollIntoView({ block: "nearest" }),
      );
    }
    libConfig.tag.counts = counts;
    failed.value = false;
    const validTag = tags.value.some((tag) => tag.id === libConfig.tag.id);
    const validGroup = groups.value.some(
      (group) => group.id === libConfig.tag.groupId,
    );
    if (!validTag && !validGroup) {
      const fallback = groups.value.find((g) => g.is_default);
      if (fallback) selectGroup(fallback);
    }
    libConfig.tag.collapsedGroupIds = (
      libConfig.tag.collapsedGroupIds || []
    ).filter((id: number) => groups.value.some((g) => g.id === id));
  } catch {
    if (current === request) failed.value = true;
  } finally {
    if (current === request) loading.value = false;
  }
}
onMounted(async () => {
  document.addEventListener("pointerdown", handleReorderOutside, true);
  const stop = await listen("tags-changed", async () => {
    await load();
    if (
      !disposed &&
      config.main.sidebarIndex === SIDEBAR.TAG &&
      libConfig.activePane === "main"
    )
      libConfig.tag.activateTick++;
  });
  if (disposed) stop();
  else unlisten = stop;
  await load();
  if (selectedTag.value) expand(selectedTag.value.group_id);
});
onBeforeUnmount(() => {
  document.removeEventListener("pointerdown", handleReorderOutside, true);
  uiStore.removeInputHandler("TagGroupDrag");
  uiStore.removeInputHandler("TagEditor");
  uiStore.removeInputHandler("TagRename");
  disposed = true;
  request++;
  unlisten?.();
});
watch(
  () => [config.main.sidebarIndex, libConfig.activePane],
  () => {
    if (
      config.main.sidebarIndex === SIDEBAR.TAG &&
      libConfig.activePane === "main"
    )
      void load();
  },
);
watch(
  () => [
    config.settings.categorySort,
    config.settings.smallFileFilter,
    libConfig._libraryId,
  ],
  () => {
    editor.value = null;
    renaming.value = null;
    uiStore.removeInputHandler("TagRename");
    reorderingGroupId.value = null;
    deleteTarget.value = null;
    void load();
  },
);
defineExpose({ clickAddTag });
</script>
