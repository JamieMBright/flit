# Flit Architecture — State, Persistence & Flow Reference

> How game state, settings, and stats are preserved across every user interaction.

---

## System Overview

```mermaid
graph TB
    subgraph "Client — Flutter App"
        UI["UI Layer<br/>(Screens & Widgets)"]
        RP["Riverpod Providers<br/>(AccountProvider, etc.)"]
        GS["GameSettings Singleton<br/>(ChangeNotifier)"]
        UPS["UserPreferencesService<br/>(Debounced Writer)"]
        OQ["Offline Write Queue<br/>(SharedPreferences)"]
        AS["AuthService"]
        LS["LeaderboardService"]
        CS["ChallengeService"]
        MS["MatchmakingService"]
        FS["FriendsService"]
        ES["ErrorService"]
        AM["AudioManager"]
    end

    subgraph "Backend — Supabase (PostgreSQL + Auth)"
        SA["Supabase Auth<br/>(JWT sessions)"]
        DB[("PostgreSQL")]
        RLS["Row Level Security"]
    end

    subgraph "Backend — Vercel Serverless"
        VE["/api/errors<br/>(Error Telemetry)"]
        VH["/api/health<br/>(Keep-alive + Status)"]
    end

    subgraph "External — GitHub"
        GH["logs/runtime-errors.jsonl<br/>(Durable error log)"]
    end

    UI --> RP
    UI --> GS
    RP --> UPS
    GS --> UPS
    UPS --> DB
    UPS --> OQ
    OQ -.->|retry on flush| DB
    AS --> SA
    LS --> DB
    CS --> DB
    MS --> DB
    FS --> DB
    ES --> VE
    VE --> GH
    VH -.->|cron ping| SA
    DB --> RLS
```

---

## Database Schema

```mermaid
erDiagram
    AUTH_USERS ||--o| PROFILES : "trigger creates"
    AUTH_USERS ||--o| USER_SETTINGS : has
    AUTH_USERS ||--o| ACCOUNT_STATE : has
    AUTH_USERS ||--o{ SCORES : submits
    AUTH_USERS ||--o{ FRIENDSHIPS : participates
    AUTH_USERS ||--o{ CHALLENGES : participates
    AUTH_USERS ||--o{ MATCHMAKING_POOL : queues

    PROFILES {
        uuid id PK
        text username
        text display_name
        text avatar_url
        int level
        int xp
        int coins
        int games_played
        int best_score
        bigint best_time_ms
        bigint total_flight_time_ms
        int countries_found
        int flags_correct
        int capitals_correct
        int outlines_correct
        int borders_correct
        int stats_correct
        int best_streak
        timestamptz updated_at
    }

    USER_SETTINGS {
        uuid user_id PK
        real turn_sensitivity
        boolean invert_controls
        boolean enable_night
        text map_style
        boolean english_labels
        text difficulty
        boolean sound_enabled
        float music_volume
        float effects_volume
        boolean notifications_enabled
        boolean haptic_enabled
        timestamptz updated_at
    }

    ACCOUNT_STATE {
        uuid user_id PK
        jsonb avatar_config
        jsonb license_data
        text_arr unlocked_regions
        text_arr owned_avatar_parts
        text_arr owned_cosmetics
        text equipped_plane_id
        text equipped_contrail_id
        text last_free_reroll_date
        text last_daily_challenge_date
        jsonb daily_streak_data
        jsonb last_daily_result
        timestamptz updated_at
    }

    SCORES {
        bigint id PK
        uuid user_id FK
        int score
        bigint time_ms
        text region
        int rounds_completed
        timestamptz created_at
    }

    FRIENDSHIPS {
        bigint id PK
        uuid requester_id FK
        uuid addressee_id FK
        text status
        timestamptz created_at
    }

    CHALLENGES {
        uuid id PK
        uuid challenger_id FK
        text challenger_name
        uuid challenged_id FK
        text challenged_name
        text status
        jsonb rounds
        uuid winner_id
        int challenger_coins
        int challenged_coins
        timestamptz created_at
        timestamptz completed_at
    }

    MATCHMAKING_POOL {
        uuid id PK
        uuid user_id FK
        text region
        text seed
        jsonb rounds
        int elo_rating
        text gameplay_version
        timestamptz created_at
        timestamptz matched_at
        uuid matched_with
        uuid challenge_id FK
    }

    SCORES }|--|| LEADERBOARD_GLOBAL : "view"
    SCORES }|--|| LEADERBOARD_DAILY : "view"
    SCORES }|--|| LEADERBOARD_REGIONAL : "view"

    LEADERBOARD_GLOBAL {
        int rank "ROW_NUMBER()"
        uuid user_id
        int score
        bigint time_ms
    }

    LEADERBOARD_DAILY {
        int rank "ROW_NUMBER()"
        uuid user_id
        int score
        text region "= daily"
    }

    LEADERBOARD_REGIONAL {
        int rank "PARTITION BY region"
        uuid user_id
        int score
        text region
    }
```

