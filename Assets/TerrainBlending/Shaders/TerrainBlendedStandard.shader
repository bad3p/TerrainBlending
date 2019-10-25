Shader "Standart/Terrain-Blended"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}

        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        _DetailNormalMap("Normal Map", 2D) = "bump" {}

        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0


        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }
    
    CGINCLUDE
        #define UNITY_SETUP_BRDF_INPUT MetallicSetup        
    ENDCG
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300


        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 3.5
            #pragma exclude_renderers gles 

            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE
            
            #pragma vertex vertTerrainBlended
            #pragma fragment fragTerrainBlended
            
            #define UNITY_STANDARD_SIMPLE 0              
            #include "UnityStandardCoreForward.cginc"            
            
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

            float2 TerrainUV(float3 worldPos)
            {
                return ( worldPos.xz - _TerrainPos.xz ) / _TerrainSize.xz;
            }
        
            float TerrainHeight(half2 terrainUV)
            {
                return _TerrainPos.y + UnpackHeightmap( tex2Dlod( _TerrainHeightmap, half4(terrainUV,0,0) ) ) * _TerrainHeightmapDoubleScale.y;
            }
        
            half3 TerrainNormal(half2 terrainUV)
            {
                return tex2Dlod( _TerrainNormalmap, half4(terrainUV,0,0) ).xyz * 2.0 - 1.0;
            }
            
            half2 MetallicGlossFromSamples(float4 mainTexSample, float4 metallicGlossMapSample, float metallic)
            {
                half2 mg;
            
                #ifdef _METALLICGLOSSMAP
                    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                        mg.r = metallicGlossMapSample.r;
                        mg.g = mainTexSample.a;
                    #else
                        mg = metallicGlossMapSample.ra;
                    #endif
                    mg.g *= _GlossMapScale;
                #else
                    mg.r = metallic;
                    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                        mg.g = mainTexSample.a * _GlossMapScale;
                    #else
                        mg.g = _Glossiness;
                    #endif
                #endif
                return mg;
            }
            
            struct VertexOutputForwardTerrainBlended
            {
                UNITY_POSITION(pos);
                float4 tex                            : TEXCOORD0;
                float4 eyeVec                         : TEXCOORD1;    // eyeVec.xyz | fogCoord
                float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
                half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UV
                UNITY_LIGHTING_COORDS(6,7)

                #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
                    float3 posWorld                   : TEXCOORD8;
                #endif
                
                float2 terrainUV : TEXCOORD9;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            void WrapVertexOutput(VertexOutputForwardBase i, out VertexOutputForwardTerrainBlended o)
            {
                UNITY_INITIALIZE_OUTPUT(VertexOutputForwardTerrainBlended,o);
                o.pos = i.pos;
                o.tex = i.tex;
                o.eyeVec = i.eyeVec;
                o.tangentToWorldAndPackedData[0] = i.tangentToWorldAndPackedData[0];
                o.tangentToWorldAndPackedData[1] = i.tangentToWorldAndPackedData[1];
                o.tangentToWorldAndPackedData[2] = i.tangentToWorldAndPackedData[2];
                o.ambientOrLightmapUV = i.ambientOrLightmapUV;
                #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE) || defined(DIRECTIONAL_COOKIE)
                    o._LightCoord = i._LightCoord;
                #endif
                #if defined(SHADOWS_SCREEN)
                    o._ShadowCoord = i._ShadowCoord;
                #endif
                #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
                    o.posWorld = i.posWorld;
                #endif                
                #if defined(UNITY_INSTANCIONG_ENABLED)
                    o.instanceID = i.instanceID;
                #endif
                #ifdef UNITY_STEREO_INSTANCING_ENABLED
                    #if defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)
                        o.stereoTargetEyeIndexSV = i.stereoTargetEyeIndexSV;
                        o.stereoTargetEyeIndex = i.stereoTargetEyeIndex;
                    #else
                        o.stereoTargetEyeIndex = i.stereoTargetEyeIndex;
                    #endif
                #endif
            }
            
            void WrapVertexOutput(VertexOutputForwardTerrainBlended i, out VertexOutputForwardBase o)
            {
                UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase,o);
                o.pos = i.pos;
                o.tex = i.tex;
                o.eyeVec = i.eyeVec;
                o.tangentToWorldAndPackedData[0] = i.tangentToWorldAndPackedData[0];
                o.tangentToWorldAndPackedData[1] = i.tangentToWorldAndPackedData[1];
                o.tangentToWorldAndPackedData[2] = i.tangentToWorldAndPackedData[2];
                o.ambientOrLightmapUV = i.ambientOrLightmapUV;
                #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE) || defined(DIRECTIONAL_COOKIE)
                    o._LightCoord = i._LightCoord;
                #endif
                #if defined(SHADOWS_SCREEN)
                    o._ShadowCoord = i._ShadowCoord;
                #endif
                #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
                    o.posWorld = i.posWorld;
                #endif                
                #if defined(UNITY_INSTANCIONG_ENABLED)
                    o.instanceID = i.instanceID;
                #endif
                #ifdef UNITY_STEREO_INSTANCING_ENABLED
                    #if defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)
                        o.stereoTargetEyeIndexSV = i.stereoTargetEyeIndexSV;
                        o.stereoTargetEyeIndex = i.stereoTargetEyeIndex;
                    #else
                        o.stereoTargetEyeIndex = i.stereoTargetEyeIndex;
                    #endif
                #endif
            }
            
            VertexOutputForwardTerrainBlended vertTerrainBlended (VertexInput v) 
            {
                UNITY_SETUP_INSTANCE_ID(v);
                VertexOutputForwardBase o;
                UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase, o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
                #if UNITY_REQUIRE_FRAG_WORLDPOS
                    #if UNITY_PACK_WORLDPOS_WITH_TANGENT
                        o.tangentToWorldAndPackedData[0].w = posWorld.x;
                        o.tangentToWorldAndPackedData[1].w = posWorld.y;
                        o.tangentToWorldAndPackedData[2].w = posWorld.z;
                    #else
                        o.posWorld = posWorld.xyz;
                    #endif
                #endif
                o.pos = UnityObjectToClipPos(v.vertex);

                o.tex = TexCoords(v);
                o.eyeVec.xyz = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
                float3 normalWorld = UnityObjectToWorldNormal(v.normal);
                #ifdef _TANGENT_TO_WORLD
                    float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

                    float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
                    o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
                    o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
                    o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
                #else
                    o.tangentToWorldAndPackedData[0].xyz = 0;
                    o.tangentToWorldAndPackedData[1].xyz = 0;
                    o.tangentToWorldAndPackedData[2].xyz = normalWorld;
                #endif

                //We need this for shadow receving
                UNITY_TRANSFER_LIGHTING(o, v.uv1);

                o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);

                #ifdef _PARALLAXMAP
                    TANGENT_SPACE_ROTATION;
                    half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
                    o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
                    o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
                    o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
                #endif

                UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,o.pos);
                
                VertexOutputForwardTerrainBlended ob;                
                WrapVertexOutput( o, ob );                
                ob.terrainUV = TerrainUV( posWorld );
                                
                return ob; 
            }
            
            half4 fragTerrainBlended (VertexOutputForwardTerrainBlended ib) : SV_Target 
            {
                // reconstruct terrain splatting at position of the fragment
                
                half2 terrainLightmapUV = TRANSFORM_TEX( ib.terrainUV, _TerrainLightmap );
                half4 splatControl = tex2D( _TerrainControl, ib.terrainUV );
                half weight = dot( splatControl, half4(1,1,1,1) );
                splatControl /= (weight + 1e-3f);
                
                half2 uvSplat0 = TRANSFORM_TEX( ib.terrainUV, _TerrainSplat0 );
                half2 uvSplat1 = TRANSFORM_TEX( ib.terrainUV, _TerrainSplat1 );
                half2 uvSplat2 = TRANSFORM_TEX( ib.terrainUV, _TerrainSplat2 );
                half2 uvSplat3 = TRANSFORM_TEX( ib.terrainUV, _TerrainSplat3 );
                
                half mixedMetallic = splatControl.r * _TerrainMetallic0;
                mixedMetallic += splatControl.g * _TerrainMetallic1;
                mixedMetallic += splatControl.b * _TerrainMetallic2;
                mixedMetallic += splatControl.a * _TerrainMetallic3;
                
                //half mixedSmoothness = splatControl.r * _TerrainSmoothness0;
                //mixedSmoothness += splatControl.g * _TerrainSmoothness1;
                //mixedSmoothness += splatControl.b * _TerrainSmoothness2;
                //mixedSmoothness += splatControl.a * _TerrainSmoothness3;
                
                half4 mixedDiffuse = splatControl.r * tex2D( _TerrainSplat0, uvSplat0 ) * half4(1,1,1,_TerrainSmoothness0);
                mixedDiffuse += splatControl.g * tex2D( _TerrainSplat1, uvSplat1 ) * half4(1,1,1,_TerrainSmoothness1);
                mixedDiffuse += splatControl.b * tex2D( _TerrainSplat2, uvSplat2 ) * half4(1,1,1,_TerrainSmoothness2);
                mixedDiffuse += splatControl.a * tex2D( _TerrainSplat3, uvSplat3 ) * half4(1,1,1,_TerrainSmoothness3);                
                
                half3 mixedNormal = UnpackNormalWithScale( tex2D( _TerrainNormal0, uvSplat0 ), _TerrainNormalScale0 ) * splatControl.r;
                mixedNormal += UnpackNormalWithScale( tex2D( _TerrainNormal1, uvSplat1 ), _TerrainNormalScale1 ) * splatControl.g;
                mixedNormal += UnpackNormalWithScale( tex2D( _TerrainNormal2, uvSplat2 ), _TerrainNormalScale2 ) * splatControl.b;
                mixedNormal += UnpackNormalWithScale( tex2D( _TerrainNormal3, uvSplat3 ), _TerrainNormalScale3 ) * splatControl.a;
                mixedNormal.z += 1e-5f;
                
                // VertexOutputForwardBase for underlying terrain
                
                VertexOutputForwardBase i;
                WrapVertexOutput( ib, i );
                
                #if UNITY_REQUIRE_FRAG_WORLDPOS
                    #if UNITY_PACK_WORLDPOS_WITH_TANGENT
                        float3 posWorld = float3( 
                            i.tangentToWorldAndPackedData[0].w,
                            i.tangentToWorldAndPackedData[1].w,
                            i.tangentToWorldAndPackedData[2].w
                        );
                    #else
                        float3 posWorld = ib.posWorld;
                    #endif
                                        
                    float terrainHeight = TerrainHeight( ib.terrainUV );                    
                    float3 terrainPosWorld = float3( posWorld.x, terrainHeight, posWorld.z );
                    float deltaHeight = posWorld.y - terrainHeight;
                    
                    half3 terrainNormalWorld = TerrainNormal( ib.terrainUV );
                    
                    #ifdef _TANGENT_TO_WORLD
                        half3 terrainTangentWorld = cross( terrainNormalWorld, half3(0,0,1) );
                        half3 terrainBitangentWorld = cross( terrainTangentWorld, terrainNormalWorld ); 
                        i.tangentToWorldAndPackedData[0].xyz = terrainTangentWorld;
                        i.tangentToWorldAndPackedData[1].xyz = terrainBitangentWorld;
                        i.tangentToWorldAndPackedData[2].xyz = terrainNormalWorld;
                    #else
                        i.tangentToWorldAndPackedData[0].xyz = 0;
                        i.tangentToWorldAndPackedData[1].xyz = 0;
                        i.tangentToWorldAndPackedData[2].xyz = terrainNormalWorld;
                    #endif
                                        
                    i.eyeVec.xyz = normalize(terrainPosWorld - _WorldSpaceCameraPos);
                #endif
                
                i.ambientOrLightmapUV.xy = TRANSFORM_TEX( ib.terrainUV, _TerrainLightmap );
                i.ambientOrLightmapUV.zw = 0;
                
                // Standard shading for underlying terrain
                
                {                
                    FRAGMENT_SETUP(s)                    
                    s.oneMinusReflectivity = OneMinusReflectivityFromMetallic( mixedMetallic );                   
                    s.smoothness = mixedDiffuse.a;
                    s.diffColor = mixedDiffuse * s.oneMinusReflectivity;
                    s.specColor = lerp( unity_ColorSpaceDielectricSpec.rgb, mixedDiffuse, mixedMetallic );
                    #if UNITY_REQUIRE_FRAG_WORLDPOS
                        s.posWorld = terrainPosWorld;
                    #endif                                        
                    #if UNITY_REQUIRE_FRAG_WORLDPOS
                        #ifdef _TANGENT_TO_WORLD
                            s.normalWorld = float3(
                                dot(i.tangentToWorldAndPackedData[0].xyz,mixedNormal),
                                dot(i.tangentToWorldAndPackedData[1].xyz,mixedNormal),
                                dot(i.tangentToWorldAndPackedData[2].xyz,mixedNormal)
                            );
                        #else
                            s.normalWorld = terrainNormalWorld;
                        #endif
                        s.normalWorld = normalize(s.normalWorld);
                    #endif                                                       
                    UNITY_SETUP_INSTANCE_ID(i);
                    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                    UnityLight mainLight = MainLight ();
                    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);
                    half occlusion = 0;//Occlusion(i.tex.xy);
                    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
                    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
                    //c.rgb += Emission(i.tex.xy);
                    UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
                    UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
                    
                    return OutputForward (c, s.alpha);
                } 
                
                // standard shader
                     
                WrapVertexOutput( ib, i );
            
                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

                FRAGMENT_SETUP(s)

                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                UnityLight mainLight = MainLight ();
                UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

                half occlusion = Occlusion(i.tex.xy);
                UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);

                half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
                c.rgb += Emission(i.tex.xy);

                UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
                UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
                return OutputForward (c, s.alpha); 
            }
            ENDCG
        }
        
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass 
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _PARALLAXMAP
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }        

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta

            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "UnityStandardMeta.cginc"
            ENDCG
        }
    }
    
    FallBack "VertexLit"
    CustomEditor "StandardShaderGUI"
}

