-- Фото профиля: колонка avatar_url + Storage bucket "avatars" + RLS
-- Применить в: Supabase Dashboard → SQL Editor
-- (миграция не применяется автоматически, применить вручную и проверить перед прод-раскаткой)

-- 1. Колонка для ссылки на аватар
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Bucket для аватаров (публичный на чтение — для getPublicUrl() на клиенте)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 3. RLS: любой может читать аватары (bucket публичный),
--    но загружать/обновлять/удалять можно только свой файл
--    (имя файла = ${auth.uid()}.jpg, см. profile_screen.dart)
-- DROP POLICY IF EXISTS — чтобы миграцию можно было безопасно перезапускать,
-- если предыдущий прогон прервался на середине (SQL Editor коммитит по стейтменту).
DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_owner_insert" ON storage.objects;
CREATE POLICY "avatars_owner_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.filename(name)) = auth.uid()::text || '.jpg'
  );

DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
CREATE POLICY "avatars_owner_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND (storage.filename(name)) = auth.uid()::text || '.jpg'
  );

DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;
CREATE POLICY "avatars_owner_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND (storage.filename(name)) = auth.uid()::text || '.jpg'
  );
