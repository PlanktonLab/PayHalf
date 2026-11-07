/**
 * 協辦 (Assisted Application) — 易讀輔助:字級放大與朗讀。
 * Copyright (C) 2026 協辦 team
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU Affero General Public License as published by the Free Software Foundation, either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License along with this program.
 * If not, see https://www.gnu.org/licenses/.
 *
 * 朗讀使用瀏覽器內建的 speechSynthesis(系統語音),不使用任何雲端語音服務。
 */
import { ref } from 'vue';
import { useConnectionMessage } from '@/composables/useConnectionMessage';
import { useAssistI18n } from './i18n';

export type FontLevel = 0 | 1 | 2;

/** 根字級:一般 / 大 / 特大。畫面全部使用 rem,所以整體會一起放大。 */
export const FONT_PX: Record<FontLevel, number> = { 0: 16, 1: 20, 2: 24 };

const STORAGE_KEY = 'assist-font-level';

const readStoredLevel = (): FontLevel => {
  try {
    const stored = Number(window.localStorage.getItem(STORAGE_KEY));
    return stored === 1 || stored === 2 ? stored : 1;
  } catch {
    return 1;
  }
};

/** 預設用「大」,長輩較容易閱讀 */
const fontLevel = ref<FontLevel>(readStoredLevel());

export const useFontLevel = () => {
  const setFontLevel = (level: FontLevel) => {
    fontLevel.value = level;
    try {
      window.localStorage.setItem(STORAGE_KEY, String(level));
    } catch {
      // 無法儲存時忽略
    }
  };

  return { fontLevel, setFontLevel };
};

const speaking = ref(false);

/** App 朗讀橋接回報的錯誤:LANG_UNAVAILABLE(手機沒有該語言語音)、FAILED 等 */
const ttsError = ref<string | null>(null);
let bridgeListening = false;

const hasBridge = () =>
  // @ts-ignore flutterObject 由 App 的 WebView 注入
  typeof flutterObject !== 'undefined' && !!flutterObject;

/**
 * Android WebView 沒有 speechSynthesis,所以在 App 內改走 `tts` 橋接,由手機系統語音引擎朗讀。
 * 橋接的回覆只需註冊一次(所有朗讀按鈕共用),避免每顆按鈕各自監聽造成重複。
 */
const ensureBridgeListener = () => {
  if (bridgeListening || !hasBridge()) return;
  bridgeListening = true;
  // @ts-ignore
  flutterObject.addEventListener('message', (event: { data: string }) => {
    try {
      const result = JSON.parse(event.data);
      if (result.name !== 'tts') return;
      ttsError.value =
        result.data && result.data.ok === false ? result.data.error ?? 'FAILED' : null;
    } catch {
      // 不是朗讀的訊息就忽略
    }
  });
};

export const useTtsError = () => ({ ttsError });

export const useReadAloud = () => {
  const { speechLang } = useAssistI18n();

  const supported = typeof window !== 'undefined' && (hasBridge() || 'speechSynthesis' in window);

  const stop = () => {
    if (hasBridge()) {
      useConnectionMessage('tts', { action: 'stop' });
      return;
    }
    if (!supported) return;
    window.speechSynthesis.cancel();
    speaking.value = false;
  };

  const speak = (text: string) => {
    if (!supported || !text) return;
    if (hasBridge()) {
      ensureBridgeListener();
      ttsError.value = null;
      useConnectionMessage('tts', { action: 'speak', text, lang: speechLang() });
      return;
    }
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = speechLang();
    utterance.rate = 0.9;
    utterance.onend = () => {
      speaking.value = false;
    };
    utterance.onerror = () => {
      speaking.value = false;
    };
    speaking.value = true;
    window.speechSynthesis.speak(utterance);
  };

  return { supported, speaking, speak, stop };
};
