<!--
協辦 (Assisted Application) — S5:我的協助者(授權、結束授權)。
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
import { storeToRefs } from 'pinia';
import BaseButton from '@/components/atoms/BaseButton.vue';
import BaseDialog from '@/components/atoms/BaseDialog.vue';
import BaseInput from '@/components/atoms/BaseInput.vue';
import { useAssistStore } from '@/stores/assist';
import { useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';
import { addDelegation, endDelegation } from '@/assist/api';
import type { DelegateType, Delegation } from '@/assist/types';

const store = useAssistStore();
const { delegations } = storeToRefs(store);
const { t, lang } = useAssistI18n();

const typeOptions: DelegateType[] = ['FAMILY', 'CAREGIVER', 'VILLAGE_CHIEF'];
const dayOptions = [7, 30, 90];

const newType = ref<DelegateType>('CAREGIVER');
const newName = ref('');
const newDays = ref(30);
const isNameInvalid = ref(false);

const endTarget = ref<Delegation | null>(null);
const isEndDialogOpen = ref(false);

onMounted(() => {
  store.loadDelegations();
});

const formatDate = (iso: string) =>
  new Date(iso).toLocaleDateString(lang.value === 'zh-Hant' ? 'zh-TW' : lang.value);

const onSave = async () => {
  const name = String(newName.value ?? '').trim();
  if (!name) {
    isNameInvalid.value = true;
    return;
  }
  isNameInvalid.value = false;
  await addDelegation(newType.value, name, newDays.value, store.elderId);
  newName.value = '';
  await store.loadDelegations();
};

const onAskEnd = (item: Delegation) => {
  endTarget.value = item;
  isEndDialogOpen.value = true;
};

const onEnd = async () => {
  if (endTarget.value) {
    await endDelegation(endTarget.value.id, store.elderId);
    await store.loadDelegations();
  }
};
</script>

<template>
  <main class="px-4 pb-10 pt-4">
    <h1 class="text-2xl font-bold text-[#5AB4C5]">{{ t('deleg.title') }}</h1>
    <p class="mt-2 rounded bg-secondary-50 p-3 text-lg text-secondary-800">{{ t('deleg.tip') }}</p>

    <p
      v-if="!delegations.length"
      class="mt-4 rounded bg-white p-6 text-center text-lg text-grey-500"
    >
      {{ t('deleg.empty') }}
    </p>
    <ul v-else class="mt-4 flex flex-col gap-y-4">
      <li v-for="item in delegations" :key="item.id" class="rounded bg-white p-4 shadow-card">
        <p class="text-xl font-bold text-grey-900">
          {{ t(`helper.${item.helperType}` as MessageKey) }}
          <span class="font-normal text-grey-700"> · {{ item.helperName }}</span>
        </p>
        <p class="mt-1 text-base text-grey-500">
          {{ t('deleg.until', { date: formatDate(item.expiresAt) }) }}
        </p>
        <BaseButton outline class="mt-3 w-full !py-3 text-lg font-bold" @click="onAskEnd(item)">
          {{ t('deleg.end') }}
        </BaseButton>
      </li>
    </ul>

    <section class="mt-8 rounded bg-white p-4 shadow-card">
      <h2 class="text-xl font-bold text-grey-900">{{ t('deleg.add') }}</h2>

      <p class="mt-4 text-base text-grey-500">{{ t('deleg.type') }}</p>
      <div class="mt-2 flex flex-wrap gap-2">
        <button
          v-for="type in typeOptions"
          :key="type"
          type="button"
          class="assist-pill"
          :class="{ 'assist-pill--active': newType === type }"
          :aria-pressed="newType === type"
          @click="newType = type"
        >
          {{ t(`helper.${type}` as MessageKey) }}
        </button>
      </div>

      <p class="mt-4 text-base text-grey-500">{{ t('deleg.name') }}</p>
      <BaseInput v-model="newName" class="mt-2 w-full text-lg" :placeholder="t('deleg.name')" />
      <p v-if="isNameInvalid" class="mt-2 text-right text-sm text-warn-200">
        {{ t('deleg.name') }}
      </p>

      <p class="mt-4 text-base text-grey-500">{{ t('deleg.days') }}</p>
      <div class="mt-2 flex gap-2">
        <button
          v-for="days in dayOptions"
          :key="days"
          type="button"
          class="assist-pill w-16 justify-center"
          :class="{ 'assist-pill--active': newDays === days }"
          :aria-pressed="newDays === days"
          @click="newDays = days"
        >
          {{ days }}
        </button>
      </div>

      <BaseButton class="mt-6 w-full !py-4 text-lg font-bold" @click="onSave">
        {{ t('deleg.save') }}
      </BaseButton>
    </section>

    <BaseDialog
      v-model="isEndDialogOpen"
      is-alert
      :title="t('deleg.endTitle')"
      :content="t('deleg.endBody', { name: endTarget?.helperName ?? '' })"
      :negative-text="t('common.cancel')"
      :positive-text="t('deleg.end')"
      @on-positive-click="onEnd"
    />
  </main>
</template>
