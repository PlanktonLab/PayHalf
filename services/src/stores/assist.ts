/**
 * 協辦 (Assisted Application) — 狀態管理。
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
 */
import { computed, ref, watch } from 'vue';
import { defineStore } from 'pinia';
import { useUserStore } from '@/stores/user';
import * as api from '@/assist/api';
import type { AssistRequest, Delegation, RevisionReason } from '@/assist/types';

export const useAssistStore = defineStore('assist', () => {
  const userStore = useUserStore();

  /**
   * 用來辨識「這位長輩」的鍵。沒有從 App 取得登入者時,使用示範長輩。
   * - 記憶體模擬:帳號 ID
   * - HTTP 模式(兩支手機共用後端):身分證字號,協助者填的長輩身分證字號要和長輩登入的相同
   */
  const elderId = computed(() =>
    api.USE_HTTP
      ? userStore.user?.idNo || api.DEFAULT_ELDER_ID_NO
      : userStore.user?.id || api.DEFAULT_ELDER_ID
  );

  // 必須同步執行:收到登入者資料後,馬上重新綁定示範資料,再載入待確認清單(僅記憶體模擬)
  watch(
    elderId,
    (id) => {
      if (!api.USE_HTTP) api.rebindDemoElder(id);
    },
    { immediate: true, flush: 'sync' }
  );

  const pending = ref<AssistRequest[]>([]);
  const current = ref<AssistRequest | null>(null);
  const delegations = ref<Delegation[]>([]);
  const loading = ref(false);

  const loadPending = async () => {
    loading.value = true;
    try {
      pending.value = await api.listPending(elderId.value);
    } catch {
      // 連不上後端時保留目前的清單,下一次輪詢再試
    } finally {
      loading.value = false;
    }
  };

  const loadRequest = async (id: string) => {
    loading.value = true;
    try {
      current.value = await api.getRequest(id);
    } catch {
      current.value = null;
    } finally {
      loading.value = false;
    }
    return current.value;
  };

  const accept = async (id: string) => {
    current.value = await api.acceptRequest(id);
  };

  const reject = async (id: string) => {
    current.value = await api.rejectRequest(id);
  };

  const revise = async (id: string, reasons: RevisionReason[]) => {
    current.value = await api.reviseRequest(id, reasons);
  };

  const confirm = async (id: string) => {
    current.value = await api.confirmRequest(id);
  };

  const undo = async (id: string) => {
    current.value = await api.undoRequest(id);
  };

  const redeem = async (token: string) => {
    current.value = await api.redeemQr(token, elderId.value);
    return current.value;
  };

  const loadDelegations = async () => {
    delegations.value = await api.listDelegations(elderId.value);
  };

  return {
    elderId,
    pending,
    current,
    delegations,
    loading,
    loadPending,
    loadRequest,
    accept,
    reject,
    revise,
    confirm,
    undo,
    redeem,
    loadDelegations
  };
});
