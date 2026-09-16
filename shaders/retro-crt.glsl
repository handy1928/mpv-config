//!HOOK OUTPUT
//!BIND HOOKED
//!BIND MAIN

// ==================== CONTROLS ====================
// Scanline Shape & Thickness (Adjust these to taste!)
#define SCANLINE_THINNESS 3.0    // 1.5 = thick chunky bars | 2.8 - 3.5 = thin, crisp, fine lines (recommended for 480p)
#define SCANLINE_STRENGTH 0.60   // Darkness depth: 0.4 = very subtle, 0.6 = balanced, 0.85 = dark
#define SCANLINE_CUTOFF 600.0    // Active on 480p/576p, auto-disabled above 600p

// Auto-fix for very low res (e.g. 240p)
#define DOUBLE_SCAN_240P 1       // 1 = doubles scanline count if video is <= 288p so lines stay fine

// Pixel Sharpness
#define SHARPNESS_H 0.5          // Horizontal sharpness (0.0 = soft, 1.0 = sharp)
#define SHARPNESS_V 1.0          // Vertical sharpness

// CRT Shadow Mask / Phosphor Grille
#define MASK_STRENGTH 0.15       // 0.0 = off, 0.15 = subtle CRT phosphor dots
#define MASK_SIZE 1.0
#define MASK_DOT_WIDTH 1
#define MASK_DOT_HEIGHT 1.0
#define MASK_STAGGER 0

// NTSC Artifacts & Glow
#define NTSC_CHROMA_BLEED 0.5    // Subtle horizontal color fringe
#define GLOW_STRENGTH 0.06       // Phosphor bloom
#define NOISE_STRENGTH 0.01      // Subtle analog grain

// Colors
#define GAMMA 2.2
#define BRIGHT_BOOST 1.06        // Slight compensation for scanline dimming
// ==================================================

#define PI 3.141592653589
const vec2 sharp = vec2(SHARPNESS_H, SHARPNESS_V);

// Safe linear-space texture sampling
vec3 sampleLinear(vec2 uv) {
    uv = clamp(uv, vec2(0.0), vec2(1.0));
    vec3 c = MAIN_tex(uv).rgb;
    return pow(c, vec3(GAMMA));
}

// NTSC composite color fringing
vec3 ntscArtifact(vec2 uv) {
    vec2 texel = 1.0 / MAIN_size;
    float offset = NTSC_CHROMA_BLEED * texel.x;

    float r = sampleLinear(uv - vec2(offset, 0.0)).r;
    float g = sampleLinear(uv).g;
    float b = sampleLinear(uv + vec2(offset, 0.0)).b;

    return vec3(r, g, b);
}

// Phosphor glow
vec3 phosphorGlow(vec2 uv, vec3 color) {
    if (GLOW_STRENGTH <= 0.0) return color;
    vec2 texel = 1.0 / MAIN_size;
    vec3 blur = (sampleLinear(uv + vec2(texel.x, 0.0)) +
                 sampleLinear(uv - vec2(texel.x, 0.0)) +
                 sampleLinear(uv + vec2(0.0, texel.y)) +
                 sampleLinear(uv - vec2(0.0, texel.y))) * 0.25;
    return mix(color, blur, GLOW_STRENGTH);
}

// Analog noise
float analogNoise(vec2 uv) {
    if (NOISE_STRENGTH <= 0.0) return 0.0;
    return (fract(sin(dot(uv * MAIN_size.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * NOISE_STRENGTH;
}

vec4 hook() {
    // Sharp CRT pixel curve
    vec2 fcoord = fract(MAIN_pos * MAIN_size - vec2(0.5));
    vec2 base   = MAIN_pos - MAIN_pt * fcoord;

    vec2 fstep  = step(0.5, fcoord);
    vec2 fcurve = fcoord - fstep;
    fcurve = vec2(0.5) - sqrt(vec2(0.25) - fcurve * fcurve) * sign(vec2(0.5) - fcoord);
    fcoord = mix(fcoord, fcurve, sharp);

    vec2 uv = base + MAIN_pt * fcoord;

    // 1. Linear color with NTSC chroma split
    vec3 color = ntscArtifact(uv);

    // 2. Phosphor glow
    color = phosphorGlow(uv, color);

    // 3. Scanline calculation
    float line_mult = (DOUBLE_SCAN_240P == 1 && MAIN_size.y <= 288.0) ? 2.0 : 1.0;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // A higher beam power tightens the dark gap into a fine slit
    float beam = clamp(luma * SCANLINE_THINNESS * 1.4, SCANLINE_THINNESS * 0.8, SCANLINE_THINNESS * 2.0);
    float scan_weight = 1.0 - pow(cos(MAIN_pos.y * 2.0 * PI * MAIN_size.y * line_mult) * 0.5 + 0.5, beam) * SCANLINE_STRENGTH;

    if (MAIN_size.y < SCANLINE_CUTOFF) {
        color *= scan_weight;
    }

    // 4. CRT Phosphor Mask
    if (MASK_STRENGTH > 0.0) {
        ivec2 mod_fac = ivec2(HOOKED_pos * HOOKED_size / vec2(MASK_SIZE, MASK_DOT_HEIGHT * MASK_SIZE));
        int dot_no = (mod_fac.x + (mod_fac.y % 2) * MASK_STAGGER) / MASK_DOT_WIDTH % 3;

        vec3 mask_weight = vec3(1.0 - MASK_STRENGTH);
        if (dot_no == 0)      mask_weight.r = 1.0;
        else if (dot_no == 1) mask_weight.g = 1.0;
        else                  mask_weight.b = 1.0;

        color *= mask_weight;
    }

    // 5. Noise
    color += vec3(analogNoise(MAIN_pos.xy));

    // 6. Return to sRGB gamma space
    color = max(color, vec3(0.0));
    color = pow(color, vec3(1.0 / GAMMA));
    color *= BRIGHT_BOOST;

    return vec4(color, 1.0);
}