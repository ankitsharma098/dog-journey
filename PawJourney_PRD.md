# PawJourney — Product Requirements Document

**Version:** 1.0
**Date:** 10 September 2026
**Owner:** Ankit Sharma
**Status:** Draft for build

---

## 1. Summary

PawJourney is a mobile app that covers a dog's whole life in one place: identify
the breed, keep the health record, get triage advice at 2am, feed correctly, and
keep the memories.

Five modules, one app:

| # | Module | Role | Tier |
|---|---|---|---|
| 1 | AI Breed Scanner | Acquisition hook | Free, 3 scans/day |
| 2 | Health Passport | Retention through accumulated data | Free (1 pet) |
| 3 | AI Vet Chat | Revenue | Premium |
| 4 | Nutrition & Care Planner | Revenue | Premium |
| 5 | Memory Timeline | Emotional retention + organic growth | Free, cloud backup is Premium |

Platform: Flutter (iOS + Android), Firebase backend.

---

## 2. Problem

Dog ownership generates a stream of small decisions that owners are badly
equipped to make and that nothing currently tracks in one place:

- **"What is my dog?"** Mixed-breed owners want to know, and breed drives
  everything downstream — health risks, calorie needs, exercise, life stages.
- **"When is the next shot due?"** Vaccine records live on paper certificates,
  in three clinics' systems, and in nobody's calendar.
- **"Is this an emergency?"** The core anxiety. 52% of US owners skip vet visits
  over cost, and 40% are interested in telemedicine. The question isn't "what's
  wrong" — it's "do I need to spend $200 tonight."
- **"How much do I feed him?"** Most owners overfeed. Obesity is the single most
  common preventable health problem in dogs, and calorie needs are not linear
  with body weight.
- **"Where did the puppy years go?"** Photos scatter across the camera roll with
  no structure and no dates that mean anything.

### The honest market position

This space is crowded and we should build knowing that.

- Several apps already bundle breed scanning, food safety, a vet log and AI chat
  in one product. The bundle itself is not the differentiator.
- Free AI triage tiers already exist. For a licensed vet, competitors run
  unlimited chat around $99/year, or roughly $35 a visit. **Charging as our core
  revenue line means competing against free.**
- Visual breed ID on mixes is genuinely hard. Competitor reviews are full of the
  same purebred returning three different breeds on three scans. DNA is the
  ground truth; a photo is an estimate.
- Breed ID is one-time curiosity. Excellent for installs, poor for retention.

**Our defensible position is the accumulated record, not the scan.** Modules 2
and 5 create switching cost because the data can't be recreated elsewhere. The
scanner buys the install; the passport and the timeline keep it. Everything in
this PRD should be read through that lens.

---

## 3. Goals and non-goals

### Goals

- **G1.** Get a new user from install to a created pet profile with at least one
  saved health record inside the first session.
- **G2.** Give owners a trustworthy, fast answer to "should I go to the vet."
- **G3.** Build a health record valuable enough that leaving means losing it.
- **G4.** Convert on genuine utility — multi-pet, unlimited chat, cloud photos —
  not on artificial locks.
- **G5.** Ship a schema and codebase that becomes a cat app by swapping seed data.

### Non-goals for v1

- Live video or text consults with real, licensed vets.
- Booking, prescriptions, or pharmacy.
- Marketplace, e-commerce, insurance sales.
- Social feed, follows, or dog-owner community.
- Wearables, GPS collars, activity trackers.
- Web app. Mobile only.
- Any B2B or clinic-facing product.

### Explicit product principles

1. **Never diagnose.** We triage and inform. We describe possibilities and what
   distinguishes them. Naming a condition as fact is out of scope, always.
2. **Urgency is deterministic, never model-decided.** See §7.3.
3. **The free tier must be genuinely useful.** A crippled passport gets deleted
   before the paywall is ever seen.
4. **No dark patterns.** Cancel is easy, the trial reminder is real, and the
   paywall states what it costs before the tap.

---

## 4. Users

### Primary: the new dog owner (0–12 months)

Highest anxiety, highest engagement, most willing to pay. Doesn't know the
vaccine schedule, doesn't know how much to feed, panics at every symptom. This
is the acquisition target.

### Secondary: the established owner (1–8 years)

