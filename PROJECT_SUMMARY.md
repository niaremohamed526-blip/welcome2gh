# Welcome2GH — Complete Project Summary (Full Record)

Everything about the app and all the work done on it, to the current version.

---

## 1. What the app is
**Welcome2GH** — a smart tourism & student-assistance mobile/web app for international
visitors and students in **Accra, Ghana**. Discover places, navigate safely with live
IoT-style data, get fair prices, read community posts, and get AI local tips.

- **Version:** 1.0.0+1
- **Developer:** Mohamed — Wisconsin International University College (WIUC), Accra
- **Platforms:** Android, iOS, Web
- **Live web URL:** https://welcome2gh.vercel.app
- **GitHub:** github.com/niaremohamed526-blip/welcome2gh
- **Supabase project:** nvgjkqdgylngwutwhvdd.supabase.co

---

## 2. Tech Stack
| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Supabase — PostgreSQL + PostGIS, Auth, Storage, Realtime, Edge Functions |
| Maps | flutter_map + OpenStreetMap (Carto Voyager tiles) |
| Routing | FOSSGIS OSRM — routed-car / routed-bike / routed-foot (real per-mode times, no key) |
| Geocoding | OpenStreetMap Nominatim (address/place search, no key) |
| Navigation | go_router (auth-guarded routes, bottom-nav shell) |
| AI | Claude API via Supabase Edge Function (`ai-guide`) |
| Video | video_player |
| Images | cached_network_image + shimmer skeletons |
| Fonts | Barlow (headings) + Inter (body) via google_fonts |
| Location | geolocator + permission_handler |
| Storage | image_picker → Supabase Storage |
| Sharing | share_plus + url_launcher |
| Settings | shared_preferences |
| HTTP | http |

---

## 3. Design System
| Token | Value |
|---|---|
| Background dark | Navy `#0D1B2A` |
| Background light | `#F0F4F8` |
| Card dark | `#1A2535` |
| Card light | `#FFFFFF` |
| Accent | Yellow `#FFCC00` |
| Border dark | `#243044` |
| Border light | `#D8E2EE` |
| Danger | Red `#E53935` |
| Success | Green `#43A047` |

Glassmorphism cards, 16px radius, bold Barlow headings, Adinkra motifs, Ghana flag palette,
"Akwaaba" greeting. `AppColors` uses **theme-aware getters** (white→navy, grey, navyCard→white,
cardBorder) so light/dark switch automatically; yellow/red/green/teal are const accents.

---

## 4. Project Structure
```
lib/
├── core/
│   ├── supabase_service.dart      ← ALL backend calls (single entry point)
│   ├── supabase_config.dart       ← URL + anon key + admin secret
│   ├── router.dart                ← GoRouter, auth guard, bottom-nav shell
│   ├── models.dart                ← Place, CommunityPost, Review, AlertItem, FairPrice, UserProfile
│   ├── settings_controller.dart   ← language, theme mode, notif prefs
│   ├── image_upload.dart          ← photo + video pick/upload to Storage
│   ├── routing_service.dart       ← OSRM route summary (walk/drive ETA)   [NEW]
│   ├── geocoding_service.dart     ← Nominatim search/reverse              [NEW]
│   └── geo/
│       ├── geo_math.dart          ← Web-Mercator coordinate utility       [NEW]
│       └── marker_layout.dart     ← marker bounding-box collision system  [NEW]
├── shared/
│   ├── theme/app_theme.dart       ← Material 3 dark + light, AppColors
│   ├── utils/time_utils.dart      ← timeAgo()
│   └── widgets/ app_image.dart, app_logo.dart, user_location_dot.dart
└── features/
    splash, onboarding, auth, home, map (+ map_state.dart [NEW]),
    place_details, community, favorites, profile, ai_assistant,
    add_place, edit_profile, fair_price, admin, settings, directions,
    notifications [NEW], legal, about, support

test/  geo_math_test.dart, marker_layout_test.dart, widget_test.dart
supabase/  schema.sql, functions/ai-guide/, community_upgrade.sql [NEW],
           admin_edit_policies.sql [NEW], fix_place_coords.sql [NEW]
deploy.ps1   ← one-command deploy script  [NEW]
vercel.json  ← outputDirectory: public + no-cache headers
```

---

