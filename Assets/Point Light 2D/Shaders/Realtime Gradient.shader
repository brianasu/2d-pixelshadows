Shader "Custom/Realtime Gradient"
{
	Properties
	{
		
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", COLOR) = (1, 1, 1, 1)
		_ColorStart ("Color Start", COLOR) = (1, 1, 1, 1)
		_ColorEnd ("Color End", COLOR) = (1, 1, 1, 1)
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
		LOD 100
		
		Blend SrcAlpha OneMinusSrcAlpha
		ZWrite Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}
			
			fixed4 _Color;
			fixed4 _ColorStart;
			fixed4 _ColorEnd;
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);
				fixed circle = length((i.uv - 0.5) * 2);
				clip(1 - circle);
				return col * lerp(_ColorStart, _ColorEnd, circle) * _Color;
			}
			ENDCG
		}
	}
}
