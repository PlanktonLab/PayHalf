<!--
協辦 (Assisted Application) — 新邀請提示條(帶紅色「新」徽章)。
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
import { onUnmounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import AssistReadButton from '@/components/atoms/AssistReadButton.vue';
import { useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';
import { useInviteWatcher } from '@/assist/useInviteWatcher';

const router = useRouter();
const { t } = useAssistI18n();
const { newInvite, dismiss, describeHelper } = useInviteWatcher();

/** 沒有操作時,8 秒後自動收起 */
let hideTimer: ReturnType<typeof setTimeout> | undefined;

watch(newInvite, (value) => {
  if (hideTimer) clearTimeout(hideTimer);
  if (value) hideTimer = setTimeout(dismiss, 8000);
});

onUnmounted(() => {
  if (hideTimer) clearTimeout(hideTimer);
});

const onView = () => {
  const id = newInvite.value?.id;
  dismiss();
  if (id) router.push({ name: 'assist-request', params: { id } });
};

const message = () =>
  newInvite.value
    ? t('invite.from', {
        who: describeHelper(newInvite.value),
        service: t(`svc.${newInvite.value.serviceId}` as MessageKey)
      })
    : '';
</script>

<template>
  <transition name="invite">
    <div v-if="newInvite" role="alert" class="fixed left-0 top-0 z-50 w-full px-3 pt-3">
      <div class="flex items-start gap-3 rounded bg-white p-4 shadow-card">
        <span
          class="mt-1 inline-flex shrink-0 items-center rounded-full bg-warn-200 px-2 py-0.5 text-sm font-bold text-white"
        >
          {{ t('invite.badge') }}
        </span>
        <div class="min-w-0 flex-1">
          <p class="text-lg font-bold text-grey-900">{{ t('invite.new') }}</p>
          <p class="mt-1 break-words text-base text-grey-700">{{ message() }}</p>
          <div class="mt-3 flex items-center gap-2">
            <button
              type="button"
              class="min-h-11 flex-1 rounded-lg bg-primary-500 px-3 font-bold text-white"
              @click="onView"
            >
              {{ t('invite.view') }}
            </button>
            <AssistReadButton :text="`${t('invite.new')}。${message()}`" />
            <button
              type="button"
              class="min-h-11 rounded-lg border border-primary-500 px-3 text-primary-600"
              @click="dismiss"
            >
              {{ t('invite.close') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </transition>
</template>

<style lang="postcss">
.invite-enter-active,
.invite-leave-active {
  transition:
    transform 0.25s ease,
    opacity 0.25s ease;
}

.invite-enter-from,
.invite-leave-to {
  transform: translateY(-16px);
  opacity: 0;
}
</style>
