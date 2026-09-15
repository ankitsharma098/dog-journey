-- ================================================================
--  MODULE 1: Breed Scanner        (free, 3 scans/day)
--  Photo -> breed mix + personality/health profile
-- ================================================================

CREATE TYPE scan_status AS ENUM ('pending', 'done', 'failed');

-- ----------------------------------------------------------------
-- SCANS
-- The result stays as JSONB rather than a separate results table:
-- it is always read whole, never queried by individual breed.
-- image_hash doubles as the cache key - a repeat scan of the same
-- photo reads the earlier row instead of calling the model again.
-- ----------------------------------------------------------------
CREATE TABLE scans (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(id),
    pet_id          UUID        REFERENCES pets(id) ON DELETE SET NULL,  -- null = a stranger's pet
    species         species     NOT NULL,

    photo_url       TEXT        NOT NULL,
    image_hash      CHAR(64)    NOT NULL,          -- sha256, cache key
    model_version   VARCHAR(30) NOT NULL,
    status          scan_status NOT NULL DEFAULT 'pending',

    -- [{breed_id, slug, name, pct, confidence}] ordered best first
    result          JSONB       NOT NULL DEFAULT '[]',
    species_matched BOOLEAN,                        -- false = photo was not a dog/cat
    from_cache      BOOLEAN     NOT NULL DEFAULT FALSE,
    error_code      VARCHAR(40),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX scans_user_idx  ON scans(user_id, created_at DESC);
CREATE INDEX scans_cache_idx ON scans(image_hash, model_version) WHERE status = 'done';
CREATE INDEX scans_pet_idx   ON scans(pet_id, created_at DESC);
