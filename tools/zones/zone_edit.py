"""Edit a zone of the game in Blender, saved as layers over what its code builds.

Opened by the game's `editzone` command (the Developer tab's "Edit Zone in
Blender"), which exports the zone you're in to build/zone_edit/<zone>/ and
runs:

    blender --python tools/zones/zone_edit.py -- <that folder>

The scene holds, in the game's world yards (Blender's Z is the game's up):
  - Ground: the zone's ground grid with its current edits. Move its vertices
    (sculpt, grab, proportional editing...) but don't add or delete any: it
    stays a grid. The vertex group "Locked" is the zone's border, which stays
    as built so neighbouring zones still meet; edits there are dropped.
  - Cave objects (one per cave): its tunnels, chambers, mouth and rim, with
    their current edits. Move vertices freely; new vertices aren't kept (use
    Additions for new rock).
  - Additions: mesh objects put in this collection are added to the world,
    drawn as rock, or as the ground's surface if their material's name has
    "ground" in it.
  - Cuts: closed mesh objects put in this collection cut the ground away
    inside them.
  - Mouth rocks: the rocks round each cave's mouth, an object each with its
    origin at its middle. Move, rotate, scale or delete them; a copy
    (Shift+D) is kept as an added rock.

Edits save themselves a couple of seconds after each change (and on
Ctrl+S); "Save Edits" in the sidebar (N, the AI RPG tab) saves at once. It
writes the edit layers to data/zone_edits/<zone>/ (heights, caves, additions, cuts); Reload
Game in the game to see them. Only the differences from the code's zone are
saved, so the zone's code can change and the edits still lie over it.
"""

from __future__ import annotations

import json
import os
import sys
import time
from array import array

import bmesh
import bpy
from mathutils import Matrix, Vector

STATE: dict = {}


def to_blender(x: float, y: float, z: float) -> Vector:
    """A point in the game's yards (Y up) in Blender's (Z up)."""
    return Vector((x, -z, y))


def to_game(v: Vector) -> tuple:
    return (v.x, v.z, -v.y)


def read_floats(path: str) -> array:
    data = array("f")
    with open(path, "rb") as f:
        data.frombytes(f.read())
    return data


def read_json(path: str):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def spot_key(local, places: int) -> str:
    return ",".join(f"{v:.{places}f}" for v in local)


