<!--
協辦 (Assisted Application) — 長輩確認資料用的欄位卡片(一個欄位一張,可朗讀;可點選標示「不對」)。
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
import AssistReadButton from '@/components/atoms/AssistReadButton.vue';
import { useAssistI18n } from '@/assist/i18n';

const props = defineProps<{
  label: string;
  value: string;
  /** 「有錯」模式:整張卡片可點選,標示這一項不對 */
  selectable?: boolean;
  selected?: boolean;
}>();

const emit = defineEmits<{ (e: 'toggle'): void }>();

const { t } = useAssistI18n();

const onToggle = () => {
  if (props.selectable) emit('toggle');
};
</script>

<template>
  <div
    class="flex items-center justify-between gap-3 rounded bg-white p-4 shadow-card"
    :class="{
      'cursor-pointer border-2 border-grey-200': props.selectable && !props.selected,
      'cursor-pointer border-2 border-warn-200 bg-[#fdecec]': props.selectable && props.selected
    }"
    :role="props.selectable ? 'checkbox' : undefined"
    :aria-checked="props.selectable ? !!props.selected : undefined"
    :tabindex="props.selectable ? 0 : undefined"
    @click="onToggle"
    @keydown.enter.prevent="onToggle"
    @keydown.space.prevent="onToggle"
  >
    <div class="min-w-0">
      <p class="text-grey-500 text-base">
        {{ props.label }}
        <span
          v-if="props.selectable && props.selected"
          class="ml-2 inline-flex rounded-full bg-warn-200 px-2 text-sm font-bold text-white"
        >
          {{ t('confirm.markWrong') }}
        </span>
      </p>
      <p class="mt-1 break-words text-2xl font-bold text-grey-900">{{ props.value }}</p>
    </div>
    <span @click.stop @keydown.stop>
      <AssistReadButton :text="`${props.label}。${props.value}`" />
    </span>
  </div>
</template>
