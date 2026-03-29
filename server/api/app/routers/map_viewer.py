import io
import os
import struct
from pathlib import Path

import numpy as np
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import HTMLResponse, StreamingResponse

router = APIRouter()

MAPS_DIR = os.getenv("MAPS_DIR", "/workspace/maps")


def _load_pointcloud(map_id: str, sample: int = 0):
    """pointcloud.npz 로드 + 샘플링. sample=0이면 전부."""
    pc_path = Path(MAPS_DIR) / map_id / "pointcloud.npz"
    if not pc_path.exists():
        return None, None

    data = np.load(str(pc_path), allow_pickle=True)
    pts = data.get("points")
    colors = data.get("colors")

    if pts is None or len(pts) == 0:
        return None, None

    if sample > 0 and len(pts) > sample:
        idx = np.random.choice(len(pts), sample, replace=False)
        pts = pts[idx]
        colors = colors[idx] if colors is not None else None

    return pts, colors


def _ply_stream(pts: np.ndarray, colors: np.ndarray | None):
    """PLY 바이너리 스트리밍 생성기"""
    n = len(pts)
    has_color = colors is not None and len(colors) == n

    header = "ply\nformat binary_little_endian 1.0\n"
    header += f"element vertex {n}\n"
    header += "property float x\nproperty float y\nproperty float z\n"
    if has_color:
        header += "property uchar red\nproperty uchar green\nproperty uchar blue\n"
    header += "end_header\n"
    yield header.encode("ascii")

    col_u8 = None
    if has_color:
        if colors.dtype in (np.float32, np.float64):
            col_u8 = (np.clip(colors, 0, 1) * 255).astype(np.uint8)
        else:
            col_u8 = colors.astype(np.uint8)

    # 청크 단위로 스트리밍 (10000포인트씩)
    chunk = 10000
    for start in range(0, n, chunk):
        end = min(start + chunk, n)
        buf = io.BytesIO()
        for i in range(start, end):
            buf.write(struct.pack("<fff", pts[i, 0], pts[i, 1], pts[i, 2]))
            if col_u8 is not None:
                buf.write(struct.pack("<BBB", col_u8[i, 0], col_u8[i, 1], col_u8[i, 2]))
        yield buf.getvalue()


@router.get("/maps/{map_id}/pointcloud.ply")
async def export_ply(
    map_id: str,
    sample: int = Query(0, description="샘플링 포인트 수. 0이면 전부."),
):
    """PLY 파일 스트리밍 다운로드"""
    pts, colors = _load_pointcloud(map_id, sample)
    if pts is None:
        raise HTTPException(404, f"Point cloud not found: {map_id}")

    return StreamingResponse(
        _ply_stream(pts, colors),
        media_type="application/octet-stream",
        headers={"Content-Disposition": f"attachment; filename={map_id}.ply"},
    )


@router.get("/maps/{map_id}/viewer", response_class=HTMLResponse)
async def viewer(
    map_id: str,
    sample: int = Query(0, description="샘플링 포인트 수. 0이면 브라우저 한계에 맞춰 자동 조정."),
):
    """브라우저 3D 포인트 클라우드 뷰어"""
    pc_path = Path(MAPS_DIR) / map_id / "pointcloud.npz"
    poses_path = Path(MAPS_DIR) / map_id / "all_poses.npz"

    if not pc_path.exists():
        raise HTTPException(404, f"Point cloud not found: {map_id}")

    # 총 포인트 수 확인
    data = np.load(str(pc_path), allow_pickle=True)
    total_points = len(data["points"]) if "points" in data else 0

    # 브라우저 WebGL 한계: ~10M 포인트
    browser_limit = 10_000_000
    if sample == 0:
        effective_sample = min(total_points, browser_limit)
    else:
        effective_sample = sample

    ply_url = f"/api/slam/maps/{map_id}/pointcloud.ply?sample={effective_sample}"
    full_ply_url = f"/api/slam/maps/{map_id}/pointcloud.ply?sample=0"

    html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Map Viewer - {map_id[:8]}</title>
<style>body{{margin:0;overflow:hidden}}canvas{{display:block}}#info{{position:absolute;top:10px;left:10px;color:#fff;font:14px monospace;background:rgba(0,0,0,0.7);padding:8px 12px;border-radius:6px;max-width:400px}}#info a{{color:#4fc3f7;text-decoration:none}}#info a:hover{{text-decoration:underline}}</style>
</head>
<body>
<div id="info">Loading...</div>
<script type="importmap">
{{
  "imports": {{
    "three": "https://cdn.jsdelivr.net/npm/three@0.174.0/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.174.0/examples/jsm/"
  }}
}}
</script>
<script type="module">
import * as THREE from 'three';
import {{ OrbitControls }} from 'three/addons/controls/OrbitControls.js';
import {{ PLYLoader }} from 'three/addons/loaders/PLYLoader.js';

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x111111);

const camera = new THREE.PerspectiveCamera(60, window.innerWidth/window.innerHeight, 0.01, 1000);
camera.position.set(5, 5, 5);

const renderer = new THREE.WebGLRenderer({{antialias:true}});
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;

// 그리드
const grid = new THREE.GridHelper(20, 40, 0x444444, 0x222222);
scene.add(grid);

// 축
scene.add(new THREE.AxesHelper(2));

// PLY 로드
const info = document.getElementById('info');
const loader = new PLYLoader();
loader.load('{ply_url}', (geometry) => {{
  geometry.computeVertexNormals();
  const hasColor = geometry.hasAttribute('color');
  const material = new THREE.PointsMaterial({{
    size: 0.02,
    vertexColors: hasColor,
    color: hasColor ? undefined : 0x00ff00,
  }});
  const points = new THREE.Points(geometry, material);
  scene.add(points);

  // 카메라를 포인트 클라우드 중심으로
  geometry.computeBoundingBox();
  const center = new THREE.Vector3();
  geometry.boundingBox.getCenter(center);
  controls.target.copy(center);
  camera.position.set(center.x+5, center.y+5, center.z+5);
  controls.update();

  const n = geometry.attributes.position.count;
  const total = {total_points};
  const sampled = total > n;
  info.innerHTML = n.toLocaleString() + ' / ' + total.toLocaleString() + ' points | {map_id[:8]}'
    + (sampled ? '<br>Sampled for browser rendering' : '')
    + '<br><a href="{full_ply_url}">Download full PLY (' + (total/1e6).toFixed(1) + 'M pts)</a>';
}}, (xhr) => {{
  info.textContent = 'Loading... ' + Math.round(xhr.loaded/1024/1024) + ' MB';
}}, (err) => {{
  info.textContent = 'Error: ' + err.message;
}});

window.addEventListener('resize', () => {{
  camera.aspect = window.innerWidth/window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}});

function animate() {{
  requestAnimationFrame(animate);
  controls.update();
  renderer.render(scene, camera);
}}
animate();
</script>
</body>
</html>"""
    return HTMLResponse(content=html)
