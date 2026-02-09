# Secrets & API Keys

This document describes the secrets required for Flit's runtime error
telemetry pipeline.

---

## `VERCEL_ERRORS_API_KEY`

**Purpose:** Authenticates requests to the error telemetry endpoint
(`/api/errors`) hosted on Vercel. Both the serverless function and the
Flutter app (at runtime) use this key.

**Used by:**

| Component | How it's used |
|-----------|---------------|
| Vercel serverless function (`api/errors/index.js`) | Validates incoming `X-API-Key` header |
| Flutter app (`ErrorService`) | Sends error payloads with `X-API-Key` header |
| GitHub Action (`fetch-errors.yml`) | Fetches stored errors via GET with `X-API-Key` header |

---

### Setting in Vercel Environment Variables

1. Go to your Vercel project dashboard.
2. Navigate to **Settings > Environment Variables**.
3. Add a new variable:
   - **Name:** `VERCEL_ERRORS_API_KEY`
   - **Value:** A securely generated random string (minimum 32 characters).
   - **Environments:** Production, Preview, Development.
4. Click **Save**.

Generate a strong key:

```bash
openssl rand -base64 32
```

---

### Setting in GitHub Secrets

1. Go to your GitHub repository.
2. Navigate to **Settings > Secrets and variables > Actions**.
3. Click **New repository secret**.
4. Add:
   - **Name:** `VERCEL_ERRORS_API_KEY`
   - **Secret:** The same value used in Vercel.
5. Click **Add secret**.

This secret is consumed by the `fetch-errors.yml` workflow to pull
error logs from the Vercel endpoint and append them to
`logs/runtime-errors.jsonl`.

---

### Using Locally for Testing

For local development and testing, set the key as an environment
variable before running the app or making curl requests:

```bash
# Export for the current shell session.
export VERCEL_ERRORS_API_KEY="your-secret-key-here"

# Pass to Flutter via --dart-define.
flutter run -d chrome \
  --dart-define=VERCEL_ERRORS_API_KEY=$VERCEL_ERRORS_API_KEY

# Test the endpoint directly with curl.
# POST an error:
curl -X POST https://flit-olive.vercel.app/api/errors \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $VERCEL_ERRORS_API_KEY" \
  -d '{
    "timestamp": "2025-01-01T00:00:00.000Z",
    "sessionId": "test-session-id",
    "appVersion": "0.1.0+1",
    "platform": "web",
    "deviceInfo": "curl-test",
    "severity": "warning",
    "error": "Test error from local development"
  }'

# GET errors:
curl -H "X-API-Key: $VERCEL_ERRORS_API_KEY" \
  "https://flit-olive.vercel.app/api/errors?limit=5"
```

You can also create a `.env` file in the project root (already in
`.gitignore`) for convenience:

```bash
# .env (never commit this file)
VERCEL_ERRORS_API_KEY=your-secret-key-here
```

---

### Security Notes

- **Never commit** the API key to source control.
- **Rotate the key** if it is ever exposed. Update both Vercel and
  GitHub Secrets simultaneously.
- The key is used for authentication only. All error payloads are
  transmitted over HTTPS.
- In release builds the key is embedded via `--dart-define` and is
  compiled into the binary. This is acceptable for a telemetry
  endpoint but should not be used for high-security APIs.