---

## Persistence Architecture

```mermaid
graph LR
    subgraph "In-Memory (Riverpod)"
        A["AccountState<br/>coins, xp, level, cosmetics,<br/>avatar, settings, streak..."]
    end

    subgraph "Debounced Writer"
        B["UserPreferencesService<br/>_profileDirty / _settingsDirty / _accountDirty"]
        T["2s Debounce Timer"]
    end

    subgraph "Supabase (PostgreSQL)"
        P["profiles"]
        S["user_settings"]
        AS2["account_state"]
    end

    subgraph "Fallback"
        Q["SharedPreferences<br/>pending_writes queue<br/>(max 50, 3 retries)"]
    end

    A -->|mutation| B
    B --> T
    T -->|flush| P
    T -->|flush| S
    T -->|flush| AS2
    T -.->|on failure| Q
    Q -.->|retry next flush| P
    Q -.->|retry next flush| S
    Q -.->|retry next flush| AS2
```

**Immediate flush triggers** (bypass 2s debounce):
- Game completion (`recordGameCompletion`)
- App lifecycle: `paused`, `hidden`, `detached`

**Periodic refresh**: Every 5 minutes, re-fetches from Supabase (skipped if pending writes exist).

---

## Flow 1 — On Login

```mermaid
sequenceDiagram
    actor User
    participant LoginScreen
    participant AuthService
    participant SupabaseAuth as Supabase Auth
    participant ProfilesDB as profiles table
    participant AccountProvider
    participant UserPrefsService as UserPreferencesService
    participant SettingsDB as user_settings table
    participant AccountDB as account_state table
    participant GameSettings

    User->>LoginScreen: Enter email + password
    LoginScreen->>AuthService: signInWithEmail(email, password)
    AuthService->>SupabaseAuth: signInWithPassword()
    SupabaseAuth-->>AuthService: JWT session + User object

    Note over SupabaseAuth: Session stored automatically<br/>in platform secure storage<br/>(web: localStorage)

    AuthService->>ProfilesDB: SELECT * FROM profiles WHERE id = user.id
    ProfilesDB-->>AuthService: Player row (stats, coins, level...)
    AuthService-->>LoginScreen: AuthState(player, isAuthenticated)

    LoginScreen->>AccountProvider: switchAccount(player)
    LoginScreen->>AccountProvider: loadFromSupabase(userId)

    par Parallel fetch — 3 tables
        AccountProvider->>UserPrefsService: load(userId)
        UserPrefsService->>ProfilesDB: SELECT * FROM profiles
        UserPrefsService->>SettingsDB: SELECT * FROM user_settings
        UserPrefsService->>AccountDB: SELECT * FROM account_state
    end

    UserPrefsService-->>AccountProvider: UserPreferencesSnapshot

    AccountProvider->>AccountProvider: _applySnapshot()<br/>(hydrate coins, xp, cosmetics,<br/>avatar, streak, etc.)
    AccountProvider->>GameSettings: hydrateFrom(snapshot)<br/>(_hydrating=true, no write-back)
    AccountProvider->>AccountProvider: _startPeriodicRefresh()<br/>(every 5 min)

    LoginScreen->>LoginScreen: Navigator.pushReplacement(HomeScreen)
```

---

## Flow 2 — On Refresh (Already Logged In)