def load(folder: str) -> None:
    meta = read_json(os.path.join(folder, "zone.json"))
    STATE.update(folder=folder, meta=meta)
    edits = meta["edits"]
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene = bpy.context.scene
    scene.name = meta["zone"]

    # The ground: the code's heights plus the saved height edits.
    columns, rows, step = meta["columns"], meta["rows"], meta["step"]
    ox, oz = meta["origin"]
    base = read_floats(os.path.join(folder, "base_heights.bin"))
    STATE["base"] = base
    delta = [0.0] * (columns * rows)
    saved = read_json(os.path.join(edits, "heights.json"))
    if saved and saved["columns"] == columns and saved["rows"] == rows and os.path.exists(os.path.join(edits, "heights.bin")):
        delta = list(read_floats(os.path.join(edits, "heights.bin")))
    points = []
    for r in range(rows):
        for c in range(columns):
            i = r * columns + c
            points.append(to_blender(ox + c * step, base[i] + delta[i], oz + r * step))
    faces = []
    for r in range(rows - 1):
        for c in range(columns - 1):
            i = r * columns + c
            faces.append((i, i + columns, i + columns + 1, i + 1))
    mesh = bpy.data.meshes.new("Ground")
    mesh.from_pydata(points, [], faces)
    index = mesh.attributes.new("grid_index", "INT", "POINT")
    index.data.foreach_set("value", list(range(columns * rows)))
    ground = bpy.data.objects.new("Ground", mesh)
    scene.collection.objects.link(ground)
    locked = ground.vertex_groups.new(name="Locked")
    border = [r * columns + c for r in range(rows) for c in range(columns)
              if r in (0, rows - 1) or c in (0, columns - 1)]
    locked.add(border, 1.0, "REPLACE")
    ground.data.materials.append(material("Ground", (0.35, 0.5, 0.25, 1.0)))

    # The caves, with their saved vertex edits.
    places = meta.get("key_places", 2)
    offsets = read_json(os.path.join(edits, "caves.json")) or {}
    caves = bpy.data.collections.new("Caves")
    scene.collection.children.link(caves)
    for cave in meta["caves"]:
        t = cave["to_world"]
        to_world = Matrix(((t[0], t[3], t[6], t[9]), (t[1], t[4], t[7], t[10]), (t[2], t[5], t[8], t[11]), (0, 0, 0, 1)))
        local = read_floats(os.path.join(folder, cave["file"]))
        moved = offsets.get(cave["key"], {})
        index_of = {}
        verts = []
        bases = []
        tris = []
        for k in range(0, len(local), 9):
            tri = []
            for j in range(3):
                p = local[k + j * 3:k + j * 3 + 3]
                key = spot_key(p, places)
                if key not in index_of:
                    index_of[key] = len(verts)
                    shift = moved.get(key, [0.0, 0.0, 0.0])
                    world = to_world @ Vector((p[0] + shift[0], p[1] + shift[1], p[2] + shift[2]))
                    verts.append(to_blender(*world))
                    bases.extend((p[0], p[1], p[2]))
                tri.append(index_of[key])
            if len(set(tri)) == 3:
                tris.append(tuple(tri))
        cave_mesh = bpy.data.meshes.new(cave["key"])
        cave_mesh.from_pydata(verts, [], list(dict.fromkeys(tris)))
        attr = cave_mesh.attributes.new("base_local", "FLOAT_VECTOR", "POINT")
        attr.data.foreach_set("vector", bases)
        obj = bpy.data.objects.new("Cave " + cave["key"], cave_mesh)
        obj["cave_key"] = cave["key"]
        obj["to_world"] = t
        obj.data.materials.append(material("Cave rock", (0.45, 0.43, 0.42, 1.0)))
        caves.objects.link(obj)

    # The added pieces and the cuts.
    for name, color in (("Additions", (0.55, 0.5, 0.45, 1.0)), ("Cuts", (0.9, 0.2, 0.2, 0.4))):
        coll = bpy.data.collections.new(name)
        scene.collection.children.link(coll)
        saved = read_json(os.path.join(edits, name.lower() + ".json")) or {}
        for piece in saved.get("pieces", []):
            v = piece["vertices"]
            pts = [to_blender(v[i], v[i + 1], v[i + 2]) for i in range(0, len(v), 3)]
            idx = piece["indices"]
            m = bpy.data.meshes.new(piece.get("name") or name)
            m.from_pydata(pts, [], [tuple(idx[i:i + 3]) for i in range(0, len(idx), 3)])
            m.validate()
            o = bpy.data.objects.new(piece.get("name") or name, m)
            mat_name = piece.get("material") or ("Rock" if name == "Additions" else "Cut")
            o.data.materials.append(material(mat_name, color))
            if name == "Cuts":
                o.display_type = "WIRE"
            coll.objects.link(o)

    # The rocks round the mouths: an object each, its origin at its middle,
    # placed as saved (moved, turned, scaled), or left out if deleted.
    rocks = read_json(os.path.join(folder, "rocks.json")) or []
    rock_edits = read_json(os.path.join(edits, "rocks.json")) or {}
    coll = bpy.data.collections.new("Mouth rocks")
    scene.collection.children.link(coll)
    rock_material = material("Mouth rock", (0.5, 0.48, 0.45, 1.0))
    shown = 0
    for rock in rocks:
        edit = rock_edits.get(rock["id"], {})
        if edit.get("deleted"):
            continue
        if "faces" in edit:
            # Saved as it was left: its own mesh in world yards, its origin
            # put back at its middle.
            world = edit["faces"]
            n = len(world) // 3
            mid = [sum(world[i * 3 + a] for i in range(n)) / max(n, 1) for a in range(3)]
            t = [world[i] - mid[i % 3] for i in range(len(world))]
            origin = to_blender(*mid)
            turn = Matrix.Identity(4)
        else:
            t = rock["triangles"]
            origin = None
        index_of, verts, tris = {}, [], []
        for k in range(0, len(t), 9):
            tri = []
            for j in range(3):
                p = tuple(round(x, 5) for x in t[k + j * 3:k + j * 3 + 3])
                if p not in index_of:
                    index_of[p] = len(verts)
                    verts.append(to_blender(*p))
                tri.append(index_of[p])
            if len(set(tri)) == 3:
                tris.append(tuple(tri))
        m = bpy.data.meshes.new(rock["id"])
        m.from_pydata(verts, [], tris)
        o = bpy.data.objects.new("Rock " + rock["id"], m)
        o.data.materials.append(rock_material)
        o["rock_id"] = rock["id"]
        o["center"] = rock["center"]
        o.matrix_world = Matrix.Translation(origin) if origin is not None else rock_matrix(rock["center"], edit)
        coll.objects.link(o)
        shown += 1
    print(f"Loaded {meta['zone']}: ground {columns}x{rows}, {len(meta['caves'])} caves, {shown} mouth rocks.")


