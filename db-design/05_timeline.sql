-- ================================================================
--  MODULE 5: Memory Timeline
--  Photo diary, gotcha day, growth milestones, shareable cards
-- ================================================================

CREATE TYPE entry_type AS ENUM (
    'photo', 'milestone', 'gotcha_day', 'birthday', 'first', 'note'
);

-- ----------------------------------------------------------------
-- MILESTONE TEMPLATES  (reference; per species, drives auto-entries
--  so the timeline is never empty on day one)
-- ----------------------------------------------------------------
CREATE TABLE milestone_templates (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    species         species     NOT NULL,
    code            VARCHAR(40) NOT NULL,
    entry_type      entry_type  NOT NULL,
    title           VARCHAR(150) NOT NULL,
    body_template   TEXT,                            -- {{pet_name}}, {{age_text}}

    age_days        INT,                             -- null = anniversary or manual
    is_anniversary  BOOLEAN     NOT NULL DEFAULT FALSE,
    size_classes    TEXT[]      NOT NULL DEFAULT '{}',  -- empty = all sizes
    sort_order      SMALLINT    NOT NULL DEFAULT 100,
    UNIQUE (species, code)
);

-- ----------------------------------------------------------------
-- TIMELINE ENTRIES
-- Photos are inline JSONB. Each entry has at most a handful, they
-- are always read with the entry, and `storage` is what makes cloud
-- backup a sellable feature: free keeps them on the device.
--   [{storage:'device'|'cloud', local_ref, url, thumb_url}]
-- ----------------------------------------------------------------
CREATE TABLE timeline_entries (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    template_id     UUID        REFERENCES milestone_templates(id),

    entry_type      entry_type  NOT NULL DEFAULT 'photo',
    title           VARCHAR(150),
    body            TEXT,
    entry_date      DATE        NOT NULL,
    photos          JSONB       NOT NULL DEFAULT '[]',

    is_auto_created BOOLEAN     NOT NULL DEFAULT FALSE,  -- back-filled from birthdate
    share_count     INT         NOT NULL DEFAULT 0,

    created_by_id   UUID        NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX entries_pet_idx    ON timeline_entries(pet_id, entry_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX entries_future_idx ON timeline_entries(entry_date) WHERE is_auto_created = TRUE;

CREATE TRIGGER trg_entries_upd BEFORE UPDATE ON timeline_entries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
