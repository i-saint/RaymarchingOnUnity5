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
    public bool m_dbg_show_steps;
    public int m_scene;
    public Color m_fog_color = new Color(0.16f, 0.13f, 0.20f);
    public RenderTexture m_rt;
    Mesh m_quad;
    Mesh m_detailed_quad;

    Camera m_camera;
    CommandBuffer m_cb_prepass;
    CommandBuffer m_cb_raymarch;
    CommandBuffer m_cb_show_steps;

    bool m_enable_adaptive_prev;
    bool m_dbg_show_steps_prev;

    void Awake()
    {
        m_camera = GetComponent<Camera>();
        //m_rt = new RenderTexture(m_camera.pixelWidth / 2, m_camera.pixelHeight / 2, 32, RenderTextureFormat.ARGBHalf);
        //m_rt.filterMode = FilterMode.Trilinear;
        //m_rt.Create();
        //m_camera.targetTexture = m_rt;

        m_enable_adaptive_prev = m_enable_adaptive;
    }

    void ClearCommandBuffer()
    {
        if (m_camera != null)
        {
            if (m_cb_prepass != null)
            {
                m_camera.RemoveCommandBuffer(CameraEvent.BeforeGBuffer, m_cb_prepass);
            }
            if (m_cb_raymarch != null)
            {
                m_camera.RemoveCommandBuffer(CameraEvent.AfterGBuffer, m_cb_raymarch);
            }
            if (m_cb_show_steps != null)
            {
                m_camera.RemoveCommandBuffer(CameraEvent.AfterEverything, m_cb_show_steps);
            }
            m_cb_prepass = null;
            m_cb_raymarch = null;
            m_cb_show_steps = null;
        }
    }

    void OnDisable()
    {
        ClearCommandBuffer();
    }

    void OnPreRender()
    {
        m_material.SetInt("g_frame", Time.frameCount);
        m_material.SetInt("g_hdr", m_camera.hdr ? 1 : 0);
        m_material.SetInt("g_scene", m_scene);
        m_material.SetInt("g_enable_adaptive", m_enable_adaptive ? 1 : 0);
        m_material.SetInt("g_dbg_show_steps", m_dbg_show_steps ? 1 : 0);

        RenderSettings.fogColor = m_fog_color;

        if (m_quad == null)
        {
            m_quad = RaymarcherUtils.GenerateQuad();
        }
        if (m_detailed_quad == null)
        {
            m_detailed_quad = RaymarcherUtils.GenerateDetailedQuad();
        }

        bool need_to_reflesh_command_buffer = false;
        if (m_enable_adaptive_prev != m_enable_adaptive)
        {
            m_enable_adaptive_prev = m_enable_adaptive;
            need_to_reflesh_command_buffer = true;
        }
        if (m_dbg_show_steps_prev != m_dbg_show_steps)
        {
            m_dbg_show_steps_prev = m_dbg_show_steps;
            need_to_reflesh_command_buffer = true;
        }

        if (need_to_reflesh_command_buffer)
        {
            need_to_reflesh_command_buffer = false;
            ClearCommandBuffer();
        }

        if (m_cb_raymarch==null)
        {
            if (m_enable_adaptive)
            {
                m_cb_prepass = new CommandBuffer();
                m_cb_prepass.name = "Raymarcher Adaptive PrePass";

                int qdepth = Shader.PropertyToID("QuarterDepth");
                int hdepth = Shader.PropertyToID("HalfDepth");
                int adepth = Shader.PropertyToID("ActualDepth");
                int pdepth = Shader.PropertyToID("PrevDepth");
                m_cb_prepass.GetTemporaryRT(qdepth, m_camera.pixelWidth / 4, m_camera.pixelHeight / 4, 0, FilterMode.Point, RenderTextureFormat.RFloat);
                m_cb_prepass.GetTemporaryRT(hdepth, m_camera.pixelWidth / 2, m_camera.pixelHeight / 2, 0, FilterMode.Point, RenderTextureFormat.RFloat);
                m_cb_prepass.GetTemporaryRT(adepth, m_camera.pixelWidth / 1, m_camera.pixelHeight / 1, 0, FilterMode.Point, RenderTextureFormat.RFloat);
                m_cb_prepass.GetTemporaryRT(pdepth, m_camera.pixelWidth / 1, m_camera.pixelHeight / 1, 0, FilterMode.Point, RenderTextureFormat.RFloat);

                if (m_dbg_show_steps)
                {
                    int qsteps = Shader.PropertyToID("QuarterSteps");
                    int hsteps = Shader.PropertyToID("HalfSteps");
                    int asteps = Shader.PropertyToID("ActualSteps");
                    m_cb_prepass.GetTemporaryRT(qsteps, m_camera.pixelWidth / 4, m_camera.pixelHeight / 4, 0, FilterMode.Point, RenderTextureFormat.R8);
                    m_cb_prepass.GetTemporaryRT(hsteps, m_camera.pixelWidth / 2, m_camera.pixelHeight / 2, 0, FilterMode.Point, RenderTextureFormat.R8);
                    m_cb_prepass.GetTemporaryRT(asteps, m_camera.pixelWidth / 1, m_camera.pixelHeight / 1, 0, FilterMode.Point, RenderTextureFormat.R8);

                    var rt = new RenderTargetIdentifier[2] { qdepth, qsteps };
                    m_cb_prepass.SetRenderTarget(rt, qdepth);
                    m_cb_prepass.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 1);

                    rt = new RenderTargetIdentifier[2] { hdepth, hsteps };
                    m_cb_prepass.SetRenderTarget(rt, hdepth);
                    m_cb_prepass.SetGlobalTexture("g_depth", qdepth);
                    m_cb_prepass.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 2);

                    rt = new RenderTargetIdentifier[2] { adepth, asteps };
                    m_cb_prepass.SetRenderTarget(rt, adepth);
                    m_cb_prepass.SetGlobalTexture("g_depth", hdepth);
                    m_cb_prepass.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 3);

                    m_cb_prepass.SetGlobalTexture("g_qsteps", qsteps);
                    m_cb_prepass.SetGlobalTexture("g_hsteps", hsteps);
                    m_cb_prepass.SetGlobalTexture("g_asteps", asteps);

                    m_cb_show_steps = new CommandBuffer();
                    m_cb_show_steps.name = "Raymarcher Steps";
                    m_cb_show_steps.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 4);
                    m_camera.AddCommandBuffer(CameraEvent.AfterEverything, m_cb_show_steps);
                }
                else
                {
                    m_cb_prepass.SetRenderTarget(qdepth);
                    m_cb_prepass.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 1);

                    m_cb_prepass.SetRenderTarget(hdepth);
                    m_cb_prepass.SetGlobalTexture("g_depth", qdepth);
                    m_cb_prepass.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 2);

                    m_cb_prepass.SetRenderTarget(adepth);
                    m_cb_prepass.SetGlobalTexture("g_depth", hdepth);
                    m_cb_prepass.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 3);
                }
                m_cb_prepass.Blit(adepth, pdepth);
                m_cb_prepass.SetGlobalTexture("g_depth_prev", pdepth);
                m_cb_prepass.SetGlobalTexture("g_depth", adepth);

                m_camera.AddCommandBuffer(CameraEvent.BeforeGBuffer, m_cb_prepass);
            }

            m_cb_raymarch = new CommandBuffer();
            m_cb_raymarch.name = "Raymarcher";
            m_cb_raymarch.DrawMesh(m_quad, Matrix4x4.identity, m_material, 0, 0);
            m_camera.AddCommandBuffer(CameraEvent.AfterGBuffer, m_cb_raymarch);
        }
    }
}