```mermaid
sequenceDiagram
    actor Browser as User (web reload / app resume)
    participant Main as main()
    participant SupabaseSDK as Supabase SDK
    participant LoginScreen
    participant AuthService
    participant ProfilesDB as profiles table
    participant AccountProvider
    participant UserPrefsService as UserPreferencesService
    participant GameSettings

    Browser->>Main: App cold start
    Main->>SupabaseSDK: Supabase.initialize(url, anonKey)

    Note over SupabaseSDK: SDK auto-restores session<br/>from secure local storage.<br/>Refresh token used if JWT expired.

    Main->>LoginScreen: Always opens LoginScreen first

    LoginScreen->>LoginScreen: initState() → _checkExistingSession()
    LoginScreen->>AuthService: checkExistingAuth()
    AuthService->>SupabaseSDK: currentSession / currentUser
    SupabaseSDK-->>AuthService: Restored session (or null)

    alt Session exists
        AuthService->>ProfilesDB: SELECT * FROM profiles WHERE id = user.id
        ProfilesDB-->>AuthService: Player row
        AuthService-->>LoginScreen: AuthState(isAuthenticated: true)

        LoginScreen->>AccountProvider: switchAccount(player)
        LoginScreen->>AccountProvider: loadFromSupabase(userId)

        par Parallel fetch — 3 tables
            AccountProvider->>UserPrefsService: load(userId)
            Note over UserPrefsService: profiles + user_settings + account_state
        end

        AccountProvider->>GameSettings: hydrateFrom(snapshot)
        LoginScreen->>LoginScreen: _navigateToHome()
    else No session
        LoginScreen->>LoginScreen: Show login form
    end
```

---

## Flow 3 — On Profile Page

```mermaid
sequenceDiagram
    actor User
    participant ProfileScreen
    participant AccountProvider as AccountProvider (Riverpod)
    participant AvatarProvider as AvatarProvider (Riverpod)
    participant LeaderboardService

    User->>ProfileScreen: Navigate to Profile tab

    Note over ProfileScreen: NO Supabase calls on open.<br/>All data already in Riverpod state.

    ProfileScreen->>AccountProvider: ref.watch(accountProvider)
    AccountProvider-->>ProfileScreen: AccountState

    ProfileScreen->>AvatarProvider: ref.watch(avatarProvider)
    AvatarProvider-->>ProfileScreen: AvatarConfig

    Note over ProfileScreen: Renders from cached state:

    ProfileScreen->>ProfileScreen: _ProfileHeader<br/>(name, username, avatar)
    ProfileScreen->>ProfileScreen: _LevelProgress<br/>(level, xp, progress bar)
    ProfileScreen->>ProfileScreen: _StatsGrid<br/>(coins, games, countries,<br/>best score, best time, flight time)
    ProfileScreen->>ProfileScreen: _NationalitySection<br/>(pilot license country)
    ProfileScreen->>ProfileScreen: SocialTitlesCard<br/>(equipped title)

    opt User taps "Game History"
        ProfileScreen->>LeaderboardService: fetchGameHistory(userId)
        LeaderboardService->>LeaderboardService: SELECT FROM scores<br/>WHERE user_id = ?<br/>ORDER BY created_at DESC<br/>LIMIT 20
        LeaderboardService-->>ProfileScreen: List of recent games
    end

    opt User edits username
        ProfileScreen->>AccountProvider: switchAccount(player.copyWith(username: new))
        AccountProvider->>AccountProvider: _prefs.saveProfile() → debounced upsert
    end
```

---

## Flow 4 — On Game Start

```mermaid
sequenceDiagram
    actor User
    participant RegionSelect as RegionSelectScreen
    participant PlayScreen
    participant GameSession
    participant CountryData
    participant GameSettings

    User->>RegionSelect: Select region + difficulty
    RegionSelect->>PlayScreen: Navigate with config<br/>(region, difficulty, equipped cosmetics)

    PlayScreen->>PlayScreen: initState()

    alt Free Play
        PlayScreen->>GameSession: GameSession.random()
        GameSession->>CountryData: Pick random country<br/>(filtered by region + difficulty)
    else Daily Challenge
        PlayScreen->>GameSession: GameSession.seeded(dailySeed + round * 7919)
        GameSession->>CountryData: Deterministic country<br/>(same for all players)
    else Friend Challenge
        PlayScreen->>GameSession: GameSession.seeded(challenge.rounds[i].seed)
        GameSession->>CountryData: Seed from challenges table
    end

    CountryData-->>GameSession: Target country + clues

    Note over PlayScreen: No database reads at game start.<br/>Session is entirely in-memory.<br/>Settings already in GameSettings singleton.

    PlayScreen->>GameSettings: Read sensitivity, invertControls,<br/>enableNight, difficulty, sound
    PlayScreen->>PlayScreen: Initialize plane, globe, timer, fuel
    PlayScreen->>PlayScreen: Show first clue → game begins
```

