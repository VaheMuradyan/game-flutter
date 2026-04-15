-- admin_panel.sql
-- Apply-once script. Adds is_admin to users, creates the audit log table,
-- and adds created_at indexes used by the admin keyset pagination.
--
-- Apply with:
--   psql "postgresql://pixelmatch:pixelmatch_secret_2024@localhost:5432/pixelmatch" \
--     -f pixelmatch-server/database/schema/admin_panel.sql

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS admin_audit_log (
    id          BIGSERIAL PRIMARY KEY,
    actor_uid   TEXT NOT NULL,
    action      TEXT NOT NULL,
    target_uid  TEXT,
    path        TEXT NOT NULL,
    ip          TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_created_at    ON users    (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_matches_created_at  ON matches  (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_battles_created_at  ON battles  (created_at DESC);
