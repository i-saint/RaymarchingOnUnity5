Shader "Raymarcher/pseudo_kleinian" {
Properties {
    _Color ("Color", Color) = (1,1,1,1)
    _MainTex ("Albedo (RGB)", 2D) = "white" {}
    _Glossiness ("Smoothness", Range(0,1)) = 0.5
    _Metallic ("Metallic", Range(0,1)) = 0.0
}

CGINCLUDE
#include "UnityStandardCore.cginc"


float  modc(float  a, float  b) { return a - b * floor(a/b); }
float2 modc(float2 a, float2 b) { return a - b * floor(a/b); }
float3 modc(float3 a, float3 b) { return a - b * floor(a/b); }
float4 modc(float4 a, float4 b) { return a - b * floor(a/b); }


// distance function from Hartverdrahtet
// ( http://www.pouet.net/prod.php?which=59086 )
float hartverdrahtet(float3 f)
{
    float3 cs=float3(.808,.808,1.167);
    float fs=1.;
    float3 fc=0;
    float fu=10.;
    float fd=.763;
    
    // scene selection
    float time = _Time.y;
    int i = int(modc(time/2.0, 9.0));
    if(i==0) cs.y=.58;
    if(i==1) cs.xy=.5;
    if(i==2) cs.xy=.5;
    if(i==3) fu=1.01,cs.x=.9;
    if(i==4) fu=1.01,cs.x=.9;
    if(i==6) cs=float3(.5,.5,1.04);
    if(i==5) fu=.9;
    if(i==7) fd=.7,fs=1.34,cs.xy=.5;
    if(i==8) fc.z=-.38;
    
    //cs += sin(time)*0.2;

    float v=1.;
    for(int i=0; i<12; i++){
        f=2.*clamp(f,-cs,cs)-f;
        float c=max(fs/dot(f,f),1.);
        f*=c;
        v*=c;
        f+=fc;
    }
    float z=length(f.xy)-fu;
    return fd*max(z,abs(length(f.xy)*f.z)/sqrt(dot(f,f)))/abs(v);
}

float pseudo_kleinian(float3 p)
{
    float3 CSize = float3(0.92436,0.90756,0.92436);
    float Size = 1.0;
    float3 C = float3(0.0,0.0,0.0);
    float DEfactor=1.;
    float3 Offset = float3(0.0,0.0,0.0);
    float3 ap=p+1.;
    for(int i=0;i<10 ;i++){
        ap=p;
        p=2.*clamp(p, -CSize, CSize)-p;
        float r2 = dot(p,p);
        float k = max(Size/r2,1.);
        p *= k;
        DEfactor *= k + 0.05;
        p += C;
    }
    float r = abs(0.5*abs(p.z-Offset.z)/DEfactor);
    return r;
}

float pseudo_knightyan(float3 p)
{
    float3 CSize = float3(0.63248,0.78632,0.875);
    float DEfactor=1.;
    for(int i=0;i<6;i++){
        p = 2.*clamp(p, -CSize, CSize)-p;
        float k = max(0.70968/dot(p,p),1.);
        p *= k;
        DEfactor *= k + 0.05;
    }
    float rxy=length(p.xy);
    return max(rxy-0.92784, abs(rxy*p.z) / length(p))/DEfactor;
}


float map(float3 p)
{
    //return length(p)-1.0;
    return pseudo_kleinian(p);
    //return pseudo_knightyan(p);
    //return hartverdrahtet(p);
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
    
    float3 camPos = float3(5.0*cos(time*0.1), 5.0*sin(time*0.1), 0.25*sin(time*0.25)+0.75);
    float3 camDir = normalize(camPos*float3(-1.0, -1.0, sin(time*0.33)*1.5));
    //float3 camPos = _WorldSpaceCameraPos;
    //float3 camDir = float3(0.0, 0.0, 1.0);

    float3 camUp  = normalize(float3(0.0, 1, 1.0));
    float3 camSide = cross(camDir, camUp);
    float focus = 1.8;
    
    float3 rayDir = normalize(camSide*pos.x + camUp*pos.y + camDir*focus);
    float3 ray = camPos;
    float m = 0.0;
    float d = 0.0, total_d = 0.0;
    const int MAX_MARCH = 100;
    const float MAX_DISTANCE = 100.0;
    for(int i=0; i<MAX_MARCH; ++i) {
        d = map(ray);
        total_d += d;
        ray += rayDir * d;
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
    glow += max(1.0-abs(dot(-camDir, normal)) - 0.4, 0.0) * 0.5;
    
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
    float2 pos = v.spos.xy / v.spos.w;
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
