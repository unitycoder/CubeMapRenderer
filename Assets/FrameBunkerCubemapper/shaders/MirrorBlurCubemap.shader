Shader "Custom/MirrorBlurCubemap" 
{
	Properties {
		//_MainTex ("Cube (RGB) Trans (A)", 2D) = "white" {}
		//myCube ("Cubemap", Cube) = "myCube" { TexGen CubeReflect }
		myCube ("Cubemap", CUBE) = "myCube" {}
		_SpecPwr("SpecPwr", Float) = 1
	}

	SubShader 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		LOD 100
		
		Pass 
		{  
			CGPROGRAM
			// Upgrade NOTE: excluded shader from DX11, Xbox360, OpenGL ES 2.0 because it uses unsized arrays
			#pragma exclude_renderers d3d11 xbox360 gles
			// needed this so I could sample cubemap mips directly
			#pragma target 3.0
			#pragma glsl 
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata_t {
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float3 cubePos : TEXCOORD0;
			};
			
			
		float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
		float2 mod289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
		float3 permute(float3 x) { return mod289(((x*34.0)+1.0)*x); }

		float snoise (float2 v)
		{
			const float4 C = float4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
								0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
								-0.577350269189626, // -1.0 + 2.0 * C.x
								0.024390243902439); // 1.0 / 41.0

			// First corner
			float2 i  = floor(v + dot(v, C.yy) );
			float2 x0 = v -   i + dot(i, C.xx);

			// Other corners
			float2 i1;
			i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
			float4 x12 = x0.xyxy + C.xxzz;
			x12.xy -= i1;

			// Permutations
			i = mod289(i); // Avoid truncation effects in permutation
			float3 p = permute( permute( i.y + float3(0.0, i1.y, 1.0 ))
				+ i.x + float3(0.0, i1.x, 1.0 ));

			float3 m = max(0.5 - float3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
			m = m*m ;
			m = m*m ;

			// Gradients: 41 points uniformly over a line, mapped onto a diamond.
			// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)
			float3 x = 2.0 * frac(p * C.www) - 1.0;
			float3 h = abs(x) - 0.5;
			float3 ox = floor(x + 0.5);
			float3 a0 = x - ox;

			// Normalise gradients implicitly by scaling m
			// Approximation of: m *= inversesqrt( a0*a0 + h*h );
			m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

			// Compute final noise value at P
			float3 g;
			g.x  = a0.x  * x0.x  + h.x  * x0.y;
			g.yz = a0.yz * x12.xz + h.yz * x12.yw;
			return 130.0 * dot(m, g);
		}
		
			
			//const int kSampleCount=3;

			//const float3 ringSamples[3] = {float3(0,0,0),float3(1,0,0),float3(0,1,0)};

//			const float3 ringSamples[kSampleCount] = 10; //{ /* generate tons of directions in a script */ };
			float _SpecPwr;
			samplerCUBE myCube;
			
			
			v2f vert (appdata_t v)
			{
				v2f o;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.cubePos = v.vertex.xyz;
				return o;
			}
			
			float4 frag (v2f v) : COLOR
			{
				float3 viewNorm = normalize(v.cubePos);
				float totalW = 0;
				float3 col = float3(0,0,0);
				
				// go over all samples
				for (int i=0;i<32; i++)
				{
					// FIXME: tried getting random directions.. i guess it doesnt work like this..
					float noise1 = snoise(v.cubePos.xy * float2(1024.0 + _Time.x * 512.0, 1024.0 + _Time.x * 512.0)) * 0.5;
					float noise2 = snoise(v.cubePos.xy * float2(124.0 + _Time.y * 51.0, 1024.0 + _Time.y * 2.0)) * 0.5;
					float noise3 = snoise(v.cubePos.xy * float2(14.0 + _Time.x * 512.0, 14.0 + _Time.y * 51.0)) * 0.5;

				
					float3 baseDir = float3(noise1,noise2,noise3); //ringSamples[i];
					float facing = dot(baseDir, viewNorm);
					
					// if ray faces away, it will never contricute
					if (facing<0)
					{
						baseDir = -baseDir; // flip it
					}
						
					// find out how importance this sample is
					float w = pow(dot(baseDir,viewNorm), _SpecPwr);
//					col+= texCUBElod(baseDir, 0) * w;
//					col+= texCUBElod(myCube, 0) * w;
					col+= texCUBElod(myCube, float4(baseDir,0)) * w;
					totalW += w;
				}
				
				// normalize the returned values
				return float4(col/totalW,0);
				//return texCUBE(myCube,v.cubePos );
			}
			ENDCG
		}
	}

}
