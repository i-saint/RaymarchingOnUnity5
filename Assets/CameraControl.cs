using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Threading;

[ExecuteInEditMode]
public class CameraControl : MonoBehaviour
{
    public bool m_rotate_by_time = false;
    public float m_rotate_speed = -10.0f;
    public Transform m_camera;
    public Transform m_look_target;


    void Awake()
    {
    }

    void Update()
    {
        if (m_camera == null || m_look_target == null) return;

        if (Input.GetKeyUp(KeyCode.R)) { m_rotate_by_time = !m_rotate_by_time; }

        Vector3 pos = m_camera.position - m_look_target.position;
        if (m_rotate_by_time)
        {
            pos = Quaternion.Euler(0.0f, Time.deltaTime * m_rotate_speed, 0) * pos;
        }
        if (Input.GetMouseButton(0))
        {
            float ry = Input.GetAxis("Mouse X") * 3.0f;
            float rxz = Input.GetAxis("Mouse Y") * 0.25f;
            pos = Quaternion.Euler(0.0f, ry, 0) * pos;
            pos.y += rxz;
        }
        {
            float wheel = Input.GetAxis("Mouse ScrollWheel");
            pos += pos.normalized * wheel * 4.0f;
        }
        m_camera.position = pos + m_look_target.position;
        m_camera.transform.LookAt(m_look_target.position);
    }
}
