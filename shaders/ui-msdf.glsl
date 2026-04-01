uniform sampler msdfSampler;

vec2 squared(vec2 v) {
    return v * v;
}

float screenPxRange() {
    vec2 unitRange = vec2(2) / textureSize(ColorTexture, 0);
    vec2 screenTexSize = inversesqrt(squared(dFdx(UV)) + squared(dFdy(UV)));
    
    return max(0.5 * dot(unitRange, screenTexSize), 1.0);
}

float median(float a, float b, float c) {
    return max(min(a, b), min(max(a, b), c));
}

vec4 lovrmain() {
    vec2 uv = clamp(UV, vec2(0.01), vec2(0.99));

    vec3 msd = texture(sampler2D(ColorTexture, msdfSampler), uv).rgb;
    float sd = median(msd.r, msd.g, msd.b);
    float screenPxDistance = screenPxRange() * (sd - 0.5);
    float opacity = clamp(screenPxDistance + 0.5, 0.0, 1.0);

    return vec4(Color.rgb, Color.a * opacity);
}
