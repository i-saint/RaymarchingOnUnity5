Shader "Raymarcher/RayMarcher" {
Properties {
    _Color ("Color", Color) = (1,1,1,1)
    _MainTex ("Albedo (RGB)", 2D) = "white" {}
    _Glossiness ("Smoothness", Range(0,1)) = 0.5
    _Metallic ("Metallic", Range(0,1)) = 0.0
}

CGINCLUDE
#include "UnityStandardCore.cginc"
#include "distance_functions.cginc"

#define MAX_MARCH_QUARTER_PASS 100
#define MAX_MARCH_HALF_PASS 40
#define MAX_MARCH_GBUFFER_PASS 20

#define MAX_MARCH_SINGLE_GBUFFER_PASS 100

int g_scene;
int g_hdr;
int g_enable_adaptive;

float map(float3 p)
{
    if(g_scene==0) {
        return pseudo_kleinian( rotateX(p+float3(0.0, -0.5, 0.0), 90.0*DEG2RAD) );
    }
    else if (g_scene==1) {
        return tglad_formula(p);
    }
    else {
        return pseudo_knightyan( rotateX(p+float3(0.0, -0.5, 0.0), 90.0*DEG2RAD) );
    }

    //return length(p)-1.0;
    //return kaleidoscopic_IFS(p);
    //return pseudo_knightyan( rotateX(p+float3(0.0, -0.5, 0.0), 90.0*DEG2RAD) );
    //return hartverdrahtet( rotateX(p+float3(0.0, -0.5, 0.0), 90.0*DEG2RAD) );
}

float3 guess_normal(float3 p)
{
    const float d = 0.001;
    return normalize( float3(
        map(p+float3(  d,0.0,0.0))-map(p+float3( -d,0.0,0.0)),
        map(p+float3(0.0,  d,0.0))-map(p+float3(0.0, -d,0.0)),
        map(p+float3(0.0,0.0,  d))-map(p+float3(0.0,0.0, -d)) ));
}

float2 pattern(float2 p)
{
    p = frac(p);
    float r = 0.123;
    float v = 0.0, g = 0.0;
    r = frac(r * 9184.928);
    float cp, d;
    
    d = p.x;
    g += pow(clamp(1.0 - abs(d), 0.0, 1.0), 1000.0);
    d = p.y;
    g += pow(clamp(1.0 - abs(d), 0.0, 1.0), 1000.0);
    d = p.x - 1.0;
    g += pow(clamp(3.0 - abs(d), 0.0, 1.0), 1000.0);
    d = p.y - 1.0;
    g += pow(clamp(1.0 - abs(d), 0.0, 1.0), 10000.0);

    const int ITER = 12;
    for(int i = 0; i < ITER; i ++)
    {
        cp = 0.5 + (r - 0.5) * 0.9;
        d = p.x - cp;
        g += pow(clamp(1.0 - abs(d), 0.0, 1.0), 200.0);
        if(d > 0.0) {
            r = frac(r * 4829.013);
            p.x = (p.x - cp) / (1.0 - cp);
            v += 1.0;
        }
        else {
            r = frac(r * 1239.528);
            p.x = p.x / cp;
        }
        p = p.yx;
    }
    v /= float(ITER);
    return float2(g, v);
}

struct ia_out
{
    float4 vertex : POSITION;
};

struct vs_out
{
    float4 vertex : SV_POSITION;
    float4 spos : TEXCOORD0;
};


vs_out vert(ia_out v)
{
    vs_out o;
    o.vertex = v.vertex;
    o.spos = o.vertex;
    return o;
}

vs_out vert_dummy(ia_out v)
{
    vs_out o;
    o.vertex = o.spos = float4(0.0, 0.0, 0.0, 1.0);
    return o;
}


void raymarching(float2 pos, const int num_march, inout float o_total_distance, out float o_num_march, out float o_last_distance, out float3 o_raypos)
{
    float3 cam_pos      = get_camera_position();
    float3 cam_forward  = get_camera_forward();
    float3 cam_up       = get_camera_up();
    float3 cam_right    = get_camera_right();
    float  cam_focal_len= get_camera_focal_length();

    float3 ray_dir = normalize(cam_right*pos.x + cam_up*pos.y + cam_forward*cam_focal_len);
    float max_distance = _ProjectionParams.z - _ProjectionParams.y;
    o_raypos = cam_pos + ray_dir * o_total_distance;

    o_num_march = 0.0;
    o_last_distance = 0.0;
    for(int i=0; i<num_march; ++i) {
        o_last_distance = map(o_raypos);
        o_total_distance += o_last_distance;
        o_raypos += ray_dir * o_last_distance;
        o_num_march += 1.0;
        if(o_last_distance < 0.001 || o_total_distance > max_distance) { break; }
    }
}



struct gbuffer_out
{
    half4 diffuse           : SV_Target0; // RT0: diffuse color (rgb), occlusion (a)
    half4 spec_smoothness   : SV_Target1; // RT1: spec color (rgb), smoothness (a)
    half4 normal            : SV_Target2; // RT2: normal (rgb), --unused, very low precision-- (a) 
    half4 emission          : SV_Target3; // RT3: emission (rgb), --unused-- (a)
    float depth             : SV_Depth;
};


gbuffer_out frag_gbuffer(vs_out v)
{
#if UNITY_UV_STARTS_AT_TOP
    v.spos.y *= -1.0;
#endif
    float time = _Time.y;
    float2 pos = v.spos.xy;
    pos.x *= _ScreenParams.x / _ScreenParams.y;

    float num_march;
    float last_distance;
    float total_distance = 0.0;
    float3 ray_pos;
    if(g_enable_adaptive) {
        total_distance = sample_depth(v.spos.xy*0.5+0.5);
        raymarching(pos, MAX_MARCH_GBUFFER_PASS, total_distance, num_march, last_distance, ray_pos);
    }
    else {
        raymarching(pos, MAX_MARCH_SINGLE_GBUFFER_PASS, total_distance, num_march, last_distance, ray_pos);
    }

    //if(last_distance>0.1) { discard; }

    float3 cam_forward  = get_camera_forward();
    float3 normal = guess_normal(ray_pos);

    float glow = max((modc(length(ray_pos)-time*1.5, 10.0)-9.0)*2.5, 0.0);
    float2 p = pattern(ray_pos.xz*0.5);
    if(p.x<1.3) {
        glow = 0.0;
    }
    else {
        glow += 0.0;
    }
    glow += max(1.0-abs(dot(-cam_forward, normal)) - 0.4, 0.0) * 0.5;
    
    float c = total_distance*0.01;
    float4 color = float4( c + float3(0.02, 0.02, 0.025)*num_march*0.4, 1.0 );
    color.xyz += float3(0.5, 0.5, 0.75)*glow;

    float3 emission = float3(0.7, 0.7, 1.0)*glow*0.6;

    gbuffer_out o;
    o.diffuse = float4(0.75, 0.75, 0.80, 1.0);
    o.spec_smoothness = float4(0.2, 0.2, 0.2, 0.5);
    o.normal = float4(normal*0.5+0.5, 1.0);
    o.emission = g_hdr ? float4(emission, 1.0) : exp2(float4(-emission, 1.0));
    o.depth = compute_depth(mul(UNITY_MATRIX_VP, float4(ray_pos, 1.0)));
    return o;
}

float frag_quarter_depth(vs_out v) : SV_Target0
{
#if UNITY_UV_STARTS_AT_TOP
    v.spos.y *= -1.0;
#endif
    float2 pos = v.spos.xy;
    pos.x *= _ScreenParams.x / _ScreenParams.y;

    float num_march, last_distance, total_distance = _ProjectionParams.y;
    float3 ray_pos;
    raymarching(pos, MAX_MARCH_QUARTER_PASS, total_distance, num_march, last_distance, ray_pos);

    return total_distance;
}

float frag_half_depth(vs_out v) : SV_Target0
{
#if UNITY_UV_STARTS_AT_TOP
    v.spos.y *= -1.0;
#endif
    float2 pos = v.spos.xy;
    pos.x *= _ScreenParams.x / _ScreenParams.y;

    float num_march, last_distance, total_distance = sample_depth(v.spos.xy*0.5+0.5);
    float3 ray_pos;
    raymarching(pos, MAX_MARCH_HALF_PASS, total_distance, num_march, last_distance, ray_pos);

    return total_distance;
}

ENDCG

SubShader {
    Tags { "RenderType"="Opaque" }
    Cull Off

    Pass {
        Name "DEFERRED"
        Tags { "LightMode" = "Deferred" }
        Stencil {
            Comp Always
            Pass Replace
            //Ref [_StencilNonBackground] // problematic
            Ref 128
        }
CGPROGRAM
#pragma enable_d3d11_debug_symbols
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag_gbuffer
ENDCG
    }

    Pass {
        Name "QuarterDepth"
        ZWrite Off
        ZTest Always
CGPROGRAM
#pragma vertex vert
#pragma fragment frag_quarter_depth
ENDCG
    }

    Pass {
        Name "HalfDepth"
        ZWrite Off
        ZTest Always
CGPROGRAM
#pragma vertex vert
#pragma fragment frag_half_depth
ENDCG
    }
}
Fallback Off
}
