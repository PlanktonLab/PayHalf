<!--
協辦 (Assisted Application) — 協助者:幫長輩填好資料並產生一次性 QR。
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
import { computed, nextTick, onUnmounted, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import QrcodeVue from 'qrcode.vue';
import BaseButton from '@/components/atoms/BaseButton.vue';
import BaseCheckbox from '@/components/atoms/BaseCheckbox.vue';
import BaseInput from '@/components/atoms/BaseInput.vue';
import AssistRequiredLabel from '@/components/atoms/AssistRequiredLabel.vue';
import { LANG_OPTIONS, useAssistI18n } from '@/assist/i18n';
import type { MessageKey } from '@/assist/i18n';
import { buildQrPayload, createHelperRequest } from '@/assist/api';
import { useAssistStore } from '@/stores/assist';
import type { AssistField, AssistRequest, FieldKey, HelperType, Lang } from '@/assist/types';

const router = useRouter();
const store = useAssistStore();
const { t } = useAssistI18n();

const roleOptions: Exclude<HelperType, 'CS_1999'>[] = ['FAMILY', 'VILLAGE_CHIEF', 'CAREGIVER'];
const role = ref<Exclude<HelperType, 'CS_1999'>>('FAMILY');
const helperName = ref('');
const elderLang = ref<Lang>('zh-Hant');
const consent = ref<string[]>([]);

const fieldKeys: FieldKey[] = ['name', 'idNumber', 'birthday', 'bank', 'account'];
const form = reactive<Record<FieldKey, string>>({
  name: '',
  idNumber: '',
  birthday: '',
  bank: '',
  account: ''
});

const showInvalid = ref(false);
const created = ref<AssistRequest | null>(null);
const payload = ref('');
const secondsLeft = ref(0);
let timer: ReturnType<typeof setInterval> | undefined;

/** 身分證字號只在長輩端顯示遮罩後的版本 */
const maskId = (value: string) =>
  value.length > 6 ? `${value.slice(0, 3)}****${value.slice(-3)}` : value;

const fillSample = () => {
  helperName.value = helperName.value || '王小明(示範)';
  form.name = '王大明';
  form.idNumber = 'A123456789';
  form.birthday = '民國 40 年 5 月 3 日';
  form.bank = '範例銀行 中山分行';
  form.account = '000-123-456789';
};

const nameMissing = computed(() => String(helperName.value ?? '').trim() === '');
const fieldMissing = (key: FieldKey) => String(form[key] ?? '').trim() === '';
const consentMissing = computed(() => consent.value.length === 0);

/** 還沒填的必填項目數量 */
const missingCount = computed(
  () =>
    (nameMissing.value ? 1 : 0) +
    fieldKeys.filter((key) => fieldMissing(key)).length +
    (consentMissing.value ? 1 : 0)
);
const isValid = computed(() => missingCount.value === 0);

const tick = () => {
  if (!created.value) return;
  const left = Math.ceil((new Date(created.value.expiresAt).getTime() - Date.now()) / 1000);
  secondsLeft.value = Math.max(0, left);
  if (secondsLeft.value === 0 && timer) {
    clearInterval(timer);
    timer = undefined;
  }
};

const onGenerate = async () => {
  showInvalid.value = true;
  if (!isValid.value) {
    // 捲到第一個沒填的必填項目,並把游標移過去
    await nextTick();
    const first = document.querySelector<HTMLElement>(
      '[aria-invalid="true"], #consent-row[data-invalid="true"]'
    );
    first?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    first?.focus();
    return;
  }
  const fields: AssistField[] = fieldKeys.map((key) => ({
    key,
    value: key === 'idNumber' ? maskId(form[key].trim()) : form[key].trim()
  }));
  const request = await createHelperRequest({
    elderId: store.elderId,
    helperType: role.value,
    helperName: String(helperName.value).trim(),
    elderLang: elderLang.value,
    serviceId: 'elderBonus',
    fields
  });
  created.value = request;
  payload.value = buildQrPayload(request.token ?? '');
  tick();
  if (timer) clearInterval(timer);
  timer = setInterval(tick, 500);
};

const onAgain = () => {
  if (timer) clearInterval(timer);
  created.value = null;
  payload.value = '';
};

onUnmounted(() => {
  if (timer) clearInterval(timer);
});

const countdown = computed(() =>
  t('help.expiresIn', {
    m: Math.floor(secondsLeft.value / 60),
    s: String(secondsLeft.value % 60).padStart(2, '0')
  })
);

// 開發測試:直接以長輩身分打開這個 QR
const isDev = import.meta.env.DEV;
const openAsElder = () => {
  router.push({ name: 'assist-scan', query: { payload: payload.value } });
};
</script>

<template>
  <main class="px-4 pb-10 pt-4">
    <h1 class="text-2xl font-bold text-[#5AB4C5]">{{ t('help.title') }}</h1>

    <!-- 已產生 QR -->
    <section v-if="created" class="mt-4 rounded bg-white p-6 text-center shadow-card">
      <h2 class="text-xl font-bold text-grey-900">{{ t('help.qrTitle') }}</h2>
      <div v-if="secondsLeft > 0" class="mt-4 flex justify-center">
        <QrcodeVue :value="payload" :size="220" level="M" />
      </div>
      <p v-if="secondsLeft > 0" class="mt-4 text-2xl font-bold text-primary-700">{{ countdown }}</p>
      <p v-else class="mt-4 text-xl font-bold text-warn-200">{{ t('help.expired') }}</p>
      <p class="mt-2 text-base text-grey-500">{{ t('help.qrHint') }}</p>

      <BaseButton outline class="mt-6 w-full !py-3 text-lg font-bold" @click="onAgain">
        {{ t('help.again') }}
      </BaseButton>
      <BaseButton v-if="isDev && secondsLeft > 0" class="mt-3 w-full !py-3" @click="openAsElder">
        (DEV) 以長輩身分打開
      </BaseButton>
    </section>

    <!-- 填寫表單 -->
    <section v-else class="mt-4 flex flex-col gap-y-5 rounded bg-white p-4 shadow-card">
      <p class="text-base text-grey-500">{{ t('help.requiredLegend') }}</p>

      <div>
        <p class="text-base text-grey-500">{{ t('help.service') }}</p>
        <p class="text-lg font-bold text-grey-900">{{ t('svc.elderBonus') }}</p>
      </div>

      <div>
        <p class="text-base text-grey-500">{{ t('help.who') }}</p>
        <div class="mt-2 flex flex-wrap gap-2">
          <button
            v-for="item in roleOptions"
            :key="item"
            type="button"
            class="assist-pill"
            :class="{ 'assist-pill--active': role === item }"
            :aria-pressed="role === item"
            @click="role = item"
          >
            {{ t(`helper.${item}` as MessageKey) }}
          </button>
        </div>
        <AssistRequiredLabel
          class="mt-3"
          for-id="helper-name"
          :label="t('help.yourName')"
          required
        />
        <BaseInput
          id="helper-name"
          v-model="helperName"
          class="mt-2 w-full text-lg"
          :class="{ 'base-input--warn': showInvalid && nameMissing }"
          aria-required="true"
          :aria-invalid="showInvalid && nameMissing"
        />
        <p v-if="showInvalid && nameMissing" class="mt-1 text-sm text-warn-200">
          {{ t('help.fillIn', { field: t('help.yourName') }) }}
        </p>
      </div>

      <div>
        <p class="text-base text-grey-500">{{ t('help.elderLang') }}</p>
        <div class="mt-2 flex flex-wrap gap-2">
          <button
            v-for="item in LANG_OPTIONS"
            :key="item.value"
            type="button"
            class="assist-pill"
            :class="{ 'assist-pill--active': elderLang === item.value }"
            :aria-pressed="elderLang === item.value"
            @click="elderLang = item.value"
          >
            {{ item.label }}
          </button>
        </div>
      </div>

      <div v-for="key in fieldKeys" :key="key">
        <AssistRequiredLabel
          :for-id="`help-${key}`"
          :label="t(`helpfield.${key}` as MessageKey)"
          required
        />
        <BaseInput
          :id="`help-${key}`"
          v-model="form[key]"
          class="mt-2 w-full text-lg"
          :class="{ 'base-input--warn': showInvalid && fieldMissing(key) }"
          aria-required="true"
          :aria-invalid="showInvalid && fieldMissing(key)"
        />
        <p v-if="showInvalid && fieldMissing(key)" class="mt-1 text-sm text-warn-200">
          {{ t('help.fillIn', { field: t(`helpfield.${key}` as MessageKey) }) }}
        </p>
      </div>

      <button
        type="button"
        class="text-left text-base text-primary-600 underline"
        @click="fillSample"
      >
        {{ t('help.sample') }}
      </button>

      <div id="consent-row" tabindex="-1" :data-invalid="showInvalid && consentMissing">
        <BaseCheckbox v-model="consent" :option="{ label: `${t('help.consent')} *`, value: 'Y' }" />
        <p v-if="showInvalid && consentMissing" class="mt-1 text-sm text-warn-200">
          {{ t('help.needConsent') }}
        </p>
      </div>

      <p
        v-if="showInvalid && !isValid"
        role="alert"
        class="rounded bg-secondary-50 p-3 text-lg font-bold text-warn-200"
      >
        {{ t('help.fixErrors', { n: missingCount }) }}
      </p>

      <BaseButton class="w-full !py-4 text-lg font-bold" @click="onGenerate">
        {{ t('help.generate') }}
      </BaseButton>
    </section>
  </main>
</template>
