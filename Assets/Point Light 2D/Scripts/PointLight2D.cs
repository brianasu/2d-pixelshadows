using UnityEngine;
using System.Collections;
using System.Collections.Generic;

[ExecuteInEditMode]
public class PointLight2D : MonoBehaviour
{
	[Header("Shadows are based on the alpha channel")]
	[Header("Lights need to be on a seperate layer excluded by the camera")]
	[Space(20)]
	[SerializeField]
	[Range(0, 0.1f)]
	float shadowBias = 0.001f;
	[SerializeField]
	[Range(0, 10)]
	float blurSize;
	[SerializeField]
	[Range(0, 8)]
	int blurIterations = 0;
	[SerializeField]
	Shader lightDistanceShader;
	[SerializeField]
	[Header("Only in edit mode")]
	Gradient lightGradient = new Gradient()
	{
		alphaKeys = new GradientAlphaKey[] {
			new GradientAlphaKey(1, 0),
			new GradientAlphaKey(1, 1)
		},		
		colorKeys = new GradientColorKey[] {
			new GradientColorKey(Color.white, 0),
			new GradientColorKey(Color.white, 1)
		}
	};
	[SerializeField]
	[Header("Only in edit mode")]
	AnimationCurve fallOffCurve = AnimationCurve.EaseInOut(0, 1, 1, 0);

	[SerializeField]
	[Header("Don't multiply shadow alpha by light gradient")]
	bool solidShadow = false;
	[Space(20)]
	[SerializeField]
	Color gradientTint = Color.white;
	[SerializeField]
	Color shadowColor = Color.black;

	[Header("This will have a large effect on performance")]
	[SerializeField]
	[Range(32, 512)]
	int shadowMapSize = 512;

	[SerializeField]
	[Header("Distance based penumbras. Very expensive")]
	bool highQualityPenumbras = false;

	[SerializeField]
	[Header("Leave these guys alone.")]
	Mesh _lightmesh;
	[SerializeField]
	Material _lightMaterial;

	//
	RenderTexture _texTarget;
	List<RenderTexture> _tempRenderTextures = new List<RenderTexture> ();
	Material _materialShadow;
	Camera _shadowCamera;

	[HideInInspector][SerializeField]
	Texture2D _fallOffTexture;
	MaterialPropertyBlock _propertyBlock;

	Camera ShadowCamera
	{
		get
		{
			if(_shadowCamera == null)
			{
				_shadowCamera = GetComponent<Camera>();
				if(_shadowCamera == null)
				{
					_shadowCamera = gameObject.AddComponent<Camera>();
				}
				_shadowCamera.orthographic = true;
				_shadowCamera.clearFlags = CameraClearFlags.Color;
				_shadowCamera.backgroundColor = Color.clear;
				_shadowCamera.renderingPath = RenderingPath.VertexLit;
				_shadowCamera.nearClipPlane = -100;
				_shadowCamera.farClipPlane = 100;
			}
			return _shadowCamera;
		}
	}

	
	Material ShadowMaterial
	{
		get
		{
			if(_materialShadow == null)
			{
				_materialShadow = new Material(lightDistanceShader);
				_materialShadow.hideFlags = HideFlags.DontSave;
			}
			return _materialShadow;
		}
	}
		
	Texture2D FallOffTexture
	{
		get
		{
			if(_fallOffTexture == null)
			{
				_fallOffTexture = new Texture2D(128, 1);
				_fallOffTexture.wrapMode = TextureWrapMode.Clamp;
			}
			return _fallOffTexture;
		}
	}


	MaterialPropertyBlock PropertyBlock
	{
		get
		{
			if (_propertyBlock == null)
			{
				_propertyBlock = new MaterialPropertyBlock();
			}
			return _propertyBlock;
		}
	}

	RenderTexture OutputTexture
	{
		get
		{
			if(_texTarget == null)
			{
				_texTarget = new RenderTexture (shadowMapSize, shadowMapSize, 0, RenderTextureFormat.Default);
				_texTarget.wrapMode = TextureWrapMode.Clamp;
				_texTarget.hideFlags = HideFlags.DontSave;
				PropertyBlock.SetTexture("_MainTex", _texTarget);
			}
			return _texTarget;
		}
	}

	public Color GradientTint
	{
		set { gradientTint = value; }
		get { return gradientTint; }
	}

	void DestroySafe(UnityEngine.Object obj)
	{
		if(obj == null)
		{
			return;
		}

		if(Application.isEditor)
		{
			DestroyImmediate(obj);
		}
		else
		{
			Destroy(obj);
		}
	}
	
