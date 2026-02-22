// =============================================================================
// globe.frag — Flit Globe Fragment Shader (V1–V7 Complete)
//
// Renders a photorealistic Earth globe with:
//   V1: Ray-sphere globe with satellite texture + diffuse lighting
//   V2: Depth-based ocean coloring, animated waves, specular, fresnel
//   V3: Coastline foam from shore distance field
//   V4: Atmospheric scattering, rim glow, sky gradient, sun disc
//   V5: Procedural volumetric clouds on a shell above the globe
//   V6: Day/night cycle, city lights, star field, terminator glow
//   V7: Country borders from distance field (packed in uShoreDist green channel)
//
// Compatible with Flutter FragmentProgram.fromAsset() on iOS, Android, Web.
// =============================================================================

#include <flutter/runtime_effect.glsl>

// ---------------------------------------------------------------------------
// Uniforms — set from Dart via shader.setFloat(index, value)
// ---------------------------------------------------------------------------

uniform vec2  uResolution;   // Index 0–1:  viewport size (px)
uniform vec3  uCameraPos;    // Index 2–4:  camera position (world)
uniform vec3  uCameraUp;     // Index 5–7:  heading-aligned up vector
uniform vec3  uSunDir;       // Index 8–10: normalised sun direction
uniform float uTime;         // Index 11:   elapsed time (seconds)
uniform float uGlobeRadius;  // Index 12:   globe radius (typically 1.0)
uniform float uCloudRadius;  // Index 13:   cloud shell radius (> globe)
uniform float uFOV;          // Index 14:   field of view (radians)
uniform float uEnableShading; // Index 15:  0.0 = raw texture, 1.0 = full shading
uniform float uEnableNight;   // Index 16:  0.0 = always day,  1.0 = day/night cycle

// ---------------------------------------------------------------------------
// Samplers — maximum 4 per shader pass
// ---------------------------------------------------------------------------

uniform sampler2D uSatellite;   // NASA Blue Marble (equirectangular)
uniform sampler2D uHeightmap;   // ETOPO heightmap (0 = deep ocean, 1 = peak)
uniform sampler2D uShoreDist;   // R = shore distance, G = border distance
uniform sampler2D uCityLights;  // NASA Earth at Night

// Fragment output
out vec4 fragColor;

// ===========================================================================
// CONSTANTS — named magic numbers for clarity
// ===========================================================================

// Globe geometry
const float GLOBE_CENTER      = 0.0;
const vec3  GLOBE_ORIGIN      = vec3(0.0);

// Ocean palette (depth-based)
const vec3  OCEAN_DEEP         = vec3(0.02, 0.05, 0.15);
const vec3  OCEAN_MID          = vec3(0.05, 0.15, 0.35);
const vec3  OCEAN_SHALLOW      = vec3(0.10, 0.35, 0.50);
const vec3  OCEAN_COASTAL      = vec3(0.15, 0.50, 0.55);
const float SEA_LEVEL          = 0.15;

// Ocean surface
const float WAVE_AMPLITUDE     = 0.012;
const float WAVE_FREQUENCY     = 18.0;
const float WAVE_SPEED         = 1.2;
const float SPECULAR_POWER     = 256.0;
const float SPECULAR_INTENSITY = 1.8;
const float FRESNEL_POWER      = 5.0;
const float FRESNEL_BIAS       = 0.04;

// Coastline foam
const float FOAM_SHORE_WIDTH   = 0.02;
const float FOAM_RING_FREQ     = 80.0;
const float FOAM_RING_SPEED    = 2.5;
const float FOAM_FADE_DIST     = 0.12;
const float FOAM_NOISE_SCALE   = 40.0;

// Atmosphere
const vec3  RAYLEIGH_COEFF     = vec3(5.8e-3, 1.35e-2, 3.31e-2);
const float MIE_COEFF          = 4.0e-3;
const float MIE_G              = 0.76;
const float ATMO_THICKNESS     = 0.05;
const float RIM_INTENSITY      = 0.35;
const float HAZE_STRENGTH      = 0.15;

