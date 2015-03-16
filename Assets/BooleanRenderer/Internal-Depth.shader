Shader "BooleanRenderer/Internal-Depth" {
Properties {
}

CGINCLUDE
#include "UnityStandardCore.cginc"

float  modc(float  a, float  b) { return a - b * floor(a/b); }
float2 modc(float2 a, float2 b) { return a - b * floor(a/b); }
float3 modc(float3 a, float3 b) { return a - b * floor(a/b); }
float4 modc(float4 a, float4 b) { return a - b * floor(a/b); }

float ComputeDepth(float4 clippos)
{
#if defined(SHADER_TARGET_GLSL)
    return ((clippos.z / clippos.w) + 1.0) * 0.5;
#else 
    return clippos.z / clippos.w;
#endif 
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

struct ps_out
{
    float depth : SV_Depth;
};


vs_out vert(ia_out v)
{
    vs_out o;
    o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
    o.spos = o.vertex;
    return o;
}

ps_out frag(vs_out v)
{
    float depth = v.spos.z / v.spos.w;

    ps_out r;
    r.depth = depth;
    return r;
}

ENDCG

SubShader {
    Fog { Mode off }

    // draw front depth
    Pass {
        Stencil {
            Comp Always
            Pass Replace
            Ref 1
        }
        Cull Back
        ColorMask 0
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
ENDCG
    }

    // draw back depth
    Pass {
        Stencil {
            Comp Always
            Pass Replace
            Ref 1
        }
        Cull Front
        ColorMask 0
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
ENDCG
    }
}
}