Lower anxiety, uses the app episodically — a reminder, a "can he eat this," an
annual record. Retention depends almost entirely on reminders firing and the
record being worth keeping.

### Tertiary: the senior-dog owner (8+ years)

Re-enters high engagement. More medications, more visits, more weight tracking,
more emotional attachment to the timeline. Underserved by every competitor.

### The shared household

A second adult who needs to see the same record — "did you give him the pill?"
This is a real, chargeable need and the reason sharing sits in Premium.

---

## 5. Success metrics

### North star

**Weekly active pets with a health record updated in the last 30 days.** This
measures the thing that actually retains, not the thing that acquires.

### Activation funnel (measure from day one)

| Step | Target |
|---|---|
| Install → pet profile created | 60% |
| Pet created → first scan completed | 70% |
| Pet created → first health record saved | 40% |
| D1 retention | 40% |
| D7 retention | 22% |
| D30 retention | 12% |

### Monetization

| Metric | Target |
|---|---|
| Paywall view → trial start | 6% |
| Trial → paid conversion | 35% |
| Overall free → paid | 2.5% |
| Month-1 subscription churn | < 15% |

### The one that decides Module 3

Ship v1 with a **paywall stub on the chat tab** — real paywall, no chat behind
it. If `paywall_viewed → trial_started` on that stub clears 5% over two weeks,
build the chat. If it doesn't, we've saved six weeks and should reconsider the
revenue model instead.

### Quality guardrails

- Breed scan p95 latency < 4s
- Crash-free sessions > 99.5%
- Reminder delivery rate > 95%
- **Missed-emergency reports: 0.** Any single instance is a P0.

---

## 6. Scope and release plan

### v1.0 — "The Record" (target: 6 weeks)

Modules 1, 2, 5 (local photos only) + paywall stub. Ships to store.

- Firebase Auth email sign-in
- Pet profile creation with breed scan
- Health passport: vaccines, visits, medications, weight
- Reminders via local notifications
- Timeline with auto-seeded milestones, device-local photos
- Premium paywall live for multi-pet + cloud photos
- Chat tab present, paywall stub only

### v1.1 — "The Answer" (+4 weeks, gated on the stub metric)

Module 3. Deterministic triage gate, then LLM. Shareable vet report.

### v1.2 — "The Plan" (+3 weeks)

Module 4. Feeding calculator, food safety lookup, treat counter, recall alerts.

### v1.3 — "The Album" (+2 weeks)

Cloud photo backup, share cards, household sharing.

### v2.0 — CatJourney

Same schema, same codebase, swapped reference data. See §13.

---

## 7. Feature specifications

### 7.1 Module 1 — AI Breed Scanner

**Purpose:** acquisition hook and the source of breed data that every other
module reads.

#### User stories

- As a new owner, I photograph my dog and learn its likely breed mix.
- As a mixed-breed owner, I get a percentage breakdown, not a single wrong guess.
- As any owner, I learn what health risks my dog's breeds carry.

#### Flow

1. Camera or gallery picker. Guidance overlay: full body, side-on, good light.
2. Client compresses to ~1200px, computes SHA-256 hash.
3. Server checks `scans` for a matching `image_hash` + `model_version`. Hit →
   return cached result, `from_cache = true`, **do not decrement quota**.
4. Miss → check quota via `usage_counters`. Over limit → paywall.
5. Vision model call with forced JSON output.
6. Result screen: breed cards with percentages, personality traits, health risks.
7. CTA: "Save to [pet name]" or "Create a profile for this dog."

#### Requirements

| ID | Requirement |
|---|---|
| BS-1 | Returns a ranked mix with percentages, not a single breed. |
| BS-2 | Detects non-dog photos and returns a friendly rejection, not a breed. |
| BS-3 | Free tier: 3 scans/day, enforced server-side. Cached repeats are free. |
| BS-4 | Confidence is shown honestly. Below 60% top match → "best guess" framing. |
| BS-5 | Every result carries: "This is a visual estimate. Only a DNA test is definitive." |
| BS-6 | Result writes `pets.breed_mix`, `breed_id`, `size_class` on save. |
| BS-7 | Scan works without a pet profile — that's the pre-signup hook. |
| BS-8 | Model version stored per scan, so a model change is traceable. |

#### Edge cases