// Clouds
const float CLOUD_COVERAGE     = 0.42;
const float CLOUD_SOFTNESS     = 0.25;
const float CLOUD_DRIFT_SPEED  = 0.008;
const float CLOUD_BRIGHTNESS   = 1.0;
const float CLOUD_SHADOW_STR   = 0.15;
const int   FBM_OCTAVES        = 4;

// Day/night cycle
const float TERMINATOR_SOFT    = -0.1;
const float TERMINATOR_HARD    = 0.2;
const vec3  TERMINATOR_WARM    = vec3(1.0, 0.45, 0.15);
const float CITY_LIGHT_BOOST   = 2.0;
const float NIGHT_RIM_STRENGTH = 0.3;

// Sky / stars
const float SUN_DISC_SIZE      = 0.9995;
const float SUN_BLOOM_SIZE     = 0.997;
const float STAR_THRESHOLD     = 0.9985;
const float STAR_TWINKLE_SPEED = 3.0;

// Shared
const float PI                 = 3.14159265;
const float TWO_PI             = 6.28318530;

// ===========================================================================
// HELPER FUNCTIONS
// ===========================================================================

// -- Hash & Noise -----------------------------------------------------------

// 2D → 1D hash (deterministic pseudo-random)
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D → 2D hash for vector noise
vec2 hash22(vec2 p) {
    vec3 q = fract(p.xyx * vec3(123.34, 234.34, 345.65));
    q += dot(q, q.yzx + 45.51);
    return fract((q.xx + q.yz) * q.zy);
}

// Smooth 2D value noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Quintic interpolation for smoother derivatives
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 3D value noise (for cloud FBM)
float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float n000 = hash21(i.xy + i.z * 137.0);
    float n100 = hash21(i.xy + vec2(1.0, 0.0) + i.z * 137.0);
    float n010 = hash21(i.xy + vec2(0.0, 1.0) + i.z * 137.0);
    float n110 = hash21(i.xy + vec2(1.0, 1.0) + i.z * 137.0);
    float n001 = hash21(i.xy + (i.z + 1.0) * 137.0);
    float n101 = hash21(i.xy + vec2(1.0, 0.0) + (i.z + 1.0) * 137.0);
    float n011 = hash21(i.xy + vec2(0.0, 1.0) + (i.z + 1.0) * 137.0);
    float n111 = hash21(i.xy + vec2(1.0, 1.0) + (i.z + 1.0) * 137.0);

    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);

    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);

    return mix(nxy0, nxy1, u.z);
}

