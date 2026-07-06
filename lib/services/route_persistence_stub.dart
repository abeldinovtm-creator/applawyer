// Заглушка для не-web платформ (android/ios/desktop) — сохранение
// последнего экрана нужно только в web (обновление страницы браузера).
String? getLastRoute() => null;
void setLastRoute(String? route) {}
