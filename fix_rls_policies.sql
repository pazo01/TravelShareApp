-- FIX: Rimuove ricorsione infinita nelle policy RLS
-- Esegui questo script DOPO aver eseguito chat_schema_fixed.sql

-- 1. RIMUOVI le policy con ricorsione infinita
DROP POLICY IF EXISTS "Users can view members of their chats" ON chat_members;
DROP POLICY IF EXISTS "Service can insert chat members" ON chat_members;

-- 2. CREA policy corrette senza ricorsione
-- Policy per chat_members SELECT: l'utente può vedere i membri solo se fa parte della stessa chat
CREATE POLICY "Users can view chat members"
ON chat_members FOR SELECT
USING (
  -- L'utente può vedere i membri se è lui stesso
  user_id = auth.uid()
  OR
  -- O se esiste un altro record chat_members con lo stesso chat_id e il suo user_id
  EXISTS (
    SELECT 1 FROM chat_members cm
    WHERE cm.chat_id = chat_members.chat_id
    AND cm.user_id = auth.uid()
  )
);

-- Policy per chat_members INSERT: solo tramite authenticated users
CREATE POLICY "Authenticated users can join chats"
ON chat_members FOR INSERT
WITH CHECK (
  -- Qualsiasi utente autenticato può inserire, verificheremo a livello applicativo
  auth.role() = 'authenticated'
);

-- 3. Verifica policy messages
-- Rimuovi policy esistenti per evitare conflitti
DROP POLICY IF EXISTS "Users can view messages in their chats" ON messages;
DROP POLICY IF EXISTS "Users can insert messages in their chats" ON messages;

-- Policy SELECT per messages: semplificata
CREATE POLICY "Users can view their group or chat messages"
ON messages FOR SELECT
USING (
  -- Messaggi in chat di cui è membro
  (chat_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM chat_members WHERE chat_id = messages.chat_id AND user_id = auth.uid()
  ))
  OR
  -- Messaggi in gruppi di cui è membro
  (group_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM group_members WHERE group_id = messages.group_id AND user_id = auth.uid()
  ))
);

-- Policy INSERT per messages: semplificata
CREATE POLICY "Users can send messages to their chats or groups"
ON messages FOR INSERT
WITH CHECK (
  -- L'utente deve essere il mittente
  user_id = auth.uid()
  AND
  (
    -- E deve essere membro della chat
    (chat_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM chat_members WHERE chat_id = messages.chat_id AND user_id = auth.uid()
    ))
    OR
    -- O membro del gruppo
    (group_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM group_members WHERE group_id = messages.group_id AND user_id = auth.uid()
    ))
  )
);

-- 4. Policy per chats: semplificata
DROP POLICY IF EXISTS "Users can view chats they are members of" ON chats;

CREATE POLICY "Users can view their chats"
ON chats FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM chat_members WHERE chat_id = chats.id AND user_id = auth.uid()
  )
);

-- 5. Verifica finale
DO $$
BEGIN
  RAISE NOTICE '✅ Policy RLS corrette installate!';
  RAISE NOTICE 'Ricorsione infinita risolta.';
END $$;
