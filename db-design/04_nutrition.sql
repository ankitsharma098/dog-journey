-- ================================================================
--  MODULE 4: Nutrition & Care Planner    (paid)
--  Feeding guide by breed/size/age, treat counter, recall alerts
--
--  RER = 70 * (weight_kg ^ 0.75), then a life-stage factor.
--  Both formula constants live in app_config, not in a table.
-- ================================================================

CREATE TYPE food_safety   AS ENUM ('safe', 'caution', 'toxic');
CREATE TYPE log_category  AS ENUM ('meal', 'treat', 'human_food', 'toxic_alert');
CREATE TYPE plan_goal     AS ENUM ('maintain', 'lose', 'gain', 'growth');

-- ----------------------------------------------------------------
-- FOOD ITEMS  (reference; safety is per species)
-- ----------------------------------------------------------------
CREATE TABLE food_items (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    species         species     NOT NULL,
    slug            VARCHAR(80) NOT NULL,
    name            VARCHAR(120) NOT NULL,
    aliases         TEXT[]      NOT NULL DEFAULT '{}',

    kcal_per_100g   INT,
    kcal_per_unit   INT,
    unit_label      VARCHAR(30),                    -- "1 medium", "1 tbsp"

    safety          food_safety NOT NULL DEFAULT 'safe',
    toxic_item_id   UUID        REFERENCES toxic_items(id),
    prep_notes      TEXT,
    UNIQUE (species, slug)
);

-- ----------------------------------------------------------------
-- FEEDING PLANS
-- The inputs are stored, not just the output, because owners ask why
-- the number is what it is - and for weight loss the basis is the
-- TARGET weight, not the current one.
-- ----------------------------------------------------------------
CREATE TABLE feeding_plans (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id              UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    goal                plan_goal   NOT NULL DEFAULT 'maintain',

    basis_weight_kg     NUMERIC(5,2) NOT NULL,
    target_weight_kg    NUMERIC(5,2),
    mer_factor          NUMERIC(3,1) NOT NULL,
    daily_kcal          INT         NOT NULL,
    treat_budget_kcal   INT         NOT NULL,        -- the 10% rule

    -- [{label,time,kcal,grams,food}] - always read whole
    meals               JSONB       NOT NULL DEFAULT '[]',
    notes               TEXT,

    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    recalculate_after   DATE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX plans_one_active_uidx ON feeding_plans(pet_id) WHERE is_active = TRUE;

-- ----------------------------------------------------------------
-- FOOD LOGS  (the treat counter)
-- ----------------------------------------------------------------
CREATE TABLE food_logs (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    food_item_id    UUID        REFERENCES food_items(id),
    item_text       VARCHAR(150) NOT NULL,
    category        log_category NOT NULL DEFAULT 'meal',
    kcal            INT,
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    logged_by_id    UUID        NOT NULL REFERENCES users(id)
);

CREATE INDEX food_logs_pet_idx ON food_logs(pet_id, logged_at DESC);

-- ----------------------------------------------------------------
-- RECALLS  (polled from the FDA feed; global, read-only to the app)
-- ----------------------------------------------------------------
CREATE TABLE recalls (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    species_scope   species[]   NOT NULL,
    external_id     VARCHAR(80) NOT NULL UNIQUE,    -- dedupe key: always upsert on this
    brand           VARCHAR(120) NOT NULL,
    product         VARCHAR(200) NOT NULL,
    reason          TEXT,
    lot_codes       TEXT[]      NOT NULL DEFAULT '{}',
    published_on    DATE        NOT NULL,
    source_url      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX recalls_published_idx ON recalls(published_on DESC);

CREATE TRIGGER trg_plans_upd BEFORE UPDATE ON feeding_plans
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- today's intake against the plan
CREATE VIEW daily_intake AS
SELECT pet_id, DATE(logged_at) AS day,
       SUM(kcal)                                                   AS total_kcal,
       SUM(kcal) FILTER (WHERE category IN ('treat','human_food')) AS treat_kcal
FROM food_logs
GROUP BY pet_id, DATE(logged_at);
