<!--
協辦 (Assisted Application) — 首頁:等你確認的請求、掃 QR、我的協助者。
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
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import BaseButton from '@/components/atoms/BaseButton.vue';
import { useAssistStore } from '@/stores/assist';
import { useUserStore } from '@/stores/user';
import type { User } from '@/stores/user';
import { useConnectionMessage } from '@/composables/useConnectionMessage';
import { useHandleConnectionData } from '@/composables/useHandleConnectionData';
import { useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';

const router = useRouter();
const store = useAssistStore();
const { pending, loading } = storeToRefs(store);
const { user } = storeToRefs(useUserStore());
const { t } = useAssistI18n();

const handleUserInfo = (event: { data: string }) => {
  try {
    const result: { name: string; data: User } = JSON.parse(event.data);
    if (result.name === 'userinfo') {
      user.value = result.data;
      store.loadPending();
    }
  } catch {
    // 不是我們要的訊息就忽略
  }
};

useConnectionMessage('userinfo', null);
useHandleConnectionData(handleUserInfo);

onMounted(() => {
  store.loadPending();
});

const helperLabel = (type: string) => t(`helper.${type}` as MessageKey);
</script>

<template>
  <main class="px-4 pb-10 pt-4">
    <section class="relative rounded bg-white p-6 shadow-card">
      <img
        src="@/assets/images/person-icon.svg"
        class="absolute left-0 top-0"
        width="64"
        height="64"
        alt=""
      />
      <h1 class="text-center text-2xl font-semibold text-[#5AB4C5]">{{ t('app.title') }}</h1>
      <p class="mt-3 text-center text-lg text-grey-700">{{ t('app.subtitle') }}</p>
    </section>

    <section class="mt-6">
      <h2 class="mb-3 flex items-center gap-2 text-xl font-bold text-grey-900">
        {{ t('home.pending') }}
        <span
          v-if="pending.length"
          class="inline-flex min-w-7 items-center justify-center rounded-full bg-warn-200 px-2 text-base text-white"
          :aria-label="`${pending.length}`"
        >
          {{ pending.length }}
        </span>
      </h2>

      <p v-if="loading" class="py-6 text-center text-grey-500">{{ t('common.loading') }}</p>
      <p v-else-if="!pending.length" class="rounded bg-white p-6 text-center text-lg text-grey-500">
        {{ t('home.noPending') }}
      </p>
      <ul v-else class="flex flex-col gap-y-4">
        <li v-for="item in pending" :key="item.id" class="rounded bg-white p-4 shadow-card">
          <p class="text-base text-grey-500">{{ t('req.helper') }}</p>
          <p class="text-xl font-bold text-grey-900">
            {{ helperLabel(item.helperType) }}
            <span
              v-if="item.helperName !== helperLabel(item.helperType)"
              class="font-normal text-grey-700"
            >
              · {{ item.helperName }}
            </span>
          </p>
          <p class="mt-3 text-base text-grey-500">{{ t('req.service') }}</p>
          <p class="text-lg text-grey-900">{{ t(`svc.${item.serviceId}` as MessageKey) }}</p>
          <BaseButton
            class="mt-4 w-full !py-4 text-lg font-bold"
            @click="router.push({ name: 'assist-request', params: { id: item.id } })"
          >
            {{ t('home.open') }}
          </BaseButton>
        </li>
      </ul>
    </section>

    <section class="mt-8 flex flex-col gap-y-4">
      <div>
        <BaseButton
          class="w-full !py-4 text-lg font-bold"
          @click="router.push({ name: 'assist-scan' })"
        >
          {{ t('home.scan') }}
        </BaseButton>
        <p class="mt-2 text-center text-base text-grey-500">{{ t('home.scanHint') }}</p>
      </div>
      <BaseButton
        outline
        class="w-full !py-4 text-lg font-bold"
        @click="router.push({ name: 'assist-delegations' })"
      >
        {{ t('home.delegations') }}
      </BaseButton>
      <BaseButton
        outline
        class="w-full !py-4 text-lg font-bold"
        @click="router.push({ name: 'assist-help' })"
      >
        {{ t('home.helpOthers') }}
      </BaseButton>
    </section>
  </main>
</template>
