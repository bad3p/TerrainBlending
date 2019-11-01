
#ifndef TERRAIN_STANDARD_BLENDABLE_INCLUDED
#define TERRAIN_STANDARD_BLENDABLE_INCLUDED

#include "UnityStandardCore.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardUtils.cginc"

#ifdef _NORMALMAP
    #define _TERRAIN_NORMAL_MAP
#endif

sampler2D _Control;
float4 _Control_ST;
float4 _Control_TexelSize;
sampler2D _Splat0, _Splat1, _Splat2, _Splat3;
float4 _Splat0_ST, _Splat1_ST, _Splat2_ST, _Splat3_ST;

#if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X)
    sampler2D _TerrainHeightmapTexture;
    sampler2D _TerrainNormalmapTexture;
    float4    _TerrainHeightmapRecipSize;   // float4(1.0f/width, 1.0f/height, 1.0f/(width-1), 1.0f/(height-1))
    float4    _TerrainHeightmapScale;       // float4(hmScale.x, hmScale.y / (float)(kMaxHeight), hmScale.z, 0.0f)
#endif

UNITY_INSTANCING_BUFFER_START(Terrain)
    UNITY_DEFINE_INSTANCED_PROP(float4, _TerrainPatchInstanceData) // float4(xBase, yBase, skipScale, ~)
UNITY_INSTANCING_BUFFER_END(Terrain)

#ifdef _NORMALMAP
    sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
    float _NormalScale0, _NormalScale1, _NormalScale2, _NormalScale3;
#endif

#if defined(TERRAIN_BASE_PASS) && defined(UNITY_PASS_META)
    // When we render albedo for GI baking, we actually need to take the ST
    float4 _MainTex_ST;
#endif

half _Metallic0, _Metallic1, _Metallic2, _Metallic3;

// --------------------------------------------------------------------------------
// EXTENDED VERTEX FORMAT
// --------------------------------------------------------------------------------

struct VertexOutputForwardBaseExt
{
    UNITY_POSITION(pos);
    float4 tex                            : TEXCOORD0;
    float4 eyeVec                         : TEXCOORD1;    // eyeVec.xyz | fogCoord
    float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
    half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UV
    UNITY_LIGHTING_COORDS(6,7)