- Multiple dogs in frame → ask which one, or crop.
- Puppy → note that appearance shifts and suggest rescanning at 6 months.
- Cat, human, or object → BS-2 rejection, no quota consumed.
- Network failure mid-scan → row stays `pending`, retryable, no quota consumed.
- Known purebred already on the profile → offer to confirm rather than overwrite.

#### Acceptance criteria

- Same photo scanned twice consumes one quota unit.
- A cat photo never returns a dog breed.
- p95 latency under 4s on a mid-range Android device on 4G.

#### Deliberate honesty

We will not claim accuracy we can't deliver. Copy says "best visual estimate,"
never "identifies." Overclaiming here is exactly what produces the one-star
reviews every competitor in this category has.

---

### 7.2 Module 2 — Health Passport

**Purpose:** the retention engine. The one thing users can't rebuild elsewhere.

#### User stories

- As an owner, I record a vaccine and get reminded before the next is due.
- As an owner at the vet, I show the full history without hunting for paper.
- As a household, my partner and I see the same record.
- As a senior-dog owner, I track weight over years and see the trend.

#### Record types

All in one `health_records` table with a `type` discriminator:

| Type | Captures |
|---|---|
| `vaccine` | Vaccine, date given, next due, batch, certificate photo |
| `vet_visit` | Clinic, date, reason, notes, cost, attached reports |
| `medication` | Name, dosage, frequency, dose times, start/end |
| `weight` | Weight, optional 9-point body condition score |
| `allergy` | Allergen, severity, notes |
| `preventive` | Heartworm, flea/tick, deworming, next due |

#### Requirements

| ID | Requirement |
|---|---|
| HP-1 | Adding a vaccine auto-computes `due_on` from `vaccine_types` and the dog's age. |
| HP-2 | Puppy series uses short intervals; adult boosters use the 12/36-month rule. |
| HP-3 | Rabies interval is user-overridable — it's set by state law, not by us. |
| HP-4 | Reminders fire at −30, −14, −3, 0, +7 days for vaccines; −3/0/+3 inside a puppy series. |
| HP-5 | Medication reminders fire at each configured `dose_times` entry. |
| HP-6 | Weight entry updates `pets.weight_kg` and feeds the nutrition calculator. |
| HP-7 | Photo attachments on any record (certificates, lab reports, receipts). |
| HP-8 | Export the full record as a shareable PDF for a vet visit. |
| HP-9 | Free tier: 1 pet, unlimited records. Premium: up to 5 pets. |
| HP-10 | Timezone-aware reminders — 9am in the user's zone, not the server's. |

#### Onboarding shortcut

Asking a new user to enter a year of history is how you lose them. Instead:

1. Ask only for birthdate (or estimate) and adoption date.
2. Generate the *expected* vaccine schedule from the dog's age.
3. Present it as a checklist: "Tick what he's already had."

Three taps instead of a data-entry session.

#### Edge cases

- Unknown birthdate → `birthdate_is_estimate = true`, ask for approximate age,
  soften all age-derived language ("around 2 years old").
- Adopted adult with no records → start from today, don't imply negligence.
- Dog passes away → archive, never delete. The timeline is why people keep the
  app. Handle this path with real care in copy.
- Two household members log the same vaccine → dedupe on
  `(pet_id, vaccine_type_id, occurred_on)` and merge silently.

#### Acceptance criteria

- A 9-week-old puppy generates a correct, correctly-ordered vaccine schedule.
- Reminder titles carry the due date, not the fire date.
- Deleting a record removes its pending reminders.

---

### 7.3 Module 3 — AI Vet Chat

**Purpose:** the revenue module and the highest-risk surface in the product.

#### The safety architecture

This is non-negotiable and should be treated as product spec, not implementation
detail.

```
user message
   ↓
[1] normalise text (lowercase, strip punctuation)
   ↓
[2] deterministic gate — match against triage_rules
   ↓
[3] any rule at level = emergency?
        YES → show the rule's headline + action_text VERBATIM, immediately,
              above anything the model produces. Log the flag.
        NO  → continue
   ↓
[4] inject matched rules' llm_directive + pet context into the system prompt
   ↓
[5] model responds beneath the fixed text
```

**The model never decides urgency.** It elaborates on a decision already made by
a reviewed rule table. A model that hedges on bloat kills a dog; a rule table
that fires on "retching and swollen belly" does not.

