<!--
協辦 (Assisted Application) — 版面:頂端工具列(語言、字級)與子頁面。
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
import { onMounted, onUnmounted, watch } from 'vue';
import { RouterView } from 'vue-router';
import AssistToolbar from '@/components/molecules/AssistToolbar.vue';
import AssistInviteBanner from '@/components/molecules/AssistInviteBanner.vue';
import { useInviteWatcher } from '@/assist/useInviteWatcher';
import { useAssistI18n } from '@/assist/i18n';
import { FONT_PX, useFontLevel, useReadAloud, useTtsError } from '@/assist/useEasyRead';

const { fontLevel } = useFontLevel();
const { lang, t } = useAssistI18n();
const { ttsError } = useTtsError();
const { start: startWatching, stop: stopWatching } = useInviteWatcher();
const { stop } = useReadAloud();

const applyFontSize = () => {
  document.documentElement.style.fontSize = `${FONT_PX[fontLevel.value]}px`;
};

const applyLang = () => {
  document.documentElement.lang = lang.value === 'zh-Hant' ? 'zh-Hant' : lang.value;
};

onMounted(() => {
  applyFontSize();
  applyLang();
  startWatching();
});

watch(fontLevel, applyFontSize);
watch(lang, applyLang);

onUnmounted(() => {
  stopWatching();
  stop();
  document.documentElement.style.fontSize = '';
  document.documentElement.lang = 'zh-Hant';
});
</script>

<template>
  <div class="min-h-screen bg-grey-50">
    <AssistInviteBanner />
    <AssistToolbar />
    <p v-if="ttsError" role="alert" class="bg-secondary-50 px-4 py-3 text-lg text-secondary-800">
      {{ ttsError === 'LANG_UNAVAILABLE' ? t('tool.noVoice') : t('tool.readFailed') }}
    </p>
    <!-- 依網址重新建立子頁面:從一筆邀請直接切到另一筆時,Vue 預設會重用元件,畫面會停在上一筆 -->
    <RouterView v-slot="{ Component, route }">
      <component :is="Component" :key="route.fullPath" />
    </RouterView>
  </div>
</template>