# The game's axes in Blender's: (x, y, z) -> (x, -z, y).
AXES = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def rock_matrix(center, edit) -> Matrix:
    """A rock's place in Blender from its middle and its saved edit (the
    game's turn-and-scale basis about its middle, and how far it moved)."""
    b = edit.get("basis", [1, 0, 0, 0, 1, 0, 0, 0, 1])
    basis = Matrix(((b[0], b[3], b[6]), (b[1], b[4], b[7]), (b[2], b[5], b[8])))
    o = edit.get("offset", [0, 0, 0])
    linear = AXES @ basis @ AXES.inverted()
    where = to_blender(center[0] + o[0], center[1] + o[1], center[2] + o[2])
    return Matrix.Translation(where) @ linear.to_4x4()


def world_triangles(obj) -> list:
    """An object's mesh as it stands (modifiers, edits), as world-yard
    triangles in the game's axes, wound outward even if it was mirrored."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    m = evaluated.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(m)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    mirrored = obj.matrix_world.to_3x3().determinant() < 0.0
    out = []
    for f in bm.faces:
        corners = [obj.matrix_world @ v.co for v in f.verts]
        if mirrored:
            corners.reverse()
        for c in corners:
            out.extend(to_game(c))
    bm.free()
    evaluated.to_mesh_clear()
    return out


def same_points(a: list, b: list, near: float = 0.01) -> bool:
    """Whether two triangle lists have the same points, each within `near`
    yards of one of the other's (Blender keeps points a little less exactly
    than the export wrote them)."""
    pa = {tuple(a[i:i + 3]) for i in range(0, len(a), 3)}
    pb = {tuple(b[i:i + 3]) for i in range(0, len(b), 3)}
    for one, other in ((pa, pb), (pb, pa)):
        for p in one:
            if not any(abs(p[0] - q[0]) < near and abs(p[1] - q[1]) < near and abs(p[2] - q[2]) < near for q in other):
                return False
    return True


def rock_edits() -> tuple:
    """Each rock changed in any way (moved, turned, scaled, mirrored or its
    mesh reshaped) saved as its mesh as it stands, so the game shows exactly
    what's here; deleted when its object is gone; and the extra copies of
    rocks (Shift+D) as added pieces."""
    rocks = read_json(os.path.join(STATE["folder"], "rocks.json")) or []
    made = {r["id"]: r for r in rocks}
    edits = {}
    copies = []
    seen = set()
    for obj in bpy.data.objects:
        if "rock_id" not in obj.keys() or obj.type != "MESH":
            continue
        rid = obj["rock_id"]
        if rid in seen:
            # A copy: kept as an added piece, wherever it was put.
            copies.append(obj)
            continue
        seen.add(rid)
        now = world_triangles(obj)
        rock = made.get(rid)
        if rock is not None:
            c = rock["center"]
            first = [rock["triangles"][i] + c[i % 3] for i in range(len(rock["triangles"]))]
            # Its points where the code put them? (The code's flat scraps of
            # triangles are dropped on loading, so the points are compared,
            # not the triangles.)
            if same_points(first, now):
                continue
        edits[rid] = {"faces": [round(x, 5) for x in now]}
    for rock in rocks:
        if rock["id"] not in seen:
            edits[rock["id"]] = {"deleted": True}
    return edits, copies


def material(name: str, color) -> bpy.types.Material:
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def mesh_pieces(collection_name: str) -> list:
    """Each mesh in a collection as world-yard triangles (game axes)."""
    coll = bpy.data.collections.get(collection_name)
    if coll is None:
        return []
    # A rock dragged in here stays a rock (rock_edits counts it).
    return objects_as_pieces([o for o in coll.all_objects if "rock_id" not in o.keys()])


def objects_as_pieces(objects: list) -> list:
    """Meshes as world-yard triangles (game axes)."""
    pieces = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        m = evaluated.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(m)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.verts.ensure_lookup_table()
        vertices = []
        for v in bm.verts:
            vertices.extend(to_game(obj.matrix_world @ v.co))
        indices = [v.index for f in bm.faces for v in f.verts]
        bm.free()
        evaluated.to_mesh_clear()
        mat = obj.material_slots[0].material.name if obj.material_slots and obj.material_slots[0].material else ""
        pieces.append({"name": obj.name, "material": mat, "vertices": vertices, "indices": indices})
    return pieces


def sync_edit_mode() -> None:
    """Brings the meshes being edited (Edit Mode) up to date, so what's
    saved is what's on screen, without leaving the mode."""
    for obj in bpy.context.view_layer.objects:
        if obj.type == "MESH" and obj.mode == "EDIT":
            obj.update_from_editmode()


