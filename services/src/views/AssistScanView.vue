<!--
協辦 (Assisted Application) — S0:掃 QR(沿用 App 的 qr_code_scan 橋接)。
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
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import BaseButton from '@/components/atoms/BaseButton.vue';
import BaseDialog from '@/components/atoms/BaseDialog.vue';
import BaseTextarea from '@/components/atoms/BaseTextarea.vue';
import { useConnectionMessage } from '@/composables/useConnectionMessage';
import { useHandleConnectionData } from '@/composables/useHandleConnectionData';
import { useAssistStore } from '@/stores/assist';
import { useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';
import { parseQrPayload } from '@/assist/api';
import { AssistError } from '@/assist/types';

const route = useRoute();
const router = useRouter();
const store = useAssistStore();
const { t } = useAssistI18n();

const isErrorDialogOpen = ref(false);
const errorCode = ref<'EXPIRED' | 'NOT_YOU' | 'USED' | 'INVALID'>('INVALID');

const showError = (code: typeof errorCode.value) => {
  errorCode.value = code;
  isErrorDialogOpen.value = true;
};

const redeemPayload = async (payload: string) => {
  const token = parseQrPayload(payload);
  if (!token) {
    showError('INVALID');
    return;
  }
  try {
    const request = await store.redeem(token);
    // 長輩親自掃描 QR,就是同意讓對方協助;直接進入確認資料
    router.replace({ name: 'assist-confirm', params: { id: request.id } });
  } catch (error) {
    if (
      error instanceof AssistError &&
      (error.code === 'EXPIRED' ||
        error.code === 'NOT_YOU' ||
        error.code === 'USED' ||
        error.code === 'INVALID')
    ) {
      showError(error.code);
    } else {
      showError('INVALID');
    }
  }
};

const handleScan = (event: { data: string }) => {
  let result: { name: string; data: string | null };
  try {
    result = JSON.parse(event.data);
  } catch {
    return;
  }
  if (result.name !== 'qr_code_scan') return;

  if (result.data) {
    redeemPayload(result.data);
  } else {
    // 使用者關閉了掃描畫面
    router.back();
  }
};

const startScan = () => useConnectionMessage('qr_code_scan', null);

useHandleConnectionData(handleScan);

// 開發測試:在一般瀏覽器(沒有 App 橋接)時,可貼上 QR 內容測試
const isDev = import.meta.env.DEV;
const devPayload = ref('');

onMounted(() => {
  startScan();
  const fromQuery = route.query.payload;
  if (isDev && typeof fromQuery === 'string') {
    redeemPayload(fromQuery);
  }
});

const onRetry = () => {
  isErrorDialogOpen.value = false;
  startScan();
};
</script>

<template>
  <main class="px-4 pb-10 pt-4">
    <section class="rounded bg-white p-6 text-center shadow-card">
      <h1 class="text-2xl font-bold text-[#5AB4C5]">{{ t('scan.title') }}</h1>
      <p class="mt-4 text-xl text-grey-700">{{ t('scan.hint') }}</p>
      <BaseButton class="mt-6 w-full !py-4 text-xl font-bold" @click="startScan">
        {{ t('scan.retry') }}
      </BaseButton>
    </section>

    <section v-if="isDev" class="mt-6 rounded bg-white p-4 shadow-card">
      <p class="text-sm text-grey-500">{{ t('scan.devHint') }}</p>
      <BaseTextarea v-model="devPayload" class="mt-2 w-full" />
      <BaseButton class="mt-2 w-full" @click="redeemPayload(devPayload)">
        {{ t('common.confirm') }}
      </BaseButton>
    </section>

    <BaseDialog
      v-model="isErrorDialogOpen"
      is-alert
      :content="t(`scan.err.${errorCode}` as MessageKey)"
      :positive-text="t('scan.retry')"
      @on-positive-click="onRetry"
    />
  </main>
</template>