## 5. Features (every screen)
- **Splash** — animated Ghana-themed intro (timed navigation)
- **Onboarding** — 6 slides with custom illustrations
- **Auth** — email/password + Google OAuth + Forgot Password (+ admin signup code)
- **Home** — logo header, search, hero banner, **Quick Actions row**, **"Top-rated in Accra" carousel (real data)**, category chips, paginated places list (full-bleed cards)
- **Map** — full-screen OSM, icon markers (category-colored), alert danger zones, live GPS + follow, search-this-area, nearby list, place card with real ETA + Directions
- **Place Details** — photos, IoT scores, reviews, directions, save
- **Community** — realtime feed, posts with image/video, like (+ double-tap), comment, bookmark, share, 3-dot (delete/report), pull-to-refresh, notifications bell
- **Notifications** — bell badge + screen; you're notified when someone likes/comments your post
- **Favorites (Saved)** — saved places grid
- **Profile** — stats, settings menu, emergency contacts, sign out → login
- **AI Assistant** — Claude chat with fallback responses
- **Add Place** — photo, category, price, **map location picker** (search/tap/GPS)
- **Edit Profile** — name, nationality, photo
- **Fair Price** — community price reports + verified prices
- **Admin Dashboard** — 7 tabs; **view/verify/EDIT/delete** places, posts, reviews, alerts, fair prices, users, hero banner
- **Settings** — language, dark/light theme, notifications, location
- **Directions** — in-app OSRM routing, turn-by-turn, **real per-mode Drive/Bike/Walk times**
- **Legal / About / Support**

### Special features
- Google-Maps-style GPS dot (pulsing ring + heading cone + glow), follow mode
- Turn-by-turn navigation with haptics + arrival state
- Full dark/light theme (persisted)
- Admin hero-banner manager (title/image/button stored in DB)

---

## 6. Database (Supabase)
**Tables:** profiles, places, reviews, favorites, posts, post_likes, post_comments,
**post_favorites**, **post_reports**, fair_prices, alerts, iot_data, notifications, app_settings.

**Features:** PostGIS geo-search, RLS policies, `nearby_places` / `nearby_alerts` RPCs, realtime
enabled, triggers (rating recalc, like/comment counters, auto-profile on signup, geom from
lat/lng via `st_makepoint(lng,lat)`, **like/comment → notification** via SECURITY DEFINER).

**Storage buckets (public):** profiles, places, reviews, posts.

## 7. User Roles
| Role | Access |
|---|---|
| Tourist / Student / Local | Full app |
| Admin | + Admin Dashboard (signup code `W2G-ADMIN-2026`) |

---

## 8. Complete history of work done

### Session A — original build + first bug-fix pass
- Built the entire app (all screens above).
- Fixed 14 analyzer issues → 0 (e.g. `throw 'string'` → `throw Exception`, community category filter underscores, captured messengers before async gaps, `double.tryParse`, `mounted` checks, deprecated `Switch.activeColor`, concurrent route-fetch guard, dead code/imports).

### Session B — Vercel deployment
- Diagnosed the root-URL 404 (files in `public/`, Vercel served repo root) → fixed `vercel.json` `outputDirectory: public`. Re-imported the project; site live at welcome2gh.vercel.app.
- Created **`deploy.ps1`** (analyze + test + build + sync public + push).

### Session C — admin delete consistency
- Soft-deleted places/posts/alerts were lingering in admin lists and realtime feeds. Added `active=true` filtering to `getAllPlacesForAdmin`, `getAllPostsForAdmin`, `getAllAlertsForAdmin`, `watchPosts`, `watchAlerts`, `getPlace`.

### Session D — Map overhaul (the big one)
- **Architecture:** `geo_math.dart` (Web-Mercator world↔screen projection, metres↔pixels, haversine, viewport), `marker_layout.dart` (typed MarkerSpec + ScreenBox + priority collision resolver), `map_state.dart` (immutable `MapViewState` + controller, single source of truth, unidirectional flow). **34 unit tests** (distance, projection at zoom 0/max, antimeridian, bounding-box collisions).
- **Fixed 14 map bugs (M1–M14):** animation-controller double-dispose crash, danger-zone radius (real `radius_meters` + `useRadiusInMeter`), expired alerts hidden, all categories filterable, honest alert count, stale selected card cleared, locate-on-first-tap, location-permission feedback, no stream leak, no banner overlap, zoom clamping, search-vs-follow, go_router nav, distinct marker colors.
- **Features:** tap category → fly to nearest place; icon markers; rich place card; "Search this area"; nearby list sheet; glassmorphism overlays; legibility scrims; chip icons. (Dark theme-aware tiles added, then reverted to light Voyager by preference.)

### Session E — Directions real per-mode times
- The car-only public OSRM returned identical times for all modes. Switched to FOSSGIS `routed-car/bike/foot` engines → Drive/Bike/Walk now differ. Added the map card's **real routed walk/drive ETA** (`routing_service.dart`).

