Shader "Unlit/Water"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _NormalMap("Normal Map",2D) = "bump" {}
        _Color("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include  "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
            };

            sampler2D _MainTex;
            sampler2D _NormalMap;
            sampler2D _NoiseTex;
            
            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _NormalMap_ST;
            float4 _NoiseTex_ST;
            float3 _Color;
            CBUFFER_END

            float2 rand(float2 st, int seed)
			{
				float2 s = float2(dot(st, float2(127.1, 311.7)) + seed, dot(st, float2(269.5, 183.3)) + seed);
				return -1 + 2 * frac(sin(s) * 43758.5453123);
			}
			float noise(float2 st, int seed)
			{
				st.y += _Time[1];

				float2 p = floor(st);
				float2 f = frac(st);

				float w00 = dot(rand(p, seed), f);
				float w10 = dot(rand(p + float2(1, 0), seed), f - float2(1, 0));
				float w01 = dot(rand(p + float2(0, 1), seed), f - float2(0, 1));
				float w11 = dot(rand(p + float2(1, 1), seed), f - float2(1, 1));
				
				float2 u = f * f * (3 - 2 * f);

				return lerp(lerp(w00, w10, u.x), lerp(w01, w11, u.x), u.y);
			}

            float3 swell(float3 normal , float3 pos , float anisotropy)
            {
				float height = noise(pos.xz * 0.1,0);
				height *= anisotropy;
				normal = normalize(
					cross ( 
						float3(0,ddy(height),1),
						float3(1,ddx(height),0)
					)
				);
				return normal;
			}

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _NoiseTex);

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = normalInputs.normalWS;
                o.tangentWS = normalInputs.tangentWS;
                o.bitangentWS = normalInputs.bitangentWS;

                o.worldPos = mul(unity_ObjectToWorld, v.positionOS).xyz;
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                float2 uv = float2(i.uv.x, i.uv.y + _Time.y);
                // float height = noise(i.worldPos.xz * 3,0);
                // float height2 = noise(i.worldPos.xz * 3,10);
                
                // float3 normalMapSample = UnpackNormal(float4(height, height2, height, height));
                
                float3 normalMapSample = UnpackNormal(tex2D(_NoiseTex, uv));

                float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3 normalWS = normalize(TransformTangentToWorld(normalMapSample, TBN));


                // fresnel reflect
                half3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float f0 = 0.02;
    			float vReflect = f0 + (1 - f0) * pow((1 - dot(worldViewDir, normalWS)), 5);
				vReflect = saturate(vReflect * 2.0);

                

                col.rgb = saturate(_Color + vReflect);
                // col.rgb = normalWS;
                return col;
            }
            ENDHLSL
        }
    }
}