#### Rule coverage (v1.1 minimum)

Emergency: bloat/GDV, respiratory distress, seizure, collapse with pale gums,
heatstroke, toxin ingestion, urinary obstruction, pyometra, trauma, eye
emergency, acute neurological signs, sick puppy.

Urgent: repeated vomiting, persistent lameness, appetite loss beyond 24h, severe
itching or ear infection.

Info/routine: diet questions, behaviour, preventive care questions.

#### Requirements

| ID | Requirement |
|---|---|
| VC-1 | Deterministic gate runs before every model call. No exceptions. |
| VC-2 | Emergency text is shown verbatim from `triage_rules`, never paraphrased. |
| VC-3 | Toxin severity is computed from `toxic_items` scaled by the dog's weight. |
| VC-4 | The model never states a drug name with a dose, and never a human medication. |
| VC-5 | The model never says an amount of a toxic substance is safe. |
| VC-6 | Every response ends with a clear next step: monitor / call / go today / go now. |
| VC-7 | Every response carries a visible "not a substitute for a vet" disclaimer. |
| VC-8 | Pet context (age, weight, breed, allergies, current meds) is injected each turn. |
| VC-9 | `pet_snapshot` is frozen on the thread at creation. |
| VC-10 | Breed risk flags escalate matching rules — flat-faced + breathing, deep-chested + retching. |
| VC-11 | Thumbs up/down on every assistant message. Down + "missed emergency" is a P0 alert. |
| VC-12 | System prompt and model name live in `app_config`, changeable without a release. |
| VC-13 | Photo input supported for skin, eye, wound and stool questions. |
| VC-14 | Threads exportable as a vet-ready summary. |

#### Emergency UX

When the gate fires at emergency level:

- Full-width red card, above the fold, before any model text.
- One-tap "Find emergency vet near me" (maps intent, no directory to maintain).
- The model's elaboration appears below, visually secondary.
- No follow-up questions before the instruction is delivered.

#### What we will not do

- No triage of human symptoms, ever. Out-of-scope detection returns a redirect.
- No claim of veterinary licensure, anywhere, in any copy or store listing.
- No "our vets say." We have no vets on staff.

#### Clinical review gate

`toxic_items.vet_reviewed_at` and the emergency/urgent split in `triage_rules`
**must be signed off by a licensed veterinarian before v1.1 ships.** This is a
release blocker, not a nice-to-have. Budget for a paid review.

---

### 7.4 Module 4 — Nutrition & Care Planner

**Purpose:** premium utility that produces a number owners can act on daily.

#### The calculation

```
RER = 70 × (weight_kg ^ 0.75)          resting energy requirement
MER = RER × life-stage factor          daily calories
```

**Never linear with weight.** A 40kg dog does not need twice a 20kg dog's food.
Getting this wrong is the single most common error in competing apps.

| Life stage | Factor |
|---|---|
| Puppy under 4 months | 2.5–3.0 |
| Puppy 4 months to adult | 1.8–2.0 |
| Adult, neutered | 1.6 |
| Adult, intact | 1.8 |
| Senior | 1.2–1.4 |
| Weight loss | 1.0 **on target weight, not current** |

Factors live in `app_config` so they can be tuned without a release.

#### Requirements

| ID | Requirement |
|---|---|
| NP-1 | Plan stores its inputs (`basis_weight_kg`, `mer_factor`), not just the output. |
| NP-2 | Weight-loss plans compute on target weight and say so in the UI. |
| NP-3 | Meal count derives from age: 4 under 3 months, 3 under 6 months, 2 after. |
| NP-4 | Treat budget = 10% of daily calories, shown as a live daily counter. |
| NP-5 | "Can my dog eat X" search over `food_items` with fuzzy matching. |
| NP-6 | A `toxic` result routes to the Module 3 toxin path, not a casual answer. |
| NP-7 | Recalls polled from the FDA feed, deduped on `external_id`. |
| NP-8 | Recall alerts fire only to users who logged a matching brand in 120 days. |
| NP-9 | Plan prompts recalculation every 4 weeks or on a 10% weight change. |
| NP-10 | Breed-specific warnings surface — pancreatitis risk, bloat feeding guidance. |

#### Edge cases

