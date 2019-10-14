
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

[RequireComponent(typeof(Terrain))]
[ExecuteInEditMode]
public class TerrainShaderPropertyBridge : MonoBehaviour
{
    private static class Uniforms
    {
        internal static readonly int _TerrainHeightmap = Shader.PropertyToID("_TerrainHeightmap");
        internal static readonly int _TerrainNormalmap = Shader.PropertyToID("_TerrainNormalmap");
        internal static readonly int _TerrainControl = Shader.PropertyToID("_TerrainControl");
        internal static readonly int _TerrainLightmap = Shader.PropertyToID("_TerrainLightmap");
        internal static readonly int _TerrainLightmap_ST = Shader.PropertyToID("_TerrainLightmap_ST");
        internal static readonly int _TerrainHeightmapDoubleScale = Shader.PropertyToID("_TerrainHeightmapDoubleScale");
        internal static readonly int _TerrainSize = Shader.PropertyToID("_TerrainSize");
        internal static readonly int _TerrainPos = Shader.PropertyToID("_TerrainPos");
        internal static readonly int[] _TerrainSplat =
        {
            Shader.PropertyToID("_TerrainSplat0"),
            Shader.PropertyToID("_TerrainSplat1"),
            Shader.PropertyToID("_TerrainSplat2"),
            Shader.PropertyToID("_TerrainSplat3")
        };
        internal static readonly int[] _TerrainSplat_ST =
        {
            Shader.PropertyToID("_TerrainSplat0_ST"),
            Shader.PropertyToID("_TerrainSplat1_ST"),
            Shader.PropertyToID("_TerrainSplat2_ST"),
            Shader.PropertyToID("_TerrainSplat3_ST")
        };
        internal static readonly int[] _TerrainNormal =
        {
            Shader.PropertyToID("_TerrainNormal0"),
            Shader.PropertyToID("_TerrainNormal1"),
            Shader.PropertyToID("_TerrainNormal2"),
            Shader.PropertyToID("_TerrainNormal3")
        };
        internal static readonly int[] _TerrainNormalScale =
        {
            Shader.PropertyToID("_TerrainNormalScale0"),
            Shader.PropertyToID("_TerrainNormalScale1"),
            Shader.PropertyToID("_TerrainNormalScale2"),
            Shader.PropertyToID("_TerrainNormalScale3")
        };
        internal static readonly int[] _TerrainMetallic =
        {
            Shader.PropertyToID("_TerrainMetallic0"),
            Shader.PropertyToID("_TerrainMetallic1"),
            Shader.PropertyToID("_TerrainMetallic2"),
            Shader.PropertyToID("_TerrainMetallic3")
        };
        internal static readonly int[] _TerrainSmoothness =
        {
            Shader.PropertyToID("_TerrainSmoothness0"),
            Shader.PropertyToID("_TerrainSmoothness1"),
            Shader.PropertyToID("_TerrainSmoothness2"),
            Shader.PropertyToID("_TerrainSmoothness3")
        };
    }
    
    private Terrain _cachedTerrain;
    private Vector3 _cachedTerrainSize;
    private TerrainLayer[] _cachedTerrainLayers = new TerrainLayer[0];
    private Texture2D[] _cachedAlphamapTextures = new Texture2D[0];
    private LightmapData[] _cachedLightmaps = new LightmapData[0];
    
    void Awake()
    {
        _cachedTerrain = GetComponent<Terrain>();
        _cachedTerrainSize = _cachedTerrain.terrainData.size;
        _cachedTerrainLayers = _cachedTerrain.terrainData.terrainLayers;
        _cachedAlphamapTextures = _cachedTerrain.terrainData.alphamapTextures;
        _cachedLightmaps = LightmapSettings.lightmaps;
    }

    void OnEnable()
    {
        Shader.EnableKeyword("_TERRAIN_BLENDING");
    }

    void OnDisable()
    {
        Shader.DisableKeyword("_TERRAIN_BLENDING");
    }

    void OnDestroy()
    {
        Shader.DisableKeyword("_TERRAIN_BLENDING");
    }

    Vector4 GetSplatTextureScaleOffset(int terrainLayer)
    {
#if UNITY_EDITOR
        if (EditorApplication.isPlaying)
#else
        if( Application.isPlaying )
#endif
        {
            Vector3 tileSize = _cachedTerrainLayers[terrainLayer].tileSize;
            Vector3 tileOffset = _cachedTerrainLayers[terrainLayer].tileOffset;
            return new Vector4(_cachedTerrainSize.x / tileSize.x, _cachedTerrainSize.z / tileSize.y, tileOffset.x, tileOffset.y);
        }
        else
        {
            Vector3 terrainSize = _cachedTerrain.terrainData.size;
            Vector3 tileSize = _cachedTerrain.terrainData.terrainLayers[terrainLayer].tileSize;
            Vector3 tileOffset = _cachedTerrain.terrainData.terrainLayers[terrainLayer].tileOffset;
            return new Vector4(terrainSize.x / tileSize.x, terrainSize.z / tileSize.y, tileOffset.x, tileOffset.y);
        }
    }

