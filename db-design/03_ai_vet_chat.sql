-- ================================================================
--  MODULE 3: AI Vet Chat          (paid core)
--  24/7 triage + "is this worth a vet visit?"
--
--  triage_rules run BEFORE the model and their text is shown to the
--  user verbatim. This is the highest-stakes table in the database.
-- ================================================================

CREATE TYPE triage_level  AS ENUM ('emergency', 'urgent', 'routine', 'info');
CREATE TYPE message_role  AS ENUM ('user', 'assistant');

-- ----------------------------------------------------------------
-- TRIAGE RULES  (reference; species array so a rule can cover both)
-- ----------------------------------------------------------------
CREATE TABLE triage_rules (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(40) NOT NULL UNIQUE,
    species_scope   species[]   NOT NULL,               -- {dog} | {cat} | {dog,cat}

    match_patterns  TEXT[]      NOT NULL,               -- lowercase substrings
    negate_patterns TEXT[]      NOT NULL DEFAULT '{}',  -- suppress false positives
    level           triage_level NOT NULL,
    breed_flags     TEXT[]      NOT NULL DEFAULT '{}',  -- matches breeds.risk_flags

    headline        VARCHAR(160),                       -- shown verbatim
    action_text     TEXT,                               -- shown verbatim
    llm_directive   TEXT,                               -- appended to the system prompt

    priority        SMALLINT    NOT NULL DEFAULT 100,   -- lower fires first
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,

    CONSTRAINT emergency_needs_text CHECK (
        level NOT IN ('emergency','urgent')
        OR (headline IS NOT NULL AND action_text IS NOT NULL)
    )
);

CREATE INDEX triage_priority_idx ON triage_rules(priority) WHERE is_active = TRUE;

-- ----------------------------------------------------------------
-- TOXIC ITEMS  (reference; the SAME item differs by species -
--               lilies are lethal to cats, mild for dogs)
-- ----------------------------------------------------------------
CREATE TABLE toxic_items (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    species             species     NOT NULL,
    slug                VARCHAR(60) NOT NULL,
    name                VARCHAR(120) NOT NULL,
    aliases             TEXT[]      NOT NULL DEFAULT '{}',
    agent               VARCHAR(60),                    -- theobromine, xylitol...

    toxic_dose_mg_kg    NUMERIC(10,3),                  -- null = any amount is a concern
    severe_dose_mg_kg   NUMERIC(10,3),
    signs               TEXT[]      NOT NULL DEFAULT '{}',
    always_emergency    BOOLEAN     NOT NULL DEFAULT FALSE,
    notes               TEXT,

    vet_reviewed_at     TIMESTAMPTZ,                    -- gate release on this
    UNIQUE (species, slug)
);

-- ----------------------------------------------------------------
-- CHAT THREADS
-- ----------------------------------------------------------------
CREATE TABLE chat_threads (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(id),
    pet_id          UUID        REFERENCES pets(id) ON DELETE SET NULL,

    title           VARCHAR(150),
    level           triage_level,                       -- highest level reached
    summary         TEXT,                               -- so long threads stop resending history

    -- age, weight, breed and allergies AT THE TIME of the chat, so a
    -- report shared with a vet months later is still accurate
    pet_snapshot    JSONB       NOT NULL DEFAULT '{}',

    message_count   SMALLINT    NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX threads_user_idx      ON chat_threads(user_id, created_at DESC);
CREATE INDEX threads_emergency_idx ON chat_threads(created_at DESC) WHERE level = 'emergency';

-- ----------------------------------------------------------------
-- CHAT MESSAGES
-- ----------------------------------------------------------------
CREATE TABLE chat_messages (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id       UUID        NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
    role            message_role NOT NULL,
    content         TEXT        NOT NULL,
    photo_urls      TEXT[]      NOT NULL DEFAULT '{}',

    -- written from the deterministic gate, never from the model output
    matched_rules   TEXT[]      NOT NULL DEFAULT '{}',
    level           triage_level,

    was_helpful     BOOLEAN,                            -- thumbs up/down: how you find
                                                        -- out the gate got it wrong
    tokens_used     INT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX messages_thread_idx ON chat_messages(thread_id, created_at);
CREATE INDEX messages_bad_idx    ON chat_messages(created_at DESC) WHERE was_helpful = FALSE;

CREATE TRIGGER trg_threads_upd BEFORE UPDATE ON chat_threads
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- reference rows still waiting on clinical sign-off
CREATE VIEW toxins_pending_review AS
SELECT species, slug, name FROM toxic_items WHERE vet_reviewed_at IS NULL;
