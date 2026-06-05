# Welcome2GH — Project Summary (Current Version)

Smart tourism & student-assistance app for **Accra, Ghana** — Flutter + Supabase.
Developer: Mohamed (Wisconsin International University College).
Live (web): **https://welcome2gh.vercel.app** · Repo: github.com/niaremohamed526-blip/welcome2gh

---

## Tech Stack
- **Flutter (Dart)** — Android, iOS, Web
- **Supabase** — Auth, PostgreSQL + PostGIS, Storage, Realtime, RLS, Edge Functions
- **flutter_map + OpenStreetMap** (Carto Voyager tiles) — no key
- **Routing:** FOSSGIS OSRM (routed-car / routed-bike / routed-foot) — real per-mode times, no key
- **Geocoding:** OpenStreetMap Nominatim — address/place search, no key
- **go_router** (navigation + auth guard) · **video_player** · **geolocator** · **cached_network_image + shimmer** · **google_fonts** (Barlow + Inter) · **share_plus / url_launcher**

## Design System
- Dark navy `#0D1B2A` + Yellow accent `#FFCC00`; light theme `#F0F4F8` / white cards
- Glassmorphism, 16px radius, Barlow headings; Ghana flag palette, Adinkra motifs
- `AppColors` uses theme-aware getters (white→navy, navyCard→white, etc.); yellow/red/green are const accents

---

## Core Features
Splash · Onboarding (6 slides) · Auth (email/password + Google + forgot password) ·
Home · Map · Community · Favorites · Profile · AI Assistant · Add/Edit Place ·
Fair Price · Admin Dashboard · Settings · Directions · Legal/About/Support

---

## What's been built / fixed recently (this version)

### Deployment & infrastructure
- **Vercel web deploy fixed** — `vercel.json` sets `outputDirectory: public`; auto-deploys on every GitHub push.
- **`deploy.ps1`** — one-command deploy: analyze + test + build + sync `public/` + push. Usage: `.\deploy.ps1 "message"`.
- **Cache problem solved permanently** — service worker disabled (`flutter build web --pwa-strategy=none`) + `Cache-Control: no-store` headers on index.html / main.dart.js, so deploys always load fresh. One-time Safari cache clear needed to escape a previously-stuck service worker.

### Map (major overhaul)
- New architecture: `core/geo/geo_math.dart` (Web-Mercator coordinate utility), `core/geo/marker_layout.dart` (priority bounding-box collision/declutter), `features/map/map_state.dart` (immutable state + controller, single source of truth). **34 unit tests**.
- Fixed 14 map bugs (animation crash, danger-zone radius, expired alerts, category filters, alert count, stale card, locate button, permission feedback, stream leaks, banner overlap, zoom clamp, search-vs-follow, nav, marker colors).
- **Locate button** works on web. **Tap a category → flies to the nearest** place to your live location.
- **Icon markers** (category-colored) + **rich place card** (rating, distance, **real routed walk/drive ETA**, Directions button).
- **"Search this area"** pill (nearby_places PostGIS) · **Nearby list sheet** (sorted by distance).
- Glassmorphism overlays, legibility scrims, chip icons. (Light Voyager basemap — dark tiles tried then reverted by preference.)

### Directions
- Real **per-mode times**: Drive / Bike / Walk now differ (FOSSGIS OSRM engines). Replaced the car-only demo server.

### Community (v2)
- **Tap image → fullscreen** (pinch-zoom) · **double-tap to like**
- **Video posts** — pick/upload + inline player (+ "Open video" fallback for iPhone .mov/HEVC)
- **Favorite/bookmark posts**
- **Notifications** — bell + unread badge + Notifications screen; DB triggers notify the author on like/comment
- **3-dot menu** — delete own post / report others · **pull-to-refresh** · loading skeletons
- Fixes: list keys (state leak), cached notification stream

### Home (redesign)
- Removed the overlapping floating `+`; added a **Quick Actions row** (Add Place / Fair Price / AI Guide / Safety)
- Replaced fake "THREE WORLDS" cards with a **real "Top-rated in Accra"** carousel from the DB
- Place-list cards: **full-bleed thumbnails** (no gaps)

### Add Place — location picker (fixes wrong coordinates)
- **No more typing lat/lng.** Search a place/address (geocoding), **tap the map**, or use **GPS**. Pin shown for confirmation → matches Google.

### Admin — can now EDIT everything (not just delete)
- **Places:** full editor + map picker (✏️) — fix name, category, **location**, photo, price
- **Posts:** edit text · **Alerts:** edit · **Fair Prices:** edit amount

### Other fixes
- **Sign out → Login** (router auth guard + navigate-first + timeout)
- **Saved screen** no longer crashes when a favourited place was deleted
- Admin delete now hides soft-deleted places/posts/alerts everywhere (admin lists + realtime feeds)
- **Light theme** Profile menu text fixed (was white-on-white)
- Corrected real place coordinates; found a longitude **sign error** on user-added places (Atlantic Mall, Academic City) — fixable now via the place editor

---

## ⚠️ SQL to run in Supabase (SQL Editor → Run)
1. **`supabase/community_upgrade.sql`** → video, favorites, notifications, reports
2. **`supabase/admin_edit_policies.sql`** → lets admin edit posts / alerts / fair-prices
3. **`supabase/fix_place_coords.sql`** (+ Atlantic Mall / Academic City) → correct coordinates *(or just use the place editor)*

All idempotent (safe to run more than once).

## Database (Supabase)
Tables: profiles, places, reviews, favorites, posts, post_likes, post_comments,
**post_favorites, post_reports**, fair_prices, alerts, iot_data, notifications, app_settings.
PostGIS geo-search, RLS, nearby_places/nearby_alerts RPC, realtime, triggers
(ratings, like/comment counts, geom from lat/lng, **like/comment → notification**).
Storage buckets (public): profiles, places, reviews, posts.

## Roles
Tourist / Student / Local = full app · **Admin** = + Admin Dashboard (signup code `W2G-ADMIN-2026`).

## Outstanding
🔴 Run the 3 SQL files above · Google OAuth (Supabase dashboard) · AI Guide edge function + ANTHROPIC_API_KEY
🟡 Move admin secret off the client · iPhone .mov transcoding (guaranteed inline playback) · Saved Posts browse screen
🟢 Android APK (`flutter build apk --release`)

## Deploy workflow
`.\deploy.ps1 "what changed"` → builds + tests + pushes → Vercel auto-publishes in ~30–60s.
