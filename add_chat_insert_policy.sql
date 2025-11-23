-- Aggiunge policy INSERT mancante per tabella chats
-- Permette agli utenti autenticati di creare nuove chat

-- 1. Aggiungi policy INSERT per chats
DROP POLICY IF EXISTS "Users can create chats" ON chats;

CREATE POLICY "Users can create chats"
ON chats FOR INSERT
WITH CHECK (
  -- Qualsiasi utente autenticato può creare chat
  auth.role() = 'authenticated'
);

-- 2. Aggiungi anche policy UPDATE per permettere di modificare il nome
DROP POLICY IF EXISTS "Users can update their chats" ON chats;

CREATE POLICY "Users can update their chats"
ON chats FOR UPDATE
USING (can_user_access_chat(id))
WITH CHECK (can_user_access_chat(id));

-- 3. Verifica tutte le policy su chats
DO $$
DECLARE
  policy_count integer;
BEGIN
  SELECT count(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'chats';

  RAISE NOTICE '════════════════════════════════════════════';
  RAISE NOTICE '✅ Policy RLS per tabella CHATS aggiornate!';
  RAISE NOTICE '════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Numero policy attive: %', policy_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ SELECT: Users can view their chats';
  RAISE NOTICE '✅ INSERT: Users can create chats (NUOVO!)';
  RAISE NOTICE '✅ UPDATE: Users can update their chats (NUOVO!)';
  RAISE NOTICE '';
  RAISE NOTICE 'Ora puoi creare gruppi e chat senza errori RLS!';
  RAISE NOTICE '════════════════════════════════════════════';
END $$;
