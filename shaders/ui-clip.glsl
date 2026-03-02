uniform ClipPlanes {
    vec3 centers[4];
    vec3 directions[4];
};

vec4 lovrmain() {
    ClipDistance[0] = dot(PositionWorld - centers[0], directions[0]);
    ClipDistance[1] = dot(PositionWorld - centers[1], directions[1]);
    ClipDistance[2] = dot(PositionWorld - centers[2], directions[2]);
    ClipDistance[3] = dot(PositionWorld - centers[3], directions[3]);

    return DefaultPosition;
}
