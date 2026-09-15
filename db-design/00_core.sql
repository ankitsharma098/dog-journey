-- ================================================================
--  PETJOURNEY  ::  00_core.sql
--  Single database. Species-agnostic.
--
--  The SAME schema runs the dog app and the cat app. Only the
--  reference rows differ (breeds, vaccines, foods, toxins, triage).
--  app_config.active_species decides which app this deployment is.
--
--  Auth is Firebase (email sign-in). No sessions, no OTP, no
--  refresh tokens, no devices table - Firebase owns all of that.
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------
-- ENUMS
-- ----------------------------------------------------------------
CREATE TYPE species     AS ENUM ('dog', 'cat');
CREATE TYPE pet_sex     AS ENUM ('male', 'female', 'unknown');
CREATE TYPE size_class  AS ENUM ('small', 'medium', 'large');
CREATE TYPE member_role AS ENUM ('owner', 'member');
CREATE TYPE plan_tier   AS ENUM ('free', 'premium');
CREATE TYPE unit_system AS ENUM ('metric', 'imperial');

-- ----------------------------------------------------------------
-- APP CONFIG
-- Server-side settings so a change is not an app release: the vet
-- chat system prompt, the Gemini model name, the calorie factors,
-- reminder offsets, and which species this deployment serves.
-- ----------------------------------------------------------------
CREATE TABLE app_config (
    key         VARCHAR(60)  PRIMARY KEY,
    value       JSONB        NOT NULL,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
-- expected keys: active_species, ai_model, vet_chat_prompt,
--                mer_factors, reminder_offsets, free_scan_limit

-- ----------------------------------------------------------------
-- USERS  (mirror of the Firebase user; Firebase is the source of truth)
-- ----------------------------------------------------------------
CREATE TABLE users (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid    VARCHAR(128) NOT NULL UNIQUE,
    email           VARCHAR(255) NOT NULL,
    display_name    VARCHAR(150),
    photo_url       TEXT,

    locale          VARCHAR(10) NOT NULL DEFAULT 'en-US',
    timezone        VARCHAR(50) NOT NULL DEFAULT 'America/New_York',
    units           unit_system NOT NULL DEFAULT 'imperial',

    -- denormalised so the paywall never needs a join
    tier            plan_tier   NOT NULL DEFAULT 'free',
    tier_expires_at TIMESTAMPTZ,

    fcm_token       TEXT,
    onboarding_done BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

-- ----------------------------------------------------------------
-- BREEDS  (reference; one row set per species)
-- ----------------------------------------------------------------
CREATE TABLE breeds (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    species         species     NOT NULL,
    slug            VARCHAR(60) NOT NULL,
    name            VARCHAR(100) NOT NULL,
    size_class      size_class  NOT NULL DEFAULT 'medium',

    weight_kg_min   NUMERIC(5,2),
    weight_kg_max   NUMERIC(5,2),
    lifespan_years  NUMERIC(4,1),

    -- free-form so a new species needs no schema change:
    -- dogs use brachycephalic|deep_chested|long_backed,
    -- cats use brachycephalic|flat_faced|long_haired
    risk_flags      TEXT[]      NOT NULL DEFAULT '{}',

    traits          JSONB       NOT NULL DEFAULT '{}',  -- {energy,shedding,...} 1-5
    health_risks    JSONB       NOT NULL DEFAULT '[]',  -- [{condition,severity,screen}]
    care_guide      JSONB       NOT NULL DEFAULT '{}',  -- {feeding,exercise,grooming}

    is_mixed        BOOLEAN     NOT NULL DEFAULT FALSE, -- the "Mixed Breed" row
    UNIQUE (species, slug)
);

CREATE INDEX breeds_species_idx ON breeds(species);

-- ----------------------------------------------------------------
-- PETS
-- ----------------------------------------------------------------
CREATE TABLE pets (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id        UUID        NOT NULL REFERENCES users(id),
    species         species     NOT NULL,
    name            VARCHAR(100) NOT NULL,
    sex             pet_sex     NOT NULL DEFAULT 'unknown',

    birthdate       DATE,
    birthdate_is_estimate BOOLEAN NOT NULL DEFAULT FALSE,  -- rescues rarely know
    adopted_date    DATE,
    is_neutered     BOOLEAN,
    photo_url       TEXT,

    -- denormalised: read on nearly every screen
    breed_id        UUID        REFERENCES breeds(id),
    breed_mix       JSONB       NOT NULL DEFAULT '[]',   -- [{breed_id,name,pct}]
    weight_kg       NUMERIC(5,2),
    allergies       TEXT[]      NOT NULL DEFAULT '{}',

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX pets_owner_idx ON pets(owner_id) WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------
-- PET MEMBERS  (household sharing - a paid feature)
-- ----------------------------------------------------------------
CREATE TABLE pet_members (
    pet_id      UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role        member_role NOT NULL DEFAULT 'member',
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (pet_id, user_id)
);

CREATE INDEX pet_members_user_idx ON pet_members(user_id);

-- ----------------------------------------------------------------
-- TRIGGERS
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

CREATE TRIGGER trg_users_upd BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_pets_upd  BEFORE UPDATE ON pets  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- every pet a user can see, owned or shared
CREATE VIEW user_pets AS
SELECT m.user_id, m.role, p.*
FROM pets p
JOIN pet_members m ON m.pet_id = p.id
WHERE p.deleted_at IS NULL;
