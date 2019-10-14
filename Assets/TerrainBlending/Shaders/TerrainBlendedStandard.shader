Shader "Standart/Terrain-Blended"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers gles            
            #pragma multi_compile_fog
            #pragma multi_compile _ _TERRAIN_BLENDING             

            #include "UnityCG.cginc"
            
            sampler2D _TerrainHeightmap;
            sampler2D _TerrainNormalmap;
            sampler2D _TerrainControl;
            float4 _TerrainControl_ST;
            sampler2D _TerrainLightmap;
            float4 _TerrainLightmap_ST;
            float4 _TerrainHeightmapDoubleScale;
            float4 _TerrainSize;
            float4 _TerrainPos;        
            sampler2D _TerrainSplat0, _TerrainSplat1, _TerrainSplat2, _TerrainSplat3;
            float4 _TerrainSplat0_ST, _TerrainSplat1_ST, _TerrainSplat2_ST, _TerrainSplat3_ST;        
            sampler2D _TerrainNormal0, _TerrainNormal1, _TerrainNormal2, _TerrainNormal3;
            float _TerrainNormalScale0, _TerrainNormalScale1, _TerrainNormalScale2, _TerrainNormalScale3;            
            float _TerrainMetallic0, _TerrainMetallic1, _TerrainMetallic2, _TerrainMetallic3;
            float _TerrainSmoothness0, _TerrainSmoothness1, _TerrainSmoothness2, _TerrainSmoothness3;
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            half _Glossiness;
            half _Metallic;  

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                UNITY_FOG_COORDS(2)
            };

            float2 TerrainUVs(float3 worldPos)
            {
                return ( worldPos.xz - _TerrainPos.xz ) / _TerrainSize.xz;
            }
        
            half TerrainHeight(half2 terrainUV)
            {
                return _TerrainPos.y + UnpackHeightmap( tex2Dlod( _TerrainHeightmap, half4(terrainUV,0,0) ) ) * _TerrainHeightmapDoubleScale.y;
            }
        
            half3 TerrainNormal(half2 terrainUV)
            {
                return tex2Dlod( _TerrainNormalmap, half4(terrainUV,0,0) ).xyz * 2.0 - 1.0;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul( unity_ObjectToWorld, v.vertex).xyz;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float2 splatUV = TerrainUVs( i.worldPos );
                half4 splatControl = tex2D( _TerrainControl, splatUV );
                half weight = dot( splatControl, half4(1,1,1,1) );
                splatControl /= (weight + 1e-3f);
                
                float2 uvSplat0 = TRANSFORM_TEX( splatUV, _TerrainSplat0 );
                float2 uvSplat1 = TRANSFORM_TEX( splatUV, _TerrainSplat1 );
                float2 uvSplat2 = TRANSFORM_TEX( splatUV, _TerrainSplat2 );
                float2 uvSplat3 = TRANSFORM_TEX( splatUV, _TerrainSplat3 );
                
                half4 mixedDiffuse = splatControl.r * tex2D( _TerrainSplat0, uvSplat0 );
                mixedDiffuse += splatControl.g * tex2D( _TerrainSplat1, uvSplat1 );
                mixedDiffuse += splatControl.b * tex2D( _TerrainSplat2, uvSplat2 );
                mixedDiffuse += splatControl.a * tex2D( _TerrainSplat3, uvSplat3 );
                
                half3 mixedNormal = UnpackNormalWithScale( tex2D( _TerrainNormal0, uvSplat0 ), _TerrainNormalScale0 ) * splatControl.r;
                mixedNormal += UnpackNormalWithScale( tex2D( _TerrainNormal1, uvSplat1 ), _TerrainNormalScale1 ) * splatControl.g;
                mixedNormal += UnpackNormalWithScale( tex2D( _TerrainNormal2, uvSplat2 ), _TerrainNormalScale2 ) * splatControl.b;
                mixedNormal += UnpackNormalWithScale( tex2D( _TerrainNormal3, uvSplat3 ), _TerrainNormalScale3 ) * splatControl.a;
                mixedNormal.z += 1e-5f;
                return half4( mixedDiffuse.xyz,1 );
            
                fixed4 col = tex2D( _MainTex, i.uv );
                UNITY_APPLY_FOG( i.fogCoord, col );
                return col;
            }
            ENDCG
        }
    }
}
