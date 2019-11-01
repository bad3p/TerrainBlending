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
            #include "TerrainStandardExt.cginc"            
            
            sampler2D _TerrainHeightmap;
            sampler2D _TerrainNormalmap;
            sampler2D _TerrainControl;
            float4 _TerrainControl_ST;
            sampler2D _TerrainLightmap;
            float4 _TerrainLightmap_ST;
            float4 _TerrainHeightmapDoubleScale;
            float4 _TerrainSize;
            float4 _TerrainPos;        
            UNITY_DECLARE_TEX2D(_TerrainSplat0);
            UNITY_DECLARE_TEX2D(_TerrainSplat1);
            UNITY_DECLARE_TEX2D(_TerrainSplat2);
            UNITY_DECLARE_TEX2D(_TerrainSplat3);
            float4 _TerrainSplat0_ST, _TerrainSplat1_ST, _TerrainSplat2_ST, _TerrainSplat3_ST;        
            UNITY_DECLARE_TEX2D_NOSAMPLER(_TerrainNormal0);
            UNITY_DECLARE_TEX2D_NOSAMPLER(_TerrainNormal1);
            UNITY_DECLARE_TEX2D_NOSAMPLER(_TerrainNormal2);
            UNITY_DECLARE_TEX2D_NOSAMPLER(_TerrainNormal3);
            float _TerrainNormalScale0, _TerrainNormalScale1, _TerrainNormalScale2, _TerrainNormalScale3;            
            float _TerrainMetallic0, _TerrainMetallic1, _TerrainMetallic2, _TerrainMetallic3;

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
            
            half4 TerrainGIForward(half2 terrainUV, half3 posWorld, half3 normalWorld)
            {
                half4 ambientOrLightmapUV = 0;
                // Static lightmaps
                #ifdef LIGHTMAP_ON
                    ambientOrLightmapUV.xy = terrainUV * _TerrainLightmap_ST.xy + _TerrainLightmap_ST.zw;
                // Sample light probe for Dynamic objects only (no static or dynamic lightmaps)
                #elif UNITY_SHOULD_SAMPLE_SH
                    #ifdef VERTEXLIGHT_ON
                        // Approximated illumination from non-important point lights
                        ambientOrLightmapUV.rgb = Shade4PointLights (
                            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                            unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                            unity_4LightAtten0, posWorld, normalWorld);
                    #endif
                    ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, ambientOrLightmapUV.rgb);
                #endif

                return ambientOrLightmapUV;
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
                
                half4 mixedDiffuse = splatControl.r * UNITY_SAMPLE_TEX2D_SAMPLER( _TerrainSplat0, _TerrainSplat0, uvSplat0 );
                mixedDiffuse += splatControl.g * UNITY_SAMPLE_TEX2D_SAMPLER( _TerrainSplat1, _TerrainSplat1, uvSplat1 );
                mixedDiffuse += splatControl.b * UNITY_SAMPLE_TEX2D_SAMPLER( _TerrainSplat2, _TerrainSplat2, uvSplat2 );
                mixedDiffuse += splatControl.a * UNITY_SAMPLE_TEX2D_SAMPLER( _TerrainSplat3, _TerrainSplat3, uvSplat3 );                
                
                half3 mixedNormal = UnpackNormalWithScale( UNITY_SAMPLE_TEX2D_SAMPLER( _TerrainNormal0, _TerrainSplat0, uvSplat0 ), _TerrainNormalScale0 ) * splatControl.r;
                mixedNormal += UnpackNormalWithScale( UNITY_SAMPLE_TEX2D_SAMPLER( _TerrainNormal1, _TerrainSplat1, uvSplat1 ), _TerrainNormalScale1 ) * splatControl.g;
                mixedNormal += UnpackNormalWithScale( UNITY_SAMPLE_TEX2D_SAMPLER( _TerrainNormal2, _TerrainSplat2, uvSplat2 ), _TerrainNormalScale2 ) * splatControl.b;
                mixedNormal += UnpackNormalWithScale( UNITY_SAMPLE_TEX2D_SAMPLER( _TerrainNormal3, _TerrainSplat3, uvSplat3 ), _TerrainNormalScale3 ) * splatControl.a;
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
                    
                    #if UNITY_PACK_WORLDPOS_WITH_TANGENT
                        i.tangentToWorldAndPackedData[0].w = terrainPosWorld.x;
                        i.tangentToWorldAndPackedData[1].w = terrainPosWorld.y;
                        i.tangentToWorldAndPackedData[2].w = terrainPosWorld.z;
                    #else
                        i.posWorld = terrainPosWorld;
                    #endif
                    
                    i.ambientOrLightmapUV = TerrainGIForward( ib.terrainUV, terrainPosWorld, terrainNormalWorld );
                #endif
                
                //i.ambientOrLightmapUV.xy = TRANSFORM_TEX( ib.terrainUV, _TerrainLightmap );
                //i.ambientOrLightmapUV.zw = 0;                      
                
                // Standard shading for underlying terrain
                
                half4 terrainColor = 0;
                {
                    FragmentCommonData s = TerrainFragmentSetup( mixedDiffuse, mixedNormal, mixedMetallic, i.eyeVec, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndPackedData, IN_WORLDPOS(i) );                                          
                    UNITY_SETUP_INSTANCE_ID(i);
                    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                    UnityLight mainLight = MainLight ();
                    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);
                    half occlusion = 1; 
                    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);    
                    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
                    UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
                    UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
                    terrainColor = OutputForward (c, s.alpha);                                         
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
                half4 color = OutputForward (c, s.alpha);
                
                #if UNITY_REQUIRE_FRAG_WORLDPOS
                    return lerp( terrainColor, color, smoothstep( 0, 0.05, deltaHeight ) );
                #else
                    return color;
                #endif
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