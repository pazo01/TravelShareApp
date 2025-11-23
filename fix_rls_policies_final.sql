-- SOLUZIONE DEFINITIVA: Usa funzioni helper per evitare ricorsione RLS
-- Simile a can_user_access_group che hai già
-- Esegui questo script su Supabase

-- 1. Crea funzione helper per verificare accesso chat
-- Questa funzione bypassa le policy RLS usando SECURITY DEFINER
CREATE OR REPLACE FUNCTION can_user_access_chat(_chat_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verifica se l'utente corrente è membro della chat
  RETURN EXISTS (
    SELECT 1
    FROM chat_members
    WHERE chat_id = _chat_id
    AND user_id = auth.uid()
  );
END;
$$;

-- 2. RIMUOVI tutte le policy esistenti per evitare conflitti
DROP POLICY IF EXISTS "Users can view chats they are members of" ON chats;
DROP POLICY IF EXISTS "Users can view their chats" ON chats;
DROP POLICY IF EXISTS "Users can view chat members" ON chat_members;
DROP POLICY IF EXISTS "Users can view members of their chats" ON chat_members;
DROP POLICY IF EXISTS "Service can insert chat members" ON chat_members;
DROP POLICY IF EXISTS "Authenticated users can join chats" ON chat_members;
DROP POLICY IF EXISTS "Users can view messages in their chats" ON messages;
DROP POLICY IF EXISTS "Users can view their group or chat messages" ON messages;
DROP POLICY IF EXISTS "Users can insert messages in their chats" ON messages;
DROP POLICY IF EXISTS "Users can send messages to their chats or groups" ON messages;

-- 3. CREA policy SEMPLICI usando la funzione helper

-- Policy per chats (SELECT)
CREATE POLICY "Users can view their chats"
ON chats FOR SELECT
USING (can_user_access_chat(id));

-- Policy per chat_members (SELECT) - usa DIRETTAMENTE user_id, NO subquery
CREATE POLICY "Users can view chat members"
ON chat_members FOR SELECT
USING (
  -- L'utente può vedere se stesso
  user_id = auth.uid()
  OR
  -- O se può accedere alla chat (usa funzione helper)
  can_user_access_chat(chat_id)
);

-- Policy per chat_members (INSERT) - semplice
CREATE POLICY "Anyone authenticated can join chats"
ON chat_members FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Policy per messages (SELECT)
CREATE POLICY "Users can view chat or group messages"
ON messages FOR SELECT
USING (
  -- Messaggi nelle chat accessibili
  (chat_id IS NOT NULL AND can_user_access_chat(chat_id))
  OR
  -- Messaggi nei gruppi accessibili (se hai can_user_access_group)
  (group_id IS NOT NULL AND can_user_access_group(group_id))
);

-- Policy per messages (INSERT)
CREATE POLICY "Users can send messages"
ON messages FOR INSERT
WITH CHECK (
  -- Deve essere il mittente
  user_id = auth.uid()
  AND
  (
    -- E deve avere accesso alla chat o al gruppo
    (chat_id IS NOT NULL AND can_user_access_chat(chat_id))
    OR
    (group_id IS NOT NULL AND can_user_access_group(group_id))
  )
);

-- 4. GRANT permessi sulla funzione
GRANT EXECUTE ON FUNCTION can_user_access_chat(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION can_user_access_chat(uuid) TO anon;

-- 5. Verifica finale
DO $$
BEGIN
  RAISE NOTICE '✅✅✅ Policy RLS DEFINITIVE installate!';
  RAISE NOTICE 'Usa funzione can_user_access_chat per evitare ricorsione';
  RAISE NOTICE 'Nessuna subquery ricorsiva nelle policy';
END $$;
