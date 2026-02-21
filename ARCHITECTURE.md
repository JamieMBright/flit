# Flit - Application Architecture

## Screen Flow

The app follows a linear navigation model. The entry point is `LoginScreen`,
which transitions to `HomeScreen` after authentication. From there, all features
are accessible via the main menu.

```mermaid
graph TD
    A[App Launch] --> B{Authenticated?}
    B -->|No| C[LoginScreen]
    B -->|Yes| D[HomeScreen]
    C -->|Create Account| D
    C -->|Sign In| D

    D -->|Play| E[Game Mode Sheet]
    D -->|Leaderboard| F[LeaderboardScreen]
    D -->|Profile| G[ProfileScreen]
    D -->|Avatar| H[AvatarEditorScreen]
    D -->|Pilot License| I[LicenseScreen]
    D -->|Shop| J[ShopScreen]
    D -->|Debug| K[DebugScreen]

    E -->|Free Flight| L[RegionSelectScreen]
    E -->|Training Sortie| M[PracticeScreen]
    E -->|Daily Scramble| N[DailyChallengeScreen]
    E -->|Dogfight| O[FriendsScreen]

    L -->|Select Region| P[PlayScreen]
    M --> P
    N -->|Play Today's Challenge| P
    O -->|Challenge Friend| P

    P -->|Landing| Q{Result Dialog}
    Q -->|Play Again| P
    Q -->|Send Challenge| R[Challenge Sent Dialog]
    Q -->|Exit| D
    R --> D

    O -->|View Result| S[ChallengeResultScreen]
    S -->|Rematch| O
    S -->|Home| D

    style A fill:#2C3E50,color:#ECF0F1
    style C fill:#1A5276,color:#ECF0F1
    style D fill:#1E8449,color:#ECF0F1
    style P fill:#B03A2E,color:#ECF0F1
    style N fill:#D4AC0D,color:#1A1A1A
    style J fill:#D4AC0D,color:#1A1A1A
```

---

## Authentication Flow

```mermaid
graph LR
    subgraph LoginScreen
        W[Welcome View] -->|Sign Up| ES[Email + Username + Display Name]
        W -->|Sign In| SI[Email + Password]
    end

    ES -->|AuthService.signUpWithEmail| AUTH{AuthResult}
    SI -->|AuthService.signInWithEmail| AUTH

    AUTH -->|isAuthenticated| HOME[HomeScreen]
    AUTH -->|error| ERR[Show Error]
    ERR --> W

    style HOME fill:#1E8449,color:#ECF0F1
    style AUTH fill:#2C3E50,color:#ECF0F1
```

**Auth Strategy:**
- Primary: Email + password via Supabase Auth
- All players must have accounts — no guest mode
- Profiles are auto-created by database trigger on sign-up

---

## Game Mode Selection

Pressing **Play** on the HomeScreen opens a bottom sheet with four game modes:

```mermaid
graph TD
    subgraph "Play Modal (Bottom Sheet)"
        FF[Free Flight<br/><i>Explore at your own pace</i>]
        TS[Training Sortie<br/><i>Practice without rank pressure</i>]
        DS[Daily Scramble<br/><i>Today's challenge - compete for glory</i>]
        DF[Dogfight<br/><i>Challenge your friends head-to-head</i>]
    end

    FF --> RS[RegionSelectScreen<br/>Pick: World / US / UK / Caribbean / Ireland]
    TS --> PS_Practice[PlayScreen<br/>10 rounds, no rank]
    DS --> DCS[DailyChallengeScreen<br/>Rewards, leaderboard, seasonal events]
    DF --> FS[FriendsScreen<br/>Send/accept challenges]

    RS --> PS_Play[PlayScreen<br/>Single round, region-specific]
    DCS --> PS_Daily[PlayScreen<br/>Date-seeded, coin reward]
    FS --> PS_Challenge[PlayScreen<br/>Challenge round vs friend]

    style DS fill:#D4AC0D,color:#1A1A1A
    style DF fill:#2874A6,color:#ECF0F1
```

---

## In-Game Flow (PlayScreen)