---

## Flow 5 — On Leaderboard Load

```mermaid
sequenceDiagram
    actor User
    participant LBScreen as LeaderboardScreen
    participant LBService as LeaderboardService
    participant GlobalView as leaderboard_global view
    participant DailyView as leaderboard_daily view
    participant RegionalView as leaderboard_regional view
    participant FriendshipsDB as friendships table

    User->>LBScreen: Navigate to Leaderboard tab
    LBScreen->>LBScreen: initState()

    par Load default tab + player rank
        LBScreen->>LBService: fetchGlobal()
        LBService->>GlobalView: SELECT rank, user_id, username,<br/>avatar_url, score, time_ms<br/>ORDER BY rank LIMIT 100
        GlobalView-->>LBScreen: Top 100 global entries

        LBScreen->>LBService: fetchPlayerRank(userId)
        LBService->>GlobalView: SELECT * WHERE user_id = ?
        GlobalView-->>LBScreen: Player's rank + score
    end

    opt User switches to Daily tab
        LBScreen->>LBService: fetchDaily()
        LBService->>DailyView: SELECT * WHERE created_at >= TODAY<br/>AND region = 'daily'<br/>ORDER BY rank
        DailyView-->>LBScreen: Today's daily scores
    end

    opt User switches to Regional tab
        LBScreen->>LBService: fetchRegional(region)
        LBService->>RegionalView: SELECT * WHERE region = ?<br/>ORDER BY rank
        RegionalView-->>LBScreen: Region-filtered scores
    end

    opt User switches to Friends tab
        LBScreen->>LBService: fetchFriends(userId)
        LBService->>FriendshipsDB: SELECT friend IDs<br/>WHERE status = 'accepted'
        FriendshipsDB-->>LBService: List of friend user_ids
        LBService->>GlobalView: SELECT * WHERE user_id<br/>IN (friendIds + self)
        GlobalView-->>LBScreen: Friends leaderboard
    end
```

---

## Flow 6 — On Shop Purchase

```mermaid
sequenceDiagram
    actor User
    participant ShopScreen
    participant AccountProvider
    participant AccountState as AccountState (in-memory)
    participant UserPrefsService as UserPreferencesService
    participant ProfilesDB as profiles table
    participant AccountDB as account_state table

    User->>ShopScreen: Tap "Buy" on cosmetic item

    ShopScreen->>ShopScreen: Validate: coins >= price<br/>AND item not already owned

    ShopScreen->>AccountProvider: purchaseCosmetic(itemId, price)

    AccountProvider->>AccountProvider: spendCoins(price)
    Note over AccountProvider: state.coins -= price

    AccountProvider->>AccountState: ownedCosmetics.add(itemId)

    par Save to 2 tables (debounced)
        AccountProvider->>UserPrefsService: saveProfile(player)<br/>→ marks _profileDirty
        Note over UserPrefsService: profiles.coins updated
        AccountProvider->>UserPrefsService: saveAccountState(...)<br/>→ marks _accountDirty
        Note over UserPrefsService: account_state.owned_cosmetics updated
    end

    UserPrefsService->>UserPrefsService: _scheduleSave() → 2s timer

    Note over UserPrefsService: After 2s debounce...

    par Flush dirty tables
        UserPrefsService->>ProfilesDB: UPSERT profiles<br/>(coins, xp, level...)
        UserPrefsService->>AccountDB: UPSERT account_state<br/>(owned_cosmetics array)
    end

    ShopScreen->>ShopScreen: UI rebuilds via ref.watch<br/>→ item shows "Owned" / "Equip"

    opt User taps "Equip"
        ShopScreen->>AccountProvider: equipPlane(itemId)
        AccountProvider->>AccountState: equippedPlaneId = itemId
        AccountProvider->>UserPrefsService: saveAccountState()<br/>→ debounced upsert
    end
```