    // next ones would not fit into SM2.0 limits, but they are always for SM3.0+
#if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
    float3 posWorld                     : TEXCOORD8;
#endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void WrapVertexOutputForwardBase(VertexOutputForwardBase i, out VertexOutputForwardBaseExt o)
{
    UNITY_INITIALIZE_OUTPUT( VertexOutputForwardBaseExt, o );
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
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        o.fogCoord = i.fogCoord;
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

void WrapVertexOutputForwardBaseExt(VertexOutputForwardBaseExt i, out VertexOutputForwardBase o)
{
    UNITY_INITIALIZE_OUTPUT( VertexOutputForwardBase, o );
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
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        o.fogCoord = i.fogCoord;
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

// --------------------------------------------------------------------------------
// FRAGMENT
// --------------------------------------------------------------------------------

inline float3 TerrainPerPixelWorldNormal(half3 mixedNormal, float4 tangentToWorld[3])
{
    #ifdef _NORMALMAP
        half3 tangent = tangentToWorld[0].xyz;
        half3 binormal = tangentToWorld[1].xyz;
        half3 normal = tangentToWorld[2].xyz;

        #if UNITY_TANGENT_ORTHONORMALIZE
            normal = NormalizePerPixelNormal(normal);
            // ortho-normalize Tangent
            tangent = normalize (tangent - normal * dot(tangent, normal));
            // recalculate Binormal
            half3 newB = cross(normal, tangent);
            binormal = newB * sign (dot (newB, binormal));
        #endif

        half3 normalTangent = mixedNormal;
        float3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
    #else
        float3 normalWorld = normalize(tangentToWorld[2].xyz);
    #endif
    return normalWorld;
}

inline half2 TerrainMetallicRough(half4 mixedDiffuse, half mixedMetallic)
{
    return half2( _Metallic, mixedDiffuse.a );
}

inline half3 TerrainDiffuseAndSpecularFromMetallic (half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
{
    specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo * oneMinusReflectivity;
}

inline half3 TerrainAlbedo(half4 mixedDiffuse)
{
    half3 albedo = mixedDiffuse.rgb;
    return albedo;
}

inline FragmentCommonData TerrainRoughnessSetup(half4 mixedDiffuse, half mixedMetallic)
{
    half2 metallicGloss = TerrainMetallicRough(mixedDiffuse, mixedMetallic);
    half metallic = metallicGloss.x;
    half smoothness = metallicGloss.y; // this is 1 minus the square root of real roughness m.    

    half oneMinusReflectivity;
    half3 specColor;
    half3 diffColor = TerrainDiffuseAndSpecularFromMetallic (TerrainAlbedo(mixedDiffuse), mixedMetallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

    FragmentCommonData o = (FragmentCommonData)0;
    o.diffColor = diffColor;
    o.specColor = specColor;
    o.oneMinusReflectivity = oneMinusReflectivity;
    o.smoothness = smoothness;
    return o;
}

inline FragmentCommonData TerrainFragmentSetup(half4 mixedDiffuse, half3 mixedNormal, half mixedMetallic, float3 i_eyeVec, half3 i_viewDirForParallax, float4 tangentToWorld[3], float3 i_posWorld)
{
    half alpha = 1.0;

    FragmentCommonData o = TerrainRoughnessSetup( mixedDiffuse, mixedMetallic );
    o.normalWorld = TerrainPerPixelWorldNormal( mixedNormal, tangentToWorld );
    o.eyeVec = normalize( i_eyeVec );
    o.posWorld = i_posWorld;
    
    return o;
}

inline void TerrainSplatting(float4 itex, out half4 mixedDiffuse, out half3 mixedNormal, out half mixedMetallic)
{
    // adjust splatUVs so the edges of the terrain tile lie on pixel centers
    float2 splatUV = (itex.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
    half4 splat_control = tex2D(_Control, splatUV);
    half weight = dot( splat_control, half4(1,1,1,1) );
    
    #if !defined(SHADER_API_MOBILE) && defined(TERRAIN_SPLAT_ADDPASS)
        clip(weight == 0.0f ? -1 : 1);
    #endif
    
    // Normalize weights before lighting and restore weights in final modifier functions so that the overal
    // lighting result can be correctly weighted.
    splat_control /= (weight + 1e-3f);
    
    float2 uvSplat0 = TRANSFORM_TEX(itex.xy, _Splat0);
    float2 uvSplat1 = TRANSFORM_TEX(itex.xy, _Splat1);
    float2 uvSplat2 = TRANSFORM_TEX(itex.xy, _Splat2);
    float2 uvSplat3 = TRANSFORM_TEX(itex.xy, _Splat3);
    
    mixedDiffuse = splat_control.r * tex2D(_Splat0, uvSplat0);
    mixedDiffuse += splat_control.g * tex2D(_Splat1, uvSplat1);
    mixedDiffuse += splat_control.b * tex2D(_Splat2, uvSplat2);
    mixedDiffuse += splat_control.a * tex2D(_Splat3, uvSplat3);
        
    mixedNormal = 0.0f;
    #ifdef _NORMALMAP        
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal0, uvSplat0), _NormalScale0) * splat_control.r;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal1, uvSplat1), _NormalScale1) * splat_control.g;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal2, uvSplat2), _NormalScale2) * splat_control.b;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal3, uvSplat3), _NormalScale3) * splat_control.a;
        mixedNormal.z += 1e-5f; // to avoid nan after normalizing
    #endif 
    
    #if defined(INSTANCING_ON) && defined(SHADER_TARGET_SURFACE_ANALYSIS) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
        mixedNormal = float3(0, 0, 1); // make sure that surface shader compiler realizes we write to normal, as UNITY_INSTANCING_ENABLED is not defined for SHADER_TARGET_SURFACE_ANALYSIS.
    #endif
    
    #if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
        float3 geomNormal = normalize(tex2D(_TerrainNormalmapTexture, splatUV).xyz * 2 - 1);
        #ifdef _NORMALMAP
            float3 geomTangent = normalize(cross(geomNormal, float3(0, 0, 1)));
            float3 geomBitangent = normalize(cross(geomTangent, geomNormal));
            mixedNormal = mixedNormal.x * geomTangent
                          + mixedNormal.y * geomBitangent
                          + mixedNormal.z * geomNormal;
        #else
            mixedNormal = geomNormal;
        #endif
        mixedNormal = mixedNormal.xzy;        
    #endif
    
    mixedMetallic = dot( splat_control, half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3) );    
}

// --------------------------------------------------------------------------------
// FORWARD BASE
// --------------------------------------------------------------------------------
        
