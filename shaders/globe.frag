// =============================================================================
// globe.frag — Flit Globe Fragment Shader (Performance-Optimized)
//
// Renders a photorealistic Earth globe with:
//   V1: Ray-sphere globe with satellite texture + diffuse lighting
//   V2: Ocean coloring, specular, fresnel (ocean detected from satellite color)
//   V4: Atmospheric scattering, rim glow, sky gradient, sun disc
//   V5: Procedural volumetric clouds on a shell above the globe (high alt only)
//   V6: Day/night cycle, city lights, star field, terminator glow
//
// 2 texture samplers (reduced from 4):
//   uSatellite  — NASA Blue Marble
//   uCityLights — NASA Earth at Night
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
uniform float uEnableClouds;  // Index 17:  0.0 = no clouds,   1.0 = clouds on
uniform float uCloudCoverage; // Index 18:  cloud coverage threshold (0.0–1.0)
uniform float uCloudOpacity;  // Index 19:  cloud blend opacity (0.0–1.0)
uniform float uCameraDist;    // Index 20:  camera distance from globe center

// ---------------------------------------------------------------------------
// Samplers — 2 per shader pass (reduced from 4)
// ---------------------------------------------------------------------------

uniform sampler2D uSatellite;   // NASA Blue Marble (equirectangular)
uniform sampler2D uCityLights;  // NASA Earth at Night

// Fragment output
out vec4 fragColor;

// ===========================================================================
// CONSTANTS
// ===========================================================================

// Globe geometry
const vec3  GLOBE_ORIGIN      = vec3(0.0);

// Ocean detection — satellite blue channel threshold
const float OCEAN_BLUE_RATIO  = 1.2;

// Ocean surface
const float SPECULAR_POWER    = 128.0;
const float SPECULAR_INTENSITY = 1.8;
const float FRESNEL_BIAS       = 0.04;

// Atmosphere
const vec3  RAYLEIGH_COEFF     = vec3(5.8e-3, 1.35e-2, 3.31e-2);
const float MIE_COEFF          = 4.0e-3;
const float MIE_G              = 0.76;
const float ATMO_THICKNESS     = 0.05;
const float RIM_INTENSITY      = 0.35;
const float HAZE_STRENGTH      = 0.15;

// Clouds
const float CLOUD_SOFTNESS     = 0.25;
const float CLOUD_DRIFT_SPEED  = 0.008;
const float CLOUD_BRIGHTNESS   = 1.0;
const float CLOUD_SHADOW_STR   = 0.15;
const int   FBM_OCTAVES        = 4;

// Cloud altitude gate — skip clouds when camera is close to globe
const float CLOUD_MIN_DISTANCE = 1.5;

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

// Precomputed Mie constants (MIE_G = 0.76)
const float MIE_G2             = 0.5776;  // MIE_G * MIE_G
const float MIE_2G             = 1.52;    // 2.0 * MIE_G
const float MIE_NUMERATOR      = 0.03362; // (1 - MIE_G2) / (4 * PI)

const float PI                 = 3.14159265;
const float TWO_PI             = 6.28318530;

// ===========================================================================
// HELPER FUNCTIONS
// ===========================================================================

// 2D → 1D hash (deterministic pseudo-random)
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
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

// Fractal Brownian motion — 3D
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

// Analytical ray-sphere intersection — nearest positive t, or -1.0 on miss
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

vec3 cameraRayDir(vec2 fragCoord, vec2 resolution, vec3 camPos, vec3 camUp, float fov) {
    vec2 uv = (fragCoord - 0.5 * resolution) / resolution.y;
    uv.y = -uv.y;
    const float tiltDown = 0.35;
    uv.y += tiltDown;

    float halfFov = tan(fov * 0.5);
    uv *= halfFov;

    vec3 forward = normalize(-camPos);
    vec3 right   = normalize(cross(camUp, forward));
    vec3 up      = cross(forward, right);

    return normalize(uv.x * right + uv.y * up + forward);
}