---

## Flow 7 — On Avatar Save

```mermaid
sequenceDiagram
    actor User
    participant AvatarEditor as AvatarEditorScreen
    participant AccountProvider
    participant UserPrefsService as UserPreferencesService
    participant AccountDB as account_state table
    participant ProfilesDB as profiles table

    User->>AvatarEditor: Customize avatar parts<br/>(skin, hair, eyes, mouth, etc.)

    Note over AvatarEditor: Changes stored in local<br/>_config variable only.<br/>NOT yet persisted.

    opt Part requires purchase
        User->>AvatarEditor: Tap locked part → Purchase dialog
        AvatarEditor->>AccountProvider: purchaseAvatarPart(partId, price)
        AccountProvider->>AccountProvider: spendCoins(price)
        AccountProvider->>AccountProvider: ownedAvatarParts.add(partId)
        par Debounced writes
            AccountProvider->>UserPrefsService: saveProfile() → profiles.coins
            AccountProvider->>UserPrefsService: saveAccountState() → owned_avatar_parts
        end
    end

    User->>AvatarEditor: Tap "SAVE" button

    AvatarEditor->>AccountProvider: updateAvatar(config)
    AccountProvider->>AccountProvider: state.avatar = config
    AccountProvider->>UserPrefsService: saveAccountState()<br/>(avatar_config: config.toJson())
    UserPrefsService->>UserPrefsService: _accountDirty = true<br/>_scheduleSave() → 2s timer

    Note over UserPrefsService: After 2s debounce...

    UserPrefsService->>AccountDB: UPSERT account_state<br/>SET avatar_config = {json}

    AvatarEditor->>AvatarEditor: Navigator.pop()<br/>(return to profile)

    Note over AvatarEditor: If user navigates away<br/>WITHOUT tapping Save,<br/>changes are discarded.
```

---

## Flow 8 — On Completing Daily Challenge

```mermaid
sequenceDiagram
    actor User
    participant PlayScreen
    participant ResultDialog as _ResultDialog
    participant DailyScreen as DailyChallengeScreen
    participant AccountProvider
    participant UserPrefsService as UserPreferencesService
    participant ScoresDB as scores table
    participant ProfilesDB as profiles table
    participant AccountDB as account_state table

    User->>PlayScreen: Complete round 5 (or fuel runs out)

    PlayScreen->>PlayScreen: _completeLanding()

    PlayScreen->>AccountProvider: recordGameCompletion(<br/>  elapsed, score, roundsCompleted,<br/>  coinReward, region: 'daily'<br/>)

    AccountProvider->>AccountProvider: Update in-memory state:<br/>games_played++, coins += reward,<br/>xp += earned, level up check,<br/>best_score/time comparison

    par Immediate writes (no debounce)
        AccountProvider->>UserPrefsService: saveGameResult(score, timeMs, 'daily', rounds)
        UserPrefsService->>ScoresDB: INSERT INTO scores<br/>(user_id, score, time_ms,<br/>region='daily', rounds_completed)

        AccountProvider->>UserPrefsService: flush()
        UserPrefsService->>ProfilesDB: UPSERT profiles<br/>(games_played, coins, xp,<br/>best_score, countries_found...)
    end

    PlayScreen->>ResultDialog: Show results overlay

    ResultDialog->>ResultDialog: Display score, time,<br/>round indicators

    User->>ResultDialog: Tap "Done"
    ResultDialog->>DailyScreen: onComplete callback

    DailyScreen->>AccountProvider: recordDailyChallengeCompletion()

    AccountProvider->>AccountProvider: Update streak:<br/>currentStreak++,<br/>longestStreak = max(),<br/>lastCompletionDate = today

    DailyScreen->>AccountProvider: recordDailyResult(DailyResult)

    AccountProvider->>AccountProvider: lastDailyResult = result<br/>(rounds, scores, hints, theme)

    AccountProvider->>UserPrefsService: saveAccountState()<br/>→ debounced 2s

    UserPrefsService->>AccountDB: UPSERT account_state<br/>SET daily_streak_data = {json},<br/>last_daily_result = {json},<br/>last_daily_challenge_date = 'YYYY-MM-DD'
```

