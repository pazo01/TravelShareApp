-- Schema per il sistema di chat con limite di 4 persone per gruppo
-- Esegui questo script nel SQL Editor di Supabase

-- Tabella per le chat (sia di gruppo che individuali)
CREATE TABLE IF NOT EXISTS chats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  is_group BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabella per i messaggi
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id UUID REFERENCES chats(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'text' CHECK (type IN ('text', 'image', 'file', 'system')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabella per i membri delle chat
CREATE TABLE IF NOT EXISTS chat_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id UUID REFERENCES chats(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(chat_id, user_id)
);

-- Aggiungi colonna chat_id alla tabella groups (se non esiste già)
ALTER TABLE groups
ADD COLUMN IF NOT EXISTS chat_id UUID REFERENCES chats(id) ON DELETE SET NULL;

-- Indici per performance
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_members_chat_id ON chat_members(chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_members_user_id ON chat_members(user_id);
CREATE INDEX IF NOT EXISTS idx_groups_chat_id ON groups(chat_id);

-- Trigger per aggiornare updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_chats_updated_at
BEFORE UPDATE ON chats
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_messages_updated_at
BEFORE UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- RLS (Row Level Security) Policies

-- Abilita RLS su tutte le tabelle
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_members ENABLE ROW LEVEL SECURITY;

-- Policy per chats: gli utenti possono vedere solo le chat di cui sono membri
CREATE POLICY "Users can view chats they are members of"
ON chats FOR SELECT
USING (
  id IN (
    SELECT chat_id FROM chat_members WHERE user_id = auth.uid()
  )
);

-- Policy per messages: gli utenti possono vedere messaggi delle loro chat
CREATE POLICY "Users can view messages in their chats"
ON messages FOR SELECT
USING (
  chat_id IN (
    SELECT chat_id FROM chat_members WHERE user_id = auth.uid()
  )
);

-- Policy per messages: gli utenti possono inserire messaggi nelle loro chat
CREATE POLICY "Users can insert messages in their chats"
ON messages FOR INSERT
WITH CHECK (
  chat_id IN (
    SELECT chat_id FROM chat_members WHERE user_id = auth.uid()
  )
  AND sender_id = auth.uid()
);

-- Policy per chat_members: gli utenti possono vedere i membri delle loro chat
CREATE POLICY "Users can view members of their chats"
ON chat_members FOR SELECT
USING (
  chat_id IN (
    SELECT chat_id FROM chat_members WHERE user_id = auth.uid()
  )
);

-- Policy per chat_members: solo il sistema può inserire membri (tramite service role)
CREATE POLICY "Service can insert chat members"
ON chat_members FOR INSERT
WITH CHECK (true);

-- Commenti per documentazione
COMMENT ON TABLE chats IS 'Tabella per le chat di gruppo e individuali. Massimo 4 membri per gruppo.';
COMMENT ON TABLE messages IS 'Messaggi inviati nelle chat. Supporta text, image, file, system.';
COMMENT ON TABLE chat_members IS 'Membri delle chat. Relazione many-to-many tra chat e utenti.';
COMMENT ON COLUMN groups.chat_id IS 'Riferimento alla chat associata al gruppo di viaggio.';
