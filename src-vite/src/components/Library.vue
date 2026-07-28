<template>

  <div class="sidebar-panel">
    <div class="sidebar-panel-header">
      <span class="sidebar-panel-header-title flex-1">{{ titlebar }}</span>
    </div>

    <div class="min-h-0 flex-1 overflow-x-hidden overflow-y-auto">
      <div
        v-for="item in libraryItems"
        :key="item.id"
        :class="[
          'sidebar-item',
          libConfig.library.item === item.id ? 'sidebar-item-selected' : 'sidebar-item-hover',
        ]"
        @click="selectItem(item.id)"
      >
        <component :is="item.icon" class="mx-1 w-5 h-5 shrink-0" />
        <div class="sidebar-item-label">
          <span>{{ item.label }}</span>
        </div>
        <div class="ml-auto flex items-center">
          <span v-if="item.count && item.count > 0" class="sidebar-item-count">
            {{ item.count.toLocaleString() }}
          </span>
        </div>
      </div>

      <div class="sidebar-item sidebar-item-hover" @click="toggleRatings">
        <IconRight
          :class="[
            'p-1 w-6 h-6 shrink-0 transition-transform',
            libConfig.library.ratingsExpanded ? 'rotate-90' : '',
          ]"
          @click.stop="toggleRatings"
        />
        <span class="sidebar-item-label">
          {{ localeMsg.rating.title }}
        </span>
      </div>

      <Transition
        @before-enter="onBeforeEnter"
        @enter="onEnter"
        @after-enter="onAfterEnter"
        @leave="onLeave"
      >
        <div v-if="libConfig.library.ratingsExpanded" class="overflow-hidden">
          <ul class="mb-2">
            <li class="pl-4">
              <div
                :class="[
                  'sidebar-item sidebar-item-compact ml-2',
                  libConfig.library.item === LIB_ITEM.RATINGS && libConfig.rating.item === RATE.ALL ? 'sidebar-item-selected' : 'sidebar-item-hover',
                ]"
                @click="selectRating(RATE.ALL)"
              >
                <IconStarFilled class="mx-1 w-4 h-4 shrink-0" />
                <span class="sidebar-item-label">{{ localeMsg.rating.rated }}</span>
                <span v-if="ratedCount" class="text-[10px] tabular-nums text-base-content/30 mr-2">{{ ratedCount.toLocaleString() }}</span>
              </div>
            </li>
            <li v-for="rating in [5, 4, 3, 2, 1]" :key="rating" class="pl-4">
              <div
                :class="[
                  'sidebar-item sidebar-item-compact ml-2',
                  libConfig.library.item === LIB_ITEM.RATINGS && libConfig.rating.item === rating ? 'sidebar-item-selected' : 'sidebar-item-hover',
                ]"
                @click="selectRating(rating)"
              >
                <div class="mx-1 flex items-center gap-0.5">
                  <IconStarFilled
                    v-for="index in rating"
                    :key="index"
                    class="w-4 h-4 shrink-0"
                  />
                </div>
                <span v-if="ratingCounts[rating]" class="ml-auto text-[10px] tabular-nums text-base-content/30 mr-2">{{ ratingCounts[rating].toLocaleString() }}</span>
              </div>
            </li>
            <li class="pl-4">
              <div
                :class="[
                  'sidebar-item sidebar-item-compact ml-2',
                  libConfig.library.item === LIB_ITEM.RATINGS && libConfig.rating.item === RATE.UNRATED ? 'sidebar-item-selected' : 'sidebar-item-hover',
                ]"
                @click="selectRating(RATE.UNRATED)"
              >
                <IconStar class="mx-1 w-4 h-4 shrink-0" />
                <span class="sidebar-item-label">{{ localeMsg.rating.unrated }}</span>
                <span v-if="unratedCount" class="text-[10px] tabular-nums text-base-content/30 mr-2">{{ unratedCount.toLocaleString() }}</span>
              </div>
            </li>
          </ul>
        </div>
      </Transition>

      <div class="sidebar-item sidebar-item-hover" @click="toggleCulling">
        <IconRight
          :class="[
            'p-1 w-6 h-6 shrink-0 transition-transform',
            libConfig.library.cullingExpanded ? 'rotate-90' : '',
          ]"
          @click.stop="toggleCulling"
        />
        <span class="sidebar-item-label">{{ localeMsg.culling.title }}</span>
      </div>

      <Transition
        @before-enter="onBeforeEnter"
        @enter="onEnter"
        @after-enter="onAfterEnter"
        @leave="onLeave"
      >
        <div v-if="libConfig.library.cullingExpanded" class="overflow-hidden">
          <ul class="mb-2">
            <li v-for="item in cullingItems" :key="item.id" class="pl-4">
              <div
                :class="[
                  'sidebar-item sidebar-item-compact ml-2',
                  libConfig.library.item === LIB_ITEM.CULLING && libConfig.culling.item === item.id ? 'sidebar-item-selected' : 'sidebar-item-hover',
                ]"
                @click="selectCulling(item.id)"
              >
                <component :is="item.icon" class="mx-1 w-4 h-4 shrink-0" />
                <span class="sidebar-item-label">{{ item.label }}</span>
                <span v-if="item.count" class="ml-auto text-[10px] tabular-nums text-base-content/30 mr-2">{{ item.count.toLocaleString() }}</span>
              </div>
            </li>
          </ul>
        </div>
      </Transition>

      <div class="sidebar-item sidebar-item-hover" @click="toggleSubjects">
        <IconRight
          :class="[
            'p-1 w-6 h-6 shrink-0 transition-transform',
            libConfig.library.subjectsExpanded ? 'rotate-90' : '',
          ]"
          @click.stop="toggleSubjects"
        />
        <span class="sidebar-item-label">
          {{ localeMsg.subject.title }}
        </span>
      </div>

      <Transition
        @before-enter="onBeforeEnter"
        @enter="onEnter"
        @after-enter="onAfterEnter"
        @leave="onLeave"
      >
        <div v-if="libConfig.library.subjectsExpanded" class="overflow-hidden">
          <ul class="mb-2">
            <li v-for="item in smartTagItems" :key="item.id" class="pl-4">
              <div
                :class="[
                  'sidebar-item sidebar-item-compact ml-2',
                  libConfig.library.item === LIB_ITEM.SUBJECTS && libConfig.library.smartId === item.id ? 'sidebar-item-selected' : 'sidebar-item-hover',
                ]"
                @click="selectSmartTag(item.id)"
              >
                <IconBolt class="mx-1 w-4 h-4 shrink-0" />
                <span class="sidebar-item-label">{{ item.label }}</span>
                <span v-if="item.count" class="text-[10px] tabular-nums text-base-content/30 mr-2">{{ formatSearchResultCount(item.count) }}</span>
              </div>
            </li>
          </ul>
        </div>
      </Transition>
    </div>

  </div>

