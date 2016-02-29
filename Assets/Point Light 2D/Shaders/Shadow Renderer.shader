Shader "Custom/Shadow/Distance" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "" {}

	}

	// Shader code pasted into all further CGPROGRAM blocks
	CGINCLUDE

	#include "UnityCG.cginc"

	struct v2f {
		float4 pos : POSITION;
		float2 uv[3] : TEXCOORD0;
	};

	sampler2D _SrcTex;
	sampler2D _MainTex;
	sampler2D _FallOffTex;
	float4 _MainTex_TexelSize;
		
	float _MinLuminance;
	float _ShadowOffset;
	float4 _FallOff;

	v2f vert(appdata_img v) {
		v2f o;
		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

		o.uv[0] = v.texcoord.xy;
		o.uv[1] = v.texcoord.xy;

		#if UNITY_UV_STARTS_AT_TOP
		if (_MainTex_TexelSize.y < 0)
			o.uv[0].y = 1-o.uv[0].y;
		#endif

		return o;
	}

 	v2f vertOffset(appdata_img v) {
		v2f o;
		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

		o.uv[0] = v.texcoord.xy;
		o.uv[1] = v.texcoord.xy;

		#if UNITY_UV_STARTS_AT_TOP
		if (_MainTex_TexelSize.y < 0)
			o.uv[0].y = 1-o.uv[0].y;
		#endif

		o.uv[2] = o.uv[1];
		o.uv[2].x -= _MainTex_TexelSize.x;

		return o;
	}

 	v2f vertQuadrant(appdata_img v) {
		v2f o;
		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

		o.uv[0] = v.texcoord.xy;
		o.uv[1] = v.texcoord.xy;

		#if UNITY_UV_STARTS_AT_TOP
		if (_MainTex_TexelSize.y < 0)
			o.uv[0].y = 1-o.uv[0].y;
		#endif

		o.uv[2].x = 2.0f * (o.uv[1].x - 0.5f);
		o.uv[2].y = 2.0f * (o.uv[1].y - 0.5f);

		return o;
	}

	fixed4 frag(v2f i) : COLOR
	{
		fixed4 color = tex2D(_MainTex, i.uv[1]);
		fixed distance = lerp(1.0f, length(i.uv[1] - 0.5), step(0.001, color.a));

		// save it to the Red channel
		return fixed4(distance, 0, 0, 1);
	}

	fixed4 fragStretch(v2f i) : COLOR
	{
		//translate u and v into [-1 , 1] domain
		float u0 = (i.uv[1].x) * 2 - 1;
		float v0 = (i.uv[1].y) * 2 - 1;

		//then, as u0 approaches 0 (the center), v should also approach 0
		v0 = v0 * abs(u0);
		//convert back from [-1,1] domain to [0,1] domain
		v0 = (v0 + 1) / 2;
		//we now have the coordinates for reading from the initial image
		float2 newCoords = float2(i.uv[1].x, v0);

		//read for both horizontal and vertical direction and store them in separate channels
		fixed horizontal = tex2D(_MainTex, newCoords).r;
		fixed vertical = tex2D(_MainTex, newCoords.yx).r;
		return fixed4(horizontal, vertical, 0, 1);
	}

	fixed4 fragSquish(v2f i) : COLOR
	{
		fixed2 color = tex2D(_MainTex, i.uv[1]);
		fixed2 colorR = tex2D(_MainTex, i.uv[2]);
		fixed2 result = min(color, colorR);
		return fixed4(result, 0, 1);
	}

	fixed GetShadowDistanceH(float2 TexCoord)
	{
		float u = TexCoord.x;
		float v = TexCoord.y;

		u = abs(u - 0.5f) * 2;
		v = v * 2 - 1;
		float v0 = v/u;
		v0 = (v0 + 1) / 2;

		float2 newCoords = float2(TexCoord.x * _MainTex_TexelSize.x * 2, v0);

		//horizontal info was stored in the Red component
		return tex2D(_MainTex, newCoords).r;
	}

	fixed GetShadowDistanceV(float2 TexCoord)
	{
		float u = TexCoord.y;
		float v = TexCoord.x;

		u = abs(u - 0.5f) * 2;
		v = v * 2 - 1;
		float v0 = v/u;
		v0 = (v0 + 1) / 2;

		float2 newCoords = float2(TexCoord.y * _MainTex_TexelSize.x * 2, v0);

		//vertical info was stored in the Green component
		return tex2D(_MainTex, newCoords).g;
	}

	fixed4 _ShadowColor;
	float _FOV;
	fixed4 fragShadow(v2f i) : COLOR
	{
		// 1.0f / _ShadowMapSize shift shadow by a pixel
		float distance = length(i.uv[1] - 0.5f) - _ShadowOffset;

		//coords in [-1,1]
		//we use these to determine which quadrant we are in
		float nX = abs(i.uv[2].x);
		float nY = abs(i.uv[2].y);

		//if distance to this pixel is lower than distance from shadowMap, then we are not in shadow
		float shadowMapDistance =
			lerp(
				GetShadowDistanceH(i.uv[1]),
				GetShadowDistanceV(i.uv[1]),
			step(nX, nY));
			
		fixed light = step(distance, shadowMapDistance);


		fixed4 col = tex2D(_FallOffTex, half2(distance * 2, 0.5));

		fixed cp = step(distance, 0.5);

		fixed4 shadowColor = _ShadowColor;
		#if SOLID_SHADOW
		shadowColor.a *= cp;
		#else
		shadowColor.a *= col.a * cp;
		#endif

		col *= cp;



		return lerp(shadowColor, col, light);
	}
	
	struct v2fBlur
	{
		float4 pos : SV_POSITION;
#if ULTRA_QUALITY		
		float2 offset : TEXCOORD0;
		float2 uv[7] : TEXCOORD1;
#else			
		float2 uv[5] : TEXCOORD0;
#endif
	};	

	float _BlurSize;
	
	v2fBlur vertBlurHorz( appdata_img v ) {
		v2fBlur o;
		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

 		float3 off = float3(_MainTex_TexelSize.x, -_MainTex_TexelSize.x, 0) * _BlurSize;

		o.uv[0] = v.texcoord.xy;
		o.uv[1] = v.texcoord.xy + off.xz;
		o.uv[2] = v.texcoord.xy + off.yz;
		o.uv[3] = v.texcoord.xy + off.xz * 2;
		o.uv[4] = v.texcoord.xy + off.yz * 2;
		
#if ULTRA_QUALITY
		o.uv[5] = v.texcoord.xy + off.xz * 3;
		o.uv[6] = v.texcoord.xy + off.yz * 3;		
		o.offset = off.xz;
#endif
		
		return o;
	}

	v2fBlur vertBlurVert( appdata_img v ) {
		v2fBlur o;
		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

 		float3 off = float3(_MainTex_TexelSize.y, -_MainTex_TexelSize.y, 0) * _BlurSize;

		o.uv[0] = v.texcoord.xy;				
		o.uv[1] = v.texcoord.xy + off.zx;
		o.uv[2] = v.texcoord.xy + off.zy;
		o.uv[3] = v.texcoord.xy + off.zx * 2;
		o.uv[4] = v.texcoord.xy + off.zy * 2;
#if ULTRA_QUALITY
		o.uv[5] = v.texcoord.xy + off.zx * 3;
		o.uv[6] = v.texcoord.xy + off.zy * 3;		
		o.offset = off.xz;
#endif
		
		return o;
	} 	
	
	fixed4 fragBlur(v2fBlur i) : COLOR
	{
#if ULTRA_QUALITY
		half distance = length(i.uv[0] - 0.5f) - _ShadowOffset;
		half4 color = 0;
		color += tex2D(_MainTex, i.uv[0] + i.offset.xy * distance);
		color += tex2D(_MainTex, i.uv[0] - i.offset.xy * distance);
		color += tex2D(_MainTex, i.uv[0] + (i.offset.xy * 2) * distance);
		color += tex2D(_MainTex, i.uv[0] - (i.offset.xy * 2) * distance);
		color += tex2D(_MainTex, i.uv[0] + (i.offset.xy * 3) * distance);
		color += tex2D(_MainTex, i.uv[0] - (i.offset.xy * 3) * distance);				
		return color / 6;
#else
		half4 color = 0;
		color += tex2D(_MainTex, i.uv[1]);
		color += tex2D(_MainTex, i.uv[2]);
		color += tex2D(_MainTex, i.uv[3]);
		color += tex2D(_MainTex, i.uv[4]);
		return color / 4;
#endif
	}	

	ENDCG

Subshader {

	Pass //0
	{ 
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		ENDCG
	}

	Pass //1
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

		CGPROGRAM
		#pragma vertex vert
		#pragma fragment fragStretch
		ENDCG
	}

	Pass //2
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

		CGPROGRAM
		#pragma vertex vertOffset
		#pragma fragment fragSquish
		ENDCG
	}

	Pass //3
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

		CGPROGRAM
		#pragma multi_compile _ SOLID_SHADOW
		#pragma vertex vertQuadrant
		#pragma fragment fragShadow
		ENDCG
	}
	
	Pass //4
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

		CGPROGRAM
		#pragma multi_compile _ ULTRA_QUALITY
		#pragma vertex vertBlurHorz
		#pragma fragment fragBlur
		ENDCG
	}
	
	Pass //5
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

		CGPROGRAM
		#pragma multi_compile _ ULTRA_QUALITY
		#pragma vertex vertBlurVert
		#pragma fragment fragBlur
		ENDCG
	}
}

Fallback off

} // shader