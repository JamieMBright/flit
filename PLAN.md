# PLAN.md — App Store & Play Store Launch Strategy

**Created**: 2026-03-08
**Status**: Draft — awaiting approval
**Constraint**: No Mac available. iPhone + iPad available for testing/Transporter.

---

## Current State

### What Exists
- **Web deployment**: Fully automated via GitHub Actions → GitHub Pages (on merge to `main`)
- **Android CI build**: APK built in CI but not signed for store, not uploaded anywhere
- **iOS CI build**: Does not exist (no macOS runner, no Xcode project)
- **No `android/` or `ios/` directories**: Generated on-the-fly in CI with `flutter create`
- **No signing keys**: No Android keystore, no Apple certificates/provisioning profiles
- **No store accounts**: No Apple Developer Program ($99/yr) or Google Play Console ($25 one-time) mentioned
- **No Fastlane or Codemagic**: No automated store upload pipeline

### What's Scaffolded (Models exist, no SDK integration)
- **Subscription model** (`subscription.dart`): 4 tiers defined (free/$2.99mo/$24.99yr/$49.99 lifetime)
- **Ad config** (`ad_config.dart`): Placements, rate limits, premium gates — no AdMob/Unity SDK
- **IAP receipts** (`iap_receipt.dart`): DB table exists — no payment provider
- **Gold packages**: 4 packages in shop UI ($0.99–$19.99) — buttons exist but don't process payment
- **Economy system**: Fully implemented (coins, cosmetics, promotions, dynamic pricing)

---

## Blockers to Store Launch

### Tier 0 — Infrastructure (Before Anything Else)

| # | Blocker | What's Needed | Effort |
|---|---------|---------------|--------|
| 0.1 | **No Apple Developer Account** | Enroll at developer.apple.com ($99/yr). Can be done from iPhone/iPad. Required for ANY iOS distribution. | 1 day (approval can take 24-48h) |
| 0.2 | **No Google Play Developer Account** | Register at play.google.com/console ($25 one-time). | 1 hour |
| 0.3 | **No platform directories** | Commit `android/` and `ios/` scaffolds to repo (currently generated ephemerally in CI). Need stable config for signing, icons, permissions. | 1 hour |
| 0.4 | **No app icons** | Need 1024x1024 icon for App Store, adaptive icon for Android. Generate with `flutter_launcher_icons` package. | 2 hours |
| 0.5 | **No splash screen** | Required for professional launch. Use `flutter_native_splash` package. | 1 hour |
| 0.6 | **Privacy Policy URL** | Required by BOTH stores. Host on GitHub Pages or Vercel. Must cover: data collected, Supabase usage, analytics, ad tracking. | 2 hours |

### Tier 1 — Revenue (Launch Blockers)

| # | Blocker | What's Needed | Effort |
|---|---------|---------------|--------|
| 1.1 | **No payment SDK** | Integrate `in_app_purchase` (Flutter official) or `revenue_cat` (recommended — handles receipt validation, cross-platform subs, webhooks). RevenueCat has a free tier up to $2.5k/mo revenue. | 2-3 days |
| 1.2 | **No ad SDK** | Integrate `google_mobile_ads` (AdMob). Create AdMob account, register app, get ad unit IDs for banner/interstitial/rewarded. Wire to existing `AdConfig` model. | 1-2 days |
| 1.3 | **No server-side receipt validation** | Create Supabase Edge Function to validate Apple/Google receipts. Without this, users can forge purchases. RevenueCat handles this automatically if chosen. | 1-2 days (or free with RevenueCat) |
| 1.4 | **No subscription purchase flow** | Build paywall screen, wire subscription tiers to IAP products, handle restore purchases, manage entitlements. | 2 days |
| 1.5 | **Gold package purchase flow** | Wire existing shop gold tab to IAP. 4 products: Pouch ($0.99), Sack ($4.99), Chest ($9.99), Vault ($19.99). | 1 day |
| 1.6 | **App Store product registration** | Create IAP products in App Store Connect and Google Play Console matching the product IDs. | 2 hours per store |
| 1.7 | **Define membership tiers & entitlements** | Finalize what each membership tier unlocks: Free vs Premium vs Pro. Map features to tiers (e.g., ad-free, unlimited H2H, exclusive companions, regional game modes, custom avatars, priority matchmaking). Define tier names, pricing, trial periods, and family sharing rules. Document in `MEMBERSHIPS.md`. | 1-2 days |

### Tier 2 — Signing & Building

