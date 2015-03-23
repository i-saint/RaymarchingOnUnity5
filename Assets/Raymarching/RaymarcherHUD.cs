using UnityEngine;
using System.Collections;

[RequireComponent(typeof(Raymarcher))]
[ExecuteInEditMode]
public class RaymarcherHUD : MonoBehaviour
{
    public bool m_show_hud;


    void Update()
    {
        if(Input.GetKeyDown(KeyCode.Tab))
        {
            m_show_hud = !m_show_hud;
        }
    }

    void OnGUI()
    {
        if (!m_show_hud) return;

        Raymarcher rm = GetComponent<Raymarcher>();

        rm.enabled = GUI.Toggle(new Rect(20, 20, 200, 20), rm.enabled, "enable raymarcher");
        rm.m_enable_adaptive = GUI.Toggle(new Rect(20, 50, 200, 20), rm.m_enable_adaptive, "enable adaptive raymarching");
        rm.m_dbg_show_steps = GUI.Toggle(new Rect(20, 80, 200, 20), rm.m_dbg_show_steps, "show march steps");

        if (GUI.Button(new Rect(30, 110, 120, 20), "next scene"))
        {
            rm.m_scene = (rm.m_scene + 1) % 3;
        }

        GUI.Label(new Rect(20, 140, 120, 20), "tab: show / hide UI");
    }
}
