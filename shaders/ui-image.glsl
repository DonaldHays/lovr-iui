uniform bool useAAUV;
uniform sampler imageSampler;

vec2 getAAUV(texture2D tex, vec2 uv) {
    vec2 texSize = textureSize(tex, 0);
    vec2 pixelSpaceTexCoord = uv * texSize;
    vec2 centerCoord = floor(pixelSpaceTexCoord - 0.5f) + 0.5f;
    vec2 halfFWidth = fwidth(pixelSpaceTexCoord) * 0.5f;
    vec2 offset = smoothstep(
        0.5f - halfFWidth,
        0.5f + halfFWidth,
        pixelSpaceTexCoord - centerCoord
    );
    vec2 aauv = (centerCoord + offset) / texSize;

    return aauv;
}

vec4 lovrmain() {
    vec2 filteredUV;

    if (useAAUV) {
        filteredUV = getAAUV(ColorTexture, UV);
    } else {
        filteredUV = UV;
    }

    return Color * texture(sampler2D(ColorTexture, imageSampler), filteredUV);
}
