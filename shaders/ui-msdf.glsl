uniform sampler msdfSampler;

vec2 sqr(vec2 x) { return x*x; } // squares vector components

float screenPxRange() {
    vec2 unitRange = vec2(1)/textureSize(ColorTexture, 0);
    // If inversesqrt is not available, use vec2(1.0)/sqrt
    vec2 screenTexSize = inversesqrt(sqr(dFdx(UV))+sqr(dFdy(UV)));
    // Can also be approximated as screenTexSize = vec2(1.0)/fwidth(UV);
    return max(0.5*dot(unitRange, screenTexSize), 1.0);
}

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

vec4 lovrmain() {
    vec3 msd = texture(sampler2D(ColorTexture, msdfSampler), UV).rgb;
    float sd = median(msd.r, msd.g, msd.b);
    float screenPxDistance = screenPxRange()*(sd - 0.5);
    float opacity = clamp(screenPxDistance + 0.5, 0.0, 1.0);
    return vec4(Color.rgb, Color.a * opacity);
}
