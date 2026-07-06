import 'dart:html' as html;

// Supabase при инициализации на web чистит hash из URL (проверяет, нет ли
// там токенов auth-колбэка) — поэтому хранить "текущий экран" в URL нельзя,
// он будет стёрт ещё до того, как Flutter успеет его прочитать при старте.
// Используем localStorage напрямую вместо URL.
const _key = 'app_last_route';

String? getLastRoute() => html.window.localStorage[_key];

void setLastRoute(String? route) {
  if (route == null) {
    html.window.localStorage.remove(_key);
  } else {
    html.window.localStorage[_key] = route;
  }
}
