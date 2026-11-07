<!--
協辦 (Assisted Application) — S4:完成(5 秒內可撤回)。
Copyright (C) 2026 協辦 team

This program is free software: you can redistribute it and/or modify it under the terms of the
GNU Affero General Public License as published by the Free Software Foundation, either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program.
If not, see https://www.gnu.org/licenses/.
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import BaseButton from '@/components/atoms/BaseButton.vue';
import AssistReadButton from '@/components/atoms/AssistReadButton.vue';
import ServiceStep from '@/components/molecules/ServiceStep.vue';
import { useAssistStore } from '@/stores/assist';
import { useAssistI18n } from '@/assist/i18n';
import { UNDO_SECONDS } from '@/assist/api';

const route = useRoute();
const router = useRouter();
const store = useAssistStore();
const { current } = storeToRefs(store);
const { t, applyDefaultLang } = useAssistI18n();

const id = route.params.id as string;
const secondsLeft = ref(0);
const isUndone = ref(false);
let timer: ReturnType<typeof setInterval> | undefined;

const tick = () => {
  const confirmedAt = current.value?.confirmedAt;
  if (!confirmedAt) {
    secondsLeft.value = 0;
    return;
  }
  const left = Math.ceil((confirmedAt + UNDO_SECONDS * 1000 - Date.now()) / 1000);
  secondsLeft.value = Math.max(0, Math.min(UNDO_SECONDS, left));
  if (secondsLeft.value === 0 && timer) {
    clearInterval(timer);
    timer = undefined;
  }
};

onMounted(async () => {
  const request = await store.loadRequest(id);
  if (!request) return;
  applyDefaultLang(request.elderLang);
  if (request.status !== 'CONFIRMED') {
    router.replace({ name: 'assist-request', params: { id } });
    return;
  }
  tick();
  timer = setInterval(tick, 500);
});

onUnmounted(() => {
  if (timer) clearInterval(timer);
});

const canUndo = computed(() => !isUndone.value && secondsLeft.value > 0);

const onUndo = async () => {
  try {
    await store.undo(id);
    isUndone.value = true;
  } catch {
    secondsLeft.value = 0;
  }
};

const readText = computed(
  () =>
    `${t('done.title')}。${t('done.caseNo')}:${current.value?.caseNo ?? ''}。${t('done.nextBody')}`
);
</script>

<template>
  <main class="px-4 pb-32 pt-4">
    <ServiceStep :step-count="3" :active-step="3" />

    <section class="mt-6 rounded bg-white p-6 text-center shadow-card">
      <template v-if="isUndone">
        <img src="@/assets/images/alert-icon.svg" class="mx-auto w-24" alt="" />
        <h1 class="mt-3 text-2xl font-bold text-grey-900">{{ t('done.undone') }}</h1>
      </template>
      <template v-else>
        <img src="@/assets/images/check-icon.svg" class="mx-auto w-24" alt="" />
        <div class="mt-3 flex items-center justify-center gap-3">
          <h1 class="text-2xl font-bold text-[#5AB4C5]">{{ t('done.title') }}</h1>
          <AssistReadButton :text="readText" />
        </div>

        <p class="mt-6 text-base text-grey-500">{{ t('done.caseNo') }}</p>
        <p class="text-2xl font-bold tracking-wide text-grey-900">{{ current?.caseNo }}</p>

        <div v-if="canUndo" class="mt-6 rounded bg-secondary-50 p-3">
          <p class="text-lg text-secondary-800">{{ t('done.undoHint', { s: secondsLeft }) }}</p>
          <BaseButton outline class="mt-3 w-full !py-3 text-lg font-bold" @click="onUndo">
            {{ t('done.undo') }}
          </BaseButton>
        </div>

        <div class="mt-6 text-left">
          <p class="text-lg font-bold text-grey-900">{{ t('done.next') }}</p>
          <p class="mt-1 text-lg text-grey-700">{{ t('done.nextBody') }}</p>
        </div>
      </template>
    </section>

    <div class="fixed bottom-0 left-0 z-10 w-full bg-white p-4 shadow-card">
      <BaseButton
        class="w-full !py-4 text-xl font-bold"
        @click="router.replace({ name: 'assist-home' })"
      >
        {{ t('done.home') }}
      </BaseButton>
    </div>
  </main>
</template>
