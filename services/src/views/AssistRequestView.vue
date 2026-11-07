<!--
協辦 (Assisted Application) — S1:有人要幫你辦(同意或拒絕)。
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
import { storeToRefs } from 'pinia';
import BaseButton from '@/components/atoms/BaseButton.vue';
import BaseDialog from '@/components/atoms/BaseDialog.vue';
import AssistReadButton from '@/components/atoms/AssistReadButton.vue';
import { useAssistStore } from '@/stores/assist';
import { useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';

const route = useRoute();
const router = useRouter();
const store = useAssistStore();
const { current, loading } = storeToRefs(store);
const { t, applyDefaultLang } = useAssistI18n();

const id = route.params.id as string;
const isRejectDialogOpen = ref(false);
const isRejected = ref(false);

onMounted(async () => {
  const request = await store.loadRequest(id);
  if (request) {
    applyDefaultLang(request.elderLang);
    // 已經同意過,直接去確認資料
    if (request.status === 'ACCEPTED') {
      router.replace({ name: 'assist-confirm', params: { id } });
    }
  }
});

const onAgree = async () => {
  await store.accept(id);
  router.push({ name: 'assist-confirm', params: { id } });
};

const onReject = async () => {
  await store.reject(id);
  isRejected.value = true;
};

const readText = () =>
  current.value
    ? `${t('req.title')}。${t(`helper.${current.value.helperType}` as MessageKey)}。${t(
        `svc.${current.value.serviceId}` as MessageKey
      )}。${t('req.warn')}`
    : '';
</script>

<template>
  <main class="px-4 pb-44 pt-4">
    <p v-if="loading" class="py-10 text-center text-grey-500">{{ t('common.loading') }}</p>

    <p v-else-if="!current" class="rounded bg-white p-6 text-center text-lg text-grey-700">
      {{ t('req.notFound') }}
    </p>

    <template v-else>
      <section class="rounded bg-white p-6 shadow-card">
        <div class="flex items-start justify-between gap-3">
          <h1 class="text-2xl font-bold text-[#5AB4C5]">{{ t('req.title') }}</h1>
          <AssistReadButton :text="readText()" />
        </div>

        <p class="mt-6 text-base text-grey-500">{{ t('req.helper') }}</p>
        <p class="text-2xl font-bold text-grey-900">
          {{ t(`helper.${current.helperType}` as MessageKey) }}
        </p>
        <p
          v-if="current.helperName !== t(`helper.${current.helperType}` as MessageKey)"
          class="text-lg text-grey-700"
        >
          {{ current.helperName }}
        </p>

        <p class="mt-6 text-base text-grey-500">{{ t('req.service') }}</p>
        <p class="text-xl font-bold text-grey-900">
          {{ t(`svc.${current.serviceId}` as MessageKey) }}
        </p>

        <p class="mt-6 rounded bg-secondary-50 p-3 text-lg text-secondary-800">
          {{ t('req.warn') }}
        </p>
      </section>

      <p
        v-if="current.status === 'EXPIRED'"
        class="mt-4 rounded bg-white p-4 text-lg text-warn-200"
      >
        {{ t('req.expired') }}
      </p>
      <p
        v-if="isRejected || current.status === 'REJECTED'"
        class="mt-4 rounded bg-white p-4 text-lg"
      >
        {{ t('req.rejected') }}
      </p>
    </template>

    <div
      v-if="current && current.status === 'PENDING' && !isRejected"
      class="fixed bottom-0 left-0 z-10 w-full bg-white p-4 shadow-card"
    >
      <BaseButton class="w-full !py-4 text-xl font-bold" @click="onAgree">
        {{ t('req.agree') }}
      </BaseButton>
      <BaseButton
        outline
        class="mt-3 w-full !py-4 text-lg font-bold"
        @click="isRejectDialogOpen = true"
      >
        {{ t('req.reject') }}
      </BaseButton>
    </div>

    <div v-else-if="current" class="fixed bottom-0 left-0 z-10 w-full bg-white p-4 shadow-card">
      <BaseButton
        outline
        class="w-full !py-4 text-lg font-bold"
        @click="router.replace({ name: 'assist-home' })"
      >
        {{ t('done.home') }}
      </BaseButton>
    </div>

    <BaseDialog
      v-model="isRejectDialogOpen"
      is-alert
      :title="t('req.rejectTitle')"
      :content="t('req.rejectBody')"
      :negative-text="t('common.cancel')"
      :positive-text="t('common.confirm')"
      @on-positive-click="onReject"
    />
  </main>
</template>
