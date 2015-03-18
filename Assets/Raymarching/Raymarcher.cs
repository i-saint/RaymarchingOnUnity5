using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;
#if UNITY_EDITOR
using UnityEditor;
#endif // UNITY_EDITOR

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class Raymarcher : MonoBehaviour
{
    public Shader m_shader;
    public int m_scene;
    public Color m_fog_color = new Color(0.16f, 0.13f, 0.20f);
    Mesh m_mesh;

    Material m_material;
    Camera m_camera;
    CommandBuffer m_cb;

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

    void OnPreRender()
    {
        if (m_material == null)
        {
            m_material = new Material(m_shader);
        }
        if(m_mesh==null )
        {
            Vector3[] vertices = new Vector3[4] {
                new Vector3( 1.0f, 1.0f, 0.0f),
                new Vector3(-1.0f, 1.0f, 0.0f),
                new Vector3(-1.0f,-1.0f, 0.0f),
                new Vector3( 1.0f,-1.0f, 0.0f),
            };
            int[] indices = new int[6] {0,1,2, 2,3,0};

            m_mesh = new Mesh();
            m_mesh.vertices = vertices;
            m_mesh.triangles = indices;
        }
        if (m_cb==null)
        {
            m_cb = new CommandBuffer();
            m_cb.name = "Raymarcher";

            m_cb.DrawMesh(m_mesh, Matrix4x4.identity, m_material, 0, 1);
            m_camera.AddCommandBuffer(CameraEvent.AfterGBuffer, m_cb);

            //m_cb.DrawMesh(m_mesh, Matrix4x4.identity, m_material, 0, 0);
            //m_camera.AddCommandBuffer(CameraEvent.AfterFinalPass, m_cb);
        }

        RenderSettings.fogColor = m_fog_color;
        m_material.SetInt("g_scene", m_scene);
    }
}