```mermaid
sequenceDiagram
    participant U as Player
    participant PS as PlayScreen
    participant FG as FlitGame (Flame)
    participant GS as GameSession

    PS->>FG: Create FlitGame
    FG-->>PS: onGameReady()
    PS->>GS: GameSession.random(region)
    PS->>FG: startGame(start, target, clue)

    loop Every 16ms
        U->>FG: Swipe left/right (steer)
        U->>FG: Tap altitude toggle
        FG-->>PS: onAltitudeChanged(isHigh)
        PS->>PS: Update timer, record flight path
        PS->>PS: Check proximity to target
    end

    alt Near target + Low altitude
        PS->>GS: session.complete()
        PS->>PS: Show Result Dialog
    else Multi-round + Near target
        PS->>PS: Auto-advance to next round
    end
```

---

## Rendering Pipeline

```mermaid
graph TB
    subgraph "Fragment Shader (globe.frag)"
        RS[Ray-Sphere Intersection]
        RS --> SAT[Satellite Texture Sampling]
        SAT --> OCN[Ocean: Waves + Specular + Foam]
        OCN --> ATM[Atmosphere: Rim Glow + Haze]
        ATM --> CLD[Clouds: Procedural FBM Noise]
        CLD --> DN[Day/Night: Terminator + City Lights]
        DN --> SKY[Sky: Analytical Scattering]
    end

    subgraph "Canvas Overlay"
        PL[PlaneComponent<br/>Bezier paths, tilt, propeller]
        CT[Contrail Particles<br/>Wing-tip trails]
        HUD[GameHud<br/>Clue, timer, altitude]
    end

    subgraph "Texture Samplers (4 max)"
        T1[uSatellite - NASA Blue Marble]
        T2[uHeightmap - ETOPO elevation]
        T3[uShoreDist - Shore distance field]
        T4[uCityLights - NASA Earth at Night]
    end

    SM[ShaderManager] --> RS
    T1 & T2 & T3 & T4 --> SM
    GR[GlobeRenderer] --> SM

    style SM fill:#8E44AD,color:#ECF0F1
    style GR fill:#2C3E50,color:#ECF0F1
```

---

## Data Architecture

```mermaid
graph TD
    subgraph "State Management (Riverpod)"
        AP[AccountProvider<br/>coins, level, xp, equipped items]
        AP --> CP[currentCoinsProvider]
        AP --> LP[currentLevelProvider]
        AP --> EP[equippedPlaneIdProvider]
    end

    subgraph "Data Models"
        PM[PlayerModel<br/>username, level, coins, xp]
        CM[Cosmetic<br/>planes, contrails, rarity, price]
        CH[Challenge<br/>rounds, wins, route data]
        DC[DailyChallenge<br/>date-seeded, rewards]
        LE[LeaderboardEntry<br/>rank, time, score]
        ST[SeasonalTheme<br/>events, vehicle skins]
    end

    subgraph "Game Logic"
        GS[GameSession<br/>target, clue, flight path]
        GMC[GameModeController<br/>solo/challenge/daily]
        LD[LandingDetector<br/>Haversine proximity]
        FR[FlightRecorder<br/>ring buffer path]
        CT_[ClueType<br/>flag/outline/borders/capital/stats]
    end

    subgraph "Regional Data"
        RG[GameRegion enum<br/>world/usStates/ukCounties/caribbean/ireland]
        RD[RegionalData<br/>50 US + 100 UK + 16 Caribbean + 32 Ireland]
        CD[CountryData<br/>country polygons + capitals]
    end

    AP --> PM
    GS --> GMC
    GS --> CT_
    GS --> RG
    RG --> RD

    style AP fill:#1E8449,color:#ECF0F1
    style GS fill:#B03A2E,color:#ECF0F1
```

---

## Shop & Economy

