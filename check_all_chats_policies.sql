-- Verifica TUTTE le policy sulla tabella chats
SELECT
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'chats'
ORDER BY cmd, policyname;
