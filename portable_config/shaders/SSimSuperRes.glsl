//!HOOK MAIN
//!BIND HOOKED
//!DESC SSimSuperRes Intermediate Detail & Edge Recovery
//!WHEN OUTPUT.w HOOKED.w > OUTPUT.h HOOKED.h > *

#define STRENGTH 0.45

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec4 hook() {
    vec4 center = HOOKED_texOff(vec2(0.0, 0.0));
    vec3 n = HOOKED_texOff(vec2( 0.0, -1.0)).rgb;
    vec3 s = HOOKED_texOff(vec2( 0.0,  1.0)).rgb;
    vec3 w = HOOKED_texOff(vec2(-1.0,  0.0)).rgb;
    vec3 e = HOOKED_texOff(vec2( 1.0,  0.0)).rgb;

    vec3 nw = HOOKED_texOff(vec2(-1.0, -1.0)).rgb;
    vec3 ne = HOOKED_texOff(vec2( 1.0, -1.0)).rgb;
    vec3 sw = HOOKED_texOff(vec2(-1.0,  1.0)).rgb;
    vec3 se = HOOKED_texOff(vec2( 1.0,  1.0)).rgb;

    vec3 mean = (n + s + w + e) * 0.15 + (nw + ne + sw + se) * 0.05 + center.rgb * 0.20;
    vec3 highpass = center.rgb - mean;

    float lc = luma(center.rgb);
    float lm = luma(mean);
    float var_local = (abs(luma(n) - lm) + abs(luma(s) - lm) + abs(luma(w) - lm) + abs(luma(e) - lm)) * 0.25;

    float weight = clamp(var_local * 6.0, 0.0, 1.0) * STRENGTH;

    vec3 min_nb = min(min(min(n, s), min(w, e)), center.rgb);
    vec3 max_nb = max(max(max(n, s), max(w, e)), center.rgb);

    vec3 result = center.rgb + highpass * (1.0 + weight);
    result = mix(result, clamp(result, min_nb, max_nb), 0.65);

    return vec4(clamp(result, 0.0, 1.0), center.a);
}
