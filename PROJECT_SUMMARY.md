# Welcome2GH — Complete Project Summary

A full record of everything built, from first line to now.

---

## What the app is

**Welcome2GH** — a smart tourism & student-assistance mobile app for international visitors in Accra, Ghana. Dark-navy + yellow design, built in Flutter with a Supabase backend.

---

## Phase 1 — Foundation (UI Prototype)

Created the Flutter project from scratch with clean architecture:

```
lib/
  core/         → router, models, services, config
  features/     → splash, onboarding, auth, home, map,
                  place_details, community, favorites, profile, ai_assistant
  shared/       → theme, reusable widgets
```

Design system (`app_theme.dart`): navy `#0D1B2A` + yellow `#FFCC00`, Barlow (headings) + Inter (body), glassmorphism, rounded cards.

14 screens built with sample data: splash, 6-slide onboarding, login/signup, home (hero + categories + place list), full-screen map with markers, place details (IoT score cards), community feed, favorites grid, profile, AI assistant chat, emergency contacts.

---

## Phase 2 — Getting it running

- Installed Flutter dependencies, fixed `pubspec.yaml`
- Android setup: installed cmdline-tools, accepted licenses, downloaded SDK platform 35 + system image, installed AEHD hypervisor driver, created the W2G_Pixel emulator
- Fixed corrupted NDK, Gradle network/heap issues (bumped JVM to 4 GB)
- App running on Android emulator ✅
- Also enabled Chrome web as a faster preview target

---

## Phase 3 — Real backend (Supabase)

Complete SQL schema (`schema.sql`): `profiles`, `places`, `reviews`, `favorites`, `posts`, `post_likes`, `post_comments`, `fair_prices`, `alerts`, `iot_data`, `notifications` — with PostGIS geo-search, RLS policies, auto-triggers (ratings recalc, like/comment counters, auto-profile-on-signup), `nearby_places`/`nearby_alerts` RPC functions, realtime enabled, and seed data (6 Accra places + fair prices + alerts).

Wired every screen to live data:
- Real Supabase Auth (email/password) with isolated users
- Home: live places + debounced search + category filter
- Place details: real reviews, working save, write-review, directions
- Map: live places + alert zones + GPS location
- Community: realtime feed + create posts + likes
- Favorites, Profile (real sign-out), tap-to-call emergency contacts

---

## Phase 4 — Admin system & roles

- Role selector at signup (Tourist / Student / Local / Admin with secret code `W2G-ADMIN-2026`)
- Admin Dashboard — 7 tabs: Overview stats, Users (change roles), Places (verify/delete), Reviews (moderate), Posts (hide), Alerts (create/broadcast), Fair Prices (verify/flag/delete)
- Admin RLS policies (`admin_policies.sql`) + `is_admin()` function + route guard

---

## Phase 5 — Auth hardening

- Fixed the "all users are Mohamed" bug
- Defensive profile upsert on signup, self-healing `signIn` + `getMyProfile`
- Reactive auth-state listener, clean sign-out
- Forgot Password + human-readable error messages
- Diagnosed login issue via direct API call (email-confirmation rate limit)

---

## Phase 6 — Feature batches

| Batch | Delivered |
|-------|-----------|
| A — Bug fixes | Real map search, real profile stats, persistent settings, change-password, place contact info, tappable alerts, bottom-nav sync, pagination, zoom controls, haptics |
| B — Image uploads | Cross-platform photo upload (profile, places, reviews, posts) via `ImageUploadHelper` → Supabase Storage |
| C — AI Guide | Real Claude API integration via secure Supabase Edge Function (`ai-guide`) — context-aware Ghanaian guide (pipeline ready, needs Anthropic key) |
| E — Performance | `AppImage` (cached + shimmer), skeleton loaders, map marker clustering, pagination |

---

## Phase 7 — Branding & polish

- Logo wired everywhere (splash, onboarding, login, home, about) via `AppLogoChip`
- App launcher icon generated (Android + iOS)
- Ghana-cultural redesign — splash + onboarding with Adinkra star motifs, Black-Star halo, Ghana flag palette, "Akwaaba" greeting
- In-app directions (replaced Google Maps redirect) with OSRM routing + 3 transport modes + fare estimate
- In-app Privacy, Terms, About, Help & Support, Settings screens

---

## Phase 8 — Real problem-solving

| Issue | Fix |
|-------|-----|
| App "very slow" | Found 27 exceptions/frame from Skeleton shimmer crashing on `double.infinity` → fixed |
| Emulator showing old version | Rebuilt + reinstalled current APK; diagnosed emulator GPU-driver crashes → recommend Chrome/physical phone |
| Like/comment 1s lag | Optimistic updates — instant heart pop + count |
| Map location jump | Smooth 900 ms glide animation |
| Kente bands masking elements | Removed from splash + onboarding |
| Hero image | Ghana-themed + cached |
| Admin hero management | New `app_settings` table + admin hero editor (title/subtitle/image) |
| Post pictures not loading | Root cause: storage buckets → created 4 public buckets + policies (verified live) |
| 18 px / 81 px overflows | `FittedBox` on onboarding + taller favorites grid cells |

---

## Tech stack (final)

Flutter · Supabase (Auth + PostgreSQL/PostGIS + Storage + Realtime + Edge Functions) · flutter_map + OSM/Carto + clustering · Claude API (Opus) · cached_network_image · geolocator · image_picker · share_plus · go_router

---

## Still needs your action

- **AI Guide** — deploy edge function + set Anthropic API key: `supabase functions deploy ai-guide`
- **Real Android testing** — emulator has a host GPU-driver instability; a physical phone via USB is the most reliable path

---

## Key files

| File | Purpose |
|------|---------|
| `supabase/schema.sql` | Full database schema + RLS + triggers + seed data |
| `supabase/admin_policies.sql` | Admin-role RLS policies |
| `supabase/functions/ai-guide/index.ts` | Claude API edge function |
| `lib/core/supabase_service.dart` | Single backend layer |
| `lib/shared/widgets/` | `app_image`, `app_logo`, shared UI |
