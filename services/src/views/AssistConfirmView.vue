<!--
協辦 (Assisted Application) — S2:確認資料(一個欄位一張卡片,可朗讀)。
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
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import BaseButton from '@/components/atoms/BaseButton.vue';
import BaseDialog from '@/components/atoms/BaseDialog.vue';
import BaseTextarea from '@/components/atoms/BaseTextarea.vue';
import AssistReadButton from '@/components/atoms/AssistReadButton.vue';
import ServiceStep from '@/components/molecules/ServiceStep.vue';
import AssistFieldCard from '@/components/molecules/AssistFieldCard.vue';
import { useAssistStore } from '@/stores/assist';
import { useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';

const route = useRoute();
const router = useRouter();
const store = useAssistStore();
const { current, loading } = storeToRefs(store);
const { t, applyDefaultLang } = useAssistI18n();

const id = route.params.id as string;

const isWrongDialogOpen = ref(false);
const isSentDialogOpen = ref(false);
const note = ref('');

onMounted(async () => {
  const request = await store.loadRequest(id);
  if (request) applyDefaultLang(request.elderLang);
});

const allText = computed(() => {
  if (!current.value) return '';
  return [
    t('confirm.title'),
    ...current.value.fields.map((f) => `${t(`field.${f.key}` as MessageKey)}。${f.value}`)
  ].join('。');
});

const onWrongSend = async () => {
  await store.revise(id, note.value);
  isSentDialogOpen.value = true;
};
</script>

<template>
  <main class="px-4 pb-44 pt-4">
    <ServiceStep :step-count="3" :active-step="1" />

    <p v-if="loading" class="py-10 text-center text-grey-500">{{ t('common.loading') }}</p>

    <p v-else-if="!current" class="mt-6 rounded bg-white p-6 text-center text-lg text-grey-700">
      {{ t('req.notFound') }}
    </p>

    <template v-else>
      <div class="mt-6 flex items-center justify-between gap-3">
        <h1 class="text-2xl font-bold text-[#5AB4C5]">{{ t('confirm.title') }}</h1>
        <AssistReadButton :text="allText" />
      </div>

      <ul class="mt-4 flex flex-col gap-y-4">
        <li v-for="field in current.fields" :key="field.key">
          <AssistFieldCard :label="t(`field.${field.key}` as MessageKey)" :value="field.value" />
        </li>
      </ul>
    </template>

    <div v-if="current" class="fixed bottom-0 left-0 z-10 w-full bg-white p-4 shadow-card">
      <BaseButton
        class="w-full !py-4 text-xl font-bold"
        @click="router.push({ name: 'assist-final', params: { id } })"
      >
        {{ t('confirm.ok') }}
      </BaseButton>
      <BaseButton
        outline
        class="mt-3 w-full !py-4 text-lg font-bold"
        @click="isWrongDialogOpen = true"
      >
        {{ t('confirm.wrong') }}
      </BaseButton>
    </div>

    <BaseDialog
      v-model="isWrongDialogOpen"
      is-slot
      content=""
      :title="t('confirm.wrongTitle')"
      :negative-text="t('common.cancel')"
      :positive-text="t('confirm.send')"
      @on-positive-click="onWrongSend"
    >
      <template #content>
        <p class="mb-3 text-center text-base text-grey-500">{{ t('confirm.wrongHint') }}</p>
        <BaseTextarea v-model="note" class="w-full" />
      </template>
    </BaseDialog>

    <BaseDialog
      v-model="isSentDialogOpen"
      is-check
      :content="t('confirm.sent')"
      :positive-text="t('done.home')"
      @on-positive-click="router.replace({ name: 'assist-home' })"
    />
  </main>
</template>
