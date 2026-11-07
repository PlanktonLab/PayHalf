# 承辦人表單後台 API 需求(給 Spring 後端)

> 草案,請與後端隊員對齊。欄位與前端 [index.html](index.html) 的資料結構一致。
> 示範資料全用假資料。

## 1. 角色與權限
| 角色 | 說明 | 可做 |
|---|---|---|
| STAFF | 局處承辦人 | 建立、編輯、發布、結束自己單位的表單;看自己單位的回覆 |
| ADMIN | 局處管理者 | 同上,並管理承辦人名單;(若需審核)核准發布 |
| 長輩端 / 協助者 | 民眾 | 只用「公開表單」與「送出回覆」介面 |

- 承辦人登入:建議接市府既有單一登入(SSO),不自建帳密。
- 每份表單綁定 `deptId`,承辦人只能操作所屬單位的表單。

## 2. 承辦人端 API(需登入)
| 方法 | 路徑 | 用途 |
|---|---|---|
| GET | /admin/forms?status=&q=&page= | 表單列表 |
| POST | /admin/forms | 建立表單(可帶 templateId) |
| GET | /admin/forms/{id} | 取得表單內容 |
| PUT | /admin/forms/{id} | 儲存整份表單(標題、說明、截止日、題目) |
| POST | /admin/forms/{id}/duplicate | 複製 |
| DELETE | /admin/forms/{id} | 刪除(有回覆者建議改為封存) |
| POST | /admin/forms/{id}/publish | 發布(後端再做一次易讀與欄位檢查) |
| POST | /admin/forms/{id}/close | 結束收件 |
| GET | /admin/form-templates | 範本清單 |
| GET | /admin/forms/{id}/responses?page= | 回覆列表(個資預設遮罩) |
| GET | /admin/forms/{id}/responses/export | 匯出 CSV(需權限、留稽核紀錄) |
| GET | /admin/forms/{id}/stats | 收件數、本人/協助比例 |

## 3. 民眾端 API(台北通 App 內)
| 方法 | 路徑 | 用途 |
|---|---|---|
| GET | /forms?status=open | 可填寫的表單列表 |
| GET | /forms/{id} | 取得題目(只回公開欄位) |
| POST | /forms/{id}/responses | 本人直接送出 |
| POST | /forms/{id}/assist-requests | 協助者代填,產生待長輩確認的請求(接 [長輩端畫面規格](../docs/長輩端畫面規格.md) 的 AssistRequest) |
| GET | /me/responses | 我送出過的紀錄與進度 |

協助辦理流程沿用既有 `/assist-requests/{id}/accept|reject|revise|confirm|undo`。
表單設定 `allowAssist=false` 時,後端要拒絕 `assist-requests`。

## 4. 資料結構(示意)
```
Form {
  id, deptId, title, desc, deadline, allowAssist,
  status: DRAFT | OPEN | CLOSED | ARCHIVED,
  version, updatedAt, updatedBy,
  fields: [Field]
}
Field {
  id, type: TEXT | TEXTAREA | RADIO | CHECKBOX | SELECT | DATE | NUMBER
          | PHONE | IDNO | ADDRESS | FILE | CONSENT,
  label, hint, placeholder, required, options: [string],
  sort
}
Response {
  id, formId, formVersion, elderId, submittedBy: SELF | FAMILY | VILLAGE_CHIEF | CAREGIVER | CS_1999,
  answers: { fieldId: value }, status, submittedAt
}
```

## 5. 後端要注意的事
- **表單版本化**:發布後再修改要產生新版本,舊回覆保留當時的題目,不然欄位對不上。
- **後端驗證**:必填、身分證字號格式(英文字母加 9 碼)、電話格式、檔案大小與類型,不能只靠前端。
- **個資**:身分證字號、電話、地址加密存放;承辦人畫面預設遮罩,看明碼要另外授權並留紀錄。
- **稽核紀錄**:建立、修改、發布、匯出、看明碼,都記錄誰、何時、做了什麼。
- **匯出**:限有權限者,檔案加註「含個資,請妥善保管」。
- **檔案上傳**:類型白名單、大小上限(前端示意為 10 MB)、病毒掃描。
- **易讀檢查**:規則清單(公文用語對照、字數上限)建議放後端設定檔,前後端共用,不要各寫一份。
- **不使用商用服務**:儲存、通知皆用市府自有或開源方案。

## 6. 優先順序
1. 表單 CRUD + 發布/結束(`/admin/forms*`)
2. 民眾取得表單與送出(`/forms*`)
3. 回覆列表與 CSV 匯出
4. 協助辦理串接 `assist-requests`
5. 版本化、稽核、範本、統計