    void Update()
    {
        Shader.SetGlobalTexture( Uniforms._TerrainHeightmap, _cachedTerrain.terrainData.heightmapTexture );
        Shader.SetGlobalTexture( Uniforms._TerrainNormalmap, _cachedTerrain.normalmapTexture );
        Shader.SetGlobalVector( Uniforms._TerrainHeightmapDoubleScale, _cachedTerrain.terrainData.heightmapScale * 2.0f );
        Shader.SetGlobalVector( Uniforms._TerrainSize, _cachedTerrain.terrainData.size );
        Shader.SetGlobalVector( Uniforms._TerrainPos, _cachedTerrain.transform.position );
        
#if UNITY_EDITOR
        if (EditorApplication.isPlaying)
#else
        if( Application.isPlaying )
#endif
        {
            for (int i = 0; i < _cachedTerrainLayers.Length; i++)
            {
                Shader.SetGlobalTexture( Uniforms._TerrainSplat[i], _cachedTerrainLayers[i].diffuseTexture );
                Shader.SetGlobalVector( Uniforms._TerrainSplat_ST[i], GetSplatTextureScaleOffset(i) );
                Shader.SetGlobalTexture( Uniforms._TerrainNormal[i], _cachedTerrainLayers[i].normalMapTexture );
                Shader.SetGlobalFloat( Uniforms._TerrainNormalScale[i], _cachedTerrainLayers[i].normalScale );
                Shader.SetGlobalFloat( Uniforms._TerrainMetallic[i], _cachedTerrainLayers[i].metallic );
                Shader.SetGlobalFloat(Uniforms._TerrainSmoothness[i], _cachedTerrainLayers[i].smoothness);
            }

            Shader.SetGlobalTexture( Uniforms._TerrainControl, _cachedAlphamapTextures[0] );
            
            if (_cachedLightmaps.Length > 0)
            {
                Shader.SetGlobalVector( Uniforms._TerrainLightmap_ST, _cachedTerrain.lightmapScaleOffset );
                Shader.SetGlobalTexture( Uniforms._TerrainLightmap, _cachedLightmaps[_cachedTerrain.lightmapIndex].lightmapColor );
            }
            else
            {
                Shader.SetGlobalVector( Uniforms._TerrainLightmap_ST, new Vector4(1,1,0,0) );
                Shader.SetGlobalTexture( Uniforms._TerrainLightmap, Texture2D.whiteTexture );
            }
        }
        else
        {
            for (int i = 0; i < _cachedTerrainLayers.Length; i++)
            {
                Shader.SetGlobalTexture( Uniforms._TerrainSplat[i], _cachedTerrain.terrainData.terrainLayers[i].diffuseTexture );
                Shader.SetGlobalVector( Uniforms._TerrainSplat_ST[i], GetSplatTextureScaleOffset(i) );
                Shader.SetGlobalTexture( Uniforms._TerrainNormal[i], _cachedTerrain.terrainData.terrainLayers[i].normalMapTexture );
                Shader.SetGlobalFloat( Uniforms._TerrainNormalScale[i], _cachedTerrain.terrainData.terrainLayers[i].normalScale );
                Shader.SetGlobalFloat( Uniforms._TerrainMetallic[i], _cachedTerrain.terrainData.terrainLayers[i].metallic );
                Shader.SetGlobalFloat(Uniforms._TerrainSmoothness[i], _cachedTerrain.terrainData.terrainLayers[i].smoothness);
            }

            Shader.SetGlobalTexture( Uniforms._TerrainControl, _cachedTerrain.terrainData.alphamapTextures[0] );
            
            if (LightmapSettings.lightmaps.Length > 0)
            {
                Shader.SetGlobalVector( Uniforms._TerrainLightmap_ST, _cachedTerrain.lightmapScaleOffset );
                Shader.SetGlobalTexture( Uniforms._TerrainLightmap, LightmapSettings.lightmaps[_cachedTerrain.lightmapIndex].lightmapColor );
            }
            else
            {
                Shader.SetGlobalVector( Uniforms._TerrainLightmap_ST, new Vector4(1,1,0,0) );
                Shader.SetGlobalTexture( Uniforms._TerrainLightmap, Texture2D.whiteTexture );
            }
        }
    }
}
