-- ================================================================
--  MODULE 2: Health Passport      (free basic, paid multi-pet)
--  Vaccines, vet visits, medications, weight, allergies
-- ================================================================

CREATE TYPE record_type AS ENUM (
    'vaccine', 'vet_visit', 'medication', 'weight', 'allergy', 'preventive'
);

-- ----------------------------------------------------------------
-- VACCINE TYPES  (reference; per species, drives due dates)
-- ----------------------------------------------------------------
CREATE TABLE vaccine_types (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    species             species     NOT NULL,
    code                VARCHAR(30) NOT NULL,
    name                VARCHAR(80) NOT NULL,
    is_core             BOOLEAN     NOT NULL DEFAULT FALSE,
    is_legally_required BOOLEAN     NOT NULL DEFAULT FALSE,   -- rabies varies by state

    -- young-animal series
    start_weeks         SMALLINT,
    dose_count          SMALLINT,
    interval_weeks      SMALLINT,
    final_min_weeks     SMALLINT,
    -- adult
    booster_months      SMALLINT,

    notes               TEXT,
    UNIQUE (species, code)
);

-- ----------------------------------------------------------------
-- HEALTH RECORDS
-- One table with a type discriminator instead of five tables. The
-- passport screen reads the whole history in a single query, and it
-- maps 1:1 onto a Firestore subcollection.
-- ----------------------------------------------------------------
CREATE TABLE health_records (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    type            record_type NOT NULL,

    title           VARCHAR(150) NOT NULL,          -- "Rabies", "Annual checkup", "Chicken"
    occurred_on     DATE        NOT NULL,
    due_on          DATE,                           -- next due; drives reminders

    -- type-specific, only the relevant ones are set
    vaccine_type_id UUID        REFERENCES vaccine_types(id),
    dose_number     SMALLINT,                       -- position in the puppy/kitten series
    weight_kg       NUMERIC(5,2),
    body_score      SMALLINT    CHECK (body_score BETWEEN 1 AND 9),
    dosage_text     VARCHAR(80),                    -- "1 tablet"
    frequency_text  VARCHAR(80),                    -- "twice daily"
    dose_times      TIME[]      NOT NULL DEFAULT '{}',  -- reminder times
    ends_on         DATE,                           -- medication course end
    clinic_name     VARCHAR(150),
    cost_amount     NUMERIC(10,2),
    notes           TEXT,
    attachment_urls TEXT[]      NOT NULL DEFAULT '{}',  -- lab reports, receipts

    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,   -- false = course finished
    created_by_id   UUID        NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX records_pet_idx    ON health_records(pet_id, occurred_on DESC);
CREATE INDEX records_type_idx   ON health_records(pet_id, type, occurred_on DESC);
CREATE INDEX records_due_idx    ON health_records(due_on) WHERE due_on IS NOT NULL;
CREATE INDEX records_weight_idx ON health_records(pet_id, occurred_on DESC) WHERE type = 'weight';

CREATE TRIGGER trg_records_upd BEFORE UPDATE ON health_records
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- latest weight per pet, for the nutrition calculator
CREATE VIEW latest_weights AS
SELECT DISTINCT ON (pet_id) pet_id, occurred_on, weight_kg, body_score
FROM health_records WHERE type = 'weight'
ORDER BY pet_id, occurred_on DESC;
