Shader "Raymarcher/pseudo_kleinian" {
Properties {
    _Color ("Color", Color) = (1,1,1,1)
    _MainTex ("Albedo (RGB)", 2D) = "white" {}
    _Glossiness ("Smoothness", Range(0,1)) = 0.5
    _Metallic ("Metallic", Range(0,1)) = 0.0
}

CGINCLUDE
#include "UnityStandardCore.cginc"
#include "distance_functions.cginc"

float map(float3 p)
{
    //return length(p)-1.0;
    //return kaleidoscopic_IFS(p);
    //return tglad_amazing_box(p);
    return pseudo_kleinian( rotateX(p+float3(0.0, -0.5, 0.0), 90.0*DEG2RAD) );
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


void raymarch(float time, float2 pos, out float3 o_raypos, out float3 o_color, out float3 o_normal, out float3 o_emission)
{
    float ct = time * 0.1;
#if UNITY_UV_STARTS_AT_TOP
        pos.y *= -1.0;
#endif

    float3 ray_dir = normalize(get_camera_right()*pos.x + get_camera_up()*pos.y + get_camera_forward()*get_camera_focal_length());
    float3 ray = get_camera_position();
    float m = 0.0;
    float d = 0.0, total_d = 0.0;
    const int MAX_MARCH = 100;
    const float MAX_DISTANCE = 100.0;
    for(int i=0; i<MAX_MARCH; ++i) {
        d = map(ray);
        total_d += d;
        ray += ray_dir * d;
        m += 1.0;
        if(d<0.001) { break; }
        if(total_d>MAX_DISTANCE) { break; }
    }
    if(total_d>MAX_DISTANCE) { discard; }

    float3 normal = guess_normal(ray);

    float r = modc(time*2.0, 20.0);
    float glow = max((modc(length(ray)-time*1.5, 10.0)-9.0)*2.5, 0.0);
    float2 p = pattern(ray.xy*1.);
    if(p.x<1.3) {
        glow = 0.0;
    }
    else {
        glow += 0.0;
    }
    glow += max(1.0-abs(dot(-get_camera_forward(), normal)) - 0.4, 0.0) * 0.5;
    
    float c = total_d*0.01;
    float4 result = float4( c + float3(0.02, 0.02, 0.025)*m*0.4, 1.0 );
    result.xyz += float3(0.5, 0.5, 0.75)*glow;

    o_raypos = ray;
    o_color = result.xyz;
    o_normal = normal;
    o_emission = float3(0.5, 0.5, 0.75)*glow;
}

float4 frag(vs_out v) : COLOR
{
    float time = _Time.y;
    float2 pos = v.spos.xy / v.spos.w;
    float aspect = _ScreenParams.x / _ScreenParams.y;
    pos.x *= aspect;

    float3 raypos;
    float3 color;
    float3 normal;
    float3 emission;
    raymarch(time, pos, raypos, color, normal, emission);
    return float4(color, 1.0);
}

struct gb_out
{
    half4 diffuse           : SV_Target0; // RT0: diffuse color (rgb), occlusion (a)
    half4 spec_smoothness   : SV_Target1; // RT1: spec color (rgb), smoothness (a)
    half4 normal            : SV_Target2; // RT2: normal (rgb), --unused, very low precision-- (a) 
    half4 emission          : SV_Target3; // RT3: emission (rgb), --unused-- (a)
    float depth             : SV_Depth;
};

float ComputeDepth(float4 clippos)
{
#if defined(SHADER_TARGET_GLSL)
    return ((clippos.z / clippos.w) + 1.0) * 0.5;
#else
    return clippos.z / clippos.w;
#endif
}

gb_out frag_gbuffer(vs_out v)
{
    float time = _Time.y;
    float2 pos = v.spos.xy;
    float aspect = _ScreenParams.x / _ScreenParams.y;
    pos.x *= aspect;

    float3 raypos;
    float3 color;
    float3 normal;
    float3 emission;
    raymarch(time, pos, raypos, color, normal, emission);

    gb_out o;
    o.diffuse = float4(0.5, 0.5, 0.55, 1.0);
    o.spec_smoothness = float4(0.2, 0.2, 0.2, 0.5);
    o.normal = float4(normal*0.5+0.5, 1.0);

    //#ifndef UNITY_HDR_ON
    //    emission = exp2(-emission);
    //#endif

    o.emission = float4(emission*0.5, 1.0);
    o.depth = ComputeDepth(mul(UNITY_MATRIX_VP, float4(raypos, 1.0)));
    return o;
}

ENDCG

SubShader {
    Fog { Mode off }
    Cull Off

    Pass {
CGPROGRAM
#pragma enable_d3d11_debug_symbols
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
ENDCG
    }

    Pass {
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
}
}