/*
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
                SHADOW_COORDS(4)
                UNITY_FOG_COORDS_PACKED(5,half4)
            };
            
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                #ifdef LIGHTMAP_ON
                    o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif 
                o.worldPos = mul( unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = mul( unity_ObjectToWorld, float4(v.normal,0)).xyz;
                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o,o.vertex);
                o.fogCoord.yzw = float3(0,-1,0); // TODO
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float2 splatUV = TerrainUVs( i.worldPos );
                float2 terrainLightmapUV = TRANSFORM_TEX( splatUV, _TerrainLightmap );
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
                
                VertexOutputBaseSimple vo;
                vo.pos = i.pos;
                vo.tex = float4(i.uv, 0, 0);
                vo.eyeVec = half4( normalize( i.worldPos - _WorldSpaceCameraPos ), 0 );
                #ifdef LIGHTMAP_ON 
                    vo.ambientOrLightmapUV = i.lightmapUV;
                #else
                    vo.ambientOrLightmapUV = 0;
                #endif 
                #ifdef SHADOWS_SCREEN
                    vo._ShadowCoord = i._ShadowCoord;
                #endif
                vo.fogCoord = i.fogCoord;
                vo.normalWorld = half4(i.worldNormal,0);
                #ifdef _NORMALMAP
                    vo.tangentSpaceLightDir = float3(0,-1,0); // TODO
                    #if SPECULAR_HIGHLIGHTS
                        vo.tangentSpaceEyeVec = float3(0,-1,0); // TODO
                    #endif
                #endif
                #if UNITY_REQUIRE_FRAG_WORLDPOS
                    vo.posWorld = i.worldPos;
                #endif
                
                
                FragmentCommonData fcd = UNITY_SETUP_BRDF_INPUT (float4(i.uv,0,0));// = FragmentSetupSimple(i);
                fcd.diffColor = mixedDiffuse.rgb;
                fcd.normalWorld = mixedNormal.xyz; // TODO: vertex normal
                fcd.eyeVec = vo.eyeVec.xyz;
                fcd.posWorld = i.worldPos;
                fcd.reflUVW = i.fogCoord.yzw;
                #ifdef _NORMALMAP
                    fcd.tangentSpaceNormal =  mixedNormal;
                #else
                    fcd.tangentSpaceNormal =  0;
                #endif
                
                UnityLight mainLight = MainLightSimple(vo, fcd);
                
                float3 viewDir = half4( normalize( i.worldPos - _WorldSpaceCameraPos ), 0 );
                
                                          
                SurfaceOutputStandard s;
                s.Albedo = mixedDiffuse.rgb;
                s.Normal = mixedNormal.xyz;
                s.Emission = half3( 0, 0, 0 ); // TODO
                s.Metallic = 0; // TODO
                s.Smoothness = 0; // TODO
                s.Occlusion = 0; // TODO
                s.Alpha = 1.0; // TODO
                
                float occlusion = s.Occlusion;
                float atten = 0;
                       
                UnityGI gi;
                gi = FragmentGI( fcd, occlusion, vo.ambientOrLightmapUV, atten, mainLight, true);
                                     
                half4 lighting = LightingStandard( s, viewDir, gi );
                return lighting;
            
                fixed4 col = tex2D( _MainTex, i.uv );
                UNITY_APPLY_FOG( i.fogCoord, col );
                return col;
            }
            */