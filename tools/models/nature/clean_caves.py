"""Cleans baked cave meshes in Blender: the CSG union leaves about a third of
a cave's triangles as slivers, tiny scraps and needle-thin strips where its
hollows cut through each other. This welds near points, dissolves what's
degenerate, collapses edges shorter than MIN_EDGE, smooths the surface a
touch (flattening the noise a little) and flips edges into better-shaped
triangles, keeping the cave sealed.

Run by tools/models/nature/bake_caves.gd for each cave (it writes the raw
mesh as OBJ and reads the cleaned one back):

    blender --background --factory-startup --python clean_caves.py -- <in.obj> <out.obj>

Several pairs may follow the "--" to clean many in one run. Prints the
mesh's triangles and slivers before and after.
"""

import math
import sys

import bmesh
import bpy

# Points nearer than this are one point.
WELD = 0.05
# Edges shorter than this are collapsed.
MIN_EDGE = 0.45
# How much each pass of smoothing pulls a point toward its neighbours, and how
# many passes.
SMOOTH = 0.35
SMOOTH_PASSES = 2
# Triangles with an angle under this (degrees) count as slivers.
SLIVER = 8.0


def read_obj(path: str):
    verts, faces = [], []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("v "):
                verts.append(tuple(float(x) for x in line.split()[1:4]))
            elif line.startswith("f "):
                faces.append(tuple(int(x.split("/")[0]) - 1 for x in line.split()[1:]))
    return verts, faces


def edge_key(e) -> tuple:
    """An edge by where its ends are, so it's found again in a copy."""
    return tuple(sorted(tuple(round(c, 4) for c in v.co) for v in e.verts))


def unsealed(bm) -> int:
    """Edges not between exactly two faces."""
    return sum(1 for e in bm.edges if len(e.link_faces) != 2)


def collapse_safely(bm, keys: list, kept: set):
    """Collapses the edges with these keys, unless that leaves more of the
    cave unsealed than before: then undone and tried in halves, and an edge
    that fails alone is kept (added to `kept`). Returns the mesh."""
    if not keys:
        return bm
    before = unsealed(bm)
    trial = bm.copy()
    lookup = {edge_key(e): e for e in trial.edges}
    edges = [lookup[k] for k in keys if k in lookup]
    if edges:
        bmesh.ops.collapse(trial, edges=edges, uvs=False)
        bmesh.ops.dissolve_degenerate(trial, dist=WELD, edges=trial.edges)
    if unsealed(trial) <= before:
        bm.free()
        return trial
    trial.free()
    if len(keys) == 1:
        kept.add(keys[0])
        return bm
    half = len(keys) // 2
    bm = collapse_safely(bm, keys[:half], kept)
    return collapse_safely(bm, keys[half:], kept)


def slivers(bm) -> int:
    count = 0
    for f in bm.faces:
        vs = [v.co for v in f.verts]
        for i in range(3):
            u, w = vs[(i + 1) % 3] - vs[i], vs[(i + 2) % 3] - vs[i]
            if u.length < 1e-6 or w.length < 1e-6 or math.degrees(u.angle(w)) < SLIVER:
                count += 1
                break
    return count


def clean(src: str, dst: str) -> None:
    verts, faces = read_obj(src)
    mesh = bpy.data.meshes.new("cave")
    mesh.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    before = (len(bm.faces), slivers(bm))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
    bmesh.ops.dissolve_degenerate(bm, dist=WELD, edges=bm.edges)
    # Short edges collapsed, a group at a time (each collapse changes its
    # neighbours), until none are left. A group that would leave the cave
    # unsealed (pinching a thin pillar shut) is undone and tried in halves;
    # an edge that can't go alone is kept.
    kept = set()
    for _ in range(30):
        short = [e for e in bm.edges if e.is_valid and e.calc_length() < MIN_EDGE and edge_key(e) not in kept]
        if not short:
            break
        taken = set()
        batch = []
        for e in short:
            a, b = e.verts
            if a in taken or b in taken:
                continue
            taken.update((a, b))
            batch.append(edge_key(e))
        bm = collapse_safely(bm, batch, kept)
    # The finishing steps, each undone if it would unseal anything.
    def tidy(m):
        bmesh.ops.dissolve_degenerate(m, dist=WELD, edges=m.edges)
        bmesh.ops.triangulate(m, faces=m.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")

    def smooth(m):
        for _ in range(SMOOTH_PASSES):
            bmesh.ops.smooth_vert(m, verts=m.verts, factor=SMOOTH, use_axis_x=True, use_axis_y=True, use_axis_z=True)

    def beautify(m):
        # Edges flipped toward rounder triangles.
        bmesh.ops.beautify_fill(m, faces=m.faces[:], edges=m.edges[:], method="ANGLE")

    for step in (tidy, smooth, beautify):
        trial = bm.copy()
        step(trial)
        if unsealed(trial) <= unsealed(bm):
            bm.free()
            bm = trial
        else:
            trial.free()
            print(f"  {step.__name__} skipped: it would unseal the cave")
    after = (len(bm.faces), slivers(bm))
    open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    bm.verts.index_update()
    with open(dst, "w", encoding="utf-8") as f:
        for v in bm.verts:
            f.write(f"v {v.co.x:.5f} {v.co.y:.5f} {v.co.z:.5f}\n")
        for face in bm.faces:
            f.write("f " + " ".join(str(v.index + 1) for v in face.verts) + "\n")
    bm.free()
    bpy.data.meshes.remove(mesh)
    print(f"CLEANED {src}: {before[0]} tris, {before[1]} slivers -> {after[0]} tris, {after[1]} slivers, {open_edges} unsealed edges")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    for i in range(0, len(args) - 1, 2):
        clean(args[i], args[i + 1])


main()
