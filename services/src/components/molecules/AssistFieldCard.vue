<!--
協辦 (Assisted Application) — 長輩確認資料用的欄位卡片(一個欄位一張,可朗讀)。
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

const props = defineProps<{ label: string; value: string }>();
</script>

<template>
  <div class="flex items-center justify-between gap-3 rounded bg-white p-4 shadow-card">
    <div class="min-w-0">
      <p class="text-grey-500 text-base">{{ props.label }}</p>
      <p class="mt-1 break-words text-2xl font-bold text-grey-900">{{ props.value }}</p>
    </div>
    <AssistReadButton :text="`${props.label}。${props.value}`" />
  </div>
</template>
