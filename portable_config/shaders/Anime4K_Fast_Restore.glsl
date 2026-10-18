//!HOOK MAIN
//!BIND HOOKED
//!DESC Anime4K Fast Line Thinning & Highlight Clamp (Intermediate/Low-Power Anime)

#define LINE_STRENGTH 0.55

float get_luma(vec3 rgb) {
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

vec4 hook() {
    vec4 cc = HOOKED_texOff(vec2(0.0, 0.0));
    vec4 n  = HOOKED_texOff(vec2( 0.0, -1.0));
    vec4 s  = HOOKED_texOff(vec2( 0.0,  1.0));
    vec4 w  = HOOKED_texOff(vec2(-1.0,  0.0));
    vec4 e  = HOOKED_texOff(vec2( 1.0,  0.0));

    vec4 nw = HOOKED_texOff(vec2(-1.0, -1.0));
    vec4 ne = HOOKED_texOff(vec2( 1.0, -1.0));
    vec4 sw = HOOKED_texOff(vec2(-1.0,  1.0));
    vec4 se = HOOKED_texOff(vec2( 1.0,  1.0));

    float lc = get_luma(cc.rgb);
    float ln = get_luma(n.rgb);
    float ls = get_luma(s.rgb);
    float lw = get_luma(w.rgb);
    float le = get_luma(e.rgb);

    float gx = (le - lw) * 0.5;
    float gy = (ls - ln) * 0.5;
    float edge = clamp(sqrt(gx * gx + gy * gy) * 3.2, 0.0, 1.0);

    vec3 min_card = min(min(n.rgb, s.rgb), min(w.rgb, e.rgb));
    vec3 max_card = max(max(n.rgb, s.rgb), max(w.rgb, e.rgb));
    vec3 min_diag = min(min(nw.rgb, ne.rgb), min(sw.rgb, se.rgb));
    vec3 max_diag = max(max(nw.rgb, ne.rgb), max(sw.rgb, se.rgb));

    vec3 min_all = min(min_card, min_diag);
    vec3 max_all = max(max_card, max_diag);

    float avg_luma = (ln + ls + lw + le) * 0.25;
    vec3 target = (lc < avg_luma) ? mix(cc.rgb, min_card, edge * LINE_STRENGTH)
                                  : mix(cc.rgb, max_card, edge * (LINE_STRENGTH * 0.7));

    vec3 clamped = clamp(target, min_all, max_all);
    return vec4(clamped, cc.a);
}
