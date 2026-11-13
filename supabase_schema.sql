-- ==============================================================================
-- SKEMA DATABASE SUPABASE: PUTAR JAJAN (MODE GRUP BERSAMA)
-- Skrip ini 100% AMAN & IDEMPOTEN (dapat dijalankan berulang kali tanpa error)
-- Jalankan di Supabase Dashboard -> SQL Editor -> Run
-- ==============================================================================

-- 1. Ekstensi UUID (biasanya sudah aktif di Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABEL: groups
CREATE TABLE IF NOT EXISTS public.groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    owner_uid TEXT NOT NULL,
    code VARCHAR(6) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    member_count INT DEFAULT 1,
    active_session JSONB DEFAULT NULL,
    wheel_slots JSONB DEFAULT NULL,
    budget_mode TEXT DEFAULT 'game',
    fixed_budget BIGINT DEFAULT 200000,
    spin_policy TEXT DEFAULT 'owner'
);

-- Kolom tambahan & migrasi jika tabel groups sudah ada sebelumnya
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS wheel_slots JSONB DEFAULT NULL;
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS budget_mode TEXT DEFAULT 'game';
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS fixed_budget BIGINT DEFAULT 200000;
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS spin_policy TEXT DEFAULT 'owner';

-- 3. TABEL: group_members
CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    gid TEXT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    uid TEXT NOT NULL,
    name TEXT NOT NULL,
    color_index INT DEFAULT 0,
    role TEXT DEFAULT 'member', -- 'owner' | 'member'
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NULL,
    CONSTRAINT unique_group_member UNIQUE (gid, uid)
);

-- Pastikan batasan UNIQUE (gid, uid) aktif dan bersihkan duplikasi jika tabel sudah ada sebelumnya
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unique_group_member'
  ) THEN
    DELETE FROM public.group_members a USING public.group_members b
    WHERE a.ctid < b.ctid AND a.gid = b.gid AND a.uid = b.uid;

    BEGIN
      ALTER TABLE public.group_members ADD CONSTRAINT unique_group_member UNIQUE (gid, uid);
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- 4. TABEL: group_notes (Append-Only)
CREATE TABLE IF NOT EXISTS public.group_notes (
    id TEXT PRIMARY KEY, -- Client-generated UUID (Idempoten)
    gid TEXT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL,
    author_uid TEXT NOT NULL,
    author_name TEXT NOT NULL,
    title TEXT NOT NULL,
    amount BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted BOOLEAN DEFAULT FALSE -- Tombstone
);

-- 5. TABEL: group_events (Log Aktivitas Immutable)
CREATE TABLE IF NOT EXISTS public.group_events (
    id TEXT PRIMARY KEY,
    gid TEXT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    session_id TEXT DEFAULT NULL,
    type TEXT NOT NULL, -- 'spin' | 'game_result' | 'expense' | 'expense_deleted' | 'member_join' | 'member_leave' | 'session_start' | 'session_end' | 'budget_changed'
    actor_uid TEXT NOT NULL,
    actor_name TEXT NOT NULL,
    summary TEXT,
    payload JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.group_events ADD COLUMN IF NOT EXISTS session_id TEXT DEFAULT NULL;

-- 5b. TABEL: group_sessions (Riwayat Sesi Date Grup - UPDATE 3B)
CREATE TABLE IF NOT EXISTS public.group_sessions (
    id TEXT PRIMARY KEY,
    gid TEXT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    started_by_uid TEXT NOT NULL,
    started_by_name TEXT NOT NULL,
    ended_at TIMESTAMPTZ DEFAULT NULL,
    ended_by_uid TEXT DEFAULT NULL,
    ended_by_name TEXT DEFAULT NULL,
    budget BIGINT NOT NULL DEFAULT 0,
    game TEXT NOT NULL DEFAULT 'wheel', -- 'wheel' | 'dice' | 'capsule' | 'envelope' | 'coin' | 'fixed'
    budget_by_uid TEXT NOT NULL DEFAULT '',
    budget_by_name TEXT NOT NULL DEFAULT '',
    detail JSONB DEFAULT NULL,
    status TEXT NOT NULL DEFAULT 'running', -- 'running' | 'lolos' | 'lewat'
    total_spent BIGINT NOT NULL DEFAULT 0
);

-- 6. TABEL: invite_codes
CREATE TABLE IF NOT EXISTS public.invite_codes (
    code VARCHAR(6) PRIMARY KEY,
    gid TEXT NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE
);

-- ==============================================================================
-- AKTIFKAN SUPABASE REALTIME REPLICATION (AMAN / IDEMPOTEN)
-- Mencegah error 42710 jika tabel sudah terdaftar di publikasi
-- ==============================================================================
ALTER TABLE public.groups REPLICA IDENTITY FULL;
ALTER TABLE public.group_members REPLICA IDENTITY FULL;
ALTER TABLE public.group_notes REPLICA IDENTITY FULL;
ALTER TABLE public.group_events REPLICA IDENTITY FULL;
ALTER TABLE public.group_sessions REPLICA IDENTITY FULL;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.groups;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_members;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_notes;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_events;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Buka akses untuk anon key dengan DROP IF EXISTS agar tidak bentrok
-- ==============================================================================
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon read/write group_sessions" ON public.group_sessions;
CREATE POLICY "Allow anon read/write group_sessions" ON public.group_sessions FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon read/write groups" ON public.groups;
CREATE POLICY "Allow anon read/write groups" ON public.groups FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon read/write group_members" ON public.group_members;
CREATE POLICY "Allow anon read/write group_members" ON public.group_members FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon read/write group_notes" ON public.group_notes;
CREATE POLICY "Allow anon read/write group_notes" ON public.group_notes FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon read/write group_events" ON public.group_events;
CREATE POLICY "Allow anon read/write group_events" ON public.group_events FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon read/write invite_codes" ON public.invite_codes;
CREATE POLICY "Allow anon read/write invite_codes" ON public.invite_codes FOR ALL USING (true) WITH CHECK (true);