| # | Blocker | What's Needed | Effort |
|---|---------|---------------|--------|
| 2.1 | **Android signing keystore** | Generate release keystore, create `key.properties`, configure `build.gradle` for release signing. Store keystore password in GitHub Secrets. | 1 hour |
| 2.2 | **Android App Bundle** | Play Store requires AAB (not APK). Change CI from `flutter build apk` to `flutter build appbundle`. | 15 min |
| 2.3 | **iOS signing (no Mac)** | Use **Codemagic** (free tier: 500 min/mo on macOS). Codemagic handles code signing, provisioning profiles, and building on macOS without you owning one. OR use GitHub Actions macOS runners ($0.08/min). | 2-3 hours setup |
| 2.4 | **iOS bundle identifier** | Register app ID in Apple Developer portal. Set bundle ID (e.g., `com.flit.game`). | 30 min |

### Tier 3 — Store Listings

| # | Blocker | What's Needed | Effort |
|---|---------|---------------|--------|
| 3.1 | **App Store listing** | Title, subtitle, description, keywords, category (Games → Trivia), screenshots (6.7" + 5.5" iPhone, iPad), preview video (optional). | 3-4 hours |
| 3.2 | **Play Store listing** | Title, short/full description, category (Games → Trivia), feature graphic (1024x500), screenshots (phone + tablet), content rating questionnaire. | 2-3 hours |
| 3.3 | **Age rating** | IARC rating for Play Store (automatic questionnaire). App Store also requires age rating. Game has no violence/adult content — should be 4+/Everyone. | 30 min |
| 3.4 | **Export compliance** | App Store asks about encryption. Supabase uses HTTPS (exempt). Mark as "uses exempt encryption" → add `ITSAppUsesNonExemptEncryption = NO` to Info.plist. | 15 min |

### Tier 4 — Moderation & Safety (Pre-Launch Features)

These are from the existing PLAN.md features list — required before public launch:

| # | Feature | Why It Blocks Launch | Effort |
|---|---------|---------------------|--------|
| 4.1 | **User Ban System** | Can't launch without ability to remove abusive users | Medium |
| 4.2 | **Player Report Queue** | Users need a way to report bad actors (store requirement for social apps) | Medium |
| 4.3 | **Admin Audit Log** | Accountability for moderation actions | Medium |
| 4.4 | **Force Update Gate** | Breaking API changes will crash old versions without this | Medium |
| 4.5 | **GDPR Compliance Tools** | Legal requirement for EU users. Data export + deletion must work. | Medium |
| 4.6 | **Content Moderation** | Usernames must be filterable. Required by both stores for social/multiplayer. | Low |

---

## CI/CD Deployment Strategy

### Current Flow (Web Only)
```
merge to main → CI (lint, test, build) → GitHub Pages deploy → smoke test → version bump
```

### Target Flow (All Platforms)
```
                                    ┌─→ GitHub Pages (web)
merge to main → CI (lint, test) ──→ ├─→ Play Store (Android) via internal track
                                    └─→ TestFlight (iOS) via Codemagic

PR branches   → CI (lint, test) ──→ ┌─→ Dev GH Pages (web preview)
                                    └─→ APK artifact (download from Actions)
```

### Phase 1: Repoint GitHub Pages to Dev Branch

**Goal**: `main` merges trigger store deployments, NOT the public web preview. Move the web preview to a `dev` branch so people can test without store submission.

**Changes to `ci.yml`**:

1. **New workflow: `ci-dev.yml`** — Triggers on push to `dev` branch
   - Runs lint, test, build-web
   - Deploys to GitHub Pages (the public preview URL)
   - This becomes the "test before store" URL

2. **Modify `ci.yml`** — Still triggers on push to `main`
   - Removes GitHub Pages deployment from `main`
   - Adds: Upload signed AAB to Play Store (internal test track)
   - Adds: Trigger Codemagic iOS build → TestFlight
   - Keeps: Vercel deploy (error telemetry backend)
   - Keeps: Version bump

3. **Branch strategy**:
   ```
   feature branches → PR → dev (web preview on GH Pages)
                              ↓
                          PR → main (store releases)
   ```

### Phase 2: Android CI/CD (GitHub Actions)

```yaml
# New job in ci.yml
deploy-android:
  name: Deploy to Play Store
  needs: [lint-and-test]
  runs-on: ubuntu-latest
  if: github.ref == 'refs/heads/main'
  steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
    - run: flutter build appbundle --release
    - uses: r0adkll/upload-google-play@v1
      with:
        serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_SERVICE_ACCOUNT }}
        packageName: com.flit.game
        releaseFiles: build/app/outputs/bundle/release/app-release.aab
        track: internal  # Start with internal testing, promote manually
```

**Required secrets**:
- `PLAY_STORE_SERVICE_ACCOUNT` — Google Play API service account JSON
- `ANDROID_KEYSTORE_BASE64` — Base64-encoded release keystore
- `ANDROID_KEY_ALIAS` — Key alias
- `ANDROID_KEY_PASSWORD` — Key password
- `ANDROID_STORE_PASSWORD` — Store password

