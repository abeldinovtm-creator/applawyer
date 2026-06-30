# Applawyer — Маркетплейс юридических услуг

Платформа для поиска юристов в Казахстане. Клиенты находят специалистов, юристы получают заявки.

**Сайт:** https://applawyer.online  
**Стек:** Flutter Web + Supabase (PostgreSQL, Auth, RLS, Realtime, Edge Functions)  
**Деплой:** GitHub Pages, автодеплой через GitHub Actions при push в `main`

---

## Статус продукта — 30.06.2026

### ✅ Реализовано

**Авторизация**
- Регистрация, вход, восстановление пароля
- Роли: клиент / юрист (подтипы: юрист, адвокат, ЧСИ)
- AuthRouter — автоматическая навигация по роли после входа

**Клиент**
- Создание заявки (категория, регион, бюджет, тип услуги)
- Экран "Мои заявки" — список своих заявок, закрытие, удаление
- Просмотр откликов юристов, принятие / отклонение
- Чат с юристом (Supabase Realtime)

**Юрист**
- Дашборд — список заявок с фильтрами (категория, тип услуги, бюджет, регион)
- Фильтры сворачиваются / разворачиваются
- Вкладка "В работе" — принятые заявки, согласованная цена, переход в чат
- Отклик на заявку с ценой (предоплата / по завершении / по результату)
- Чекбокс "Принять цену клиента" — авто-заполнение из бюджета заявки
- Профиль (имя, город, опыт, описание, ИИН, предпочтительный язык)

**Локализация**
- 3 языка: казахский (KZ), русский (RU), английский (EN)
- Дефолтный язык — казахский
- Все экраны переведены, включая данные из БД (категории, регионы, типы услуг)
- Предпочтительный язык сохраняется в профиле — применяется автоматически при входе

**Инфраструктура**
- GitHub Actions — push в `main` = автодеплой за ~3 мин
- GitHub Secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- RLS настроен на всех таблицах
- Supabase Realtime для чата

---

### 🔧 Инфраструктура готова, требует активации

**Push-уведомления (FCM)**
- Код клиента: `lib/services/push_service.dart`, `lib/firebase_options.dart`
- Service Worker: `web/firebase-messaging-sw.js`
- Edge Function: `supabase/functions/send-push/index.ts`
- SQL-триггеры: `supabase/migrations/20260630_push_notifications.sql`
- Триггеры: новый отклик → клиенту; принята/отклонена → юристу; новое сообщение → собеседнику

**Для активации:**
1. Создать Firebase проект, заполнить `lib/firebase_options.dart` и `web/firebase-messaging-sw.js`
2. Добавить секрет `FIREBASE_SERVICE_ACCOUNT` в Supabase → Edge Functions → Secrets
3. Запустить миграцию в SQL Editor (заменить `ВАШ_SERVICE_ROLE_KEY` на ключ из Settings → API)
4. `supabase functions deploy send-push`

---

### 🔴 P0 — До публичного запуска

| # | Задача |
|---|--------|
| 1 | Активировать push-уведомления (Firebase + Vault миграция) |
| 2 | Счётчик 20 бесплатных контактов + блокировка "Откликнуться" при 0 |
| 3 | Экран подписки + оплата (Kaspi / CloudPayments) |
| 4 | Политика конфиденциальности + Пользовательское соглашение |

### 🟠 P1 — Доверие и конверсия

| # | Задача |
|---|--------|
| 5 | Фото юриста (аватар, Supabase Storage) |
| 6 | Верификация юриста — галочка "Проверен" (admin) |
| 7 | Email-уведомления как резерв для push |
| 8 | SMS-верификация номера телефона |

### 🟡 P2 — Улучшение продукта

| # | Задача |
|---|--------|
| 9  | Рейтинг и отзывы на юриста |
| 10 | Срочность и дедлайн на заявке |
| 11 | Онбординг для нового юриста |
| 12 | Регион в профиле клиента |

### ⚖️ Compliance

| Задача | Описание |
|--------|----------|
| Перенос БД на серверы в РК | Закон РК «О персональных данных» — персданные должны храниться в РК. Сейчас Supabase на AWS ap-northeast-1. |

---

## Разработка

```bash
# Локальный запуск
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xkxontehimricgmmkjbw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon_key>

# Деплой (автоматически при git push origin main)
git add . && git commit -m "feat: ..." && git push origin main
```

**Структура:**
```
lib/
  main.dart               # AuthRouter, инициализация
  *_screen.dart           # Экраны
  services/               # push_service.dart
  region_picker_screen.dart
  region_translations.dart
assets/translations/      # kk.json, ru.json, en.json
supabase/
  functions/send-push/    # Edge Function для FCM
  migrations/             # SQL-миграции
web/
  firebase-messaging-sw.js
  CNAME                   # applawyer.online
  404.html                # SPA-роутинг
```
