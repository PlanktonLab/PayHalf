<!--
協辦 (Assisted Application) — 語言與字級工具列。
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
import { LANG_OPTIONS, useAssistI18n } from '@/assist/i18n';
import { useFontLevel } from '@/assist/useEasyRead';
import type { FontLevel } from '@/assist/useEasyRead';

const { lang, t, setLang } = useAssistI18n();
const { fontLevel, setFontLevel } = useFontLevel();

const fontOptions: { level: FontLevel; label: string; cls: string }[] = [
  { level: 0, label: 'A', cls: 'text-sm' },
  { level: 1, label: 'A', cls: 'text-lg' },
  { level: 2, label: 'A', cls: 'text-2xl' }
];
</script>

<template>
  <div class="bg-white px-4 py-3 shadow-card" role="toolbar" :aria-label="t('tool.language')">
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-grey-500 text-sm">{{ t('tool.language') }}</span>
      <button
        v-for="item in LANG_OPTIONS"
        :key="item.value"
        type="button"
        class="assist-pill"
        :class="{ 'assist-pill--active': lang === item.value }"
        :aria-pressed="lang === item.value"
        @click="setLang(item.value)"
      >
        {{ item.label }}
      </button>
    </div>
    <div class="mt-2 flex items-center gap-2">
      <span class="text-grey-500 text-sm">{{ t('tool.fontSize') }}</span>
      <button
        v-for="item in fontOptions"
        :key="item.level"
        type="button"
        class="assist-pill w-11 justify-center"
        :class="[item.cls, { 'assist-pill--active': fontLevel === item.level }]"
        :aria-pressed="fontLevel === item.level"
        :aria-label="`${t('tool.fontSize')} ${item.level + 1}`"
        @click="setFontLevel(item.level)"
      >
        {{ item.label }}
      </button>
    </div>
  </div>
</template>

<style lang="postcss">
.assist-pill {
  @apply inline-flex items-center min-h-11 px-3 rounded-full;
  @apply border border-primary-500 text-primary-700 bg-white;

  &--active {
    @apply bg-primary-500 text-white;
  }
}
</style>
