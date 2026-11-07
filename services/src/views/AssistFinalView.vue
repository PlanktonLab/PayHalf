<!--
協辦 (Assisted Application) — S3:最後確認。
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
import { useAssistStore } from '@/stores/assist';
import { useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';
import { AssistError } from '@/assist/types';

const route = useRoute();
const router = useRouter();
const store = useAssistStore();
const { current, loading } = storeToRefs(store);
const { t, applyDefaultLang } = useAssistI18n();

const id = route.params.id as string;
const submitting = ref(false);
const isExpiredDialogOpen = ref(false);

onMounted(async () => {
  const request = await store.loadRequest(id);
  if (request) applyDefaultLang(request.elderLang);
});

const applicantName = computed(
  () => current.value?.fields.find((f) => f.key === 'name')?.value ?? ''
);

const summaryText = computed(() => {
  if (!current.value) return '';
  return `${t('final.summary', {
    service: t(`svc.${current.value.serviceId}` as MessageKey)
  })}${t('final.applicant', { name: applicantName.value })}`;
});

const onSubmit = async () => {
  if (submitting.value) return;
  submitting.value = true;
  try {
    await store.confirm(id);
    router.replace({ name: 'assist-done', params: { id } });
  } catch (error) {
    if (error instanceof AssistError && error.code === 'EXPIRED') {
      isExpiredDialogOpen.value = true;
    }
  } finally {
    submitting.value = false;
  }
};
</script>

<template>
  <main class="px-4 pb-44 pt-4">
    <ServiceStep :step-count="3" :active-step="2" />

    <p v-if="loading" class="py-10 text-center text-grey-500">{{ t('common.loading') }}</p>

    <section v-else-if="current" class="mt-6 rounded bg-white p-6 shadow-card">
      <div class="flex items-start justify-between gap-3">
        <h1 class="text-2xl font-bold text-[#5AB4C5]">{{ t('final.title') }}</h1>
        <AssistReadButton :text="summaryText" />
      </div>
      <p class="mt-6 text-2xl font-bold leading-snug text-grey-900">
        {{ t('final.summary', { service: t(`svc.${current.serviceId}` as MessageKey) }) }}
      </p>
      <p class="mt-4 text-xl text-grey-700">{{ t('final.applicant', { name: applicantName }) }}</p>
    </section>

    <p v-else class="mt-6 rounded bg-white p-6 text-center text-lg text-grey-700">
      {{ t('req.notFound') }}
    </p>

    <div v-if="current" class="fixed bottom-0 left-0 z-10 w-full bg-white p-4 shadow-card">
      <BaseButton class="w-full !py-4 text-xl font-bold" :disabled="submitting" @click="onSubmit">
        {{ t('final.submit') }}
      </BaseButton>
      <BaseButton outline class="mt-3 w-full !py-4 text-lg font-bold" @click="router.back()">
        {{ t('final.back') }}
      </BaseButton>
    </div>

    <BaseDialog
      v-model="isExpiredDialogOpen"
      is-alert
      :content="t('req.expired')"
      :positive-text="t('done.home')"
      @on-positive-click="router.replace({ name: 'assist-home' })"
    />
  </main>
</template>
