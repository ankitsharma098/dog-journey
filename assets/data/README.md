# Bundled reference data

Per PRD §9: reference tables ship as bundled JSON assets, not Firestore
collections — zero reads, works offline, and `triage_rules` must work with
no network since that's the emergency path.

Each file mirrors the matching table in `db-design/*.sql`, scoped to
`species = "dog"` for v1. Field names match the SQL columns (snake_case)
so the data-layer model classes can deserialize 1:1.

| File | Source table | Filled in during |
|---|---|---|
| `breeds.json` | `breeds` | Module 1 — Breed Scanner |
| `vaccine_types.json` | `vaccine_types` | Module 2 — Health Passport |
| `triage_rules.json` | `triage_rules` | Module 3 — AI Vet Chat (needs vet sign-off before ship) |
| `toxic_items.json` | `toxic_items` | Module 3 / 4 — AI Vet Chat + Nutrition |
| `food_items.json` | `food_items` | Module 4 — Nutrition & Care Planner |
| `milestone_templates.json` | `milestone_templates` | Module 5 — Memory Timeline |

All files currently hold an empty array and get populated feature by
feature, not all at once.
