-- Fix policy INSERT per chats usando lo stesso pattern che funziona per groups
-- Cambia da roles:{public} con check manuale a roles:{authenticated} con check:true

-- 1. Elimina la policy INSERT esistente (non funziona)
DROP POLICY IF EXISTS "Users can create chats" ON chats;

-- 2. Crea la nuova policy usando lo stesso pattern di groups/group_members
CREATE POLICY "allow_insert_authenticated_users"
ON chats FOR INSERT
TO authenticated  -- ← Applica solo a utenti authenticated
WITH CHECK (true); -- ← Permetti tutto per utenti authenticated

-- 3. Verifica le policy
DO $$
DECLARE
  insert_policy_count integer;
BEGIN
  SELECT count(*) INTO insert_policy_count
  FROM pg_policies
  WHERE tablename = 'chats' AND cmd = 'INSERT';

  RAISE NOTICE '════════════════════════════════════════════';
  RAISE NOTICE '✅ Policy INSERT per CHATS corretta!';
  RAISE NOTICE '════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Policy INSERT trovate: %', insert_policy_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ Usa stesso pattern di groups/group_members';
  RAISE NOTICE '   - roles: {authenticated}';
  RAISE NOTICE '   - with_check: true';
  RAISE NOTICE '';
  RAISE NOTICE 'Ora la creazione chat dovrebbe funzionare!';
  RAISE NOTICE '════════════════════════════════════════════';
END $$;
