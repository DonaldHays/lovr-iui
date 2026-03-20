uniform sampler imageSampler;

vec4 lovrmain() {
    return Color * texture(sampler2D(ColorTexture, imageSampler), UV);
}
