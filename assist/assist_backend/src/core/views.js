import { findService, allFields } from '../data/services.js';
import { findUser, publicHelper } from '../data/users.js';

/**
 * 同一個 session 對不同角色輸出不同的「視圖」。
 * 這裡是「協助者永遠看不到長輩個資」的唯一出口，測試會直接檢查。
 */
function commonView(s) {
  const service = findService(s.serviceId);
  return {
    id: s.id,
    serviceId: s.serviceId,
    serviceTitle: service.title,
    status: s.status,
    phase: s.phase,
    method: s.method,
    createdAt: s.createdAt,
    expiresAt: s.expiresAt,
    startedAt: s.startedAt,
    endedAt: s.endedAt,
    endReason: s.endReason,
    endedBy: s.endedBy,
    currentStep: s.currentStep,
    stepCount: service.steps.length,
    focusField: s.focusField,
    pendingAuth: s.pendingAuth,
    caseNo: s.caseNo,
    undoUntil: s.undoUntil ?? null,
    lastActivityAt: s.lastActivityAt,
    timeline: s.timeline.map((t) => ({ ...t })),
  };
}

export function helperView(s, { maxFieldRequests }) {
  const service = findService(s.serviceId);
  const fields = {};
  for (const f of allFields(service)) {
    const st = s.fields[f.key];
    fields[f.key] = {
      status: st.status,
      // 只有非敏感欄位（長輩自己點選的選項）才讓協助者看到值
      value: f.sensitive ? null : st.value,
      requestCount: st.requestCount,
      remainingRequests: f.sensitive ? Math.max(0, maxFieldRequests - st.requestCount) : null,
    };
  }
  return {
    ...commonView(s),
    viewer: 'helper',
    elder: { displayName: s.elderLabel },
    fields,
  };
}

export function elderView(s) {
  const service = findService(s.serviceId);
  const helper = findUser(s.helperId);
  const fields = {};
  for (const f of allFields(service)) {
    const st = s.fields[f.key];
    fields[f.key] = { status: st.status, value: st.value, requestCount: st.requestCount };
  }
  const pendingField = s.pendingAuth ? allFields(service).find((f) => f.key === s.pendingAuth) : null;
  return {
    ...commonView(s),
    viewer: 'elder',
    helper: publicHelper(helper),
    agency: service.agency,
    legalBasis: service.legalBasis,
    fields,
    pendingAuthField: pendingField
      ? {
          ...pendingField,
          // 長輩看的是自己的資料，直接帶出要提供的值讓長輩核對
          value: findUser(s.elderId).profile[pendingField.profileKey],
        }
      : null,
  };
}
