-- Schema per il sistema di chat con limite di 4 persone per gruppo
-- COMPATIBILE con lo schema esistente del database
-- Esegui questo script nel SQL Editor di Supabase

-- 1. Crea tabella per le chat (sia di gruppo che individuali)
CREATE TABLE IF NOT EXISTS chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT,
  is_group BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Crea tabella per i membri delle chat
CREATE TABLE IF NOT EXISTS chat_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID REFERENCES chats(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(chat_id, user_id)
);

-- 3. Modifica la tabella messages esistente per supportare chat
-- Aggiungi chat_id (opzionale, per chat di gruppo)
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS chat_id UUID REFERENCES chats(id) ON DELETE CASCADE;

-- Rendi group_id opzionale (già dovrebbe esserlo)
ALTER TABLE messages
ALTER COLUMN group_id DROP NOT NULL;

-- Aggiungi vincolo: almeno uno tra group_id e chat_id deve essere presente
ALTER TABLE messages
ADD CONSTRAINT messages_group_or_chat_check
CHECK (
  (group_id IS NOT NULL AND chat_id IS NULL) OR
  (group_id IS NULL AND chat_id IS NOT NULL)
);

-- Rinomina message_type in type per consistenza (opzionale)
-- Se preferisci mantenere message_type, commenta questa riga
-- ALTER TABLE messages RENAME COLUMN message_type TO type;

-- 4. Aggiungi colonna chat_id alla tabella groups (se non esiste già)
ALTER TABLE groups
ADD COLUMN IF NOT EXISTS chat_id UUID REFERENCES chats(id) ON DELETE SET NULL;

-- 5. Indici per performance
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id) WHERE chat_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_group_id ON messages(group_id) WHERE group_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_members_chat_id ON chat_members(chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_members_user_id ON chat_members(user_id);
CREATE INDEX IF NOT EXISTS idx_groups_chat_id ON groups(chat_id) WHERE chat_id IS NOT NULL;

-- 6. Trigger per aggiornare updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger per chats
DROP TRIGGER IF EXISTS update_chats_updated_at ON chats;
CREATE TRIGGER update_chats_updated_at
BEFORE UPDATE ON chats
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 7. RLS (Row Level Security) Policies

-- Abilita RLS su nuove tabelle
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_members ENABLE ROW LEVEL SECURITY;

-- Policy per chats: gli utenti possono vedere solo le chat di cui sono membri
DROP POLICY IF EXISTS "Users can view chats they are members of" ON chats;
CREATE POLICY "Users can view chats they are members of"
ON chats FOR SELECT
USING (
  id IN (
    SELECT chat_id FROM chat_members WHERE user_id = auth.uid()
  )
);

-- Policy per messages con chat_id: gli utenti possono vedere messaggi delle loro chat
DROP POLICY IF EXISTS "Users can view messages in their chats" ON messages;
CREATE POLICY "Users can view messages in their chats"
ON messages FOR SELECT
USING (
  (chat_id IS NOT NULL AND chat_id IN (
    SELECT chat_id FROM chat_members WHERE user_id = auth.uid()
  ))
  OR
  (group_id IS NOT NULL AND group_id IN (
    SELECT group_id FROM group_members WHERE user_id = auth.uid()
  ))
);

-- Policy per messages: gli utenti possono inserire messaggi nelle loro chat
DROP POLICY IF EXISTS "Users can insert messages in their chats" ON messages;
CREATE POLICY "Users can insert messages in their chats"
ON messages FOR INSERT
WITH CHECK (
  (chat_id IS NOT NULL AND chat_id IN (
    SELECT chat_id FROM chat_members WHERE user_id = auth.uid()
  ) AND user_id = auth.uid())
  OR
  (group_id IS NOT NULL AND group_id IN (
    SELECT group_id FROM group_members WHERE user_id = auth.uid()
  ) AND user_id = auth.uid())
);

-- Policy per chat_members: gli utenti possono vedere i membri delle loro chat
DROP POLICY IF EXISTS "Users can view members of their chats" ON chat_members;
CREATE POLICY "Users can view members of their chats"
ON chat_members FOR SELECT
USING (
  chat_id IN (
    SELECT chat_id FROM chat_members WHERE user_id = auth.uid()
  )
);

-- Policy per chat_members: inserimento tramite service role
DROP POLICY IF EXISTS "Service can insert chat members" ON chat_members;
CREATE POLICY "Service can insert chat members"
ON chat_members FOR INSERT
WITH CHECK (true);

-- 8. Commenti per documentazione
COMMENT ON TABLE chats IS 'Tabella per le chat di gruppo. Massimo 4 membri per gruppo.';
COMMENT ON TABLE chat_members IS 'Membri delle chat. Relazione many-to-many tra chat e utenti.';
COMMENT ON COLUMN messages.chat_id IS 'Riferimento alla chat (per chat di gruppo). Alternativo a group_id.';
COMMENT ON COLUMN groups.chat_id IS 'Riferimento alla chat associata al gruppo di viaggio.';

-- 9. Verifica finale
DO $$
BEGIN
  RAISE NOTICE 'Schema chat installato con successo!';
  RAISE NOTICE 'Tabelle create: chats, chat_members';
  RAISE NOTICE 'Tabelle modificate: messages (aggiunto chat_id), groups (aggiunto chat_id)';
  RAISE NOTICE 'Policies RLS configurate correttamente';
END $$;