</template>

<script setup lang="ts">
import { computed, ref, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { listen } from '@tauri-apps/api/event';
import { config, libConfig } from '@/common/config';
import { CULLING, LIB_ITEM, RATE, type LibItem } from '@/common/constants';

import { IconFiles, IconHeartFilled, IconRight, IconBolt, IconFlag, IconFlagFilled, IconFlagOff, IconStar, IconStarFilled, IconHistory } from '@/common/icons';
import { getQueryCountAndSum, getTotalCountAndSum } from '@/common/api';
import { SMART_TAG_CATEGORIES } from '@/common/smartTags';

const props = defineProps({
  titlebar: {
    type: String,
    required: true
  }
});

const { locale, messages } = useI18n();
const localeMsg = computed(() => messages.value[locale.value] as any);
const totalCount = ref(0);
const favoriteCount = ref(0);
const todayCount = ref(0);
const unratedCount = ref(0);
const ratedCountOverride = ref<number | null>(null);
let unlistenLibraryItemCount: (() => void) | null = null;
let unlistenCullingStatus: (() => void) | null = null;
const cullingCounts = ref<Record<string, number>>({
  [CULLING.PICK]: 0,
  [CULLING.REJECT]: 0,
  [CULLING.UNREVIEWED]: 0,
});
const ratingCounts = ref<Record<number, number>>({
  1: 0,
  2: 0,
  3: 0,
  4: 0,
  5: 0,
});
const ratedCount = computed(() =>
  ratedCountOverride.value
  ?? Object.values(ratingCounts.value).reduce((sum, count) => sum + count, 0)
);

const buildQueryParams = ({ isFavorite = false, rating = RATE.NONE, cullingFlag = -1, startDate = 0, endDate = 0 } = {}) => ({
  searchFileType: 0,
  sortType: 0,
  sortOrder: 0,
  searchFileName: "",
  searchAllSubfolders: "",
  searchFolder: "",
  startDate,
  endDate,
  calendarSort: 0,
  make: "",
  model: "",
  lensMake: "",
  lensModel: "",
  locationAdmin1: "",
  locationName: "",
  isFavorite,
  rating,
  cullingFlag,
  tagId: 0,
  personId: 0,
});

const libraryItems = computed(() => [
  {
    id: LIB_ITEM.ALL,
    label: localeMsg.value.library.all_files,
    icon: IconFiles,
    count: totalCount.value,
  },
  {
    id: LIB_ITEM.FAV,
    label: localeMsg.value.favorite.files,
    icon: IconHeartFilled,
    count: favoriteCount.value,
  },
  {
    id: LIB_ITEM.TODAY,
    label: localeMsg.value.library.on_this_day,
    icon: IconHistory,
    count: todayCount.value,
  },
]);

const smartTagItems = computed(() =>
  SMART_TAG_CATEGORIES.map(category => {
    const item = category.items[0];
    return {
      id: item.id,
      label: localeMsg.value.subject.items?.[item.id] || item.id,
      count: Number(libConfig.library.subjectCounts?.[item.id] || 0),
    };
  })
);

const cullingItems = computed(() => [
  { id: CULLING.PICK, label: localeMsg.value.culling.picks, icon: IconFlagFilled, count: cullingCounts.value[CULLING.PICK] },
  { id: CULLING.REJECT, label: localeMsg.value.culling.rejected, icon: IconFlagOff, count: cullingCounts.value[CULLING.REJECT] },
  { id: CULLING.UNREVIEWED, label: localeMsg.value.culling.unreviewed, icon: IconFlag, count: cullingCounts.value[CULLING.UNREVIEWED] },
]);

function formatSearchResultCount(count: number) {
  const limit = Number(config.settings.imageSearch.limit || 0);
  return limit > 0 && count >= limit
    ? `${limit.toLocaleString()}+`
    : count.toLocaleString();
}

const refreshTotalCount = async () => {
  const result = await getTotalCountAndSum();
  totalCount.value = result ? result[0] : 0;
};

const refreshFavoriteCount = async () => {
  const result = await getQueryCountAndSum(buildQueryParams({ isFavorite: true }));
  favoriteCount.value = result ? Number(result[0]) : 0;
};

const refreshTodayCount = async () => {
  const result = await getQueryCountAndSum(buildQueryParams({ startDate: -1, endDate: -1 }));
  todayCount.value = result ? Number(result[0]) : 0;
};

const refreshRatingCounts = async () => {
  const unrated = await getQueryCountAndSum(buildQueryParams({ rating: 0 }));
  unratedCount.value = unrated ? Number(unrated[0]) : 0;

  const entries = await Promise.all(
    [1, 2, 3, 4, 5].map(async (rating) => {
      const result = await getQueryCountAndSum(buildQueryParams({ rating }));
      return [rating, result ? Number(result[0]) : 0] as const;
    }),
  );

  ratingCounts.value = Object.fromEntries(entries) as Record<number, number>;
  ratedCountOverride.value = null;
};

const refreshCullingCounts = async () => {
  const entries = await Promise.all([
    [CULLING.PICK, 1],
    [CULLING.REJECT, 2],
    [CULLING.UNREVIEWED, 0],
  ].map(async ([item, cullingFlag]) => {
    const result = await getQueryCountAndSum(buildQueryParams({ cullingFlag }));
    return [item, result ? Number(result[0]) : 0] as const;
  }));
  cullingCounts.value = Object.fromEntries(entries) as Record<string, number>;
};

function selectItem(item: LibItem) {
  libConfig.library.item = item;
}

function toggleSubjects() {
  libConfig.library.subjectsExpanded = !libConfig.library.subjectsExpanded;
}

function toggleRatings() {
  libConfig.library.ratingsExpanded = !libConfig.library.ratingsExpanded;
}

function toggleCulling() {
  libConfig.library.cullingExpanded = !libConfig.library.cullingExpanded;
}

function onBeforeEnter(el: Element) {
  const element = el as HTMLElement;
  element.style.opacity = '0';
  element.style.height = '0';
}

function onEnter(el: Element) {
  const element = el as HTMLElement;
  element.style.transition = 'all 0.1s ease';
  element.style.height = `${element.scrollHeight}px`;
  element.style.opacity = '1';
}

function onAfterEnter(el: Element) {
  (el as HTMLElement).style.height = '';
}

function onLeave(el: Element) {
  const element = el as HTMLElement;
  element.style.transition = 'all 0.1s ease';
  element.style.height = `${element.scrollHeight}px`;
  void element.offsetHeight;
  element.style.height = '0';
  element.style.opacity = '0';
}

function selectRating(rating: number) {
  libConfig.library.item = LIB_ITEM.RATINGS;
  libConfig.rating.item = rating;
}

function selectCulling(item: string) {
  libConfig.library.item = LIB_ITEM.CULLING;
  libConfig.culling.item = item;
}

function selectSmartTag(smartId: string) {
  libConfig.library.item = LIB_ITEM.SUBJECTS;
  libConfig.library.smartId = smartId;
}

const applyCountUpdate = (payload: any) => {
    const count = Math.max(0, Number(payload?.count || 0));
    switch (payload?.item) {
      case LIB_ITEM.ALL:
        totalCount.value = count;
        break;
      case LIB_ITEM.FAV:
        favoriteCount.value = count;
        break;
      case LIB_ITEM.TODAY:
        todayCount.value = count;
        break;
      case LIB_ITEM.RATINGS: {
        const rating = Number(payload?.rating);
        if (rating === RATE.ALL) {
          ratedCountOverride.value = count;
        } else if (rating === RATE.UNRATED) {
          unratedCount.value = count;
        } else if (rating >= 1 && rating <= 5) {
          ratedCountOverride.value = null;
          ratingCounts.value = { ...ratingCounts.value, [rating]: count };
        }
        break;
      }
      case LIB_ITEM.CULLING: {
        const item = String(payload?.cullingItem || '');
        if (Object.hasOwn(cullingCounts.value, item)) {
          cullingCounts.value = { ...cullingCounts.value, [item]: count };
        }
        break;
      }
      case LIB_ITEM.SUBJECTS: {
        const smartId = String(payload?.smartId || '');
        if (smartId) {
          const subjectCounts = libConfig.library.subjectCounts || {};
          if (Object.hasOwn(subjectCounts, smartId) && Number(subjectCounts[smartId]) === count) break;
          libConfig.library.subjectCounts = {
            ...subjectCounts,
            [smartId]: count,
          };
        }
        break;
      }
    }
};

onMounted(async () => {
  const pendingUpdates: any[] = [];
  let initializing = true;
  unlistenLibraryItemCount = await listen('library-item-count-updated', (event: any) => {
    if (initializing) {
      pendingUpdates.push(event.payload);
    } else {
      applyCountUpdate(event.payload);
    }
  });
  unlistenCullingStatus = await listen('culling-status-updated', () => {
    void refreshCullingCounts();
  });

  await Promise.all([
    refreshTotalCount(),
    refreshFavoriteCount(),
    refreshTodayCount(),
    refreshRatingCounts(),
    refreshCullingCounts(),
  ]);
  initializing = false;
  pendingUpdates.forEach(applyCountUpdate);
});

onBeforeUnmount(() => {
  unlistenLibraryItemCount?.();
  unlistenCullingStatus?.();
});

</script>
