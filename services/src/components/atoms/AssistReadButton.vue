<!--
協辦 (Assisted Application) — 朗讀按鈕(系統語音)。
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
import { useAssistI18n } from '@/assist/i18n';
import { useReadAloud } from '@/assist/useEasyRead';

const props = defineProps<{ text: string }>();

const { t } = useAssistI18n();
const { supported, speak } = useReadAloud();
</script>

<template>
  <button
    v-if="supported"
    type="button"
    class="inline-flex size-11 shrink-0 items-center justify-center rounded-full border border-primary-500 text-primary-500 bg-white"
    :aria-label="t('tool.read')"
    :title="t('tool.read')"
    @click="speak(props.text)"
  >
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M11 5 6 9H3v6h3l5 4z" />
      <path d="M15.5 8.5a5 5 0 0 1 0 7" />
      <path d="M18.5 5.5a9 9 0 0 1 0 13" />
    </svg>
  </button>
</template>
