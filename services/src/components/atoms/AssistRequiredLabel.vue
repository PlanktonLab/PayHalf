<!--
協辦 (Assisted Application) — 表單標籤,必填時顯示紅色 * 並提供螢幕閱讀器「必填」。
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

const props = defineProps<{ label: string; forId?: string; required?: boolean }>();

const { t } = useAssistI18n();
</script>

<template>
  <label :for="props.forId" class="block text-base text-grey-500">
    {{ props.label }}
    <template v-if="props.required">
      <span aria-hidden="true" class="font-bold text-warn-200"> *</span>
      <span class="sr-only"> ({{ t('help.required') }})</span>
    </template>
  </label>
</template>
