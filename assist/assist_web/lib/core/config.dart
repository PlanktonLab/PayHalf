/// 後端位址：
///   1. 網址帶 ?api=http://host:port 時優先使用
///   2. 編譯時 --dart-define=API_BASE=...
///   3. 預設與網頁同源（由後端直接提供 build 後的網頁）
String resolveApiBase() {
  final fromQuery = Uri.base.queryParameters['api'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  const fromDefine = String.fromEnvironment('API_BASE');
  if (fromDefine.isNotEmpty) return fromDefine;
  return Uri.base.origin;
}
