# Flit - Setup Guide

Everything you need to get the error telemetry pipeline and GPU rendering working.

---

## 1. Texture Assets (Required for Shader Rendering)

The shader expects 4 texture files. Download and place them in `assets/textures/`:

| File | Source | License |
|------|--------|---------|
| `satellite.jpg` | [NASA Blue Marble](https://visibleearth.nasa.gov/collection/1484/blue-marble) | Public Domain |
| `heightmap.jpg` | [ETOPO1](https://www.ncei.noaa.gov/products/etopo-global-relief-model) | Public Domain |
| `shore_dist.png` | Generate from Natural Earth coastlines (or use a Euclidean distance transform) | Public Domain |
| `city_lights.jpg` | [NASA Earth at Night](https://earthobservatory.nasa.gov/features/NightLights) | Public Domain |

All textures should be equirectangular projection. Recommended resolution: 2048x1024 or 4096x2048.

If textures are missing, the app falls back to the Canvas 2D legacy renderer automatically.

---

## 2. Vercel Error Telemetry (Required for Error Logging)

### 2a. Deploy to Vercel

```bash
# Install Vercel CLI if not already installed
npm i -g vercel

# From the project root (where vercel.json lives)
vercel

# Follow prompts to link to your Vercel account
# The api/ directory is auto-detected as serverless functions
```

### 2b. Set Vercel Environment Variables

In the Vercel dashboard (Settings > Environment Variables), add:

| Variable | Value | Required |
|----------|-------|----------|
| `VERCEL_ERRORS_API_KEY` | Any strong secret string (e.g. `openssl rand -hex 32`) | Yes |
| `GITHUB_TOKEN` | GitHub Personal Access Token with `repo` scope | Yes (for direct GitHub logging) |
| `GITHUB_REPO` | `<your-username>/flit` (e.g. `JamieMBright/flit`) | Yes |
| `GITHUB_LOG_PATH` | `logs/runtime-errors.jsonl` | No (this is the default) |
| `GITHUB_BRANCH` | `main` | No (this is the default) |

**Creating the GitHub Token:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scope: `repo` (full control of private repositories)
4. Copy the token and add it as `GITHUB_TOKEN` in Vercel

### 2c. Verify Deployment

```bash
# Health check (no auth required)
curl https://your-project.vercel.app/api/health

# Test error POST
curl -X POST https://your-project.vercel.app/api/errors \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "timestamp": "2024-01-01T00:00:00Z",
    "sessionId": "test-session",
    "appVersion": "0.1.0+1",
    "platform": "web",
    "deviceInfo": "test",
    "severity": "error",
    "error": "Test error from curl"
  }'

# Verify it was logged to GitHub
# Check logs/runtime-errors.jsonl in your repo
```

---

## 3. GitHub Secrets (Required for CI/CD)

In your GitHub repo (Settings > Secrets and variables > Actions), add:

| Secret | Purpose |
|--------|---------|
| `VERCEL_ERRORS_API_KEY` | Same key as Vercel env var. Used by `fetch-errors.yml` workflow. |

The `fetch-errors.yml` workflow runs daily as a backup/reconciler. With the Vercel->GitHub direct logging, errors are committed immediately on POST, but the Action catches any that were missed.

---

## 4. Flutter Build Environment

```bash
# Ensure Flutter 3.16+ (required for fragment shader support)
flutter --version

# Get dependencies
flutter pub get

# Run on web (shader compiles to WebGL)
flutter run -d chrome

# Run on Android (shader compiles via SPIR-V)
flutter run -d android

# Run on iOS (shader compiles via Metal/SPIR-V)
flutter run -d ios
```

### Passing API keys to the Flutter app

```bash
# Development (connects to your Vercel endpoint)
flutter run -d chrome \
  --dart-define=ERROR_ENDPOINT=https://your-project.vercel.app/api/errors \
  --dart-define=VERCEL_ERRORS_API_KEY=your-api-key

# Production build
flutter build web --release \
  --dart-define=ERROR_ENDPOINT=https://your-project.vercel.app/api/errors \
  --dart-define=VERCEL_ERRORS_API_KEY=your-api-key
```

---

## 5. Error Pipeline Architecture

```
Flutter App                    Vercel                      GitHub
┌─────────────────┐            ┌──────────────┐            ┌──────────────────┐
│ ErrorService     │──POST────>│ /api/errors   │──PUT─────>│ logs/runtime-    │
│  ├─ reportError  │  (batch)  │  ├─ validate  │ (GitHub   │ errors.jsonl     │
│  ├─ 60s flush    │           │  ├─ enrich    │  API)     │                  │
│  └─ lifecycle    │           │  └─ respond   │           │ fetch-errors.yml │
│     flush        │           │               │           │  (daily backup)  │
│                  │           │ /api/health   │           └──────────────────┘
│ DevOverlay       │           │  (no auth)    │
│  (debug only)    │           └──────────────┘
└─────────────────┘
```

**Data flow:**
1. Flutter app captures errors via `FlutterError.onError`, `PlatformDispatcher.onError`, and `runZonedGuarded`
2. Errors queue in `ErrorService` and flush every 60 seconds (or on app background/close)
3. Vercel endpoint validates, enriches with server timestamp, and appends to GitHub repo via Contents API
4. `fetch-errors.yml` runs daily as a backup reconciler

---

## 6. Checklist

- [ ] Texture files placed in `assets/textures/`
- [ ] Vercel project deployed
- [ ] `VERCEL_ERRORS_API_KEY` set in Vercel env vars
- [ ] `GITHUB_TOKEN` set in Vercel env vars (with `repo` scope)
- [ ] `GITHUB_REPO` set in Vercel env vars
- [ ] `VERCEL_ERRORS_API_KEY` set in GitHub Actions secrets
- [ ] Health check returns 200: `curl https://your-project.vercel.app/api/health`
- [ ] Test POST returns accepted: verify with curl
- [ ] Flutter builds with `--dart-define` flags
