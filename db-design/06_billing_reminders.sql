-- ================================================================
--  Billing & Reminders
--  RevenueCat owns the receipts; this table is the webhook's landing
--  spot. users.tier is the denormalised copy the app actually reads.
--
--  No analytics table: Firebase Analytics handles events.
-- ================================================================

CREATE TYPE store_kind      AS ENUM ('apple', 'google', 'promo');
CREATE TYPE sub_status      AS ENUM ('trialing','active','expired','canceled','refunded');
CREATE TYPE quota_kind      AS ENUM ('scan', 'chat');
CREATE TYPE reminder_status AS ENUM ('pending', 'sent', 'completed', 'skipped');

-- ----------------------------------------------------------------
-- PLANS  (caps in one row per tier, so a pricing change is an
--         UPDATE and not a backfill across every user)
-- ----------------------------------------------------------------
CREATE TABLE plans (
    tier                plan_tier   PRIMARY KEY,
    display_name        VARCHAR(60) NOT NULL,
    max_pets            SMALLINT    NOT NULL,
    scans_per_day       SMALLINT    NOT NULL,        -- -1 = unlimited
    chats_per_day       SMALLINT    NOT NULL,
    max_members_per_pet SMALLINT    NOT NULL DEFAULT 1,
    has_cloud_photos    BOOLEAN     NOT NULL DEFAULT FALSE,
    has_nutrition       BOOLEAN     NOT NULL DEFAULT FALSE,
    has_recall_alerts   BOOLEAN     NOT NULL DEFAULT FALSE
);

-- ----------------------------------------------------------------
-- SUBSCRIPTIONS  (written by the RevenueCat webhook only)
-- ----------------------------------------------------------------
CREATE TABLE subscriptions (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(id),
    tier            plan_tier   NOT NULL REFERENCES plans(tier),
    store           store_kind  NOT NULL,
    store_txn_id    VARCHAR(150) UNIQUE,
    status          sub_status  NOT NULL DEFAULT 'active',
    is_yearly       BOOLEAN     NOT NULL DEFAULT FALSE,

    trial_ends_at   TIMESTAMPTZ,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,
    canceled_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX subs_user_idx ON subscriptions(user_id, status);

-- ----------------------------------------------------------------
-- USAGE COUNTERS  (free-tier metering; date-keyed so it self-resets)
-- ----------------------------------------------------------------
CREATE TABLE usage_counters (
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    usage_date  DATE        NOT NULL DEFAULT CURRENT_DATE,
    kind        quota_kind  NOT NULL,
    used        INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, usage_date, kind)
);

-- ----------------------------------------------------------------
-- REMINDERS
-- One row per notification, not per due item, so "30 days before"
-- and "on the day" are two rows with the same source_id.
-- Offsets come from app_config.reminder_offsets.
-- ----------------------------------------------------------------
CREATE TABLE reminders (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    source_id       UUID,                           -- health_records.id, or null for custom
    due_on          DATE,                           -- the real due date
    fire_at         TIMESTAMPTZ NOT NULL,           -- when to notify

    title           VARCHAR(150) NOT NULL,
    body            TEXT,
    status          reminder_status NOT NULL DEFAULT 'pending',
    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX reminders_fire_idx ON reminders(fire_at) WHERE status = 'pending';
CREATE INDEX reminders_pet_idx  ON reminders(pet_id, fire_at);
CREATE UNIQUE INDEX reminders_dedupe_uidx ON reminders(pet_id, source_id, fire_at)
    WHERE source_id IS NOT NULL;

CREATE TRIGGER trg_subs_upd BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- what a user is allowed to do right now
CREATE VIEW user_limits AS
SELECT u.id AS user_id, u.tier,
       (u.tier = 'free' OR u.tier_expires_at > NOW()) AS is_valid,
       p.max_pets, p.scans_per_day, p.chats_per_day, p.max_members_per_pet,
       p.has_cloud_photos, p.has_nutrition, p.has_recall_alerts
FROM users u
JOIN plans p ON p.tier = u.tier
WHERE u.deleted_at IS NULL;

CREATE VIEW reminders_to_send AS
SELECT * FROM reminders WHERE status = 'pending' AND fire_at <= NOW();