- No weight logged → block the calculator, prompt for a weight. Don't guess.
- Body condition score 8–9 → recommend a vet conversation before a DIY diet.
- Pregnant or nursing → out of scope, refer to a vet. Factors range 2–6× and
  getting it wrong is dangerous.

---

### 7.5 Module 5 — Memory Timeline

**Purpose:** emotional retention, organic acquisition, and the reason people
don't delete the app.

#### Requirements

| ID | Requirement |
|---|---|
| MT-1 | Timeline is back-filled at pet creation from birthdate and adoption date. |
| MT-2 | Auto-milestones are real developmental stages, not filler. |
| MT-3 | Gotcha Day and birthdays recur annually with a share card. |
| MT-4 | Manual entries: photo, caption, date, type. |
| MT-5 | Free tier keeps photos device-local (`storage = 'device'`). |
| MT-6 | Premium syncs to cloud with a clear "X photos not backed up" prompt. |
| MT-7 | Share cards are branded, and installs from a shared card are attributed. |
| MT-8 | Health milestones auto-post — "fully vaccinated," "hit target weight." |

#### Auto-milestone set

Socialisation window (3 wks), first walk (12 wks), teething (15 wks), adult teeth
(30 wks), fully vaccinated (on record), adolescence (6 mo), skeletally mature
(10 mo small / 16 mo large), switch to adult food (size-dependent), first
birthday, each birthday, senior transition (75% of breed lifespan).

#### Why cloud backup is the paid feature

Photo storage is our largest variable cost. Making it the upgrade turns the cost
centre into the revenue line, and the value proposition is honest: "these photos
exist only on your phone."

---

## 8. Monetization

### Tiers

| | Free | Premium |
|---|---|---|
| Pets | 1 | 5 |
| Breed scans | 3/day | Unlimited |
| AI vet chat | — | Unlimited |
| Health passport | Full | Full |
| Timeline | Device photos | Cloud backup |
| Nutrition planner | — | Yes |
| Recall alerts | — | Yes |
| Household sharing | — | Up to 3 people |
| Vet report export | — | Yes |

### Pricing (proposed, to be validated)

- $6.99/month, or $39.99/year (52% saving, push the annual)
- 7-day free trial on annual only
- Managed through RevenueCat. No custom receipt validation.

### Paywall triggers

1. Second pet added
2. Chat tab opened (**the stub metric in v1.0**)
3. Fourth scan in a day
4. Cloud backup prompt after 20 device-only photos
5. Nutrition tab opened

### Honest note on pricing

The core paid feature competes with free tiers from funded competitors and with
~$99/year for chat with an actual licensed vet. Pricing at $39.99/year positions
us as the record-keeping product with AI triage included, not as a vet
replacement. If the stub metric underperforms, the answer is probably to move
the paywall toward multi-pet, sharing and cloud photos — the things nobody gives
away free — rather than to discount the chat.

---

## 9. Technical architecture

### Stack

| Layer | Choice |
|---|---|
| App | Flutter, BLoC |
| Auth | Firebase Auth, email sign-in |
| Database | Cloud Firestore, offline persistence on |
| Storage | Firebase Cloud Storage |
| AI | Firebase AI Logic (`firebase_ai`) → Gemini Flash |
| Abuse control | Firebase App Check |
| Config | `app_config` collection |
| Reminders | `flutter_local_notifications`; FCM for recalls only |
| Payments | RevenueCat |
| Functions | Two: FDA recall cron, RevenueCat webhook |
| Analytics | Firebase Analytics + Crashlytics |

### Non-negotiable setup items

1. **App Check before anything else.** From 2 November 2026 it is required to
   use Firebase AI Logic. Retrofitting means a forced app update.
2. **Model name in `app_config`.** Gemini models get deprecated on a schedule.
   Hardcoding means every deprecation is a store release.
3. **Quota enforcement server-side.** Client-side `3 scans/day` is trivially
   bypassed, and the bypasser is spending our money.

### Cost controls

- Firestore: paginate everything, `limit(20)` + cursor, no collection-wide listeners.
- Storage: compress to ~1200px WebP client-side before upload.
- Scans: hash-and-cache; repeat scans of the same photo are free.
- Chat: send `summary` + last 10 messages, not the full thread.
- Budget alert at $20 on day one.

### Data model