### Session F — Map locate button (web) + fly-to-nearest
- `getLastKnownPosition` is unsupported on web and was aborting setup; guarded it + added `getCurrentPosition` (triggers the browser permission prompt). Tapping a category flies to the nearest match.

### Session G — Community v2
- Tap image → fullscreen (pinch-zoom); double-tap to like; **video posts** (pick/upload/inline player + "Open video" fallback for iPhone .mov/HEVC); **bookmark posts**; **notifications** (bell + badge + screen + DB triggers); 3-dot delete/report; pull-to-refresh; skeletons. Fixed missing list keys (state leak) and a re-created notification stream.
- SQL: `community_upgrade.sql` (media columns, post_favorites, post_reports, notify triggers).

### Session H — Saved screen crash
- Favouriting a place that was later deleted made `places(*)` embed null → null-cast crash. Now skips null embeds.

### Session I — Home redesign
- Removed the floating `+` that overlapped cards → **Quick Actions row**. Replaced fake "THREE WORLDS" stock cards with a **real "Top-rated in Accra"** carousel. Full-bleed place-card thumbnails.

### Session J — Light theme fix
- Profile menu used literal white text → invisible on white cards in light mode. Switched to theme-aware color. Audited the rest (clean).

### Session K — Location accuracy + Add Place picker
- Diagnosed: code/DB never swap coordinates — wrong pins came from **typing lat/lng by hand**. Built a **map location picker** in Add Place (Nominatim search + tap map + GPS). Added `geocoding_service.dart`.
- Corrected real place coordinates (`fix_place_coords.sql`); found a **longitude sign error** (positive instead of negative) on user-added places like Atlantic Mall / Academic City.

### Session L — Admin edit everything
- Admin can now **edit** (not just delete): Places (full editor + map picker), Posts (text), Alerts (full), Fair Prices (amount). SQL: `admin_edit_policies.sql` (admin update/delete policies).

### Session M — Sign-out + the caching saga
- Sign-out hardened: router auth guard + navigate-to-login-first + timeout.
- **Root cause of "my changes never appear":** the Flutter offline **service worker** + browser **HTTP cache** kept serving old `main.dart.js` (proven in a controlled browser). Fixed permanently: built with `--pwa-strategy=none` (no service worker) + `Cache-Control: no-store` headers in `vercel.json` (verified live). One-time Safari "Clear History and Website Data" needed to drop the previously-stuck service worker; after that, every deploy loads fresh.

---

## 9. SQL to run in Supabase (SQL Editor → Run; all idempotent)
1. **`supabase/community_upgrade.sql`** → video, favorites, notifications, reports
2. **`supabase/admin_edit_policies.sql`** → admin can edit posts / alerts / fair-prices
3. **`supabase/fix_place_coords.sql`** (+ Atlantic Mall / Academic City) → correct coordinates *(or just use the place editor)*

## 10. Key files
| File | Role |
|---|---|
| lib/core/supabase_service.dart | Every backend call |
| lib/core/router.dart | Routes + auth guard |
| lib/core/geo/geo_math.dart | Coordinate math utility |
| lib/core/geo/marker_layout.dart | Marker collision system |
| lib/features/map/map_state.dart | Map single source of truth |
| lib/features/map/map_screen.dart | Map UI |
| lib/features/add_place/add_place_screen.dart | Add/Edit place + map picker |
| lib/features/admin/admin_dashboard.dart | Admin view/verify/edit/delete |
| lib/features/community/community_screen.dart | Feed, video, likes, bookmarks |
| lib/features/notifications/notifications_screen.dart | Notifications |
| lib/shared/theme/app_theme.dart | Themes + AppColors |
| supabase/schema.sql | Full DB schema + RLS + triggers |
| deploy.ps1 | One-command deploy |
| vercel.json | Static hosting config + no-cache headers |

## 11. Outstanding
🔴 Run the 3 SQL files · Google OAuth (Supabase dashboard) · AI Guide edge function + ANTHROPIC_API_KEY
🟡 Move admin secret (`W2G-ADMIN-2026`) server-side · iPhone `.mov` transcoding for guaranteed inline video · Saved-Posts browse screen · wire push notifications
🟢 Android APK (`flutter build apk --release`)

## 12. Deploy workflow
```powershell
.\deploy.ps1 "what you changed"
```
→ analyze + test + build (no service worker) + sync `public/` + push → Vercel auto-publishes in ~30–60s.
```