// -- Lighting helpers -------------------------------------------------------

// Blinn-Phong specular (cheaper than gaussian: no acos, no exp)
float specularHighlight(vec3 normal, vec3 viewDir, vec3 lightDir, float power) {
    vec3 halfVec = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, halfVec), 0.0);
    // Use multiply chain for power=128: x^128 = ((((((x^2)^2)^2)^2)^2)^2)^2
    // But since power varies, use pow — still much cheaper than acos+exp
    return pow(NdotH, power);
}

// Schlick fresnel approximation (unrolled for power=5)
float fresnel(vec3 viewDir, vec3 normal) {
    float base = 1.0 - max(dot(viewDir, normal), 0.0);
    float base2 = base * base;
    float base4 = base2 * base2;
    float f = FRESNEL_BIAS + (1.0 - FRESNEL_BIAS) * base4 * base; // base^5
    return clamp(f, 0.0, 1.0);
}

// ===========================================================================
// ATMOSPHERE (V4) — analytical Rayleigh + Mie scattering
// ===========================================================================

vec3 atmosphere(vec3 rayDir, vec3 sunDir) {
    float sunDot = dot(rayDir, sunDir);

    // Rayleigh scattering
    float rayleighPhase = 0.75 * (1.0 + sunDot * sunDot);
    vec3 rayleigh = RAYLEIGH_COEFF * rayleighPhase;

    // Mie scattering — precomputed constants, multiply chain for pow(x,1.5)
    float mieBase = 1.0 + MIE_G2 - MIE_2G * sunDot;
    float miePhase = MIE_NUMERATOR / (mieBase * sqrt(mieBase)); // x^1.5 = x * sqrt(x)
    vec3 mie = vec3(MIE_COEFF) * miePhase;

    // Horizon brightening — multiply chains instead of pow
    float horizonBase = max(1.0 - abs(rayDir.y), 0.0);
    float hb2 = horizonBase * horizonBase;
    float horizonFactor = hb2 * hb2; // x^4

    float sunH = max(sunDot, 0.0);
    float sh2 = sunH * sunH;
    float sh4 = sh2 * sh2;
    float sunHorizon = sh4 * sh4; // x^8

    vec3 horizonWarm = mix(vec3(0.2, 0.4, 0.8), vec3(1.0, 0.5, 0.2), sunHorizon) * horizonFactor;

    vec3 scatter = (rayleigh + mie) * 12.0 + horizonWarm * 0.6;

    // Vertical gradient
    float altitude = max(rayDir.y, 0.0);
    vec3 zenithColor  = vec3(0.05, 0.10, 0.25);
    vec3 horizonColor = vec3(0.40, 0.55, 0.80);
    vec3 skyGradient  = mix(horizonColor, zenithColor, sqrt(altitude));

    // Night sky
    float dayAmount = smoothstep(-0.3, 0.1, sunDir.y);
    vec3 nightSky = vec3(0.005, 0.007, 0.02);

    vec3 daySky = skyGradient + scatter;
    return mix(nightSky, daySky, dayAmount);
}

// ===========================================================================
// STARS (V6) — procedural star field
// ===========================================================================