22 tables, modelled in SQL, deployed as Firestore collections. Reference tables
(breeds, vaccine types, triage rules, toxins, foods, milestones, plans) ship as
**bundled JSON assets** — zero reads, works offline, and the triage rules must
work with no network because that's the emergency path.

---

## 10. Compliance and legal

| Area | Requirement |
|---|---|
| App Store 1.4.1 | Written for human patients, so a pet app avoids device clearance. But health apps get extra review scrutiny. Ship a visible disclaimer and never use "diagnose" or "prescribe" in copy or metadata. |
| Store listing | No claim of veterinary licensure. No "our vets." Market as triage and record-keeping. |
| Disclaimer | Persistent in chat, on every AI response, and in onboarding. |
| Clinical review | Vet sign-off on toxin thresholds and the emergency/urgent split is a **release blocker for v1.1**. |
| Privacy | Photos and health records are personal data. Full export and full delete must work. GDPR/CCPA compliant. |
| Data retention | Deleted account purges within 30 days. Timeline archive on pet death is opt-in, not automatic. |
| Age rating | 4+. No user-generated public content in v1. |

---

## 11. Analytics plan

Instrument from launch — these can't be backfilled:

```
app_open, signup_complete, onboarding_pet_added
scan_started, scan_completed, scan_failed, scan_quota_hit, scan_saved_to_pet
record_added (type), reminder_sent, reminder_tapped, reminder_completed
paywall_viewed (trigger), paywall_dismissed, trial_started,
  purchase_completed, subscription_churned
chat_opened, chat_message_sent, triage_emergency_shown, chat_feedback (helpful)
plan_generated, food_searched, food_toxic_result, recall_alert_sent
timeline_entry_added, share_card_created, share_completed, install_attributed
```

The decisive one: `paywall_viewed → trial_started`, segmented by trigger.

---

## 12. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| The gate misses a real emergency | **Critical** | Broad match patterns, err toward false positives, thumbs-down alerting, weekly review of `emergency_log`, vet sign-off |
| Breed scanner accuracy complaints | High | Honest "visual estimate" framing, percentage output, never overclaim |
| Chat competes with free tiers | High | Position on the record, not the chat; validate with the stub before building |
| LLM cost overrun | Medium | Server-side quotas, caching, summarisation, budget alerts |
| App Store rejection on health grounds | Medium | Disclaimers, careful metadata wording, no diagnosis language |
| Firebase cost spiral | Medium | Pagination discipline, compression, device-local photos on free tier |
| Solo-founder scope collapse | High | Ship v1 at three modules. The five-module app is 3–4 months; the record app is 6 weeks |

---

## 13. Species portability

The schema and app are species-agnostic by design. Nothing in the data model
says "dog."

To ship CatJourney: same schema, same Flutter code, swap the reference seed data,
set `app_config.active_species = 'cat'`.

| Reference table | Dog | Cat |
|---|---|---|
| `breeds` | ~25 dog breeds | ~20 cat breeds |
| `vaccine_types` | DAPP, rabies, lepto | FVRCP, rabies, FeLV |
| `toxic_items` | chocolate, xylitol, grapes | lilies, onion, paracetamol |
| `triage_rules` | bloat, BOAS | urinary blockage, hepatic lipidosis |
| `food_items` | dog-safe list | cat-safe list |
| `milestone_templates` | puppy stages | kitten stages |

`breeds.risk_flags` is a text array rather than boolean columns, and
`toxic_items` is keyed on `(species, slug)` — the same item genuinely differs by
species, and lilies vs cats is the case that proves it.

Two caveats before treating this as free:

- Cat triage is not dog triage with different words. Urinary blockage in male
  cats and hepatic lipidosis after 48h of not eating are species-specific
  emergencies that need their own clinical review.
- Cat owners are a different acquisition market with different app-store
  keywords. The engineering ports; the marketing doesn't.

---

## 14. Open questions

1. Do we validate pricing with a paywall A/B test before v1.1, or ship one price?
2. Who does the clinical review, and what does it cost? This blocks v1.1.
3. Is household sharing v1.3 or does it move earlier — it's a strong Premium
   driver and technically cheap given `pet_members` already exists.
4. Do we build a real vet-report PDF export in v1.0, or does the record screen
   suffice as a screenshot?
5. Which acquisition channel do we test first — ASO on breed-identifier keywords,
   or organic reach from share cards?
