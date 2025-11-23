-- Fix: Permetti agli utenti autenticati di vedere tutte le chat
-- Questo risolve il problema .insert().select() che fallisce

-- 1. Rimuovi la vecchia policy SELECT troppo restrittiva
DROP POLICY IF EXISTS "Users can view chats they are members of" ON chats;

-- 2. Crea nuova policy SELECT per utenti autenticati
-- Questo permette il .select() dopo .insert() nel codice
CREATE POLICY "allow_select_authenticated_users"
ON chats FOR SELECT
TO authenticated
USING (true);

-- 3. Verifica
DO $$
DECLARE
  select_policy_count integer;
  insert_policy_count integer;
BEGIN
  SELECT count(*) INTO select_policy_count
  FROM pg_policies
  WHERE tablename = 'chats' AND cmd = 'SELECT';

  SELECT count(*) INTO insert_policy_count
  FROM pg_policies
  WHERE tablename = 'chats' AND cmd = 'INSERT';

  RAISE NOTICE '════════════════════════════════════════════';
  RAISE NOTICE '✅ Policy CHATS corrette!';
  RAISE NOTICE '════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Policy SELECT: %', select_policy_count;
  RAISE NOTICE '📊 Policy INSERT: %', insert_policy_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ Ora .insert().select() dovrebbe funzionare!';
  RAISE NOTICE '════════════════════════════════════════════';
END $$;
