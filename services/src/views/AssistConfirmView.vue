<!--
協辦 (Assisted Application) — S2:確認資料(一個欄位一張卡片,可朗讀;有錯時直接點出哪一項不對)。
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
import AssistReadButton from '@/components/atoms/AssistReadButton.vue';
import ServiceStep from '@/components/molecules/ServiceStep.vue';
import AssistFieldCard from '@/components/molecules/AssistFieldCard.vue';
import { useAssistStore } from '@/stores/assist';
import { useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';
import type { RevisionReason } from '@/assist/types';

const route = useRoute();
const router = useRouter();
const store = useAssistStore();
const { current, loading } = storeToRefs(store);
const { t, applyDefaultLang } = useAssistI18n();

const id = route.params.id as string;

/** 「有錯」模式:長輩直接點出哪一項不對,不用打字 */
const wrongMode = ref(false);
const picked = ref<RevisionReason[]>([]);
const isSentDialogOpen = ref(false);
const sending = ref(false);

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

const isPicked = (reason: RevisionReason) => picked.value.includes(reason);

const toggle = (reason: RevisionReason) => {
  picked.value = isPicked(reason)
    ? picked.value.filter((item) => item !== reason)
    : [...picked.value, reason];
};

const enterWrongMode = () => {
  picked.value = [];
  wrongMode.value = true;
};

const cancelWrongMode = () => {
  wrongMode.value = false;
  picked.value = [];
};

const onWrongSend = async () => {
  if (!picked.value.length || sending.value) return;
  sending.value = true;
  try {
    await store.revise(id, picked.value);
    isSentDialogOpen.value = true;
  } finally {
    sending.value = false;
  }
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
        <h1 class="text-2xl font-bold" :class="wrongMode ? 'text-warn-200' : 'text-[#5AB4C5]'">
          {{ wrongMode ? t('confirm.pickWrong') : t('confirm.title') }}
        </h1>
        <AssistReadButton v-if="!wrongMode" :text="allText" />
      </div>

      <ul class="mt-4 flex flex-col gap-y-4">
        <li v-for="field in current.fields" :key="field.key">
          <AssistFieldCard
            :label="t(`field.${field.key}` as MessageKey)"
            :value="field.value"
            :selectable="wrongMode"
            :selected="isPicked(field.key)"
            @toggle="toggle(field.key)"
          />
        </li>
        <li v-if="wrongMode">
          <button
            type="button"
            role="checkbox"
            :aria-checked="isPicked('notMine')"
            class="flex min-h-14 w-full items-center justify-between rounded border-2 p-4 text-left text-xl font-bold"
            :class="
              isPicked('notMine')
                ? 'border-warn-200 bg-[#fdecec] text-warn-200'
                : 'border-grey-200 bg-white text-grey-900'
            "
            @click="toggle('notMine')"
          >
            {{ t('confirm.notMine') }}
            <span
              v-if="isPicked('notMine')"
              class="ml-2 inline-flex rounded-full bg-warn-200 px-2 text-sm font-bold text-white"
            >
              {{ t('confirm.markWrong') }}
            </span>
          </button>
        </li>
      </ul>
    </template>

    <div v-if="current" class="fixed bottom-0 left-0 z-10 w-full bg-white p-4 shadow-card">
      <template v-if="!wrongMode">
        <BaseButton
          class="w-full !py-4 text-xl font-bold"
          @click="router.push({ name: 'assist-final', params: { id } })"
        >
          {{ t('confirm.ok') }}
        </BaseButton>
        <BaseButton outline class="mt-3 w-full !py-4 text-lg font-bold" @click="enterWrongMode">
          {{ t('confirm.wrong') }}
        </BaseButton>
      </template>
      <template v-else>
        <p v-if="!picked.length" class="mb-2 text-center text-base text-grey-500">
          {{ t('confirm.pickAtLeast') }}
        </p>
        <BaseButton
          class="w-full !py-4 text-xl font-bold"
          :disabled="!picked.length || sending"
          @click="onWrongSend"
        >
          {{ t('confirm.send') }}
        </BaseButton>
        <BaseButton outline class="mt-3 w-full !py-4 text-lg font-bold" @click="cancelWrongMode">
          {{ t('common.cancel') }}
        </BaseButton>
      </template>
    </div>

    <BaseDialog
      v-model="isSentDialogOpen"
      is-check
      :content="t('confirm.sent')"
      :positive-text="t('done.home')"
      @on-positive-click="router.replace({ name: 'assist-home' })"
    />
  </main>
</template>