def save() -> str:
    sync_edit_mode()
    meta = STATE["meta"]
    edits = meta["edits"]
    os.makedirs(edits, exist_ok=True)
    columns, rows = meta["columns"], meta["rows"]
    base = STATE["base"]
    notes = []

    # Ground: each grid point's height against the code's.
    ground = bpy.data.objects.get("Ground")
    delta = array("f", [0.0] * (columns * rows))
    if ground is not None:
        mesh = ground.data
        index = mesh.attributes.get("grid_index")
        locked = ground.vertex_groups.get("Locked")
        lock_index = locked.index if locked else -1
        seen = 0
        for v in mesh.vertices:
            i = index.data[v.index].value if index else v.index
            if i < 0 or i >= columns * rows:
                continue
            if any(g.group == lock_index for g in v.groups):
                continue
            height = (ground.matrix_world @ v.co).z
            delta[i] = height - base[i]
            seen += 1
        if len(mesh.vertices) != columns * rows:
            notes.append("the ground's vertex count changed; only its grid points were kept")
    with open(os.path.join(edits, "heights.bin"), "wb") as f:
        delta.tofile(f)
    with open(os.path.join(edits, "heights.json"), "w", encoding="utf-8") as f:
        json.dump({"origin": meta["origin"], "step": meta["step"], "columns": columns, "rows": rows}, f, indent="\t")

    # Caves: each vertex moved from where the code put it, in its own yards.
    places = meta.get("key_places", 2)
    caves = {}
    for obj in bpy.data.objects:
        if "cave_key" not in obj.keys():
            continue
        t = list(obj["to_world"])
        to_world = Matrix(((t[0], t[3], t[6], t[9]), (t[1], t[4], t[7], t[10]), (t[2], t[5], t[8], t[11]), (0, 0, 0, 1)))
        to_local = to_world.inverted()
        attr = obj.data.attributes.get("base_local")
        if attr is None or len(attr.data) != len(obj.data.vertices):
            notes.append(f"{obj.name} lost where its points came from (base_local), so its edits weren't saved")
            continue
        moved = {}
        for v in obj.data.vertices:
            base_local = Vector(attr.data[v.index].vector)
            now = to_local @ Vector(to_game(obj.matrix_world @ v.co))
            shift = now - base_local
            if shift.length > 0.0005:
                key = spot_key(base_local, places)
                # A copy of a vertex (an extrusion) carries its base: the
                # nearest stays.
                if key not in moved or shift.length < Vector(moved[key]).length:
                    moved[key] = [shift.x, shift.y, shift.z]
        if moved:
            caves[obj["cave_key"]] = moved
    with open(os.path.join(edits, "caves.json"), "w", encoding="utf-8") as f:
        json.dump(caves, f)

    rocks, copies = rock_edits()
    with open(os.path.join(edits, "rocks.json"), "w", encoding="utf-8") as f:
        json.dump(rocks, f)
    additions = mesh_pieces("Additions") + objects_as_pieces(copies)
    with open(os.path.join(edits, "additions.json"), "w", encoding="utf-8") as f:
        json.dump({"pieces": additions}, f)
    with open(os.path.join(edits, "cuts.json"), "w", encoding="utf-8") as f:
        json.dump({"pieces": mesh_pieces("Cuts")}, f)
    changed = sum(1 for d in delta if abs(d) > 0.0005)
    gone = sum(1 for r in rocks.values() if r.get("deleted"))
    message = f"Saved {meta['zone']}: {changed} ground points raised or lowered, {len(caves)} caves reshaped, " \
              f"{len(rocks) - gone} rocks moved, {gone} rocks deleted, {len(additions)} additions, {len(mesh_pieces('Cuts'))} cuts."
    if notes:
        message += " (" + "; ".join(notes) + ")"
    print(message)
    return message