### Phase 3: iOS CI/CD (Codemagic)

Since you don't have a Mac, **Codemagic** is the recommended path:

1. **Connect repo** to Codemagic (codemagic.io — free tier: 500 build min/mo on macOS)
2. **Configure in `codemagic.yaml`** (added to repo root):
   ```yaml
   workflows:
     ios-release:
       name: iOS Release
       triggering:
         events: [push]
         branch_patterns:
           - pattern: main
       environment:
         flutter: 3.29.3
         xcode: latest
         cocoapods: default
         groups:
           - app_store_credentials  # configured in Codemagic UI
       scripts:
         - name: Set up code signing
           script: |
             keychain initialize
             app-store-connect fetch-signing-files "com.flit.game" --type IOS_APP_STORE
             keychain add-certificates
             xcode-project use-profiles
         - name: Build
           script: flutter build ipa --release --export-options-plist=/Users/builder/export_options.plist
       artifacts:
         - build/ios/ipa/*.ipa
       publishing:
         app_store_connect:
           api_key: $APP_STORE_CONNECT_API_KEY
           key_id: $APP_STORE_CONNECT_KEY_ID
           issuer_id: $APP_STORE_CONNECT_ISSUER_ID
           submit_to_testflight: true
   ```
3. **Apple credentials** stored in Codemagic UI (not in repo):
   - App Store Connect API Key (generated in App Store Connect → Users & Access → Keys)
   - Can be created from browser — no Mac needed
4. **Codemagic manages signing** automatically — fetches/creates provisioning profiles

**Alternative**: GitHub Actions macOS runner
```yaml
deploy-ios:
  runs-on: macos-latest  # $0.08/min
  steps:
    - uses: subosito/flutter-action@v2
    - run: flutter build ipa --release
    # Upload to TestFlight via Fastlane or xcrun altool
```
This costs more than Codemagic free tier but keeps everything in one CI system.

### Phase 4: Promotion Pipeline

```
Codemagic/CI builds → TestFlight (iOS) / Internal Track (Android)
       ↓                        ↓
  Manual review            Manual review
       ↓                        ↓
  Promote to App Store    Promote to Production
  (via App Store Connect   (via Play Console
   web or Transporter       web UI)
   app on iPhone)
```

You can promote builds from your iPhone/iPad:
- **iOS**: App Store Connect app (free on App Store) or web browser
- **Android**: Play Console web UI (play.google.com/console)

---

## Revenue Integration Plan

### Recommended: RevenueCat (Free Tier)

RevenueCat is recommended over raw `in_app_purchase` because:
- Handles receipt validation server-side (eliminates blocker 1.3)
- Cross-platform subscriptions (iOS + Android + web) with one API
- Manages entitlements (premium tier check)
- Free up to $2.5k/mo revenue (then 1% of revenue)
- Dashboard for revenue analytics
- No Mac required for setup (web dashboard)

### Product Catalog

| Product ID | Type | Price | Description |
|-----------|------|-------|-------------|
| `flit_premium_monthly` | Auto-renewable sub | $2.99/mo | Remove ads, unlock Live Group |
| `flit_premium_annual` | Auto-renewable sub | $24.99/yr | Same perks, 30% discount |
| `flit_premium_lifetime` | Non-consumable | $49.99 | Permanent premium |
| `flit_gold_pouch` | Consumable | $0.99 | 500 coins |
| `flit_gold_sack` | Consumable | $4.99 | 3,000 coins |
| `flit_gold_chest` | Consumable | $9.99 | 7,500 coins |
| `flit_gold_vault` | Consumable | $19.99 | 20,000 coins |

### Ad Integration (AdMob)

| Placement | Type | Trigger | Premium Users |
|-----------|------|---------|---------------|
| Home screen footer | Banner | Always visible | Hidden |
| Pre-H2H result | Interstitial | Before result reveal (5min cooldown, max 3/session) | Skipped |
| Free play | Rewarded | User opts in for +1 play | Still available (bonus) |
| Bonus coins | Rewarded | User opts in for +50 coins | Still available (bonus) |

**Required**:
- Create AdMob account (admob.google.com)
- Register iOS + Android apps
- Create ad units for each placement
- Store ad unit IDs in environment config (not hardcoded)

---

## Implementation Order

### Sprint 1: Foundation (Week 1)
1. Enroll in Apple Developer Program + Google Play Console
2. Generate and commit `android/` and `ios/` platform directories
3. Configure app icons and splash screen
4. Set up Android release signing (keystore + `key.properties`)
5. Create privacy policy page (host on Vercel or GH Pages)
6. Set up Codemagic account and connect repo

