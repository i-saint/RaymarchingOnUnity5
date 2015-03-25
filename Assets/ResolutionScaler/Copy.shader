Shader "ResolutionScaler/Copy" {
Properties {
    _MainTex ("Source", 2D) = "white" {}
}

CGINCLUDE
sampler2D _MainTex;


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
half4 frag(vs_out v) : SV_Target0
{
    float2 t = v.spos.xy*0.5+0.5;
    return tex2D(_MainTex, t);
}

ENDCG

SubShader {
    Tags { "RenderType"="Opaque" }
    Cull Off

    Pass {
        ZWrite Off
        ZTest Always
CGPROGRAM
#pragma vertex vert
#pragma fragment frag
ENDCG
    }
}
Fallback Off
}