---

## Flow 9 — On Searching for Challengers (Matchmaking)

```mermaid
sequenceDiagram
    actor User
    participant FindScreen as FindChallengerScreen
    participant MatchService as MatchmakingService
    participant PoolDB as matchmaking_pool table
    participant ChallengeService
    participant ChallengesDB as challenges table
    participant FriendsService
    participant FriendshipsDB as friendships table
    participant PlayScreen

    User->>FindScreen: Tap "Find a Challenger"

    FindScreen->>FindScreen: Calculate ELO:<br/>1000 + (level * 50) + (bestScore / 20)

    FindScreen->>MatchService: submitToPool(region, elo, version)
    MatchService->>PoolDB: INSERT INTO matchmaking_pool<br/>(user_id, region, seed, elo_rating,<br/>gameplay_version)
    PoolDB-->>MatchService: Pool entry ID

    FindScreen->>FindScreen: State: "searching"

    FindScreen->>MatchService: findMatch(poolEntryId)

    MatchService->>PoolDB: SELECT * FROM matchmaking_pool<br/>WHERE matched_at IS NULL<br/>AND user_id != me<br/>AND region = 'world'<br/>AND gameplay_version = mine<br/>AND elo_rating BETWEEN (mine ± band)

    Note over MatchService: ELO band width:<br/>Pool < 10 → ±500<br/>Pool 10-49 → ±300<br/>Pool 50+ → ±200

    alt Match found
        MatchService->>ChallengeService: createChallenge(matchedUserId)
        ChallengeService->>ChallengesDB: INSERT INTO challenges<br/>(challenger_id, challenged_id,<br/>rounds: [{seed, round_number}...])
        ChallengesDB-->>ChallengeService: challenge_id

        MatchService->>PoolDB: UPDATE both entries<br/>SET matched_at = NOW(),<br/>matched_with, challenge_id

        MatchService->>FriendsService: Auto-friend both players
        FriendsService->>FriendshipsDB: INSERT INTO friendships<br/>(status: 'accepted')

        MatchService-->>FindScreen: Match result + opponent info

        FindScreen->>FindScreen: State: "matched"<br/>Show opponent card

        User->>FindScreen: Tap "LET'S GO!"
        FindScreen->>PlayScreen: Navigate with challenge config
    else No match
        MatchService-->>FindScreen: null
        FindScreen->>FindScreen: State: "waiting"<br/>"Entry submitted — check back later"
    end
```

---

## Flow 10 — On Submitting a Challenge to Friend

```mermaid
sequenceDiagram
    actor User
    participant FriendsScreen
    participant ChallengeService
    participant ChallengesDB as challenges table
    participant PlayScreen
    participant AccountProvider

    User->>FriendsScreen: Tap "Challenge" on friend tile

    FriendsScreen->>FriendsScreen: Show confirmation dialog<br/>"Challenge @username?"

    User->>FriendsScreen: Confirm

    FriendsScreen->>ChallengeService: createChallenge(<br/>  challengedId, challengedName,<br/>  challengerName<br/>)

    ChallengeService->>ChallengeService: Generate 5 round seeds:<br/>[{round_number: 1, seed: rng},<br/> {round_number: 2, seed: rng},<br/> ...]

    ChallengeService->>ChallengesDB: INSERT INTO challenges<br/>(challenger_id, challenger_name,<br/>challenged_id, challenged_name,<br/>status: 'pending',<br/>rounds: [{seeds...}])
    ChallengesDB-->>ChallengeService: challenge_id (UUID)

    ChallengeService-->>FriendsScreen: challengeId

    FriendsScreen->>PlayScreen: Navigate with challenge config<br/>(challengeId, 5 rounds, cosmetics)

    loop Each round (1-5)
        PlayScreen->>PlayScreen: GameSession.seeded(round.seed)<br/>→ deterministic country

        Note over PlayScreen: Player plays round...<br/>Same country as opponent<br/>will get (shared seed)

        PlayScreen->>ChallengeService: submitRoundResult(<br/>  challengeId, roundNumber,<br/>  timeMs, score<br/>)
        ChallengeService->>ChallengesDB: UPDATE challenges<br/>SET rounds[i].challenger_time_ms<br/>status = 'in_progress'
    end

    PlayScreen->>ChallengeService: tryCompleteChallenge(challengeId)

    alt Both players finished all rounds
        ChallengeService->>ChallengeService: Count round wins,<br/>determine winner,<br/>calculate coin rewards

        ChallengeService->>ChallengesDB: UPDATE challenges<br/>SET status = 'completed',<br/>winner_id, challenger_coins,<br/>challenged_coins, completed_at

        ChallengeService->>AccountProvider: addCoins(reward)
    else Opponent hasn't played yet
        Note over ChallengesDB: Challenge stays 'in_progress'<br/>until opponent completes rounds
    end
```