### Sprint 2: Revenue (Week 2)
1. **Define membership tiers** — Finalize Free/Premium/Pro feature matrix, pricing, trial periods. Document in `MEMBERSHIPS.md`
2. Add `purchases_flutter` (RevenueCat SDK) to `pubspec.yaml`
3. Create products in App Store Connect + Play Console (matching tier definitions)
4. Configure RevenueCat project with both stores
5. Build paywall screen (subscription purchase UI)
6. Wire gold package buttons to consumable IAP
7. Implement entitlement checks (replace mock subscription tier)
8. Add `google_mobile_ads` and wire to existing `AdConfig` placements

### Sprint 3: CI/CD Pipeline (Week 2-3)
1. Create `dev` branch, repoint GitHub Pages to `dev`
2. Modify `ci.yml`: remove GH Pages from `main`, add store upload
3. Add `ci-dev.yml` for dev branch web preview
4. Configure Android AAB build + Play Store upload (internal track)
5. Configure Codemagic iOS build + TestFlight upload
6. Add required secrets to GitHub + Codemagic

### Sprint 4: Moderation & Safety (Week 3-4)
1. Implement User Ban System (Tier 4.1)
2. Implement Player Report Queue (Tier 4.2)
3. Implement Admin Audit Log (Tier 4.3)
4. Implement Force Update Gate (Tier 4.4)
5. Add username content filter (profanity list)
6. GDPR compliance: fix auth deletion, add data export

### Sprint 5: Store Submission (Week 4-5)
1. Prepare store screenshots (phone + tablet for each platform)
2. Write store descriptions and metadata
3. Complete age rating questionnaires
4. Submit to App Store Review (typically 24-48h)
5. Submit to Google Play Review (typically 1-3 days)
6. Internal testing round via TestFlight + Play internal track
7. Promote to production after testing

---

## No-Mac Workflow Summary

| Task | How Without a Mac |
|------|-------------------|
| Apple Developer enrollment | developer.apple.com from any browser |
| App Store Connect management | appstoreconnect.apple.com from browser, or App Store Connect app on iPhone/iPad |
| iOS builds | Codemagic (cloud macOS, free tier 500 min/mo) |
| iOS signing/provisioning | Codemagic auto-manages via App Store Connect API |
| TestFlight testing | TestFlight app on iPhone/iPad |
| Upload to App Store | Codemagic auto-uploads, or Transporter app on iPhone |
| Promote to production | App Store Connect web/app |
| Android builds | GitHub Actions (ubuntu runner, free) |
| Play Store management | play.google.com/console from any browser |
| Internal testing (Android) | Play Console → Internal testing → install on device |

---

## Secrets & Credentials Checklist

### GitHub Secrets (for CI)
- [ ] `ANDROID_KEYSTORE_BASE64` — Release keystore (base64)
- [ ] `ANDROID_KEY_ALIAS` — Key alias
- [ ] `ANDROID_KEY_PASSWORD` — Key password
- [ ] `ANDROID_STORE_PASSWORD` — Store password
- [ ] `PLAY_STORE_SERVICE_ACCOUNT` — Google Play API JSON
- [ ] `REVENUECAT_API_KEY_ANDROID` — RevenueCat Android key
- [ ] `REVENUECAT_API_KEY_IOS` — RevenueCat iOS key
- [ ] `ADMOB_APP_ID_ANDROID` — AdMob Android app ID
- [ ] `ADMOB_APP_ID_IOS` — AdMob iOS app ID

### Codemagic (for iOS builds)
- [ ] App Store Connect API Key (key ID, issuer ID, .p8 file)
- [ ] Bundle identifier registered (`com.flit.game`)
- [ ] RevenueCat iOS API key

### RevenueCat Dashboard
- [ ] Project created
- [ ] iOS app registered with shared secret
- [ ] Android app registered with Play service account
- [ ] Products created matching catalog above
- [ ] Entitlement "premium" created and linked to subscription products

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Apple review rejection | 1-2 week delay | Follow App Store Review Guidelines, ensure moderation tools are in place before submission |
| Codemagic free tier limits (500 min) | Builds stop mid-month | Limit iOS builds to `main` only, optimize build time, upgrade to paid if needed ($38/mo) |
| RevenueCat migration later | Revenue tracking disruption | Start with RevenueCat from day 1, avoid raw `in_app_purchase` |
| Store screenshots need real devices | Can't take iOS screenshots | Use Codemagic simulator screenshots, or take from physical iPhone/iPad |
| Ad revenue low at launch | Negligible income | Focus on IAP/subscriptions as primary revenue, ads are supplementary |
| GDPR complaint before tools ready | Legal risk | Implement data export + deletion before EU-targeted launch |