VertexOutputForwardBase vertTerrainBase (VertexInput v)
{
    UNITY_SETUP_INSTANCE_ID(v);
    #ifdef UNITY_INSTANCING_ENABLED
        float2 patchVertex = v.vertex.xy;
        float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);
    
        float4 uvscale = instanceData.z * _TerrainHeightmapRecipSize;
        float4 uvoffset = instanceData.xyxy * uvscale;
        uvoffset.xy += 0.5 * _TerrainHeightmapRecipSize.xy;
        float2 sampleCoords = (patchVertex.xy * uvscale.xy + uvoffset.xy);
        
        float hm = UnpackHeightmap( tex2Dlod(_TerrainHeightmapTexture, float4(sampleCoords,0,0) ) );
        v.vertex.xz = (patchVertex.xy + instanceData.xy) * _TerrainHeightmapScale.xz * instanceData.z;
        v.vertex.y = hm * _TerrainHeightmapScale.y;
        v.vertex.w = 1;
        
        v.uv0.xy = (patchVertex.xy * uvscale.zw + uvoffset.zw);
        v.uv1 = v.uv0;
        
        #ifdef TERRAIN_INSTANCED_PERPIXEL_NORMAL
            v.normal = float3(0,1,0);
        #else
            float3 normal = tex2Dlod( _TerrainNormalmapTexture, float4(sampleCoords,0,0) ).xyz;
            v.normal = 2 * normal - 1;
        #endif
    #endif    
    
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
    return o;
}

half4 fragTerrainBase (VertexOutputForwardBase i) : SV_Target
{
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);
    
    half4 mixedDiffuse;
    half3 mixedNormal;    
    half mixedMetallic;
    TerrainSplatting( i.tex, mixedDiffuse, mixedNormal, mixedMetallic ); 
    
    // lighting
    
    FragmentCommonData s = TerrainFragmentSetup( mixedDiffuse, mixedNormal, mixedMetallic, i.eyeVec, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndPackedData, IN_WORLDPOS(i) );                                         

    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

    UnityLight mainLight = MainLight ();
    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

    //half occlusion = Occlusion(i.tex.xy);
    half occlusion = 1; 
    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
    
    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
    //c.rgb += Emission(i.tex.xy);

    UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
    UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
    return OutputForward (c, s.alpha);
}

// --------------------------------------------------------------------------------
// FORWARD ADD
// --------------------------------------------------------------------------------

VertexOutputForwardAdd vertTerrainAdd (VertexInput v)
{
    UNITY_SETUP_INSTANCE_ID(v);
    VertexOutputForwardAdd o;
    UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAdd, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
    o.pos = UnityObjectToClipPos(v.vertex);

    o.tex = TexCoords(v);
    o.eyeVec.xyz = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
    o.posWorld = posWorld.xyz;
    float3 normalWorld = UnityObjectToWorldNormal(v.normal);
    #ifdef _TANGENT_TO_WORLD
        float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

        float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
        o.tangentToWorldAndLightDir[0].xyz = tangentToWorld[0];
        o.tangentToWorldAndLightDir[1].xyz = tangentToWorld[1];
        o.tangentToWorldAndLightDir[2].xyz = tangentToWorld[2];
    #else
        o.tangentToWorldAndLightDir[0].xyz = 0;
        o.tangentToWorldAndLightDir[1].xyz = 0;
        o.tangentToWorldAndLightDir[2].xyz = normalWorld;
    #endif
    //We need this for shadow receiving and lighting
    UNITY_TRANSFER_LIGHTING(o, v.uv1);

    float3 lightDir = _WorldSpaceLightPos0.xyz - posWorld.xyz * _WorldSpaceLightPos0.w;
    #ifndef USING_DIRECTIONAL_LIGHT
        lightDir = NormalizePerVertexNormal(lightDir);
    #endif
    o.tangentToWorldAndLightDir[0].w = lightDir.x;
    o.tangentToWorldAndLightDir[1].w = lightDir.y;
    o.tangentToWorldAndLightDir[2].w = lightDir.z;

    #ifdef _PARALLAXMAP
        TANGENT_SPACE_ROTATION;
        o.viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
    #endif

    UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o, o.pos);
    return o;
}

half4 fragTerrainAdd (VertexOutputForwardAdd i) : SV_Target
{
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

    //FRAGMENT_SETUP_FWDADD(s)
    
    half4 mixedDiffuse;
    half3 mixedNormal;    
    half mixedMetallic;
    TerrainSplatting( i.tex, mixedDiffuse, mixedNormal, mixedMetallic );
    
    FragmentCommonData s = TerrainFragmentSetup( mixedDiffuse, mixedNormal, mixedMetallic, i.eyeVec, IN_VIEWDIR4PARALLAX_FWDADD(i), i.tangentToWorldAndLightDir, IN_WORLDPOS_FWDADD(i));

    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
    UnityLight light = AdditiveLight (IN_LIGHTDIR_FWDADD(i), atten);
    UnityIndirect noIndirect = ZeroIndirect ();

    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect);

    UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
    UNITY_APPLY_FOG_COLOR(_unity_fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass
    return OutputForward (c, s.alpha);
}

#endif // TERRAIN_STANDARD_BLENDABLE_INCLUDED
