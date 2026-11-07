/**
 * 協辦 (Assisted Application) — 新邀請提醒:定時檢查,有新邀請就跳出徽章提示並發出系統通知。
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
 * 說明:
 * - 這裡用「定時輪詢」而不是商用推播服務(規則只准開源、不可有第三方費用或訂閱)。
 * - 只在協辦頁面開啟時有效。App 在背景或停在別的頁面時,需要 Flutter 端另外輪詢,
 *   並且要有真正的後端(目前是前端記憶體模擬,跨手機不會同步)。
 * - 系統通知使用 App 既有的 `notify` 橋接。
 */
import { ref, watch } from 'vue';
import { listPending } from './api';
import { useAssistI18n } from './i18n';
import type { MessageKey } from './i18n';
import type { AssistRequest } from './types';
import { useAssistStore } from '@/stores/assist';
import { useConnectionMessage } from '@/composables/useConnectionMessage';

const POLL_MS = 3000;

/** 最新一則還沒被使用者看過的邀請(提示條顯示用) */
const newInvite = ref<AssistRequest | null>(null);

let timer: ReturnType<typeof setInterval> | undefined;
let seen: Set<string> | null = null;

export const useInviteWatcher = () => {
  const store = useAssistStore();
  const { t } = useAssistI18n();

  const describeHelper = (request: AssistRequest) => {
    const label = t(`helper.${request.helperType}` as MessageKey);
    return request.helperName && request.helperName !== label
      ? `${label} · ${request.helperName}`
      : label;
  };

  const poll = async () => {
    const elderId = store.elderId;
    const list = await listPending(elderId);
    // 等待期間若換了帳號(例如 App 剛把登入者資料傳進來),這次結果已過時,直接丟掉,
    // 否則會把「既有的邀請」誤當成「新邀請」。
    if (elderId !== store.elderId) return;
    store.pending = list;

    // 第一次檢查只記錄現有的邀請,不提醒;之後多出來的才算「新邀請」
    if (seen === null) {
      seen = new Set(list.map((item) => item.id));
      return;
    }

    const fresh = list.filter((item) => !seen!.has(item.id));
    list.forEach((item) => seen!.add(item.id));
    if (!fresh.length) return;

    const latest = fresh[fresh.length - 1];
    newInvite.value = latest;
    useConnectionMessage('notify', {
      title: t('invite.new'),
      content: t('invite.from', {
        who: describeHelper(latest),
        service: t(`svc.${latest.serviceId}` as MessageKey)
      })
    });
  };

  let stopWatchingAccount: (() => void) | undefined;

  const start = () => {
    if (timer) return;
    // 帳號改變時,重新建立基準並馬上檢查一次
    stopWatchingAccount = watch(
      () => store.elderId,
      () => {
        seen = null;
        poll();
      }
    );
    poll();
    timer = setInterval(poll, POLL_MS);
  };

  const stop = () => {
    if (timer) clearInterval(timer);
    timer = undefined;
    stopWatchingAccount?.();
    stopWatchingAccount = undefined;
    seen = null;
  };

  const dismiss = () => {
    newInvite.value = null;
  };

  return { newInvite, start, stop, dismiss, describeHelper };
};
