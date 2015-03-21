#ifndef foundation_h
#define foundation_h

#include "UnityCG.cginc"

#define PI      3.1415926535897932384626433832795
#define DEG2RAD (PI/180.0)

float  modc(float  a, float  b) { return a - b * floor(a/b); }
float2 modc(float2 a, float2 b) { return a - b * floor(a/b); }
float3 modc(float3 a, float3 b) { return a - b * floor(a/b); }
float4 modc(float4 a, float4 b) { return a - b * floor(a/b); }

float3 get_camera_position()    { return _WorldSpaceCameraPos; }
float3 get_camera_forward()     { return -UNITY_MATRIX_V[2].xyz; }
float3 get_camera_up()          { return UNITY_MATRIX_V[1].xyz; }
float3 get_camera_right()       { return UNITY_MATRIX_V[0].xyz; }
float get_camera_focal_length() { return abs(UNITY_MATRIX_P[1][1]); }

float compute_depth(float4 clippos)
{
#if defined(SHADER_TARGET_GLSL)
    return ((clippos.z / clippos.w) + 1.0) * 0.5;
#else
    return clippos.z / clippos.w;
#endif
}

sampler2D g_qsteps;
sampler2D g_hsteps;

sampler2D g_depth;
float sample_depth_internal(float2 t)
{
    return modc(tex2D(g_depth, t).x, _ProjectionParams.z);
}
float sample_depth(float2 t)
{
    float2 p = (_ScreenParams.zw - 1.0)*2.0;
    float d1 = sample_depth_internal(t);
    float d2 = min(
        min(sample_depth_internal(t+float2( p.x, 0.0)), sample_depth_internal(t+float2(-p.x, 0.0))),
        min(sample_depth_internal(t+float2( 0.0, p.y)), sample_depth_internal(t+float2( 0.0,-p.y))) );
    return max(min(d1, d2)-0.1, 0.0);
}


float3 rotateX(float3 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float3(p.x, c*p.y+s*p.z, -s*p.y+c*p.z);
}

float3 rotateY(float3 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float3(c*p.x-s*p.z, p.y, s*p.x+c*p.z);
}

float3 rotateZ(float3 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float3(c*p.x+s*p.y, -s*p.x+c*p.y, p.z);
}

float4x4 translation_matrix(float3 t)
{
    return float4x4(
        1.0, 0.0, 0.0, t.x,
        0.0, 1.0, 0.0, t.y,
        0.0, 0.0, 1.0, t.z,
        0.0, 0.0, 0.0, 1.0 );
}

float3x3 axis_rotation_matrix33(float3 axis, float angle)
{
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    return float3x3(
        oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
        oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
        oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c          );
}

#endif // foundation_h
