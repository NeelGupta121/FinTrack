# Deploying FinTrack Web to Render (via GitHub)

This gives you a public URL for the Flutter **web** build that redeploys
automatically on every push to `master`. It does not replace the APK — it's the
browser version of the same app.

## What's in the repo

| File | Purpose |
|------|---------|
| `render.yaml` | Render Blueprint: static site, SPA rewrite, cache/security headers |
| `scripts/render-build.sh` | Installs the pinned Flutter SDK, runs `flutter build web --release` |

## One-time setup

1. **Push these files to `master`** (they must exist on the branch Render reads).
2. Go to **https://dashboard.render.com** → **New** → **Blueprint**.
3. **Connect the GitHub repo** (`NeelGupta121/FinTrack`) and authorise Render.
   Render detects `render.yaml` automatically.
4. Confirm the plan — a **static site is free**. Click **Apply**.
5. First build takes ~5-8 min (it downloads the Flutter SDK). Later builds are
   faster because the SDK directory is cached.
6. You get a URL like `https://fintrack-web.onrender.com`.

## How auto-deploy works

```
git push origin master  ──▶  GitHub webhook  ──▶  Render build
                                                  ├─ scripts/render-build.sh
                                                  │    ├─ fetch Flutter 3.24.0
                                                  │    ├─ flutter pub get
                                                  │    └─ flutter build web --release
                                                  └─ publish ./build/web to CDN
```

Every push to `master` triggers a fresh deploy. Render also builds a preview for
pull requests if you enable **Preview Environments** on the service.

## ⚠️ API keys: do not bake them into the web build

The build script deliberately passes **no** `--dart-define` API keys.

Anything compiled into a web build lands in the **public JavaScript bundle** —
any visitor can open DevTools and read it. That is strictly worse than the APK
case (where at least extraction takes a step). So on web:

- **Mutual-fund NAVs work** (mfapi.in is keyless).
- **Stock/ETF prices are disabled** (needs Alpha Vantage key).
- **AI features are disabled** unless the user enters their own key at runtime.

If you want AI on the public web build, the correct fix is a **server-side
proxy** that holds the key (the repo already has a scaffolded Supabase AI proxy
via `SUPABASE_URL` / `SUPABASE_ANON_KEY`), not a `--dart-define`.

## Notes and gotchas

- **SPA routing**: the `rewrite /* → /index.html` rule is required. Without it,
  refreshing on a deep link (e.g. `/investments`) returns 404.
- **Stale build after deploy**: `index.html` and `flutter_service_worker.js` are
  sent `no-cache` for this reason. If you still see an old version, hard-refresh
  (Flutter's service worker caches aggressively).
- **Data is per-browser**: FinTrack stores everything locally (Hive → IndexedDB
  on web). The web deploy does **not** share data with your phone, and clearing
  site data wipes it. Use **Settings → Export data** to move data between them.
- **Flutter version is pinned** to `3.24.0` in `scripts/render-build.sh`. Bump it
  there (and in `.github/workflows/flutter-ci.yml`) together.
- **Free tier**: static sites don't sleep, but build minutes are limited.

## Verifying a deploy

1. Open the Render service → **Logs**; the build ends with `==> Built build/web`.
2. Visit the URL; the dashboard should render (onboarding on first visit).
3. Deep-link test: open `<url>/investments` directly — it must load, not 404.
