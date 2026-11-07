/**
 * 可協辦的業務與表單定義（資料驅動）。
 * 法令依據與保存期限為 Demo 示意，正式上線前須由主管機關確認。
 *
 * field.type:
 *   profile — 來自長輩實名帳號的個資，必須長輩逐項授權，協助者永遠看不到值
 *   choice  — 非敏感的選項，由長輩本人在手機上點選，協助者可看到選了什麼
 */
const SENIOR_CARD_AGENCY = '臺北市政府社會局';
const SENIOR_CARD_RETENTION = '申辦完成後保存 5 年（Demo 示意）';

export const SERVICES = [
  {
    id: 'senior-card',
    title: '敬老卡申請',
    category: '社會福利',
    summary: '年滿 65 歲且設籍臺北市的長輩，可申請敬老卡，搭乘公車、捷運享有優惠。',
    agency: SENIOR_CARD_AGENCY,
    legalBasis: '老人福利法、臺北市敬老卡相關規定（Demo 示意）',
    estMinutes: 8,
    steps: [
      {
        id: 'intro',
        title: '申辦說明',
        elderGuide: '這次要幫您申請「敬老卡」。辦好之後，搭公車、捷運都有優惠。',
        helperScript: '先口頭確認長輩年滿 65 歲、戶籍在臺北市。確認後按「下一步」。',
        fields: [],
      },
      {
        id: 'identity',
        title: '確認身分',
        elderGuide: '接下來需要您的基本資料。手機會一項一項問您，您同意才會提供。',
        helperScript: '依序按「請長輩授權」。請長輩自己看清楚手機畫面再按，不要替長輩按。',
        fields: [
          {
            key: 'realName',
            label: '姓名',
            type: 'profile',
            profileKey: 'realName',
            required: true,
            riskLevel: 'medium',
            purpose: '確認申請人是您本人',
            risks: ['姓名會印在敬老卡上'],
          },
          {
            key: 'birthday',
            label: '出生日期',
            type: 'profile',
            profileKey: 'birthday',
            required: true,
            riskLevel: 'medium',
            purpose: '確認您已年滿 65 歲',
            risks: ['出生日期常被拿來核對身分，請只提供給您信任的申請'],
          },
          {
            key: 'idNo',
            label: '身分證字號',
            type: 'profile',
            profileKey: 'idNo',
            required: true,
            riskLevel: 'high',
            purpose: '核對戶籍與申請資格，避免重複申請',
            risks: [
              '身分證字號可以拿來辦很多事，請確認是您自己要申請',
              '市府人員不會要求您把身分證字號唸給陌生人聽',
            ],
          },
        ],
      },
      {
        id: 'contact',
        title: '地址與電話',
        elderGuide: '敬老卡要寄到您家，需要您的戶籍地址和電話。',
        helperScript: '說明地址是用來寄卡片，電話是有問題時社會局聯絡用。',
        fields: [
          {
            key: 'residentAddress',
            label: '戶籍地址',
            type: 'profile',
            profileKey: 'residentAddress',
            required: true,
            riskLevel: 'high',
            purpose: '寄送敬老卡、確認設籍臺北市',
            risks: ['地址會讓人知道您住在哪裡，請確認這是您要申請的業務'],
          },
          {
            key: 'phone',
            label: '聯絡電話',
            type: 'profile',
            profileKey: 'phone',
            required: true,
            riskLevel: 'medium',
            purpose: '申請有問題時，社會局打電話給您',
            risks: ['之後若有人自稱社會局來電要求轉帳，那一定是詐騙'],
          },
        ],
      },
      {
        id: 'options',
        title: '領卡方式',
        elderGuide: '請您選擇要怎麼拿到敬老卡。',
        helperScript: '請長輩自己在手機上選。郵寄比較方便，臨櫃可以當場確認。',
        fields: [
          {
            key: 'pickup',
            label: '領卡方式',
            type: 'choice',
            required: true,
            options: [
              { value: 'mail', label: '郵寄到戶籍地址' },
              { value: 'office', label: '到區公所領取' },
            ],
          },
        ],
      },
      {
        id: 'review',
        title: '確認送出',
        elderGuide: '請您看一下資料對不對。確認沒問題，由您自己按「確認送出」。',
        helperScript: '按「請長輩確認送出」，長輩手機會顯示完整摘要。送出鍵只有長輩能按。',
        fields: [],
      },
    ],
  },
  {
    id: 'village-activity',
    title: '里民活動報名',
    category: '社區活動',
    summary: '正得里「重陽敬老餐會」線上報名，名額有限。',
    agency: '臺北市中山區正得里辦公處',
    legalBasis: '個人資料保護法第 15 條：執行法定職務必要範圍內（Demo 示意）',
    estMinutes: 4,
    retention: '活動結束後 3 個月內刪除（Demo 示意）',
    steps: [
      {
        id: 'intro',
        title: '活動說明',
        elderGuide: '重陽敬老餐會：11 月 20 日中午 12 點，在正得里活動中心。免費參加。',
        helperScript: '跟長輩說明時間地點，確認長輩想參加再繼續。',
        fields: [],
      },
      {
        id: 'applicant',
        title: '報名資料',
        elderGuide: '里辦公處需要知道是誰報名，以及怎麼聯絡您。',
        helperScript: '請長輩授權姓名與電話，兩項都會分開詢問。',
        fields: [
          {
            key: 'realName',
            label: '姓名',
            type: 'profile',
            profileKey: 'realName',
            required: true,
            riskLevel: 'medium',
            purpose: '報到時核對名單',
            risks: ['您的名字會出現在活動報到名單上'],
          },
          {
            key: 'phone',
            label: '聯絡電話',
            type: 'profile',
            profileKey: 'phone',
            required: true,
            riskLevel: 'medium',
            purpose: '活動異動時通知您',
            risks: ['之後若有人自稱里辦公處要求轉帳，那一定是詐騙'],
          },
        ],
      },
      {
        id: 'options',
        title: '餐點與接送',
        elderGuide: '請選擇餐點，以及需不需要有人去接您。',
        helperScript: '請長輩自己在手機上點選。',
        fields: [
          {
            key: 'meal',
            label: '餐點',
            type: 'choice',
            required: true,
            options: [
              { value: 'meat', label: '葷食' },
              { value: 'veg', label: '素食' },
            ],
          },
          {
            key: 'shuttle',
            label: '是否需要接送',
            type: 'choice',
            required: true,
            options: [
              { value: 'yes', label: '需要接送' },
              { value: 'no', label: '自己過去' },
            ],
          },
        ],
      },
      {
        id: 'review',
        title: '確認送出',
        elderGuide: '請您看一下資料對不對。確認沒問題，由您自己按「確認送出」。',
        helperScript: '按「請長輩確認送出」，送出鍵只有長輩能按。',
        fields: [],
      },
    ],
  },
];

// 補上每個敏感欄位的共通告知事項（個資法第 8 條）
for (const service of SERVICES) {
  for (const step of service.steps) {
    for (const field of step.fields) {
      field.sensitive = field.type === 'profile';
      if (field.sensitive) {
        field.recipient ??= service.agency;
        field.retention ??= service.retention ?? SENIOR_CARD_RETENTION;
        field.legalBasis ??= service.legalBasis;
      }
    }
  }
}

export function findService(id) {
  return SERVICES.find((s) => s.id === id) ?? null;
}

export function allFields(service) {
  return service.steps.flatMap((s) => s.fields);
}

/** 服務列表用的摘要（不含欄位細節）。 */
export function serviceSummary(s) {
  return {
    id: s.id,
    title: s.title,
    category: s.category,
    summary: s.summary,
    agency: s.agency,
    estMinutes: s.estMinutes,
    stepCount: s.steps.length,
    sensitiveFieldCount: allFields(s).filter((f) => f.sensitive).length,
  };
}