vec3 starField(vec3 rayDir, float time) {
    vec2 starUV = equirectangularUV(rayDir) * 800.0;
    vec2 cell = floor(starUV);
    float starHash = hash21(cell);

    vec3 stars = vec3(0.0);
    if (starHash > STAR_THRESHOLD) {
        float brightness = (starHash - STAR_THRESHOLD) / (1.0 - STAR_THRESHOLD);
        brightness *= brightness;
        float twinkle = 0.7 + 0.3 * sin(time * STAR_TWINKLE_SPEED + starHash * 100.0);
        brightness *= twinkle;

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

    if (d > SUN_BLOOM_SIZE) {
        float bloom = smoothstep(SUN_BLOOM_SIZE, SUN_DISC_SIZE, d);
        sun += vec3(1.0, 0.9, 0.7) * bloom * 0.5;
    }
    if (d > SUN_DISC_SIZE) {
        float disc = smoothstep(SUN_DISC_SIZE, 1.0, d);
        sun += vec3(1.0, 0.98, 0.92) * disc * 3.0;
    }
    return sun;
}

// ===========================================================================
// MAIN FRAGMENT ENTRY POINT
// ===========================================================================

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // ----- Camera ray setup ------------------------------------------------
    vec3 rayDir = cameraRayDir(fragCoord, uResolution, uCameraPos, uCameraUp, uFOV);
    vec3 ro = uCameraPos;

    // Use precomputed camera distance uniform (avoid per-pixel length())
    float camDist = uCameraDist;
    float camAlt = camDist - uGlobeRadius;

    // =======================================================================
    // BACKGROUND: Black space + Stars + Sun
    // =======================================================================

    vec3 stars    = starField(rayDir, uTime);
    vec3 sun      = sunDisc(rayDir, uSunDir);
    vec3 background = stars + sun;

    // =======================================================================
    // V5: CLOUD SHELL INTERSECTION (only at high altitude)
    // =======================================================================

    float tCloud = -1.0;
    bool cloudsActive = uEnableClouds > 0.5 && camDist > CLOUD_MIN_DISTANCE;
    if (cloudsActive) {
        tCloud = intersectSphere(ro, rayDir, GLOBE_ORIGIN, uCloudRadius);
    }

    // =======================================================================
    // GLOBE INTERSECTION
    // =======================================================================

    float tGlobe = intersectSphere(ro, rayDir, GLOBE_ORIGIN, uGlobeRadius);

    // No globe hit — render sky
    if (tGlobe < 0.0) {
        vec3 finalColor = background;

        // Atmospheric rim glow halo
        float closestApproach = length(cross(ro, rayDir));
        float atmoEdge = uGlobeRadius + ATMO_THICKNESS * uGlobeRadius;
        if (closestApproach < atmoEdge && closestApproach > uGlobeRadius * 0.95) {
            float rimFactor = smoothstep(atmoEdge, uGlobeRadius, closestApproach);
            float sunAlignment = max(dot(rayDir, uSunDir), 0.0);
            float sa2 = sunAlignment * sunAlignment;
            vec3 rimColor = mix(vec3(0.3, 0.5, 1.0), vec3(1.0, 0.6, 0.3), sa2 * sa2);
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

    // Glancing angle detection for smooth limb transition
    float viewAngle = dot(viewDir, normal);

    const float atmosphereOnlyThreshold = 0.10;
    const float fullSurfaceThreshold = 0.20;

    if (viewAngle < atmosphereOnlyThreshold) {
        // Very glancing angle — atmosphere only, skip texture sampling
        vec3 finalColor = background;
        float rim = 1.0 - viewAngle;
        float rim2 = rim * rim;
        rim = rim2 * rim; // rim^3
        float sunAlignment = max(dot(rayDir, uSunDir), 0.0);
        float sa2 = sunAlignment * sunAlignment;
        vec3 rimColor = mix(vec3(0.3, 0.5, 1.0), vec3(1.0, 0.6, 0.3), sa2 * sa2);
        finalColor += rimColor * rim * RIM_INTENSITY;

        fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
        return;
    }

    // ----- Texture sampling ------------------------------------------------
    vec2 uv       = equirectangularUV(hitPoint);
    vec4 satColor = texture(uSatellite, uv);

    float surfaceFade = smoothstep(atmosphereOnlyThreshold, fullSurfaceThreshold, viewAngle);

    // ----- Raw texture mode (shading disabled) -----------------------------
    if (uEnableShading < 0.5) {
        vec3 finalColor = mix(background, satColor.rgb, surfaceFade);
        finalColor = pow(finalColor, vec3(1.0 / 2.2));
        fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
        return;
    }

    // ----- Surface classification (from satellite color, no heightmap) -----
    bool isOcean = satColor.b > max(satColor.r, satColor.g) * OCEAN_BLUE_RATIO;

    // ----- Diffuse lighting ------------------------------------------------
    float NdotL   = dot(normal, uSunDir);
    float diffuse = max(NdotL, 0.0);

    // =======================================================================
    // V6: DAY/NIGHT TERMINATOR
    // =======================================================================

    float dayFactor = uEnableNight > 0.5
        ? smoothstep(TERMINATOR_SOFT, TERMINATOR_HARD, NdotL)
        : 1.0;

    float terminatorZone = uEnableNight > 0.5
        ? smoothstep(-0.15, 0.0, NdotL) * smoothstep(0.25, 0.05, NdotL)
        : 0.0;
    vec3 terminatorGlow = TERMINATOR_WARM * terminatorZone * 0.5;

    // =======================================================================
    // SURFACE RENDERING
    // =======================================================================

    vec3 surfaceColor;

    if (!isOcean) {
        // Land — satellite texture with diffuse lighting
        vec3 landColor = satColor.rgb;
        // Night-side ambient is near-black (0.01) so the surface is dark
        // enough for city lights to stand out. Day-side ambient is 0.06.
        float ambientLand = mix(0.01, 0.06, dayFactor);
        landColor *= (diffuse * 0.9 + ambientLand);
        landColor += terminatorGlow * 0.4;
        surfaceColor = landColor;
    } else {
        // Ocean — tinted satellite color with specular + fresnel
        vec3 oceanColor = satColor.rgb * vec3(0.8, 0.9, 1.1);

        float oceanDiffuse = max(dot(normal, uSunDir), 0.0);
        // Near-black ambient on night-side ocean to eliminate blue hue.
        float ambientOcean = mix(0.01, 0.06, dayFactor);
        oceanColor *= (oceanDiffuse * 0.85 + ambientOcean);

        // Blinn-Phong specular (cheaper than gaussian)
        float spec = specularHighlight(normal, viewDir, uSunDir, SPECULAR_POWER);
        vec3 specColor = vec3(1.0, 0.95, 0.85) * spec * SPECULAR_INTENSITY * dayFactor;
        oceanColor += specColor;

        // Fresnel rim effect (unrolled pow)
        float f = fresnel(viewDir, normal);
        vec3 fresnelColor = mix(vec3(0.1, 0.3, 0.5), vec3(0.3, 0.6, 0.8), f);
        oceanColor = mix(oceanColor, fresnelColor, f * 0.4 * dayFactor);

        oceanColor += terminatorGlow * 0.25;
        surfaceColor = oceanColor;
    }

    // =======================================================================
    // V5: CLOUD LAYER (gated: high altitude only)
    // Rendered BEFORE city lights so night-side clouds appear as dark
    // silhouettes against the surface, and city lights shine through gaps.
    // =======================================================================

    if (cloudsActive) {
        // Cloud shell overlay
        float tC = tCloud;
        if (tC > 0.0 && tC < tGlobe) {
            vec3 cloudHit = ro + rayDir * tC;
            vec3 cloudNormal = normalize(cloudHit - GLOBE_ORIGIN);

            vec3 cloudSamplePos = cloudHit * 3.0;
            cloudSamplePos.x += uTime * CLOUD_DRIFT_SPEED;
            cloudSamplePos.z += uTime * CLOUD_DRIFT_SPEED * 0.7;

            float density = fbm(cloudSamplePos);
            float cloudMask = smoothstep(uCloudCoverage - CLOUD_SOFTNESS, uCloudCoverage + CLOUD_SOFTNESS, density);

            if (cloudMask > 0.01) {
                float cloudNdotL = dot(cloudNormal, uSunDir);
                float cloudLight = smoothstep(-0.3, 1.0, cloudNdotL);
                float cloudDayFactor = smoothstep(TERMINATOR_SOFT, TERMINATOR_HARD, cloudNdotL);

                vec3 cloudColor = mix(vec3(0.25, 0.27, 0.35), vec3(CLOUD_BRIGHTNESS), cloudLight);
                // Night-side clouds: visible as dark gray silhouettes (15% brightness)
                // so they're clearly distinguishable against the dark surface.
                cloudColor = mix(vec3(0.06, 0.06, 0.08), cloudColor, max(cloudDayFactor, 0.15));

                float cloudTerminator = smoothstep(-0.15, 0.0, cloudNdotL) * smoothstep(0.25, 0.05, cloudNdotL);
                cloudColor += TERMINATOR_WARM * cloudTerminator * 0.3;

                surfaceColor = mix(surfaceColor, cloudColor, cloudMask * uCloudOpacity);
            }
        }

        // Cloud shadows on terrain
        vec3 shadowSamplePos = hitPoint * 3.0;
        shadowSamplePos.x += uTime * CLOUD_DRIFT_SPEED;
        shadowSamplePos.z += uTime * CLOUD_DRIFT_SPEED * 0.7;
        float shadowDensity = fbm(shadowSamplePos);
        float shadowMask = smoothstep(uCloudCoverage - CLOUD_SOFTNESS, uCloudCoverage + CLOUD_SOFTNESS, shadowDensity);
        surfaceColor *= 1.0 - shadowMask * CLOUD_SHADOW_STR * dayFactor;
    }

    // =======================================================================
    // V6: CITY LIGHTS ON NIGHT SIDE
    // Rendered AFTER clouds so lights shine through cloud gaps.
    // =======================================================================

    {
        float nightFactor = 1.0 - dayFactor;
        if (uEnableNight > 0.5 && nightFactor > 0.01) {
            vec3 cityLights = texture(uCityLights, uv).rgb;
            cityLights *= CITY_LIGHT_BOOST;
            vec3 lightTint = vec3(1.0, 0.85, 0.6);
            cityLights *= lightTint;
            surfaceColor += cityLights * nightFactor;
        }
    }

    // =======================================================================
    // V4: AERIAL PERSPECTIVE HAZE
    // =======================================================================

    {
        float viewDist = length(hitPoint - ro);
        float maxDist  = camDist + uGlobeRadius;
        // Reduce haze on night side so it doesn't add blue tint to dark areas.
        float hazeFactor = smoothstep(0.0, maxDist, viewDist) * HAZE_STRENGTH * dayFactor;

        float sunViewDot = max(dot(viewDir, uSunDir), 0.0);
        float sv2 = sunViewDot * sunViewDot;
        vec3 hazeColor = mix(vec3(0.5, 0.6, 0.8), vec3(0.8, 0.7, 0.5), sv2 * sv2);
        surfaceColor = mix(surfaceColor, hazeColor, hazeFactor);
    }

    // =======================================================================
    // V4: ATMOSPHERIC RIM GLOW (globe edge)
    // =======================================================================

    {
        float rimBase = 1.0 - max(dot(viewDir, normal), 0.0);
        float rb2 = rimBase * rimBase;
        float rim = rb2 * rb2 * rimBase; // rimBase^5

        float sunAlignment = max(dot(normal, uSunDir), 0.0);
        vec3 dayRimColor = mix(vec3(0.3, 0.5, 1.0), vec3(0.5, 0.7, 1.0), sunAlignment);
        vec3 dayRim = dayRimColor * rim * RIM_INTENSITY * dayFactor;

        vec3 nightRimColor = vec3(0.04, 0.05, 0.10);
        vec3 nightRim = nightRimColor * rim * NIGHT_RIM_STRENGTH * (1.0 - dayFactor);

        vec3 termRim = TERMINATOR_WARM * rim * terminatorZone * 0.4;

        surfaceColor += dayRim + nightRim + termRim;
    }

    // =======================================================================
    // FINAL COMPOSITING
    // =======================================================================

    vec3 finalColor = mix(background, surfaceColor, surfaceFade);

    // Reinhard tone-map + gamma
    finalColor = finalColor / (finalColor + vec3(1.0));
    finalColor = pow(finalColor, vec3(1.0 / 2.2));

    fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
