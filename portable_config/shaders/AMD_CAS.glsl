//!HOOK MAIN
//!BIND HOOKED
//!DESC AMD FidelityFX Contrast Adaptive Sharpening (CAS - Low Power)

#define SHARPNESS 0.65

vec4 hook() {
    vec2 pt = HOOKED_pt;
    vec4 e = HOOKED_texOff(vec2( 0.0,  0.0));
    vec3 b = HOOKED_texOff(vec2( 0.0, -1.0)).rgb;
    vec3 d = HOOKED_texOff(vec2(-1.0,  0.0)).rgb;
    vec3 f = HOOKED_texOff(vec2( 1.0,  0.0)).rgb;
    vec3 h = HOOKED_texOff(vec2( 0.0,  1.0)).rgb;

    vec3 a = HOOKED_texOff(vec2(-1.0, -1.0)).rgb;
    vec3 c = HOOKED_texOff(vec2( 1.0, -1.0)).rgb;
    vec3 g = HOOKED_texOff(vec2(-1.0,  1.0)).rgb;
    vec3 i = HOOKED_texOff(vec2( 1.0,  1.0)).rgb;

    vec3 mnRGB  = min(min(min(d, e.rgb), min(f, b)), h);
    vec3 mnRGB2 = min(mnRGB, min(min(a, c), min(g, i)));
    mnRGB += mnRGB2;

    vec3 mxRGB  = max(max(max(d, e.rgb), max(f, b)), h);
    vec3 mxRGB2 = max(mxRGB, max(max(a, c), max(g, i)));
    mxRGB += mxRGB2;

    vec3 rcpMRGB = 1.0 / max(mxRGB, vec3(0.0001));
    vec3 ampRGB  = clamp(min(mnRGB, 2.0 - mxRGB) * rcpMRGB, 0.0, 1.0);
    ampRGB = sqrt(ampRGB);

    float peak = -1.0 / mix(8.0, 5.0, SHARPNESS);
    vec3 wRGB  = ampRGB * peak;
    vec3 rcpWeightRGB = 1.0 / (1.0 + 4.0 * wRGB);

    vec3 window = (b + d) + (f + h);
    vec3 outColor = clamp((window * wRGB + e.rgb) * rcpWeightRGB, 0.0, 1.0);

    return vec4(outColor, e.a);
}