---

## Flow 11 — On Refining Game Settings

```mermaid
sequenceDiagram
    actor User
    participant SettingsSheet as SettingsSheet (Bottom Sheet)
    participant GameSettings as GameSettings Singleton
    participant Listener as ChangeNotifier Listener
    participant UserPrefsService as UserPreferencesService
    participant SettingsDB as user_settings table
    participant AudioManager
    participant ShaderManager
    participant PlaneComponent

    User->>SettingsSheet: Open settings<br/>(from Profile or in-game HUD)

    User->>SettingsSheet: Drag sensitivity slider to 1.2

    SettingsSheet->>GameSettings: turnSensitivity = 1.2

    GameSettings->>GameSettings: Clamp to [0.2, 1.5]<br/>notifyListeners()

    par Immediate effects (in-memory)
        GameSettings->>PlaneComponent: Reads turnSensitivity<br/>on next frame
        GameSettings->>Listener: _syncToSupabase() fires
    end

    Listener->>UserPrefsService: saveSettings(<br/>  turnSensitivity: 1.2,<br/>  invertControls: false,<br/>  enableNight: true, ...<br/>)

    UserPrefsService->>UserPrefsService: _settingsDirty = true<br/>_scheduleSave()

    Note over UserPrefsService: 2-second debounce window.<br/>Rapid slider drags = single write.

    User->>SettingsSheet: Toggle "Night Mode" off
    SettingsSheet->>GameSettings: enableNight = false
    GameSettings->>ShaderManager: Shader uniform updated<br/>(no city lights, no terminator)
    GameSettings->>Listener: _syncToSupabase() fires again
    UserPrefsService->>UserPrefsService: Timer resets (2s from now)

    User->>SettingsSheet: Drag music volume to 0.3
    SettingsSheet->>GameSettings: musicVolume = 0.3
    GameSettings->>AudioManager: Volume adjusted immediately
    GameSettings->>Listener: _syncToSupabase() fires again
    UserPrefsService->>UserPrefsService: Timer resets again

    Note over UserPrefsService: 2s passes with no more changes...

    UserPrefsService->>SettingsDB: UPSERT user_settings<br/>SET turn_sensitivity = 1.2,<br/>enable_night = false,<br/>music_volume = 0.3, ...

    alt Write fails (offline / network error)
        UserPrefsService->>UserPrefsService: Enqueue to SharedPreferences<br/>pending_writes queue
        Note over UserPrefsService: Retried on next flush<br/>(max 3 retries)
    end
```

**Hydration guard**: On login, `hydrateFrom()` sets `_hydrating = true` to suppress `_syncToSupabase()` while populating fields from the database — preventing a circular write-back of the values just loaded.

---

## State Residence Summary