// Fractal Brownian motion — 3D, limited octaves for performance
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < FBM_OCTAVES; i++) {
        value += amplitude * noise3D(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// -- Geometry ---------------------------------------------------------------

// Analytical ray-sphere intersection
// Returns nearest positive t, or -1.0 on miss
float intersectSphere(vec3 ro, vec3 rd, vec3 center, float radius) {
    vec3 oc = ro - center;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float disc = b * b - c;
    if (disc < 0.0) return -1.0;
    float sqrtDisc = sqrt(disc);
    float t0 = -b - sqrtDisc;
    float t1 = -b + sqrtDisc;
    if (t0 > 0.0) return t0;
    if (t1 > 0.0) return t1;
    return -1.0;
}

// Convert 3D point on unit sphere to equirectangular UV
vec2 equirectangularUV(vec3 p) {
    vec3 n = normalize(p);
    float u = atan(n.z, n.x) / TWO_PI + 0.5;
    float v = asin(clamp(n.y, -1.0, 1.0)) / PI + 0.5;
    return vec2(u, 1.0 - v);
}

// -- Camera -----------------------------------------------------------------

// Build a view matrix (look-at) and generate a ray direction.
// Uses a heading-aligned up vector instead of fixed world up (0,1,0)
// to prevent rolling at non-equatorial latitudes.
vec3 cameraRayDir(vec2 fragCoord, vec2 resolution, vec3 camPos, vec3 camUp, float fov) {
    vec2 uv = (fragCoord - 0.5 * resolution) / resolution.y;
    // Flutter fragCoord is y-down (0 at top, height at bottom).
    // Negate uv.y so that screen-up = positive = heading direction,
    // matching the plane overlay which faces up on screen.
    uv.y = -uv.y;
    // tiltDown > 0 shifts the view toward heading (up on screen),
    // pushing the globe disk down so more surface is visible and
    // the curvature / horizon sits near the top of the screen.
    // 0.35 places the horizon just above the top edge at high altitude
    // (d=1.8, fov=1.4), creating a "behind and above the plane" POV
    // where ground fills the screen and curvature is visible at the top.
    const float tiltDown = 0.35;
    uv.y += tiltDown;
    
    float halfFov = tan(fov * 0.5);
    uv *= halfFov;

    // Camera always looks at the globe center (origin).
    vec3 forward = normalize(-camPos);
    vec3 right   = normalize(cross(camUp, forward));
    vec3 up      = cross(forward, right);

    return normalize(uv.x * right + uv.y * up + forward);
}

// -- Lighting helpers -------------------------------------------------------

// Gaussian specular (soft, photorealistic sun glint)
float gaussianSpecular(vec3 normal, vec3 viewDir, vec3 lightDir, float smoothness) {
    vec3 halfVec = normalize(lightDir + viewDir);
    float angle = acos(clamp(dot(normal, halfVec), 0.0, 1.0));
    return exp(-(angle * angle) / (smoothness * smoothness));
}

// Schlick fresnel approximation
float fresnel(vec3 viewDir, vec3 normal, float bias, float power) {
    float f = bias + (1.0 - bias) * pow(1.0 - max(dot(viewDir, normal), 0.0), power);
    return clamp(f, 0.0, 1.0);
}

// ===========================================================================
// ATMOSPHERE (V4) — analytical Rayleigh + Mie scattering
// ===========================================================================

vec3 atmosphere(vec3 rayDir, vec3 sunDir) {
    float sunDot = dot(rayDir, sunDir);

    // Rayleigh scattering — more at perpendicular angles, blue-dominant
    float rayleighPhase = 0.75 * (1.0 + sunDot * sunDot);
    vec3 rayleigh = RAYLEIGH_COEFF * rayleighPhase;

    // Mie scattering — forward lobe halo around the sun
    float miePhase = (1.0 - MIE_G * MIE_G)
                   / (4.0 * PI * pow(1.0 + MIE_G * MIE_G - 2.0 * MIE_G * sunDot, 1.5));
    vec3 mie = vec3(MIE_COEFF) * miePhase;

    // Horizon brightening — warm colors near sun at horizon
    float horizonFactor = pow(max(1.0 - abs(rayDir.y), 0.0), 4.0);
    float sunHorizon = pow(max(sunDot, 0.0), 8.0);
    vec3 horizonWarm = mix(vec3(0.2, 0.4, 0.8), vec3(1.0, 0.5, 0.2), sunHorizon) * horizonFactor;

    // Compose sky colour
    vec3 scatter = (rayleigh + mie) * 12.0 + horizonWarm * 0.6;

    // Vertical gradient — darker at zenith, brighter at horizon
    float altitude = max(rayDir.y, 0.0);
    vec3 zenithColor  = vec3(0.05, 0.10, 0.25);
    vec3 horizonColor = vec3(0.40, 0.55, 0.80);
    vec3 skyGradient  = mix(horizonColor, zenithColor, pow(altitude, 0.5));

    // Night sky — dark when sun is below horizon relative to view
    float dayAmount = smoothstep(-0.3, 0.1, sunDir.y);
    vec3 nightSky = vec3(0.005, 0.007, 0.02);

    vec3 daySky = skyGradient + scatter;
    return mix(nightSky, daySky, dayAmount);
}

// ===========================================================================
// STARS (V6) — procedural star field behind the globe
// ===========================================================================

vec3 starField(vec3 rayDir, float time) {
    // Project ray direction onto a pseudo-grid
    vec2 starUV = equirectangularUV(rayDir) * 800.0;
    vec2 cell = floor(starUV);
    float starHash = hash21(cell);

    vec3 stars = vec3(0.0);
    if (starHash > STAR_THRESHOLD) {
        // Star brightness with subtle twinkle
        float brightness = (starHash - STAR_THRESHOLD) / (1.0 - STAR_THRESHOLD);
        brightness *= brightness;
        float twinkle = 0.7 + 0.3 * sin(time * STAR_TWINKLE_SPEED + starHash * 100.0);
        brightness *= twinkle;

        // Slight colour variation (warm/cool)
        vec3 starColor = mix(vec3(0.8, 0.85, 1.0), vec3(1.0, 0.92, 0.8), hash21(cell + 77.0));
        stars = starColor * brightness;
    }
    return stars;
}

// ===========================================================================
// SUN DISC (V4) — bright disc with gaussian bloom
// ===========================================================================

vec3 sunDisc(vec3 rayDir, vec3 sunDir) {
    float d = dot(rayDir, sunDir);
    vec3 sun = vec3(0.0);

    // Soft bloom
    if (d > SUN_BLOOM_SIZE) {
        float bloom = smoothstep(SUN_BLOOM_SIZE, SUN_DISC_SIZE, d);
        sun += vec3(1.0, 0.9, 0.7) * bloom * 0.5;
    }
    // Hard disc
    if (d > SUN_DISC_SIZE) {
        float disc = smoothstep(SUN_DISC_SIZE, 1.0, d);
        sun += vec3(1.0, 0.98, 0.92) * disc * 3.0;
    }
    return sun;
}

// ===========================================================================
// WAVE NORMAL PERTURBATION (V2) — multi-octave sin waves
// ===========================================================================

vec3 waveNormal(vec3 normal, vec3 hitPoint, float time) {
    vec2 uv = equirectangularUV(hitPoint) * WAVE_FREQUENCY;
    float t = time * WAVE_SPEED;

    // Multi-directional wave offsets
    float wave1 = sin(uv.x * 3.7 + t * 0.9) * sin(uv.y * 2.3 + t * 0.7);
    float wave2 = sin(uv.x * 5.1 - t * 1.1) * sin(uv.y * 4.7 + t * 0.5);
    float wave3 = sin(uv.x * 1.3 + uv.y * 6.1 + t * 1.3);

    float dx = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2) * WAVE_AMPLITUDE;
    float dy = (wave1 * 0.3 + wave2 * 0.5 + wave3 * 0.2) * WAVE_AMPLITUDE;

    // Perturb the normal in the tangent plane
    vec3 tangentU = normalize(cross(normal, vec3(0.0, 1.0, 0.001)));
    vec3 tangentV = cross(normal, tangentU);

    return normalize(normal + tangentU * dx + tangentV * dy);
}

// ===========================================================================
// MAIN FRAGMENT ENTRY POINT
// ===========================================================================

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // ----- Camera ray setup ------------------------------------------------
    vec3 rayDir = cameraRayDir(fragCoord, uResolution, uCameraPos, uCameraUp, uFOV);
    vec3 ro = uCameraPos;

    // =======================================================================
    // BACKGROUND: Black space + Stars + Sun (ray-miss path)
    // =======================================================================

    vec3 stars    = starField(rayDir, uTime);
    vec3 sun      = sunDisc(rayDir, uSunDir);

    // Black space with stars always visible and sun disc
    vec3 background = stars + sun;

    // =======================================================================
    // V5: CLOUD SHELL INTERSECTION (outer sphere)
    // =======================================================================

    float tCloud = intersectSphere(ro, rayDir, GLOBE_ORIGIN, uCloudRadius);

    // =======================================================================
    // V1: GLOBE INTERSECTION
    // =======================================================================

    float tGlobe = intersectSphere(ro, rayDir, GLOBE_ORIGIN, uGlobeRadius);

    // No globe hit — render sky
    if (tGlobe < 0.0) {
        // Even if globe missed, we might see the cloud shell from outside
        // but clouds should wrap the globe, so skip if globe is missed
        vec3 finalColor = background;

        // Atmospheric rim glow even when the globe is just off-screen
        // (creates a subtle halo effect)
        float closestApproach = length(cross(ro, rayDir));
        float atmoEdge = uGlobeRadius + ATMO_THICKNESS * uGlobeRadius;
        if (closestApproach < atmoEdge && closestApproach > uGlobeRadius * 0.95) {
            float rimFactor = smoothstep(atmoEdge, uGlobeRadius, closestApproach);
            float sunAlignment = max(dot(rayDir, uSunDir), 0.0);
            vec3 rimColor = mix(vec3(0.3, 0.5, 1.0), vec3(1.0, 0.6, 0.3), pow(sunAlignment, 4.0));
            finalColor += rimColor * rimFactor * RIM_INTENSITY * 0.5;
        }

        fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
        return;
    }

    // =======================================================================
    // GLOBE SURFACE PROCESSING
    // =======================================================================

    vec3 hitPoint = ro + rayDir * tGlobe;
    vec3 normal   = normalize(hitPoint - GLOBE_ORIGIN);
    vec3 viewDir  = normalize(ro - hitPoint);
    
    // Check viewing angle - at extreme glancing angles (looking at the edge
    // of the globe), we blend to atmosphere rather than showing full surface.
    // This prevents land textures from appearing outside the visible globe disk.
    float viewAngle = dot(viewDir, normal);
    
    // Fade surface contribution at glancing angles to avoid hard popping.
    // Below 0.10: pure atmosphere (no textures sampled for optimization)
    // 0.10 to 0.20: smooth blend from atmosphere to surface
    // Above 0.20: full surface detail
    const float atmosphereOnlyThreshold = 0.10;
    const float fullSurfaceThreshold = 0.20;
    
    if (viewAngle < atmosphereOnlyThreshold) {
        // Very glancing angle - render atmosphere only, skip texture sampling
        vec3 finalColor = background;
        
        // Atmospheric rim glow for glancing angles
        float rim = 1.0 - viewAngle;
        rim = pow(rim, 3.0);
        float sunAlignment = max(dot(rayDir, uSunDir), 0.0);
        vec3 rimColor = mix(vec3(0.3, 0.5, 1.0), vec3(1.0, 0.6, 0.3), pow(sunAlignment, 4.0));
        finalColor += rimColor * rim * RIM_INTENSITY;
        
        fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
        return;
    }

    // ----- Texture sampling (only after confirming we're within or near the globe disk) ----
    vec2 uv         = equirectangularUV(hitPoint);
    vec4 satColor   = texture(uSatellite, uv);
    float heightVal = texture(uHeightmap, uv).r;
    float shoreDist = texture(uShoreDist, uv).r;
    
    // Compute surface contribution fade for smooth limb transition
    float surfaceFade = smoothstep(atmosphereOnlyThreshold, fullSurfaceThreshold, viewAngle);

    // ----- Raw texture mode (shading disabled) -----------------------------
    // When uEnableShading is off, output the satellite texture directly
    // with no lighting, ocean, foam, clouds, or atmosphere. Useful for
    // debugging texture projection and plane direction.
    if (uEnableShading < 0.5) {
        vec3 rawColor = satColor.rgb;

        // Country borders (distance field from uShoreDist green channel).
        // Must render here because the early return below skips the full
        // V7 border block further down.
        {
            float borderDist = texture(uShoreDist, uv).g;
            float camAlt = length(uCameraPos) - uGlobeRadius;
            float borderWidth = mix(0.14, 0.10, smoothstep(0.3, 3.0, camAlt));
            float borderLine = 1.0 - smoothstep(0.0, borderWidth, borderDist);
            float borderAlpha = borderLine * 0.8;
            vec3 borderColor = vec3(1.0, 1.0, 1.0);
            rawColor = mix(rawColor, borderColor, borderAlpha);
        }

        vec3 finalColor = mix(background, rawColor, surfaceFade);
        // Gamma correction only (no tone-mapping needed for raw texture)
        finalColor = pow(finalColor, vec3(1.0 / 2.2));
        fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
        return;
    }

    // ----- Surface classification ------------------------------------------
    bool isOcean = heightVal < SEA_LEVEL;

    // ----- Diffuse lighting ------------------------------------------------
    float NdotL    = dot(normal, uSunDir);
    float diffuse  = max(NdotL, 0.0);

    // =======================================================================
    // V6: DAY/NIGHT TERMINATOR
    // =======================================================================

    // When night is disabled, force full daylight everywhere.
    float dayFactor = uEnableNight > 0.5
        ? smoothstep(TERMINATOR_SOFT, TERMINATOR_HARD, NdotL)
        : 1.0;

    // Warm terminator glow (sunset orange at the day/night boundary)
    float terminatorZone = uEnableNight > 0.5
        ? smoothstep(-0.15, 0.0, NdotL) * smoothstep(0.25, 0.05, NdotL)
        : 0.0;
    vec3 terminatorGlow  = TERMINATOR_WARM * terminatorZone * 0.5;

    // =======================================================================
    // V1: TERRAIN RENDERING (land surface)
    // =======================================================================

    vec3 surfaceColor;

    if (!isOcean) {
        // Land — satellite texture with diffuse lighting
        vec3 landColor = satColor.rgb;

        // Height-based relief shading (subtle darkening in valleys)
        float relief = mix(0.85, 1.0, smoothstep(SEA_LEVEL, 0.6, heightVal));
        landColor *= relief;

        // Apply lighting
        float ambientLand = 0.06;
        landColor *= (diffuse * 0.9 + ambientLand);

        // Terminator warm glow on land
        landColor += terminatorGlow * 0.4;

        surfaceColor = landColor;
    }

    // =======================================================================
    // V2: OCEAN RENDERING
    // =======================================================================

    else {
        // Depth-based ocean colour
        float depthNorm = smoothstep(0.0, SEA_LEVEL, heightVal);
        vec3 oceanColor;
        if (depthNorm < 0.25) {
            oceanColor = mix(OCEAN_DEEP, OCEAN_MID, depthNorm / 0.25);
        } else if (depthNorm < 0.6) {
            oceanColor = mix(OCEAN_MID, OCEAN_SHALLOW, (depthNorm - 0.25) / 0.35);
        } else {
            oceanColor = mix(OCEAN_SHALLOW, OCEAN_COASTAL, (depthNorm - 0.6) / 0.4);
        }

        // Animated wave normal perturbation
        vec3 waveN = waveNormal(normal, hitPoint, uTime);

        // Diffuse lighting with wave normal
        float oceanDiffuse = max(dot(waveN, uSunDir), 0.0);
        float ambientOcean = 0.06;
        oceanColor *= (oceanDiffuse * 0.85 + ambientOcean);

        // Specular sun reflection (Gaussian model)
        float spec = gaussianSpecular(waveN, viewDir, uSunDir, 0.06);
        vec3 specColor = vec3(1.0, 0.95, 0.85) * spec * SPECULAR_INTENSITY * dayFactor;
        oceanColor += specColor;

        // Fresnel rim effect — brighter at glancing angles
        float f = fresnel(viewDir, waveN, FRESNEL_BIAS, FRESNEL_POWER);
        vec3 fresnelColor = mix(vec3(0.1, 0.3, 0.5), vec3(0.3, 0.6, 0.8), f);
        oceanColor = mix(oceanColor, fresnelColor, f * 0.4 * dayFactor);

        // Terminator warm glow on ocean
        oceanColor += terminatorGlow * 0.25;

        surfaceColor = oceanColor;
    }

    // =======================================================================
    // V3: COASTLINE FOAM
    // =======================================================================

    {
        float d = shoreDist;

        // Solid white shore edge
        float shoreEdge = smoothstep(FOAM_SHORE_WIDTH, 0.0, d);

        // Animated concentric foam rings
        float noiseVal = noise(uv * FOAM_NOISE_SCALE);
        float rings = sin(d * FOAM_RING_FREQ - uTime * FOAM_RING_SPEED + noiseVal * 6.0);
        rings = smoothstep(0.3, 0.8, rings);

        // Distance-based fade — foam disappears far from shore
        float distFade = 1.0 - smoothstep(0.0, FOAM_FADE_DIST, d);

        // Noise mask for organic breakup
        float noiseMask = smoothstep(0.3, 0.6, noise(uv * FOAM_NOISE_SCALE * 2.0 + uTime * 0.1));

        // Combine foam layers
        float foam = max(shoreEdge, rings * distFade * noiseMask * 0.7);
        foam *= dayFactor; // Foam not visible on the night side

        // Blend foam into surface (white, lit by sun)
        vec3 foamColor = vec3(0.9, 0.93, 0.95) * (diffuse * 0.7 + 0.3);
        surfaceColor = mix(surfaceColor, foamColor, foam * 0.8);
    }

    // =======================================================================
    // V7: COUNTRY BORDERS (distance field from uShoreDist green channel)
    // =======================================================================

    {
        float borderDist = texture(uShoreDist, uv).g;

        // Camera altitude modulates border width only (not visibility)
        float camAlt = length(uCameraPos) - uGlobeRadius;

        // Border width: thicker when close, thinner when far away.
        // Minimum width of 0.10 ensures borders stay visible at max zoom-out.
        float borderWidth = mix(0.14, 0.10, smoothstep(0.3, 3.0, camAlt));

        // Anti-aliased border line (smooth falloff at edges)
        float borderLine = 1.0 - smoothstep(0.0, borderWidth, borderDist);

        // Borders always visible: constant white, unaffected by day/night.
        float borderAlpha = borderLine * 0.8;
        vec3 borderColor = vec3(1.0, 1.0, 1.0);

        surfaceColor = mix(surfaceColor, borderColor, borderAlpha);
    }

    // =======================================================================
    // V6: CITY LIGHTS ON NIGHT SIDE
    // =======================================================================

    {
        float nightFactor = 1.0 - dayFactor;
        if (uEnableNight > 0.5 && nightFactor > 0.01) {
            vec3 cityLights = texture(uCityLights, uv).rgb;
            // Boost and warm the city light emissions
            cityLights *= CITY_LIGHT_BOOST;
            vec3 lightTint = vec3(1.0, 0.85, 0.6); // Warm sodium-lamp colour
            cityLights *= lightTint;

            // City lights are emissive — add on top, scaled by night amount
            surfaceColor += cityLights * nightFactor;
        }
    }

    // =======================================================================
    // V5: CLOUD LAYER
    // =======================================================================

    {
        // Intersect the cloud shell
        float tC = tCloud;
        // If tCloud is behind the globe surface, skip
        if (tC > 0.0 && tC < tGlobe) {
            vec3 cloudHit = ro + rayDir * tC;
            vec3 cloudNormal = normalize(cloudHit - GLOBE_ORIGIN);
            vec2 cloudUV = equirectangularUV(cloudHit);

            // Animate cloud drift
            vec3 cloudSamplePos = cloudHit * 3.0;
            cloudSamplePos.x += uTime * CLOUD_DRIFT_SPEED;
            cloudSamplePos.z += uTime * CLOUD_DRIFT_SPEED * 0.7;

            // FBM for cloud density
            float density = fbm(cloudSamplePos);

            // Coverage threshold with smooth edges
            float cloudMask = smoothstep(CLOUD_COVERAGE - CLOUD_SOFTNESS, CLOUD_COVERAGE + CLOUD_SOFTNESS, density);

            if (cloudMask > 0.01) {
                // Cloud lighting from sun direction (bright tops, dark bottoms)
                float cloudNdotL = dot(cloudNormal, uSunDir);
                float cloudLight = smoothstep(-0.3, 1.0, cloudNdotL);
                float cloudDayFactor = smoothstep(TERMINATOR_SOFT, TERMINATOR_HARD, cloudNdotL);

                // Cloud colour: bright white in sun, grey in shadow
                vec3 cloudColor = mix(vec3(0.25, 0.27, 0.35), vec3(CLOUD_BRIGHTNESS), cloudLight);

                // Night-side clouds are faintly visible (moonlight)
                cloudColor = mix(vec3(0.03, 0.04, 0.06), cloudColor, max(cloudDayFactor, 0.05));

                // Terminator warm glow on clouds
                float cloudTerminator = smoothstep(-0.15, 0.0, cloudNdotL) * smoothstep(0.25, 0.05, cloudNdotL);
                cloudColor += TERMINATOR_WARM * cloudTerminator * 0.3;

                // Blend cloud on top of surface
                surfaceColor = mix(surfaceColor, cloudColor, cloudMask * 0.9);
            }
        }

        // Cloud shadows on terrain (approximate — darken terrain where clouds would be overhead)
        // Uses the globe normal as an approximation of "looking up" to the cloud layer
        vec3 shadowSamplePos = hitPoint * 3.0;
        shadowSamplePos.x += uTime * CLOUD_DRIFT_SPEED;
        shadowSamplePos.z += uTime * CLOUD_DRIFT_SPEED * 0.7;
        float shadowDensity = fbm(shadowSamplePos);
        float shadowMask = smoothstep(CLOUD_COVERAGE - CLOUD_SOFTNESS, CLOUD_COVERAGE + CLOUD_SOFTNESS, shadowDensity);
        surfaceColor *= 1.0 - shadowMask * CLOUD_SHADOW_STR * dayFactor;
    }

    // =======================================================================
    // V4: AERIAL PERSPECTIVE HAZE (distance-based desaturation)
    // =======================================================================

    {
        // Compute how much atmosphere the view ray passes through
        float viewDist = length(hitPoint - ro);
        float maxDist  = length(uCameraPos) + uGlobeRadius;
        float hazeFactor = smoothstep(0.0, maxDist, viewDist) * HAZE_STRENGTH;

        // Desaturate and lighten towards a hazy atmospheric colour
        vec3 hazeColor = mix(vec3(0.5, 0.6, 0.8), vec3(0.8, 0.7, 0.5), pow(max(dot(viewDir, uSunDir), 0.0), 4.0));
        hazeColor *= dayFactor;
        surfaceColor = mix(surfaceColor, hazeColor, hazeFactor);
    }

    // =======================================================================
    // V4: ATMOSPHERIC RIM GLOW (globe edge)
    // =======================================================================

    {
        float rim = 1.0 - max(dot(viewDir, normal), 0.0);
        rim = pow(rim, 5.0);

        // Day-side rim: blue-white atmospheric glow
        float sunAlignment = max(dot(normal, uSunDir), 0.0);
        vec3 dayRimColor = mix(vec3(0.3, 0.5, 1.0), vec3(0.5, 0.7, 1.0), sunAlignment);
        vec3 dayRim = dayRimColor * rim * RIM_INTENSITY * dayFactor;

        // Night-side rim: subtle blue glow (scattered moonlight / airglow)
        vec3 nightRimColor = vec3(0.08, 0.12, 0.25);
        vec3 nightRim = nightRimColor * rim * NIGHT_RIM_STRENGTH * (1.0 - dayFactor);

        // Terminator rim: warm orange at the day/night boundary
        vec3 termRim = TERMINATOR_WARM * rim * terminatorZone * 0.4;

        surfaceColor += dayRim + nightRim + termRim;
    }

    // =======================================================================
    // FINAL COMPOSITING
    // =======================================================================

    // Apply surface fade for smooth limb transition
    // Blend from pure atmosphere (background) to full surface rendering
    vec3 finalColor = mix(background, surfaceColor, surfaceFade);

    // Tone-map to prevent blown-out highlights
    finalColor = finalColor / (finalColor + vec3(1.0)); // Reinhard
    finalColor = pow(finalColor, vec3(1.0 / 2.2));      // Gamma correction

    fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