```mermaid
graph LR
    subgraph "Earning Coins"
        E1[Daily Challenge Completion]
        E2[Daily Leader Bonus]
        E3[Challenge Wins]
        E4[Level-Up Rewards]
        E5[IAP Gold Packages<br/><i>Coming Soon</i>]
    end

    subgraph "Spending Coins"
        S1[Plane Skins<br/>9 planes, 4 rarities]
        S2[Contrail Effects<br/>5 styles]
        S3[Region Unlocks<br/>US/UK/Caribbean/Ireland]
        S4[Mystery Plane<br/>10,000 coins, weighted rarity]
        S5[Gift to Friend]
    end

    E1 & E2 & E3 & E4 & E5 --> WALLET[Coin Balance]
    WALLET --> S1 & S2 & S3 & S4 & S5

    style WALLET fill:#D4AC0D,color:#1A1A1A
```

---

## Error Telemetry Pipeline

```mermaid
graph LR
    APP[Flutter App] -->|reportError/Warning/Critical| ES[ErrorService<br/>Singleton Queue]
    ES -->|setSender| HTTP[errorSenderHttp<br/>POST JSON]
    HTTP --> VER[Vercel /api/errors]
    VER -->|GitHub Contents API| GH[GitHub Repo<br/>logs/runtime-errors.jsonl]

    TIM[Timer.periodic 60s] -->|flush()| ES
    LC[App Lifecycle<br/>paused/detached] -->|flush()| ES
    GHA[GitHub Action<br/>fetch-errors.yml] -->|GET| VER

    style ES fill:#8E44AD,color:#ECF0F1
    style VER fill:#2C3E50,color:#ECF0F1
```

---

## File Structure

```
lib/
├── main.dart                           # App entry, error wiring
├── core/
│   ├── services/
│   │   ├── error_service.dart          # Error capture singleton
│   │   └── error_sender_http.dart      # HTTP POST sender
│   ├── theme/
│   │   └── flit_colors.dart            # Design tokens
│   └── utils/
│       ├── dev_overlay.dart            # Debug error overlay
│       └── game_log.dart               # Structured logging
├── data/
│   ├── models/
│   │   ├── cosmetic.dart               # Plane/contrail catalog
│   │   ├── challenge.dart              # Challenge data model
│   │   ├── daily_challenge.dart        # Daily challenge model
│   │   ├── leaderboard_entry.dart      # Leaderboard entry
│   │   └── seasonal_theme.dart         # Seasonal event themes
│   ├── providers/
│   │   └── account_provider.dart       # Riverpod account state
│   └── services/
│       └── auth_service.dart           # Authentication
├── features/
│   ├── auth/login_screen.dart
│   ├── home/home_screen.dart
│   ├── play/
│   │   ├── play_screen.dart            # Main game screen
│   │   ├── region_select_screen.dart   # Region picker
│   │   └── practice_screen.dart        # Training mode
│   ├── daily/daily_challenge_screen.dart
│   ├── challenge/challenge_result_screen.dart
│   ├── friends/friends_screen.dart
│   ├── leaderboard/leaderboard_screen.dart
│   ├── profile/profile_screen.dart
│   ├── avatar/avatar_editor_screen.dart
│   ├── license/license_screen.dart
│   ├── shop/shop_screen.dart
│   └── debug/debug_screen.dart
├── game/
│   ├── flit_game.dart                  # Flame game class
│   ├── rendering/
│   │   ├── globe_renderer.dart         # Shader Flame component
│   │   ├── shader_manager.dart         # Shader/texture loading
│   │   ├── camera_state.dart           # 3D camera math
│   │   ├── globe_hit_test.dart         # Point-in-polygon
│   │   └── region_camera_presets.dart  # Per-region camera defaults
│   ├── map/
│   │   ├── country_data.dart           # Country polygons
│   │   ├── region.dart                 # Regional data (198 areas)
│   │   ├── world_map.dart              # Canvas 2D fallback
│   │   └── world_map_legacy.dart       # Legacy backup
│   ├── gameplay/
│   │   ├── game_mode_controller.dart   # Mode orchestration
│   │   ├── landing_detector.dart       # Haversine proximity
│   │   └── flight_recorder.dart        # Ring buffer path
│   ├── session/
│   │   └── game_session.dart           # Session state
│   ├── clues/
│   │   └── clue_types.dart             # Clue generation
│   ├── components/
│   │   └── plane_component.dart        # Plane rendering
│   └── ui/
│       └── game_hud.dart               # In-game HUD
shaders/
└── globe.frag                          # GLSL fragment shader
```