| Data | In-Memory Location | Persistent Location | Write Strategy |
|------|-------------------|---------------------|----------------|
| Auth session (JWT) | Supabase SDK | Platform secure storage | Automatic (SDK) |
| Player stats (level, xp, coins) | `AccountState` via Riverpod | `profiles` table | Debounced 2s upsert |
| Game settings | `GameSettings` singleton | `user_settings` table | Debounced 2s upsert |
| Avatar config | `AccountState.avatar` | `account_state.avatar_config` (JSONB) | Debounced 2s upsert |
| Owned cosmetics | `AccountState.ownedCosmetics` | `account_state.owned_cosmetics` (text[]) | Debounced 2s upsert |
| Equipped items | `AccountState.equippedPlaneId` etc. | `account_state.equipped_*` | Debounced 2s upsert |
| Daily streak | `AccountState.dailyStreakData` | `account_state.daily_streak_data` (JSONB) | Debounced 2s upsert |
| Last daily result | `AccountState.lastDailyResult` | `account_state.last_daily_result` (JSONB) | Debounced 2s upsert |
| Game scores | Transient (PlayScreen) | `scores` table | Immediate INSERT |
| Active game session | `GameSession` (local) | Nowhere (ephemeral) | Not persisted |
| Challenges | Fetched on demand | `challenges` table | Immediate INSERT/UPDATE |
| Friend list | Fetched on demand | `friendships` table | Immediate INSERT/UPDATE |
| Matchmaking entry | Fetched on demand | `matchmaking_pool` table | Immediate INSERT |
| Failed writes | — | `SharedPreferences` (pending_writes) | Retry on next flush |
| Error telemetry | — | Vercel in-memory + GitHub JSONL | POST on capture |

---

## Flush Trigger Map

```mermaid
flowchart TD
    A["Setting changed"] -->|"GameSettings.setter"| B["_syncToSupabase()"]
    B --> C["saveSettings() → _settingsDirty=true"]
    C --> D["_scheduleSave() → 2s timer"]

    E["Coins/XP/Stats changed"] -->|"AccountProvider mutation"| F["saveProfile() → _profileDirty=true"]
    F --> D

    G["Avatar/Cosmetics changed"] -->|"AccountProvider mutation"| H["saveAccountState() → _accountDirty=true"]
    H --> D

    D -->|"2s elapsed"| I["flush()"]

    J["Game completed"] -->|"recordGameCompletion()"| K["flush() — IMMEDIATE"]
    L["App lifecycle: paused/hidden/detached"] --> K

    K --> M["Drain offline queue first"]
    M --> N{"Any dirty tables?"}
    N -->|"_profileDirty"| O["UPSERT profiles"]
    N -->|"_settingsDirty"| P["UPSERT user_settings"]
    N -->|"_accountDirty"| Q["UPSERT account_state"]
    N -->|"game result"| R["INSERT scores"]

    O -->|"fails"| S["Enqueue to SharedPreferences"]
    P -->|"fails"| S
    Q -->|"fails"| S
    S -->|"next flush cycle"| M
```

---

## Vercel Serverless Endpoints

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/errors` | POST | None (open) | Receive error reports from Flutter app |
| `/api/errors` | GET | X-API-Key header | Query stored errors (severity, since, limit) |
| `/api/health` | GET | None | Health check + Supabase keep-alive ping |

The health endpoint is hit by a Vercel cron every 3 days to prevent Supabase's free-tier auto-pause (7-day inactivity timeout).

---

## Key File Reference

| Component | File |
|-----------|------|
| App entry + lifecycle flush | `lib/main.dart` |
| Supabase config | `lib/core/config/supabase_config.dart` |
| Auth service | `lib/data/services/auth_service.dart` |
| Account provider (Riverpod) | `lib/data/providers/account_provider.dart` |
| Persistence service | `lib/data/services/user_preferences_service.dart` |
| Game settings singleton | `lib/core/services/game_settings.dart` |
| Settings UI | `lib/core/widgets/settings_sheet.dart` |
| Login screen | `lib/features/auth/login_screen.dart` |
| Profile screen | `lib/features/profile/profile_screen.dart` |
| Play screen (game) | `lib/features/play/play_screen.dart` |
| Daily challenge screen | `lib/features/daily/daily_challenge_screen.dart` |
| Shop screen | `lib/features/shop/shop_screen.dart` |
| Avatar editor | `lib/features/avatar/avatar_editor_screen.dart` |
| Leaderboard service | `lib/data/services/leaderboard_service.dart` |
| Challenge service | `lib/data/services/challenge_service.dart` |
| Matchmaking service | `lib/data/services/matchmaking_service.dart` |
| Friends service | `lib/data/services/friends_service.dart` |
| Error telemetry API | `api/errors/index.js` |
| Health check API | `api/health/index.js` |
| SQL migrations | `supabase/migrations/*.sql` |
