using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
#if UNITY_EDITOR
using UnityEditor;
#endif // UNITY_EDITOR


public static class RaymarcherUtils
{
    public static Mesh GenerateQuad()
    {
        Vector3[] vertices = new Vector3[4] {
                new Vector3( 1.0f, 1.0f, 0.0f),
                new Vector3(-1.0f, 1.0f, 0.0f),
                new Vector3(-1.0f,-1.0f, 0.0f),
                new Vector3( 1.0f,-1.0f, 0.0f),
            };
        int[] indices = new int[6] { 0, 1, 2, 2, 3, 0 };

        Mesh r = new Mesh();
        r.vertices = vertices;
        r.triangles = indices;
        return r;
    }

    public static Mesh GenerateDetailedQuad()
    {
        const int div_x = 325;
        const int div_y = 200;

        var cell = new Vector2(2.0f / div_x, 2.0f / div_y);
        var vertices = new Vector3[65000];
        var indices = new int[(div_x-1)*(div_y-1)*6];
        for (int iy = 0; iy < div_y; ++iy)
        {
            for (int ix = 0; ix < div_x; ++ix)
            {
                int i = div_x * iy + ix;
                vertices[i] = new Vector3(cell.x * ix - 1.0f, cell.y * iy - 1.0f, 0.0f);
            }
        }
        for (int iy = 0; iy < div_y-1; ++iy)
        {
            for (int ix = 0; ix < div_x-1; ++ix)
            {
                int i = ((div_x-1) * iy + ix)*6;
                indices[i + 0] = (div_x * (iy + 1)) + (ix + 1);
                indices[i + 1] = (div_x * (iy + 0)) + (ix + 1);
                indices[i + 2] = (div_x * (iy + 0)) + (ix + 0);

                indices[i + 3] = (div_x * (iy + 0)) + (ix + 0);
                indices[i + 4] = (div_x * (iy + 1)) + (ix + 0);
                indices[i + 5] = (div_x * (iy + 1)) + (ix + 1);
            }
        }

        Mesh r = new Mesh();
        r.vertices = vertices;
        r.triangles = indices;
        return r;
    }
}

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class Raymarcher : MonoBehaviour
{
    public Material m_material;
    public bool m_enable_adaptive;
    public int m_scene;
    public Color m_fog_color = new Color(0.16f, 0.13f, 0.20f);
    Mesh m_quad;
    Mesh m_detailed_quad;

    Camera m_camera;
    CommandBuffer m_cb_prepass;
    CommandBuffer m_cb;
    bool m_clear_commandbuffer;

    void Awake()
    {
        m_camera = GetComponent<Camera>();
    }

    void OnGUI()
    {
        if (GUI.Button(new Rect(10, 10, 120, 20), "next scene"))
        {
            m_scene = (m_scene + 1) % 3;
        }
    }

#if UNITY_EDITOR
    void OnValidate()
    {
        m_clear_commandbuffer = true;
    }
#endif // UNITY_EDITOR

    void OnPreRender()
    {
        Shader.SetGlobalFloat("g_frame", Time.frameCount);
        Shader.SetGlobalInt("g_hdr", m_camera.hdr ? 1 : 0);
        Shader.SetGlobalInt("g_enable_adaptive", m_enable_adaptive ? 1 : 0);

        if (m_quad == null)
        {
            m_quad = RaymarcherUtils.GenerateQuad();
        }
        if (m_detailed_quad == null)
        {
            m_detailed_quad = RaymarcherUtils.GenerateDetailedQuad();
        }

        if (m_clear_commandbuffer)
        {
            m_clear_commandbuffer = false;
            if (m_camera != null)
            {
                if (m_cb_prepass != null)
                {
                    m_camera.RemoveCommandBuffer(CameraEvent.BeforeGBuffer, m_cb_prepass);
                }
                if (m_cb != null)
                {
                    m_camera.RemoveCommandBuffer(CameraEvent.AfterGBuffer, m_cb);
                }
                m_cb = null;
            }
        }

        if (m_cb==null)
        {
            if (m_enable_adaptive)
            {
                m_cb_prepass = new CommandBuffer();
                m_cb_prepass.name = "Raymarcher Adaptive PrePass";

                int qdepth = Shader.PropertyToID("QuarterDepth");
                int hdepth = Shader.PropertyToID("HalfDepth");
                m_cb_prepass.GetTemporaryRT(qdepth, m_camera.pixelWidth / 4, m_camera.pixelHeight / 4, 0, FilterMode.Point, RenderTextureFormat.RFloat);
                m_cb_prepass.GetTemporaryRT(hdepth, m_camera.pixelWidth / 2, m_camera.pixelHeight / 2, 0, FilterMode.Point, RenderTextureFormat.RFloat);

                m_cb_prepass.SetRenderTarget(qdepth);
                m_cb_prepass.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 1);

                m_cb_prepass.SetRenderTarget(hdepth);
                m_cb_prepass.SetGlobalTexture("g_depth", qdepth);
                m_cb_prepass.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 2);

                m_cb_prepass.SetGlobalTexture("g_depth", hdepth);

                m_cb_prepass.ReleaseTemporaryRT(qdepth);
                m_cb_prepass.ReleaseTemporaryRT(hdepth);
                m_camera.AddCommandBuffer(CameraEvent.BeforeGBuffer, m_cb_prepass);
            }

            m_cb = new CommandBuffer();
            m_cb.name = "Raymarcher";
            m_cb.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 0);
            m_camera.AddCommandBuffer(CameraEvent.AfterGBuffer, m_cb);
        }

        RenderSettings.fogColor = m_fog_color;
        m_material.SetInt("g_scene", m_scene);
    }
}
