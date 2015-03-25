using UnityEngine;
using System.Collections;

[RequireComponent(typeof(Camera))]
public class ResolutionScaler : MonoBehaviour
{
    public Camera m_maincamera;
    public Vector2 m_resolution_scale = new Vector2(0.5f, 0.5f);
    public Material m_material;
    public RenderTexture m_rt;
    Mesh m_quad;
    Vector2 m_resolution_scale_prev;

    void OnDisable()
    {
        if (m_rt != null)
        {
            m_rt.Release();
            m_rt = null;
            if (m_maincamera != null)
            {
                m_maincamera.targetTexture = null;
            }
        }
    }

    void Update()
    {
        if (m_maincamera == null) return;

        Camera cam = GetComponent<Camera>();
        if(m_rt==null || m_resolution_scale!=m_resolution_scale_prev)
        {
            if (m_resolution_scale.x == 0.0f || m_resolution_scale.y==0.0f)
            {
                return;
            }

            m_resolution_scale_prev = m_resolution_scale;
            if(m_rt!=null)
            {
                m_rt.Release();
                m_rt = null;
            }
            m_rt = new RenderTexture(
                (int)(cam.pixelWidth * m_resolution_scale.x),
                (int)(cam.pixelHeight * m_resolution_scale.y),
                32,
                m_maincamera.hdr ? RenderTextureFormat.ARGBHalf : RenderTextureFormat.ARGB32);
            m_rt.filterMode = FilterMode.Trilinear;
            m_rt.Create();
            m_maincamera.targetTexture = m_rt;
            Debug.Log("resolution changed: " + m_rt.width + ", " + m_rt.height);
        }
    }

    void OnPostRender()
    {
        if (m_quad == null)
        {
            m_quad = RaymarcherUtils.GenerateQuad();
        }
        m_material.SetPass(0);
        m_material.mainTexture = m_rt;
        Graphics.DrawMeshNow(m_quad, Matrix4x4.identity);
    }

}