	[ContextMenu("Regenerate Curve")]
	void RegenerateCurve()
	{
		var colors = new Color[128];
		for(var i = 0; i < 128; i++)
		{
			colors[i] = lightGradient.Evaluate(i / 128.0f);
			colors[i].a *= fallOffCurve.Evaluate(i / 128.0f);
		}
		FallOffTexture.SetPixels(colors);
		FallOffTexture.Apply();
	}

	void OnDisable ()
	{
		DestroySafe (_texTarget);
		DestroySafe (_fallOffTexture);
		DestroySafe (_materialShadow);
		ReleaseAllRenderTextures ();
	}

	void Update()
	{
		if(Application.isEditor && !Application.isPlaying)
		{
			RegenerateCurve();
		}

		shadowMapSize = Mathf.NextPowerOfTwo (shadowMapSize);
		shadowMapSize = Mathf.Clamp (shadowMapSize, 8, 2048);

		if(OutputTexture.width != shadowMapSize)
		{
			DestroySafe(_texTarget);
		}
		PropertyBlock.SetTexture("_MainTex", OutputTexture);

		var shadowMap = PushRenderTexture(shadowMapSize, shadowMapSize);
		ShadowCamera.targetTexture = shadowMap;
		ShadowCamera.rect = new Rect (0, 0, 1, 1);
		ShadowCamera.Render ();
		ShadowCamera.targetTexture = null;

		if(highQualityPenumbras)
		{
			ShadowMaterial.EnableKeyword("ULTRA_QUALITY");
		}
		else
		{
			ShadowMaterial.DisableKeyword("ULTRA_QUALITY");
		}

		if (solidShadow)
		{
			ShadowMaterial.EnableKeyword("SOLID_SHADOW");
		}
		else
		{
			ShadowMaterial.DisableKeyword("SOLID_SHADOW");
		}

		ShadowMaterial.SetTexture ("_FallOffTex", _fallOffTexture);
		ShadowMaterial.SetFloat ("_BlurSize", blurSize * ((float)shadowMapSize / 512));
		ShadowMaterial.SetFloat ("_ShadowOffset", shadowBias);
		ShadowMaterial.SetColor ("_ShadowColor", shadowColor);
		ShadowMaterial.SetColor ("_ColorTint", gradientTint);

		// Calculate the distance between the light and  centre
		var texLightDistance = PushRenderTexture (shadowMapSize, shadowMapSize);
		Graphics.Blit (shadowMap, texLightDistance, ShadowMaterial, 0);

		// Stretch it into a dual parabaloid
		var texStretched = PushRenderTexture (shadowMapSize, shadowMapSize);
		Graphics.Blit (texLightDistance, texStretched, ShadowMaterial, 1);

		// Here we compress it into a 1D distance map
		var texDownSampled = texStretched;
		var width = shadowMapSize;
		while (width > 2) 
		{
			width /= 2;
			var texDownSampleTemp = PushRenderTexture (width, shadowMapSize);
			Graphics.Blit (texDownSampled, texDownSampleTemp, ShadowMaterial, 2);
			texDownSampled = texDownSampleTemp;
		}

		// Finally do a distance compare and shadow map
		Graphics.Blit (texDownSampled, OutputTexture, ShadowMaterial, 3);

		// Blur the results
		if(blurIterations > 0)
		{
			var pingPong = RenderTexture.GetTemporary(shadowMapSize, shadowMapSize, 0);
			for(int i = 0; i < blurIterations; i++)
			{
				Graphics.Blit(OutputTexture, pingPong, ShadowMaterial, 5);
				Graphics.Blit(pingPong, OutputTexture, ShadowMaterial, 4);
			}
			RenderTexture.ReleaseTemporary(pingPong);
		}

		ReleaseAllRenderTextures ();
		transform.localScale = Vector3.one * _shadowCamera.orthographicSize * 2;
		Graphics.DrawMesh(_lightmesh, transform.localToWorldMatrix, _lightMaterial, gameObject.layer, null, 0, PropertyBlock);
	}

	RenderTexture PushRenderTexture (int width, int height, int depth = 0, RenderTextureFormat format = RenderTextureFormat.Default)
	{
		var tex = RenderTexture.GetTemporary (width, height, depth, format);
		tex.filterMode = FilterMode.Point;
		tex.wrapMode = TextureWrapMode.Clamp;
		_tempRenderTextures.Add (tex);
		return tex;
	}

	void ReleaseAllRenderTextures ()
	{
		foreach (var item in _tempRenderTextures) 
		{
			RenderTexture.ReleaseTemporary (item);
		}
		_tempRenderTextures.Clear ();
	}
}