class AIRPG_OT_save_edits(bpy.types.Operator):
    bl_idname = "airpg.save_edits"
    bl_label = "Save Edits"
    bl_description = "Write the zone's edit layers for the game (then Reload Game there)"

    def execute(self, context):
        # In Edit Mode the meshes' own data (points, attributes) lags behind
        # what's being edited: back to Object Mode to write it, then back.
        mode = context.mode
        active = context.view_layer.objects.active
        if mode not in ("OBJECT", "EDIT_MESH") and active is not None:
            bpy.ops.object.mode_set(mode="OBJECT")
        try:
            write_now()
            self.report({"INFO"}, STATE.get("last_saved", "Saved"))
        finally:
            if mode == "SCULPT" and active is not None:
                bpy.ops.object.mode_set(mode="SCULPT")
        return {"FINISHED"}


class AIRPG_PT_zone(bpy.types.Panel):
    bl_label = "AI RPG Zone"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "AI RPG"

    def draw(self, context):
        meta = STATE.get("meta") or {}
        self.layout.label(text=meta.get("zone", "No zone loaded"))
        self.layout.label(text=STATE.get("last_saved", "Edits save themselves."))
        self.layout.operator("airpg.save_edits")
        col = self.layout.column()
        for line in ("Ground: move vertices, no adding.", "Locked group: border, kept.",
                     "Caves: move vertices.", "Mouth rocks: move, turn, scale,", "  delete; Shift+D adds one.", "Additions: new rock (or 'ground').", "Cuts: shapes cut away."):
            col.label(text=line)


# Edits save themselves: a change marks the scene changed, and a few
# seconds after the last one the edit layers are written (AUTOSAVE_WAIT);
# Ctrl+S writes them too.
AUTOSAVE_WAIT = 2.0


def on_change(scene, depsgraph) -> None:
    if not STATE.get("saving"):
        STATE["dirty"] = True
        STATE["changed_at"] = time.monotonic()


def autosave():
    if STATE.get("dirty") and time.monotonic() - STATE.get("changed_at", 0.0) >= AUTOSAVE_WAIT:
        write_now()
    return 1.0


def write_now() -> None:
    STATE["saving"] = True
    try:
        message = save()
        STATE["last_saved"] = "Saved " + time.strftime("%H:%M:%S")
    except Exception as error:
        STATE["last_saved"] = f"Couldn't save: {error}"
        print(STATE["last_saved"])
    finally:
        STATE["dirty"] = False
        STATE["saving"] = False


@bpy.app.handlers.persistent
def on_blend_saved(*_args) -> None:
    write_now()


def watch() -> None:
    if on_change not in bpy.app.handlers.depsgraph_update_post:
        bpy.app.handlers.depsgraph_update_post.append(on_change)
    if on_blend_saved not in bpy.app.handlers.save_post:
        bpy.app.handlers.save_post.append(on_blend_saved)
    if not bpy.app.timers.is_registered(autosave):
        bpy.app.timers.register(autosave, first_interval=AUTOSAVE_WAIT, persistent=True)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not args:
        print("Usage: blender --python tools/zones/zone_edit.py -- <exported zone folder> [--keep-scene]")
        return
    for cls in (AIRPG_OT_save_edits, AIRPG_PT_zone):
        try:
            bpy.utils.register_class(cls)
        except ValueError:
            pass
    if "--keep-scene" in args:
        # A saved .blend of an earlier session: its scene kept as it is, the
        # zone's export read for saving it.
        folder = args[0]
        STATE.update(folder=folder, meta=read_json(os.path.join(folder, "zone.json")),
                     base=read_floats(os.path.join(folder, "base_heights.bin")))
        print("Kept the open scene for", STATE["meta"]["zone"])
        # Saved at once with this script (that's what it was opened for).
        write_now()
        print(STATE.get("last_saved"))
    else:
        load(args[0])
    STATE["dirty"] = False
    watch()


main()
