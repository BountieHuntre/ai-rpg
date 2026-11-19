"""Builds the Human character model: skeleton, male and female bodies, hair
and beards, shoulder pads, weapon and shield props, and every animation, then
exports assets/models/human/human.glb and saves human.blend beside this script.

Run headless:
  "C:\\Program Files\\Blender Foundation\\Blender 4.5\\blender.exe" --background --python tools/models/human/build_human.py

Conventions: Blender units are yards. The character stands at the origin
facing +Y (the exporter turns that into Godot's -Z), right hand towards +X.
Every part is weighted wholly to one bone (chunky, rigid low-poly) except the
torso and legs, whose rings follow the bone they sit on. Colour comes from the
UVs, not a texture: U picks one of 16 colour slots (SLOTS) and V is a shade
(V * 2 multiplies the colour); shaders/character.gdshader colours each slot
from uniforms, so skin, hair and every piece of gear are recoloured in game.
Bodies, hair styles, beards, shoulder pads and props are separate meshes on
the one skeleton, shown and hidden by HumanoidModel.

Poses are written as rotations about the armature's own axes (X right, Y
forward, Z up), relative to the parent, in degrees: +X swings a hanging limb
forward and tips an upright bone (spine, head) back; -X on a shin bends the
knee, +X on a forearm bends the elbow; for right-side limbs -Y lifts the arm
or leg out to the side and +Y brings it across the body. Left-side entries
are written the same way and mirrored (see `both` and `mirror_pose`).
"""
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FPS = 30

SLOT_NAMES = [
	"skin", "hair", "eyes", "chest", "legs", "feet", "hands", "waist",
	"shoulders", "wrists", "head", "trim", "blade", "handle", "shield", "shield_trim",
	"back", "ranged", "ranged_trim", "helm_trim", "tusk", "paint", "gem", "strap", "emblem", "sclera",
]
SLOT = {name: i for i, name in enumerate(SLOT_NAMES)}
# U steps: room for this many slots (shaders/character.gdshader's array).
SLOT_COUNT = 32

# Races share the Human's parts and animations, reshaped: legs and torso
# heights, width, and the head, hands and props scaled about their joints.
# Each is written to assets/models/<race>/<race>.glb.
RACES = {
	"human": {"legs": 1.0, "torso": 1.0, "width": 1.0, "head": 1.0, "hands": 1.0, "props": 1.0},
	"dwarf": {"legs": 0.62, "torso": 0.88, "width": 1.28, "head": 1.12, "hands": 1.12, "props": 0.9},
	"gnome": {"legs": 0.5, "torso": 0.58, "width": 0.8, "head": 1.35, "hands": 1.1, "props": 0.62},
	# The rest of the playable races: reshaped, `limbs` scaling the arms' and
	# legs' thickness, with `features` of their own on the head and body
	# (race_features): tusks, ears, horns, snout...
	# `variants` are the race's feature as chosen at character creation
	# (Feature0-2 and FeatureF0-2 for women, HumanoidModel.RACE_OPTIONS), and
	# `marks` its markings (Marks0-2, MarksF0-2: war paint, runes, scars).
	"orc": {"legs": 0.96, "torso": 1.02, "width": 1.2, "head": 1.0, "hands": 1.22, "props": 1.05, "limbs": 1.15,
			"features": ["jaw", "brow", "ears_short"],
			"variants": [["tusks"], ["tusks_large"], ["tusks_broken"]],
			"marks": [["stripes"], ["eyes", "chin"], ["stripes", "chest"]]},
	"wood_elf": {"legs": 1.14, "torso": 1.08, "width": 0.97, "head": 0.97, "hands": 1.0, "props": 1.05, "limbs": 0.93,
			"features": ["brow_tufts"],
			"variants": [["ears_long"], ["ears_swept"], ["ears_tall"]],
			"marks": [["dots"], ["cheeks"], ["dots", "cheeks", "brow_rune"]]},
	"undead": {"legs": 0.98, "torso": 0.96, "width": 0.9, "head": 0.97, "hands": 1.0, "props": 1.0, "limbs": 0.72,
			"features": ["brow", "ribs"],
			"variants": [["bare_jaw"], ["whole_jaw"], ["fanged_jaw"]],
			"marks": [["scar"], ["stitches"], ["scar", "chest_stitches"]]},
	"troll": {"legs": 1.16, "torso": 1.06, "width": 1.02, "head": 1.05, "hands": 1.2, "props": 1.08, "limbs": 0.95,
			"features": ["jaw", "long_nose", "ears_wide"],
			"variants": [["big_tusks"], ["tusks_straight"], ["tusks_short"]],
			"marks": [["stripes"], ["eyes", "chin"], ["stripes", "chest"]]},
	"hornkin": {"legs": 1.12, "torso": 1.12, "width": 1.42, "head": 1.2, "hands": 1.35, "props": 1.15, "limbs": 1.2,
			"features": ["snout", "ears_side", "tail"],
			"variants": [["horns"], ["horns_swept"], ["horns_short"]],
			"marks": [["eyes"], ["stripes", "chin"], ["eyes", "chest"]]},
	# Humanoid creatures: the same body and animations with a head and tail
	# of their own (species_parts), and only the parts creatures use.
	"burrowling": {"legs": 0.5, "torso": 0.6, "width": 0.85, "head": 1.15, "hands": 1.15, "props": 0.7, "species": "burrowling"},
	"mirefin": {"legs": 0.45, "torso": 0.62, "width": 1.0, "head": 1.45, "hands": 1.1, "props": 0.75, "species": "mirefin"},
	"ditchjaw": {"legs": 1.04, "torso": 1.0, "width": 1.06, "head": 1.05, "hands": 1.1, "props": 1.05, "species": "ditchjaw"},
	"tuskfolk": {"legs": 0.78, "torso": 0.92, "width": 1.32, "head": 1.12, "hands": 1.2, "props": 0.95, "limbs": 1.2,
				 "species": "tuskfolk"},
	"imp": {"legs": 0.52, "torso": 0.5, "width": 0.68, "head": 1.45, "hands": 1.15, "props": 0.6, "limbs": 0.62,
			"species": "imp"},
}
RACE = RACES["human"]
HIP_Z = 0.96

# ---------------------------------------------------------------- skeleton

def _side(x, v):
	return (v[0] * x, v[1], v[2])


BONES = [
	# name, head, tail, parent
	("Root", (0, 0, 0), (0, 0, 0.25), None),
	("Hips", (0, 0, 0.96), (0, 0, 1.08), "Root"),
	("Spine", (0, 0, 1.08), (0, 0, 1.24), "Hips"),
	("Chest", (0, 0, 1.24), (0, 0, 1.47), "Spine"),
	("Neck", (0, 0, 1.47), (0, 0.01, 1.56), "Chest"),
	("Head", (0, 0.01, 1.56), (0, 0.01, 1.84), "Neck"),
]
for side, x in (("Right", 1), ("Left", -1)):
	BONES += [
		(side + "Shoulder", _side(x, (0.05, 0, 1.43)), _side(x, (0.22, 0, 1.44)), "Chest"),
		(side + "UpperArm", _side(x, (0.28, 0, 1.42)), _side(x, (0.32, 0, 1.14)), side + "Shoulder"),
		(side + "LowerArm", _side(x, (0.32, 0, 1.14)), _side(x, (0.34, 0.03, 0.89)), side + "UpperArm"),
		(side + "Hand", _side(x, (0.34, 0.03, 0.89)), _side(x, (0.35, 0.04, 0.78)), side + "LowerArm"),
		(side + "UpperLeg", _side(x, (0.11, 0, 0.96)), _side(x, (0.12, 0, 0.52)), "Hips"),
		(side + "LowerLeg", _side(x, (0.12, 0, 0.52)), _side(x, (0.12, -0.02, 0.1)), side + "UpperLeg"),
		(side + "Foot", _side(x, (0.12, -0.02, 0.1)), _side(x, (0.12, 0.14, 0.03)), side + "LowerLeg"),
		(side + "Toes", _side(x, (0.12, 0.14, 0.03)), _side(x, (0.12, 0.22, 0.03)), side + "Foot"),
	]
# Props hang off these: the grip of each hand, pointing forward, and the
# outside of the left forearm.
GRIP_R = Vector((0.345, 0.035, 0.81))
GRIP_L = Vector((-0.345, 0.035, 0.81))
SHIELD_AT = Vector((-0.42, 0.015, 1.0))
# The cape chain's joints, top to bottom: five bones hanging down the back.
CAPE_POINTS = [(0, -0.12, 1.47), (0, -0.155, 1.3), (0, -0.18, 1.12), (0, -0.2, 0.94), (0, -0.23, 0.77), (0, -0.27, 0.6)]
# Three chains hang the cape, so it can ripple and fold across its width:
# its left edge, middle and right edge, each CAPE_POINTS moved out sideways
# by its share (-1, 0, 1) of the cape's half-width at that height.
CAPE_CHAINS = {"L": -1.0, "C": 0.0, "R": 1.0}


def cape_half_width(z):
	"""Half the cape's width at a height: wider towards the hem."""
	return 0.2 + 0.08 * (1.49 - z) / 0.89


def cape_point(chain, i):
	x, y, z = CAPE_POINTS[i]
	return (CAPE_CHAINS[chain] * cape_half_width(z) * 0.85, y, z)
# The left wrist's place on a two-handed weapon, from the right hand's grip:
# back down the handle (the weapon points +Y in the hand) and a little up.
TWO_HAND_GRIP = Vector((0, -0.17, 0.05))
# Chunky, heroic proportions: the head, hands and feet bigger than life.
HEAD_AT = Vector((0, 0.01, 1.56))
HEAD_SCALE = 1.18
WRIST = {"RightHand": Vector((0.34, 0.03, 0.89)), "LeftHand": Vector((-0.34, 0.03, 0.89))}
HAND_SCALE = 1.3
GROUP_SCALE = {
	"RightFoot": (Vector((0.12, -0.02, 0.0)), Vector((1.2, 1.15, 1.1))),
	"LeftFoot": (Vector((-0.12, -0.02, 0.0)), Vector((1.2, 1.15, 1.1))),
}


def body_point(v):
	"""A point of the Human's body in the race's shape."""
	v = Vector(v)
	z = v.z * RACE["legs"] if v.z <= HIP_Z else HIP_Z * RACE["legs"] + (v.z - HIP_Z) * RACE["torso"]
	return Vector((v.x * RACE["width"], v.y * RACE["width"], z))


def place(v, group):
	"""Where a point weighted to `group` goes for the race: the head, hands
	and props keep their shape, scaled about the joint they hang from. A
	blended group (pairs of bone and weight) is placed by its first bone."""
	if isinstance(group, tuple):
		group = group[0][0]
	v = Vector(v)
	if group == "Head":
		return body_point(HEAD_AT) + (v - HEAD_AT) * HEAD_SCALE * RACE["head"]
	if group in WRIST:
		return body_point(WRIST[group]) + (v - WRIST[group]) * HAND_SCALE * RACE["hands"]
	if group in ("WeaponR", "WeaponL", "GripL"):
		grip = GRIP_L if group == "WeaponL" else GRIP_R
		return place(grip, "LeftHand" if group == "WeaponL" else "RightHand") + (v - grip) * RACE["props"]
	if group == "ShieldL":
		return body_point(SHIELD_AT) + (v - SHIELD_AT) * RACE["props"]
	if group in GROUP_SCALE:
		pivot, scale = GROUP_SCALE[group]
		v = pivot + Vector(a * b for a, b in zip(v - pivot, scale))
	return body_point(v)
BONES += [
	("WeaponR", tuple(GRIP_R), tuple(GRIP_R + Vector((0, 0.2, 0))), "RightHand"),
	("WeaponL", tuple(GRIP_L), tuple(GRIP_L + Vector((0, 0.2, 0))), "LeftHand"),
	("ShieldL", tuple(SHIELD_AT), tuple(SHIELD_AT + Vector((-0.15, 0, 0))), "LeftLowerArm"),
	# Where the left wrist goes on a two-handed weapon's handle, below the
	# right hand: the two-handed animations reach it there by IK (two_hand_ik).
	("GripL", tuple(GRIP_R + TWO_HAND_GRIP), tuple(GRIP_R + TWO_HAND_GRIP + Vector((0, -0.1, 0))), "WeaponR"),
	# The cape: a chain hanging down the back from the shoulders, which the
	# game swings with spring physics (HumanoidModel._cape_springs). The
	# animations leave it at rest.
] + [
	(f"Cape{chain}{i + 1}", cape_point(chain, i), cape_point(chain, i + 1), "Chest" if i == 0 else f"Cape{chain}{i}")
	for chain in CAPE_CHAINS for i in range(len(CAPE_POINTS) - 1)
]
BONE_NAMES = [b[0] for b in BONES]


def build_armature():
	data = bpy.data.armatures.new("Armature")
	arm = bpy.data.objects.new("Armature", data)
	bpy.context.scene.collection.objects.link(arm)
	bpy.context.view_layer.objects.active = arm
	arm.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	for name, head, tail, parent in BONES:
		bone = data.edit_bones.new(name)
		bone.head = place(head, name)
		bone.tail = place(tail, name)
		bone.roll = 0.0
		if parent:
			bone.parent = data.edit_bones[parent]
			bone.use_connect = False
	bpy.ops.object.mode_set(mode="OBJECT")
	return arm

# ---------------------------------------------------------------- meshes

def _along_axis(points, axis):
	"""A face's corners' texture coordinates (yards) laid along `axis`: on
	faces running along it, across and along; on faces across its end, flat."""
	axis = axis.normalized()
	normal = (points[1] - points[0]).cross(points[2] - points[0])
	if normal.length < 1e-9:
		normal = axis.orthogonal()
	normal.normalize()
	if abs(normal.dot(axis)) > 0.7:
		e1 = axis.orthogonal().normalized()
		e2 = axis.cross(e1)
		return [(p.dot(e1), p.dot(e2)) for p in points]
	across = normal.cross(axis).normalized()
	return [(p.dot(across), p.dot(axis)) for p in points]


def _outward(bm):
	"""Turns any piece that came out inside out (recalc_face_normals can get a
	thin shell, such as a hair shell, the wrong way round) the right way: a
	closed piece's faces enclose a positive volume."""
	seen = set()
	for start in bm.faces:
		if start in seen:
			continue
		island, todo = [], [start]
		seen.add(start)
		while todo:
			f = todo.pop()
			island.append(f)
			for e in f.edges:
				for g in e.link_faces:
					if g not in seen:
						seen.add(g)
						todo.append(g)
		volume = 0.0
		for f in island:
			v = [l.vert.co for l in f.loops]
			for i in range(1, len(v) - 1):
				volume += v[0].dot(v[i].cross(v[i + 1]))
		if volume < 0.0:
			bmesh.ops.reverse_faces(bm, faces=island)


class Builder:
	"""Geometry for one mesh object, in armature space."""

	def __init__(self, name):
		self.name = name
		self.verts = []
		self.groups = []
		self.faces = []
		self.face_uv = []
		# Texture coordinates in yards for each face's corners (the second UV
		# map): what the character shader lays its gear patterns by.
		self.face_uv2 = []

	def _add(self, verts, groups, faces, slots, shades, uv2=None, axis=(0, 0, 1)):
		"""Faces of a shape. `uv2` gives each face's corners' texture
		coordinates; without it they're laid along `axis` (_along_axis)."""
		base = len(self.verts)
		self.verts += [Vector(v) for v in verts]
		self.groups += groups
		for n, (face, slot, shade) in enumerate(zip(faces, slots, shades)):
			self.faces.append([base + i for i in face])
			self.face_uv.append(((SLOT[slot] + 0.5) / SLOT_COUNT, shade / 2.0))
			self.face_uv2.append(uv2[n] if uv2 else _along_axis([Vector(verts[i]) for i in face], Vector(axis)))

	def loft(self, rings, slots, sides=8, turn=None, cap_slots=None, shade=1.0):
		"""Rings of (center, rx, ry, bone) joined into a capped tube along
		any direction. `slots` gives each band's slot (one per ring gap);
		rings lie flat in the plane across the tube."""
		if turn is None:
			turn = math.pi / sides
		verts, groups, faces, fslots, uv2 = [], [], [], [], []
		# Around (yards of the average girth) and along (yards down the
		# centres), so patterns wrap round limbs and the torso in rows.
		girth = math.tau * sum((r[1] + r[2]) / 2 for r in rings) / len(rings)
		along = [0.0]
		for a, b in zip(rings, rings[1:]):
			along.append(along[-1] + (Vector(b[0]) - Vector(a[0])).length)
		ends = []
		for i, (center, rx, ry, bone) in enumerate(rings):
			center = Vector(center)
			nxt = Vector(rings[min(i + 1, len(rings) - 1)][0])
			prv = Vector(rings[max(i - 1, 0)][0])
			axis = (nxt - prv).normalized()
			# Across-axes: X stays sideways where it can, Y is forward.
			side = Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 0, 1))
			fwd = axis.cross(side).normalized()
			side = fwd.cross(axis).normalized()
			if abs(axis.z) > 0.5 and fwd.y < 0:
				fwd = -fwd
			if side.x < 0 and abs(axis.x) < 0.9:
				side = -side
			ends.append((side, fwd))
			for k in range(sides):
				a = turn + math.tau * k / sides
				verts.append(center + side * math.cos(a) * rx + fwd * math.sin(a) * ry)
				groups.append(bone)
		for i in range(len(rings) - 1):
			for k in range(sides):
				a, b = i * sides + k, i * sides + (k + 1) % sides
				faces.append([a, b, b + sides, a + sides])
				fslots.append(slots[i])
				u0, u1 = girth * k / sides, girth * (k + 1) / sides
				uv2.append([(u0, along[i]), (u1, along[i]), (u1, along[i + 1]), (u0, along[i + 1])])
		caps = cap_slots or (slots[0], slots[-1])
		faces.append(list(range(sides))[::-1])
		fslots.append(caps[0])
		last = (len(rings) - 1) * sides
		faces.append([last + k for k in range(sides)])
		fslots.append(caps[1])
		for face, (side, fwd) in ((faces[-2], ends[0]), (faces[-1], ends[-1])):
			uv2.append([(Vector(verts[i]).dot(side), Vector(verts[i]).dot(fwd)) for i in face])
		self._add(verts, groups, faces, fslots, [shade] * len(faces), uv2)

	def tube(self, p0, p1, r0, r1, bone, slot, sides=6, shade=1.0):
		self.loft([(p0, r0, r0, bone), (p1, r1, r1, bone)], [slot], sides, shade=shade)

	def box(self, center, size, bone, slot, top=(1.0, 1.0), shift=(0.0, 0.0), shade=1.0):
		"""A box, its top face scaled by `top` and moved by `shift` (x, y)."""
		cx, cy, cz = center
		sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
		verts = []
		for z, scale, off in ((-sz, (1, 1), (0, 0)), (sz, top, shift)):
			for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
				verts.append((cx + x * sx * scale[0] + off[0], cy + y * sy * scale[1] + off[1], cz + z))
		faces = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
		self._add(verts, [bone] * 8, faces, [slot] * 6, [shade] * 6)

	def beam(self, p0, p1, width, depth, bone, slot, taper=1.0, shade=1.0, up=(0, 0, 1)):
		"""A box from p0 to p1, `width` along `up`, `depth` across both."""
		p0, p1 = Vector(p0), Vector(p1)
		axis = (p1 - p0).normalized()
		u = Vector(up)
		u = (u - axis * axis.dot(u)).normalized()
		s = axis.cross(u).normalized()
		verts = []
		for p, t in ((p0, 1.0), (p1, taper)):
			for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
				verts.append(p + u * a * width / 2 * t + s * b * depth / 2 * t)
		faces = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
		self._add(verts, [bone] * 8, faces, [slot] * 6, [shade] * 6, axis=axis)

	def plate(self, outline, x0, x1, bone, slot, rim_slot=None, shade=1.0, rim_shade=None, axis=(0, 0, 1)):
		"""A flat shape in the YZ plane (outline of (y, z)) from x0 to x1,
		its patterns laid along `axis`."""
		n = len(outline)
		verts = [(x0, y, z) for y, z in outline] + [(x1, y, z) for y, z in outline]
		faces = [list(range(n))[::-1], [n + k for k in range(n)]]
		slots = [slot, slot]
		shades = [shade, shade]
		for k in range(n):
			faces.append([k, (k + 1) % n, n + (k + 1) % n, n + k])
			slots.append(rim_slot or slot)
			shades.append(rim_shade if rim_shade is not None else shade)
		self._add(verts, [bone] * len(verts), faces, slots, shades, axis=axis)

	def build(self, arm, material):
		mesh = bpy.data.meshes.new(self.name)
		bm = bmesh.new()
		bverts = [bm.verts.new(place(v, g)) for v, g in zip(self.verts, self.groups)]
		uv_layer = bm.loops.layers.uv.new("UVMap")
		uv2_layer = bm.loops.layers.uv.new("UVPattern")
		for face, uv, uv2 in zip(self.faces, self.face_uv, self.face_uv2):
			f = bm.faces.new([bverts[i] for i in face])
			f.smooth = False
			for loop, corner in zip(f.loops, uv2):
				loop[uv_layer].uv = uv
				loop[uv2_layer].uv = corner
		# Every part is a closed shell: turn its faces outward (the mirrored
		# left side and some lofts are built inside out).
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		_outward(bm)
		bm.normal_update()
		bm.to_mesh(mesh)
		bm.free()
		obj = bpy.data.objects.new(self.name, mesh)
		bpy.context.scene.collection.objects.link(obj)
		mesh.materials.append(material)
		# A vertex is on one bone, or shared between bones by weight.
		groups = {}
		for i, g in enumerate(self.groups):
			for bone, weight in (g if isinstance(g, tuple) else ((g, 1.0),)):
				if bone not in groups:
					groups[bone] = obj.vertex_groups.new(name=bone)
				groups[bone].add([i], weight, "REPLACE")
		obj.parent = arm
		mod = obj.modifiers.new("Armature", "ARMATURE")
		mod.object = arm
		return obj


def body(name, female):
	b = Builder(name)
	f = female
	# Torso: pelvis to the base of the neck, one tube bending with the spine.
	rings = [
		((0, 0, 0.86), 0.15, 0.1, "Hips"),
		((0, 0, 0.97), 0.2 if f else 0.19, 0.125, "Hips"),
		((0, 0, 1.03), 0.19 if f else 0.19, 0.12, "Hips"),
		((0, 0, 1.09), 0.155 if f else 0.18, 0.11, "Spine"),
		((0, 0.01, 1.22), 0.17 if f else 0.215, 0.12 if f else 0.13, "Spine"),
		# Ten sides round, the chest rising from the waist and falling to the
		# neck in gentler steps.
		((0, 0.013, 1.3), 0.19 if f else 0.255, 0.128 if f else 0.15, "Chest"),
		((0, 0.015, 1.37), 0.21 if f else 0.29, 0.135 if f else 0.165, "Chest"),
		((0, 0.0, 1.45), 0.2 if f else 0.28, 0.125 if f else 0.145, "Chest"),
		((0, 0, 1.49), 0.15 if f else 0.2, 0.1 if f else 0.115, "Chest"),
		((0, 0, 1.51), 0.1, 0.08, "Chest"),
	]
	b.loft(rings, ["legs", "waist", "waist", "chest", "chest", "chest", "chest", "chest", "chest"], sides=10)
	# Belt buckle.
	b.box((0, 0.125, 1.0), (0.06, 0.02, 0.05), "Hips", "trim")
	# Neck and head.
	b.tube((0, 0, 1.46), (0, 0.01, 1.6), 0.062 if f else 0.08, 0.056 if f else 0.072, "Neck", "skin")
	if RACE.get("species"):
		return _limbs(b, f)
	hw = 0.92 if f else 1.0
	# Twelve sides round, a little smaller than the eight it had so its faces
	# lie where they did (hair and helms fit it as before): a narrower chin and
	# fuller cheekbones.
	r = 0.96
	head = [
		# The chin forward of the neck, and a little down.
		((0, 0.075, 1.555), 0.05 * hw * r, 0.055 * r, "Head"),
		((0, 0.045, 1.615), (0.09 * hw if f else 0.1) * r, 0.11 * r, "Head"),
		((0, 0.01, 1.69), 0.137 * hw * r, 0.135 * r, "Head"),
		((0, 0.0, 1.78), 0.12 * hw * r, 0.13 * r, "Head"),
		((0, -0.005, 1.835), 0.075 * hw * r, 0.085 * r, "Head"),
	]
	b.loft(head, ["skin"] * 4, sides=12)
	for x in (-1, 1):
		# The white of the eye, and its iris in front.
		b.box((0.045 * x, 0.126, 1.705), (0.034, 0.02, 0.018), "Head", "sclera")
		b.box((0.044 * x, 0.131, 1.705), (0.017, 0.02, 0.018), "Head", "eyes")
		b.box((0.045 * x, 0.126, 1.737), (0.055, 0.025, 0.016), "Head", "hair")
		b.box((0.122 * hw * x, 0.0, 1.7), (0.03, 0.05, 0.065), "Head", "skin", shade=0.9)
	b.box((0, 0.14, 1.668), (0.035, 0.045, 0.06), "Head", "skin", top=(0.8, 0.6), shift=(0, -0.01), shade=0.95)
	b.box((0, 0.128, 1.625), (0.05, 0.015, 0.012), "Head", "skin", shade=0.6)
	race_features(b, f, RACE.get("features", []))
	return _limbs(b, f)


def race_features(b, f, features):
	"""A race's own features on the Human's head and body, in the Human's
	measurements (place() scales them with the head). Women's tusks and horns
	are smaller."""
	k = 0.8 if f else 1.0
	for x in (-1, 1):
		if "tusks" in features:
			b.beam((0.045 * x, 0.12, 1.595), (0.06 * x, 0.15, 1.65 + 0.02 * k), 0.025 * k, 0.025 * k, "Head", "tusk", taper=0.45)
		if "big_tusks" in features:
			b.beam((0.05 * x, 0.12, 1.595), (0.1 * x, 0.18, 1.7 + 0.04 * k), 0.035 * k, 0.035 * k, "Head", "tusk", taper=0.35)
		if "ears_short" in features:
			b.beam((0.12 * x, -0.01, 1.7), (0.18 * x, -0.04, 1.75), 0.06, 0.025, "Head", "skin", taper=0.3, shade=0.9)
		if "ears_long" in features:
			b.beam((0.12 * x, -0.01, 1.71), (0.29 * x, -0.1, 1.86), 0.07, 0.022, "Head", "skin", taper=0.2, shade=0.9)
		if "ears_wide" in features:
			b.beam((0.12 * x, -0.01, 1.7), (0.3 * x, -0.03, 1.74), 0.08, 0.022, "Head", "skin", taper=0.25, shade=0.9)
		if "ears_side" in features:
			b.beam((0.12 * x, -0.02, 1.76), (0.22 * x, -0.03, 1.73), 0.06, 0.04, "Head", "skin", taper=0.5, shade=0.85)
		if "horns" in features:
			b.beam((0.09 * x, -0.0, 1.8), (0.24 * x, 0.0, 1.84), 0.06 * k, 0.06 * k, "Head", "tusk", taper=0.7)
			b.beam((0.24 * x, 0.0, 1.84), (0.3 * x, 0.06, 1.96 * k + 1.84 * (1 - k)), 0.045 * k, 0.045 * k, "Head", "tusk", taper=0.3)
		if "horns_swept" in features:
			b.beam((0.09 * x, -0.02, 1.81), (0.2 * x, -0.1, 1.86), 0.055 * k, 0.055 * k, "Head", "tusk", taper=0.75)
			b.beam((0.2 * x, -0.1, 1.86), (0.24 * x, -0.25, 1.82 + 0.05 * k), 0.042 * k, 0.042 * k, "Head", "tusk", taper=0.3)
		if "horns_short" in features:
			b.beam((0.09 * x, 0.0, 1.81), (0.17 * x, 0.02, 1.87 + 0.02 * k), 0.06 * k, 0.06 * k, "Head", "tusk", taper=0.4)
		if "tusks_large" in features:
			b.beam((0.05 * x, 0.12, 1.595), (0.075 * x, 0.165, 1.68 + 0.03 * k), 0.034 * k, 0.034 * k, "Head", "tusk", taper=0.4)
		if "tusks_broken" in features:
			if x > 0:
				b.beam((0.045 * x, 0.12, 1.595), (0.065 * x, 0.155, 1.67 + 0.02 * k), 0.028 * k, 0.028 * k, "Head", "tusk", taper=0.45)
			else:
				b.beam((0.045 * x, 0.12, 1.595), (0.05 * x, 0.13, 1.625), 0.028 * k, 0.028 * k, "Head", "tusk", taper=0.9)
		if "tusks_straight" in features:
			b.beam((0.05 * x, 0.12, 1.6), (0.07 * x, 0.25, 1.64 + 0.02 * k), 0.032 * k, 0.032 * k, "Head", "tusk", taper=0.35)
		if "tusks_short" in features:
			b.beam((0.05 * x, 0.12, 1.595), (0.07 * x, 0.15, 1.645), 0.032 * k, 0.032 * k, "Head", "tusk", taper=0.5)
		if "ears_swept" in features:
			b.beam((0.12 * x, -0.015, 1.71), (0.27 * x, -0.17, 1.76), 0.07, 0.022, "Head", "skin", taper=0.2, shade=0.9)
		if "ears_tall" in features:
			b.beam((0.12 * x, -0.01, 1.72), (0.2 * x, -0.05, 1.93), 0.065, 0.022, "Head", "skin", taper=0.2, shade=0.9)
		if "brow_tufts" in features:
			b.beam((0.06 * x, 0.13, 1.745), (0.13 * x, 0.11, 1.8), 0.02, 0.02, "Head", "hair", taper=0.3)
		if "ribs" in features:
			for z in (1.3, 1.36):
				b.box((0.09 * x, 0.15, z), (0.08, 0.02, 0.018), "Chest", "tusk")
	if "jaw" in features:
		b.box((0, 0.085, 1.59), (0.2, 0.09, 0.06), "Head", "skin", top=(1.05, 1.1), shade=0.92)
	if "bare_jaw" in features:
		b.box((0, 0.1, 1.585), (0.12, 0.06, 0.04), "Head", "tusk", top=(1.1, 1.0))
		b.box((0, 0.12, 1.612), (0.09, 0.02, 0.014), "Head", "eyes")
	if "whole_jaw" in features:
		b.box((0, 0.098, 1.588), (0.13, 0.06, 0.04), "Head", "skin", top=(1.1, 1.0), shade=0.85)
	if "fanged_jaw" in features:
		b.box((0, 0.1, 1.585), (0.12, 0.06, 0.04), "Head", "tusk", top=(1.1, 1.0))
		b.box((0, 0.12, 1.612), (0.09, 0.02, 0.014), "Head", "eyes")
		for x in (-1, 1):
			b.beam((0.035 * x, 0.128, 1.615), (0.04 * x, 0.132, 1.585), 0.014, 0.012, "Head", "tusk", taper=0.4)
	if "brow" in features:
		b.box((0, 0.13, 1.742), (0.2, 0.035, 0.028), "Head", "skin", shade=0.8)
	if "long_nose" in features:
		b.beam((0, 0.13, 1.7), (0, 0.22, 1.63), 0.06, 0.05, "Head", "skin", taper=0.45, shade=0.95)
	if "snout" in features:
		b.box((0, 0.16, 1.63), (0.17, 0.12, 0.11), "Head", "skin", top=(0.9, 0.85), shade=0.95)
		b.box((0, 0.225, 1.64), (0.12, 0.012, 0.05), "Head", "eyes")
		b.box((0, 0.2, 1.62), (0.05, 0.02, 0.02), "Head", "trim")
	if "tail" in features:
		b.beam((0, -0.12, 0.98), (0, -0.2, 0.62), 0.04, 0.04, "Hips", "skin", taper=0.6)
		b.box((0, -0.21, 0.58), (0.06, 0.06, 0.1), "Hips", "hair")


def markings(b, f, marks):
	"""Markings drawn on the face and chest in the paint slot: war paint
	(stripes, bars by the eyes, a chin band, chest stripes), a Wood Elf's
	glowing runes (dots, cheek lines, a brow rune) and an Undead's scars and
	stitches. They stand a little proud of the skin, in the Human's
	measurements like the features."""
	chest_y = 0.152 if f else 0.178
	chest_z = 1.4 if f else 1.37
	for x in (-1, 1):
		if "stripes" in marks:
			b.box((0.075 * x, 0.128, 1.665), (0.022, 0.03, 0.085), "Head", "paint")
		if "eyes" in marks:
			b.box((0.1 * x, 0.12, 1.705), (0.045, 0.03, 0.03), "Head", "paint")
		if "chest" in marks:
			b.beam((0.06 * x, chest_y, chest_z + 0.07), (0.15 * x, chest_y - 0.01, chest_z - 0.05), 0.035, 0.02, "Chest", "paint", up=(1, 0, 0))
		if "dots" in marks:
			for dz in (0.0, 0.025):
				b.box((0.06 * x, 0.137, 1.74 + dz), (0.014, 0.012, 0.014), "Head", "paint")
		if "cheeks" in marks:
			b.box((0.06 * x, 0.132, 1.655), (0.012, 0.014, 0.06), "Head", "paint")
		if "chest_stitches" in marks and x > 0:
			b.box((0.04, chest_y, chest_z), (0.012, 0.02, 0.2), "Chest", "paint")
			for dz in (-0.07, 0.0, 0.07):
				b.box((0.04, chest_y + 0.004, chest_z + dz), (0.05, 0.02, 0.01), "Chest", "paint")
	if "stripes" in marks:
		b.box((0, 0.138, 1.775), (0.022, 0.03, 0.06), "Head", "paint")
	if "chin" in marks:
		b.box((0, 0.118, 1.595), (0.14, 0.035, 0.022), "Head", "paint")
	if "brow_rune" in marks:
		b.box((0, 0.14, 1.79), (0.05, 0.012, 0.012), "Head", "paint")
		b.box((0, 0.14, 1.8), (0.012, 0.012, 0.035), "Head", "paint")
	if "scar" in marks:
		b.beam((0.03, 0.135, 1.79), (0.1, 0.115, 1.63), 0.016, 0.018, "Head", "paint", up=(1, 0, 0))
	if "stitches" in marks:
		b.box((-0.07, 0.128, 1.65), (0.012, 0.022, 0.09), "Head", "paint")
		for dz in (-0.03, 0.0, 0.03):
			b.box((-0.07, 0.131, 1.65 + dz), (0.04, 0.02, 0.008), "Head", "paint")


def race_parts():
	"""The race's chosen feature and markings as parts of their own, each in a
	man's and a woman's shape (Feature0, FeatureF0... Marks0, MarksF0...)."""
	out = []
	for i, variant in enumerate(RACE.get("variants", [])):
		for f, prefix in ((False, "Feature"), (True, "FeatureF")):
			b = Builder(f"{prefix}{i}")
			race_features(b, f, variant)
			out.append(b)
	for i, marks in enumerate(RACE.get("marks", [])):
		for f, prefix in ((False, "Marks"), (True, "MarksF")):
			b = Builder(f"{prefix}{i}")
			markings(b, f, marks)
			out.append(b)
	return out


def _limbs(b, f):
	"""Arms, hands and legs on both sides."""
	# Arms and legs eight-sided (the radii a little less than the six-sided
	# limbs', so they're as thick).
	arm_r = (1.0 if f else 1.3) * RACE.get("limbs", 1.0) * 0.96
	for side, x in (("Right", 1), ("Left", -1)):
		sh = Vector(_side(x, (0.28, 0, 1.42)))
		el = Vector(_side(x, (0.32, 0, 1.14)))
		wr = Vector(_side(x, (0.34, 0.03, 0.89)))
		# The shoulder: a cap rounding from the top of the chest over the head
		# of the arm, so the arm grows out of the torso.
		b.loft([(sh + Vector((-0.06 * x, 0, 0.065)), 0.04 * arm_r, 0.055 * arm_r, side + "UpperArm"),
				(sh + Vector((-0.015 * x, 0, 0.05)), 0.07 * arm_r, 0.075 * arm_r, side + "UpperArm"),
				(sh + Vector((0.005 * x, 0, 0.0)), 0.08 * arm_r, 0.078 * arm_r, side + "UpperArm"),
				(el, 0.06 * arm_r, 0.06 * arm_r, side + "UpperArm")], ["chest", "chest", "chest"], sides=8)
		b.loft([(el + Vector((0, 0, 0.02)), 0.058 * arm_r, 0.058 * arm_r, side + "LowerArm"),
				(wr + Vector((0, 0, 0.0)), 0.048 * arm_r, 0.048 * arm_r, side + "LowerArm")], ["wrists"], sides=8)
		hand = 0.85 if f else 1.0
		b.box(_side(x, (0.345, 0.035, 0.83)), (0.085 * hand, 0.1 * hand, 0.12 * hand), side + "Hand", "hands", top=(1.0, 0.9))
		b.box(_side(x, (0.32, 0.085, 0.86)), (0.035, 0.035, 0.06), side + "Hand", "hands")
		leg = (1.0 if f else 1.2) * (1.0 + (RACE.get("limbs", 1.0) - 1.0) * 0.6)
		limb = leg * 0.96
		hip = Vector(_side(x, (0.1, 0, 0.97)))
		knee = Vector(_side(x, (0.12, 0, 0.52)))
		b.loft([(hip, 0.1 * limb, 0.105 * limb, side + "UpperLeg"),
				(knee + Vector((0, 0, 0.02)), 0.07 * limb, 0.072 * limb, side + "UpperLeg")], ["legs"], sides=8)
		b.loft([(knee + Vector((0, 0, 0.02)), 0.068 * limb, 0.07 * limb, side + "LowerLeg"),
				(Vector(_side(x, (0.12, -0.01, 0.35))), 0.058 * limb, 0.058 * limb, side + "LowerLeg"),
				(Vector(_side(x, (0.12, -0.01, 0.345))), 0.075 * limb, 0.078 * limb, side + "LowerLeg"),
				(Vector(_side(x, (0.12, -0.02, 0.1))), 0.064 * limb, 0.066 * limb, side + "LowerLeg")],
			   ["legs", "feet", "feet"], sides=8)
		b.box(_side(x, (0.12, 0.04, 0.055)), (0.12 * leg, 0.26, 0.11), side + "Foot", "feet", top=(0.9, 0.62), shift=(0, -0.04))
		b.box(_side(x, (0.12, 0.04, 0.008)), (0.125 * leg, 0.265, 0.016), side + "Foot", "feet", shade=0.55)
	return b


def species_parts(species):
	"""A humanoid creature's head (on the Head bone, in place of the human
	head) and tail: burrowlings rat-snouted with round ears and a thin tail,
	mirefin a great fish head with fins, ditchjaw a hyena's head and mane,
	tuskfolk a boar's head with tusks and a bristly ridge down the back, imps
	big-eared and horned with a thin barbed tail."""
	head = Builder("Species_head")
	tail = Builder("Species_tail")
	if species == "burrowling":
		head.loft([((0, -0.09, 1.7), 0.1, 0.09, "Head"), ((0, 0.02, 1.71), 0.12, 0.12, "Head"),
				   ((0, 0.14, 1.67), 0.075, 0.07, "Head"), ((0, 0.24, 1.64), 0.035, 0.035, "Head")],
				  ["skin", "skin", "skin"], sides=8, cap_slots=("skin", "trim"))
		for x in (-1, 1):
			head.box((0.11 * x, -0.02, 1.84), (0.025, 0.12, 0.13), "Head", "skin", top=(1.0, 0.8), shade=0.85)
			head.box((0.07 * x, 0.1, 1.74), (0.03, 0.03, 0.03), "Head", "eyes")
		head.box((0, 0.2, 1.61), (0.06, 0.06, 0.02), "Head", "trim")
		tail.beam((0, -0.12, 0.95), (0, -0.42, 0.82), 0.04, 0.04, "Hips", "skin", taper=0.4)
		tail.beam((0, -0.42, 0.82), (0, -0.62, 0.62), 0.025, 0.025, "Hips", "skin", taper=0.4)
	elif species == "mirefin":
		head.loft([((0, 0.0, 1.5), 0.15, 0.15, "Head"), ((0, 0.03, 1.62), 0.19, 0.18, "Head"),
				   ((0, 0.01, 1.78), 0.15, 0.16, "Head"), ((0, -0.03, 1.88), 0.07, 0.08, "Head")],
				  ["skin", "skin", "skin"], sides=8)
		head.box((0, 0.17, 1.58), (0.22, 0.04, 0.035), "Head", "eyes")
		for x in (-1, 1):
			head.box((0.1 * x, 0.12, 1.74), (0.06, 0.05, 0.06), "Head", "eyes")
			head.box((0.19 * x, -0.02, 1.64), (0.03, 0.1, 0.14), "Head", "hair", top=(1.0, 0.5))
		head.box((0, -0.05, 1.88), (0.03, 0.26, 0.14), "Head", "hair", top=(1.0, 0.6))
		head.box((0, -0.18, 1.74), (0.03, 0.08, 0.24), "Head", "hair")
	elif species == "ditchjaw":
		head.loft([((0, -0.07, 1.68), 0.1, 0.1, "Head"), ((0, 0.03, 1.72), 0.115, 0.12, "Head"),
				   ((0, 0.12, 1.67), 0.08, 0.08, "Head"), ((0, 0.28, 1.62), 0.045, 0.045, "Head")],
				  ["skin", "skin", "skin"], sides=8, cap_slots=("skin", "eyes"))
		for x in (-1, 1):
			head.box((0.08 * x, -0.03, 1.86), (0.03, 0.06, 0.16), "Head", "hair", top=(0.4, 0.4))
			head.box((0.065 * x, 0.11, 1.74), (0.03, 0.03, 0.025), "Head", "eyes")
		head.box((0, 0.2, 1.6), (0.06, 0.12, 0.02), "Head", "trim")
		head.box((0, -0.11, 1.6), (0.07, 0.07, 0.34), "Head", "hair", top=(1.0, 1.4))
		tail.beam((0, -0.13, 0.98), (0, -0.38, 0.78), 0.08, 0.08, "Hips", "hair", taper=0.6)
	elif species == "tuskfolk":
		# A boar's head: broad skull, a long snout ending in a flat nose, tusks
		# curving up from the jaw, small drooping ears and a bristly crown.
		head.loft([((0, -0.1, 1.7), 0.11, 0.11, "Head"), ((0, 0.01, 1.72), 0.14, 0.14, "Head"),
				   ((0, 0.14, 1.66), 0.095, 0.09, "Head"), ((0, 0.27, 1.62), 0.07, 0.062, "Head")],
				  ["skin", "skin", "skin"], sides=8, cap_slots=("skin", "skin"))
		head.box((0, 0.285, 1.62), (0.11, 0.025, 0.09), "Head", "skin", shade=0.7)
		head.box((0, 0.3, 1.62), (0.06, 0.01, 0.03), "Head", "eyes")
		head.box((0, 0.17, 1.575), (0.13, 0.16, 0.04), "Head", "skin", top=(0.9, 0.9), shade=0.85)
		for x in (-1, 1):
			head.box((0.075 * x, 0.11, 1.75), (0.03, 0.03, 0.025), "Head", "eyes")
			head.box((0.07 * x, 0.12, 1.775), (0.05, 0.03, 0.02), "Head", "hair")
			head.beam((0.06 * x, 0.2, 1.59), (0.11 * x, 0.25, 1.7), 0.035, 0.035, "Head", "tusk", taper=0.35)
			head.beam((0.12 * x, -0.02, 1.8), (0.19 * x, 0.02, 1.74), 0.07, 0.03, "Head", "skin", taper=0.4, shade=0.85)
		for y, z in ((0.08, 1.86), (-0.03, 1.88), (-0.13, 1.82)):
			head.beam((0, y, z - 0.06), (0, y - 0.04, z + 0.06), 0.06, 0.03, "Head", "hair", taper=0.25)
		# The bristly ridge down the back, neck to hips, and a short tail.
		for bone, y, z, h in (("Chest", -0.12, 1.52, 0.13), ("Chest", -0.16, 1.43, 0.15), ("Chest", -0.17, 1.33, 0.14),
							  ("Spine", -0.14, 1.22, 0.12), ("Spine", -0.12, 1.12, 0.1), ("Hips", -0.12, 1.02, 0.08)):
			tail.beam((0, y + 0.04, z), (0, y - h, z + h * 0.6), 0.05, 0.035, bone, "hair", taper=0.2)
		tail.beam((0, -0.12, 0.95), (0, -0.22, 0.9), 0.03, 0.03, "Hips", "skin", taper=0.6)
		tail.beam((0, -0.22, 0.9), (0, -0.25, 0.82), 0.022, 0.022, "Hips", "hair", taper=0.4)
	elif species == "imp":
		# A big round head, wide pointed ears, horns sweeping back, a sharp
		# chin and a grin; a long thin tail ending in a barb.
		head.loft([((0, 0.03, 1.56), 0.04, 0.04, "Head"), ((0, 0.05, 1.6), 0.09, 0.085, "Head"),
				   ((0, 0.02, 1.7), 0.125, 0.12, "Head"), ((0, -0.01, 1.8), 0.11, 0.11, "Head"),
				   ((0, -0.02, 1.86), 0.05, 0.05, "Head")],
				  ["skin", "skin", "skin", "skin"], sides=8)
		head.box((0, 0.12, 1.63), (0.1, 0.02, 0.015), "Head", "trim")
		head.box((0, 0.14, 1.69), (0.03, 0.04, 0.04), "Head", "skin", top=(0.6, 0.5), shade=0.9)
		for x in (-1, 1):
			head.box((0.05 * x, 0.11, 1.73), (0.04, 0.03, 0.03), "Head", "eyes")
			head.box((0.05 * x, 0.11, 1.765), (0.05, 0.02, 0.012), "Head", "skin", shade=0.6)
			head.beam((0.11 * x, 0.0, 1.73), (0.3 * x, -0.04, 1.8), 0.09, 0.02, "Head", "skin", taper=0.15, shade=0.85)
			head.beam((0.06 * x, 0.0, 1.83), (0.11 * x, -0.08, 1.95), 0.035, 0.035, "Head", "tusk", taper=0.6)
			head.beam((0.11 * x, -0.08, 1.95), (0.13 * x, -0.2, 1.98), 0.025, 0.025, "Head", "tusk", taper=0.2)
		tail.beam((0, -0.08, 0.95), (0, -0.26, 0.82), 0.025, 0.025, "Hips", "skin", taper=0.8)
		tail.beam((0, -0.26, 0.82), (0, -0.4, 0.55), 0.02, 0.02, "Hips", "skin", taper=0.8)
		tail.beam((0, -0.4, 0.55), (0, -0.44, 0.38), 0.016, 0.016, "Hips", "skin", taper=0.9)
		tail.beam((0, -0.43, 0.42), (0, -0.46, 0.3), 0.07, 0.02, "Hips", "skin", taper=0.1, up=(1, 0, 0))
	return [head] + ([tail] if tail.faces else [])


def hair_cap(b, back=1.66, back_depth=0.16):
	"""The hair over the skull, twelve-sided to hug the head, and a slab down
	the back of it (none when `back_depth` is 0)."""
	# Standing out from the skull and up on top, so it reads as hair.
	b.loft([((0, -0.005, 1.715), 0.137, 0.152, "Head"),
			((0, -0.01, 1.805), 0.14, 0.153, "Head"),
			((0, -0.012, 1.885), 0.085, 0.1, "Head")], ["hair", "hair"], sides=12)
	if back_depth > 0:
		# Tapering in at the nape.
		b.box((0, -0.1, back), (0.17, 0.055, back_depth), "Head", "hair", top=(1.38, 1.35), shift=(0, -0.012))


# The hair's outer surface round the head, by height: (z, half width, half
# depth); below the last it hangs straight down.
HAIR_PROFILE = [(1.92, 0.0, 0.0), (1.89, 0.085, 0.1), (1.85, 0.128, 0.143), (1.8, 0.142, 0.155),
				(1.72, 0.14, 0.153), (1.66, 0.136, 0.15)]


def _lerp_keys(keys, at):
	"""A value from (position, value) keys in rising order, straight between them."""
	if at <= keys[0][0]:
		return keys[0][1]
	for (a, va), (c, vc) in zip(keys, keys[1:]):
		if at <= c:
			return va + (vc - va) * (at - a) / (c - a)
	return keys[-1][1]


def hair_shell(b, edge, fringe=0.0, sweep=0.0, columns=24, rows=7, thick=0.025):
	"""A style of hair as one piece: a shell over the skull whose lower edge
	follows `edge`, (degrees from the front, height) keys round to the back:
	the hairline in front, the sideburns, the nape or the fall of long hair.
	`fringe` brings the front edge down over the brow that far, in uneven
	locks, deeper to one side by `sweep` (-1 to 1)."""
	def outer(z):
		if z >= HAIR_PROFILE[-1][0]:
			for (za, wa, da), (zc, wc, dc) in zip(HAIR_PROFILE, HAIR_PROFILE[1:]):
				if zc <= z <= za:
					t = (za - z) / (za - zc)
					return wa + (wc - wa) * t, da + (dc - da) * t
		return HAIR_PROFILE[-1][1], HAIR_PROFILE[-1][2]

	top = HAIR_PROFILE[0][0]
	verts, faces = [], []
	grid = []
	for c in range(columns):
		angle = 360.0 * c / columns
		# 90 degrees is the front (+Y); the edge keys run from the front.
		from_front = abs(((angle - 90.0) + 180.0) % 360.0 - 180.0)
		bottom = _lerp_keys(edge, from_front)
		if fringe and from_front < 50.0:
			# Which side of the front this column is on: + to the right.
			side = math.cos(math.radians(angle))
			lock = 0.6 + 0.4 * ((c % 2) * 2 - 1) * (1 if c % 3 else -0.5)
			bottom -= fringe * (1.0 - from_front / 50.0) * lock * (1.0 + sweep * side)
		column = []
		for r in range(1, rows + 1):
			z = top - (top - bottom) * r / rows
			w, d = outer(z)
			yc = -0.01 - (0.015 if z < 1.66 else 0.0)
			a = math.radians(angle)
			out_p = (w * math.cos(a), yc + d * math.sin(a), z)
			in_p = ((w - thick) * math.cos(a), yc + (d - thick) * math.sin(a), z)
			column.append((len(verts), len(verts) + 1))
			verts += [out_p, in_p]
		grid.append(column)
	apex_out, apex_in = len(verts), len(verts) + 1
	verts += [(0, -0.01, top), (0, -0.01, top - thick)]
	for c in range(columns):
		n = (c + 1) % columns
		faces.append([apex_out, grid[c][0][0], grid[n][0][0]])
		faces.append([apex_in, grid[n][0][1], grid[c][0][1]])
		for r in range(rows - 1):
			faces.append([grid[c][r][0], grid[c][r + 1][0], grid[n][r + 1][0], grid[n][r][0]])
			faces.append([grid[c][r][1], grid[n][r][1], grid[n][r + 1][1], grid[c][r + 1][1]])
		last = rows - 1
		faces.append([grid[c][last][0], grid[c][last][1], grid[n][last][1], grid[n][last][0]])
	b._add(verts, ["Head"] * len(verts), faces, ["hair"] * len(faces), [1.0] * len(faces))


# The styles' edges: (degrees from the front, height), front to back.
HAIR_SHORT = [(0, 1.785), (35, 1.765), (70, 1.66), (110, 1.65), (180, 1.6)]
HAIR_LONG = [(0, 1.775), (35, 1.75), (70, 1.62), (110, 1.52), (180, 1.5)]
HAIR_WOMAN_LONG = [(0, 1.79), (30, 1.73), (65, 1.5), (110, 1.44), (180, 1.44)]
HAIR_TIED = [(0, 1.785), (35, 1.75), (70, 1.68), (110, 1.66), (180, 1.64)]


def hairs():
	out = []
	b = Builder("HairShort")
	hair_shell(b, HAIR_SHORT, fringe=0.03, sweep=0.6)
	out.append(b)
	b = Builder("HairLong")
	hair_shell(b, HAIR_LONG, fringe=0.025, sweep=-0.4)
	out.append(b)
	b = Builder("HairCrest")
	b.box((0, -0.01, 1.86), (0.06, 0.27, 0.09), "Head", "hair", top=(0.8, 0.85))
	b.box((0, -0.12, 1.75), (0.06, 0.06, 0.16), "Head", "hair")
	out.append(b)
	b = Builder("HairFLong")
	hair_shell(b, HAIR_WOMAN_LONG, fringe=0.025)
	out.append(b)
	# The tail and the bun grow out of the shell: their first ring sunk in it.
	b = Builder("HairFTail")
	hair_shell(b, HAIR_TIED, fringe=0.02, sweep=0.5)
	b.loft([((0, -0.11, 1.75), 0.06, 0.05, "Head"), ((0, -0.18, 1.71), 0.05, 0.045, "Head"),
			((0, -0.205, 1.58), 0.042, 0.038, "Head"), ((0, -0.2, 1.42), 0.015, 0.015, "Head")],
		   ["hair", "hair", "hair"], sides=8)
	out.append(b)
	b = Builder("HairFBun")
	hair_shell(b, HAIR_TIED, fringe=0.02, sweep=-0.5)
	b.loft([((0, -0.12, 1.76), 0.085, 0.08, "Head"), ((0, -0.19, 1.79), 0.075, 0.07, "Head"),
			((0, -0.24, 1.81), 0.05, 0.05, "Head"), ((0, -0.255, 1.82), 0.015, 0.015, "Head")],
		   ["hair", "hair", "hair"], sides=10)
	out.append(b)
	# Beards along the jaw from the ears, narrowing to the chin, which stands
	# forward of the neck; a moustache over the mouth.
	for name, length in (("BeardShort", 0.0), ("BeardLong", 0.1)):
		b = Builder(name)
		# Full along the jaw and at the chin, so the face doesn't show through.
		for x in (-1, 1):
			b.beam((0.12 * x, 0.03, 1.71), (0.075 * x, 0.115, 1.575), 0.06, 0.045, "Head", "hair", taper=0.9, up=(0, 1, 0))
		b.box((0, 0.125, 1.57), (0.15, 0.08, 0.09), "Head", "hair", top=(1.25, 1.0))
		b.box((0, 0.135, 1.645), (0.11, 0.035, 0.028), "Head", "hair")
		if length:
			b.beam((0, 0.145, 1.545), (0, 0.155, 1.545 - length), 0.14, 0.065, "Head", "hair", taper=0.4, up=(1, 0, 0))
		out.append(b)
	return out + race_hairs()


def race_hairs():
	"""Styles the other races wear (HumanoidModel.RACE_HAIR_STYLES and
	RACE_FACES pick them per race): a tall mohawk and a topknot for Orcs and
	Trolls, stringy locks for the Undead, long flowing hair for Wood Elves,
	Hornkin manes and braids, and goatees and a beard under the Hornkin snout."""
	out = []
	b = Builder("HairMohawk")
	b.box((0, -0.01, 1.9), (0.055, 0.3, 0.2), "Head", "hair", top=(0.5, 0.75), shift=(0, -0.03))
	b.box((0, -0.15, 1.76), (0.05, 0.06, 0.22), "Head", "hair", top=(1.0, 1.4))
	out.append(b)
	b = Builder("HairTopknot")
	b.loft([((0, -0.04, 1.85), 0.045, 0.045, "Head"), ((0, -0.04, 1.96), 0.06, 0.06, "Head"),
			((0, -0.04, 2.04), 0.025, 0.025, "Head")], ["hair", "hair"], sides=6)
	b.box((0, -0.04, 1.885), (0.07, 0.07, 0.025), "Head", "trim")
	b.beam((0, -0.07, 1.98), (0, -0.2, 1.62), 0.05, 0.04, "Head", "hair", taper=0.4, up=(1, 0, 0))
	out.append(b)
	b = Builder("HairStringy")
	b.loft([((0, -0.005, 1.74), 0.13, 0.145, "Head"), ((0, -0.01, 1.82), 0.12, 0.135, "Head"),
			((0, -0.01, 1.86), 0.06, 0.07, "Head")], ["hair", "hair"], sides=8)
	for x, y, bottom in ((-0.11, 0.0, 1.5), (0.11, 0.0, 1.55), (-0.07, -0.12, 1.45), (0.06, -0.13, 1.5), (0.0, -0.14, 1.42)):
		b.beam((x, y, 1.76), (x * 1.15, y * 1.1, bottom), 0.025, 0.022, "Head", "hair", taper=0.4, up=(1, 0, 0))
	out.append(b)
	b = Builder("HairElfLong")
	hair_cap(b, 1.46, 0.5)
	for x in (-1, 1):
		b.beam((0.128 * x, 0.03, 1.74), (0.15 * x, 0.08, 1.36), 0.05, 0.035, "Head", "hair", taper=0.5, up=(0, 1, 0))
	b.box((0, 0.11, 1.81), (0.2, 0.05, 0.05), "Head", "hair", top=(0.9, 1.0))
	out.append(b)
	b = Builder("ManeShort")
	b.box((0, 0.0, 1.88), (0.14, 0.16, 0.07), "Head", "hair", top=(0.7, 0.7))
	b.beam((0, -0.09, 1.86), (0, -0.2, 1.5), 0.22, 0.08, "Head", "hair", taper=0.6, up=(1, 0, 0))
	out.append(b)
	b = Builder("ManeBraids")
	b.box((0, 0.0, 1.88), (0.14, 0.16, 0.07), "Head", "hair", top=(0.7, 0.7))
	b.beam((0, -0.09, 1.86), (0, -0.16, 1.62), 0.16, 0.06, "Head", "hair", taper=0.7, up=(1, 0, 0))
	for x in (-1, 1):
		b.beam((0.11 * x, -0.04, 1.72), (0.14 * x, 0.06, 1.36), 0.035, 0.035, "Head", "hair", taper=0.7, up=(0, 1, 0))
		b.box((0.14 * x, 0.06, 1.36), (0.04, 0.04, 0.04), "Head", "trim")
	out.append(b)
	b = Builder("BeardGoatee")
	b.beam((0, 0.125, 1.6), (0, 0.13, 1.47), 0.07, 0.05, "Head", "hair", taper=0.4, up=(1, 0, 0))
	out.append(b)
	b = Builder("BeardHornkin")
	b.beam((0, 0.17, 1.58), (0, 0.17, 1.44), 0.09, 0.06, "Head", "hair", taper=0.5, up=(1, 0, 0))
	out.append(b)
	b = Builder("BeardHornkinLong")
	b.beam((0, 0.17, 1.58), (0, 0.18, 1.32), 0.12, 0.07, "Head", "hair", taper=0.45, up=(1, 0, 0))
	b.box((0, 0.18, 1.36), (0.05, 0.05, 0.03), "Head", "trim")
	out.append(b)
	return out


class Prop:
	"""Builds a held prop from its grip `g`: Y runs along it (forward from the
	hand), Z across a blade's width (its edge up), X through its flat side."""

	def __init__(self, b, grip, bone, flip=False):
		self.b, self.g, self.bone = b, Vector(grip), bone
		# Built upside down (an axe's head on the side that leads a downward
		# chop): every Z turned over.
		self.zs = -1.0 if flip else 1.0

	def at(self, y, z=0.0, x=0.0):
		return self.g + Vector((x, y, z * self.zs))

	def tube(self, y0, y1, r0, r1, slot, sides=6, z=0.0, shade=1.0):
		self.b.tube(self.at(y0, z), self.at(y1, z), r0, r1, self.bone, slot, sides=sides, shade=shade)

	def rod(self, a, c, r0, r1, slot, sides=6, shade=1.0):
		"""A tube between two (y, z) points."""
		self.b.tube(self.at(*a), self.at(*c), r0, r1, self.bone, slot, sides=sides, shade=shade)

	def wraps(self, y0, y1, r, count, slot="strap"):
		"""Bands of wrapping round a grip."""
		step = (y1 - y0) / count
		for i in range(count):
			self.tube(y0 + step * (i + 0.1), y0 + step * (i + 0.6), r, r, slot)

	def ball(self, y, r, slot, z=0.0, sides=6, long=1.0):
		self.b.loft([(self.at(y - r * long, z), r * 0.35, r * 0.35, self.bone),
					 (self.at(y - r * 0.55 * long, z), r * 0.9, r * 0.9, self.bone),
					 (self.at(y + r * 0.55 * long, z), r * 0.9, r * 0.9, self.bone),
					 (self.at(y + r * long, z), r * 0.35, r * 0.35, self.bone)], [slot] * 3, sides=sides)

	def flat(self, outline, thick, slot, rim=None, shade=1.0, rim_shade=None, x=0.0):
		"""A flat piece (an outline of (y, z) from the grip) `thick` through."""
		pts = [(self.g.y + dy, self.g.z + dz * self.zs) for dy, dz in outline]
		self.b.plate(pts, self.g.x + x + thick / 2, self.g.x + x - thick / 2, self.bone, slot, rim,
					 shade=shade, rim_shade=rim_shade, axis=(0, 1, 0))

	def box(self, y, z, size, slot, x=0.0, shade=1.0, top=(1.0, 1.0)):
		self.b.box(self.at(y, z, x), size, self.bone, slot, shade=shade, top=top)

	def gem(self, y, z, size=0.03, x=0.0):
		self.box(y, z, (size * 1.2, size, size), "gem", x=x)


def blade_outline(y0, y1, w0, w1, tip, curve=0.0, steps=1):
	"""A blade's outline from y0 to y1 (widths w0 to w1), with a point `tip`
	long; `curve` lifts it towards the tip (a sabre's curve)."""
	top, bottom = [], []
	for i in range(steps + 1):
		t = i / steps
		y = y0 + (y1 - y0) * t
		w = w0 + (w1 - w0) * t
		c = curve * t * t
		top.append((y, c + w / 2))
		bottom.append((y, c - w / 2))
	end = (y1 + tip, curve + (w1 / 2 if curve else 0.0))
	return bottom + [end] + top[::-1]


def sword_kind(p, kind):
	if kind == "sword":
		# Arming sword: fullered blade, a crossguard turned down at its ends,
		# a wrapped grip and a wheel pommel.
		p.tube(-0.1, 0.07, 0.021, 0.021, "handle")
		p.wraps(-0.09, 0.06, 0.024, 4)
		p.b.loft([(p.at(-0.135), 0.03, 0.03, p.bone), (p.at(-0.12), 0.042, 0.042, p.bone), (p.at(-0.1), 0.03, 0.03, p.bone)],
				 ["trim", "trim"], sides=8)
		p.box(0.08, 0, (0.035, 0.035, 0.16), "trim")
		for z in (-1, 1):
			p.rod((0.08, 0.08 * z), (0.1, 0.12 * z), 0.017, 0.012, "trim")
		p.flat(blade_outline(0.1, 0.66, 0.072, 0.06, 0.12), 0.016, "blade")
		p.flat(blade_outline(0.12, 0.56, 0.016, 0.014, 0.04), 0.02, "blade", shade=0.6)
	elif kind == "sword_broad":
		# Broadsword: a wide plain blade, a straight square guard, a ring pommel.
		p.tube(-0.1, 0.07, 0.022, 0.022, "handle")
		p.wraps(-0.09, 0.06, 0.025, 3)
		p.tube(-0.14, -0.1, 0.035, 0.035, "trim", sides=8)
		p.box(0.08, 0, (0.045, 0.05, 0.2), "trim")
		p.flat(blade_outline(0.1, 0.64, 0.09, 0.085, 0.1), 0.018, "blade")
	elif kind == "sword_curved":
		# Scimitar or sabre: a blade widening and curving up to its point, a
		# small guard and a hooked pommel.
		p.tube(-0.1, 0.07, 0.021, 0.02, "handle")
		p.wraps(-0.09, 0.06, 0.023, 3)
		p.box(-0.11, -0.012, (0.04, 0.045, 0.06), "trim", top=(1.0, 0.6))
		p.box(0.08, 0, (0.035, 0.035, 0.12), "trim")
		p.flat(blade_outline(0.1, 0.62, 0.06, 0.1, 0.12, curve=0.12, steps=6), 0.014, "blade")
	elif kind == "sword_short":
		# Short sword or gladius: a broad leaf-shaped blade, a ball pommel.
		p.tube(-0.08, 0.06, 0.022, 0.022, "handle")
		p.ball(-0.11, 0.035, "trim")
		p.box(0.07, 0, (0.04, 0.04, 0.1), "trim")
		p.flat([(0.08, -0.03), (0.3, -0.045), (0.46, -0.03), (0.56, 0.0), (0.46, 0.03), (0.3, 0.045), (0.08, 0.03)],
			   0.018, "blade")
		p.flat(blade_outline(0.1, 0.4, 0.012, 0.01, 0.03), 0.022, "blade", shade=0.6)
	elif kind == "sword_ornate":
		# A fine sword: swept quillons curling towards the blade, gems in the
		# guard and pommel, a fullered blade.
		p.tube(-0.1, 0.07, 0.021, 0.021, "handle")
		p.wraps(-0.09, 0.06, 0.024, 5, "trim")
		p.ball(-0.125, 0.032, "trim")
		p.gem(-0.125, 0, 0.028)
		p.box(0.08, 0, (0.04, 0.045, 0.08), "trim")
		p.gem(0.08, 0, 0.03, x=0.012)
		for z in (-1, 1):
			p.rod((0.08, 0.035 * z), (0.06, 0.1 * z), 0.015, 0.013, "trim")
			p.rod((0.06, 0.1 * z), (0.13, 0.13 * z), 0.013, 0.008, "trim")
		p.flat(blade_outline(0.1, 0.68, 0.07, 0.055, 0.13), 0.016, "blade")
		p.flat(blade_outline(0.12, 0.58, 0.014, 0.012, 0.04), 0.02, "blade", shade=0.55)
	elif kind == "sword2h":
		# Longsword: a long grip, a wide crossguard, a ricasso, a long blade.
		p.tube(-0.24, 0.07, 0.024, 0.024, "handle")
		p.wraps(-0.22, 0.05, 0.027, 7)
		p.b.loft([(p.at(-0.29), 0.03, 0.03, p.bone), (p.at(-0.27), 0.045, 0.045, p.bone), (p.at(-0.24), 0.03, 0.03, p.bone)],
				 ["trim", "trim"], sides=8)
		p.box(0.08, 0, (0.045, 0.045, 0.3), "trim")
		p.flat(blade_outline(0.1, 1.04, 0.1, 0.08, 0.16), 0.022, "blade")
		p.flat(blade_outline(0.1, 0.2, 0.104, 0.104, 0.0), 0.026, "blade", shade=0.75)
		p.flat(blade_outline(0.22, 0.9, 0.022, 0.018, 0.05), 0.026, "blade", shade=0.6)
	elif kind == "sword2h_claymore":
		# Claymore: quillons angled up the blade, ending in rings.
		p.tube(-0.26, 0.07, 0.024, 0.024, "handle")
		p.wraps(-0.24, 0.05, 0.027, 7)
		p.ball(-0.29, 0.04, "trim")
		p.box(0.07, 0, (0.045, 0.05, 0.08), "trim")
		for z in (-1, 1):
			p.rod((0.07, 0.04 * z), (0.16, 0.2 * z), 0.018, 0.015, "trim")
			p.tube(0.15, 0.19, 0.03, 0.03, "trim", sides=6, z=0.21 * z)
		p.flat(blade_outline(0.1, 1.06, 0.095, 0.075, 0.15), 0.022, "blade")
		p.flat(blade_outline(0.12, 0.92, 0.02, 0.016, 0.05), 0.026, "blade", shade=0.6)
	elif kind == "sword2h_great":
		# Greatsword: a very wide blade with a blunt tip, parrying lugs above
		# a long ricasso.
		p.tube(-0.24, 0.07, 0.026, 0.026, "handle")
		p.wraps(-0.22, 0.05, 0.029, 6)
		p.tube(-0.3, -0.24, 0.04, 0.035, "trim", sides=8)
		p.box(0.08, 0, (0.05, 0.06, 0.34), "trim")
		p.flat(blade_outline(0.1, 0.3, 0.09, 0.09, 0.0), 0.026, "blade", shade=0.8)
		for z in (-1, 1):
			p.flat([(0.28, 0.045 * z), (0.32, 0.1 * z), (0.36, 0.1 * z), (0.36, 0.06 * z)], 0.022, "blade")
		p.flat([(0.3, -0.075), (1.0, -0.07), (1.12, -0.03), (1.12, 0.03), (1.0, 0.07), (0.3, 0.075)], 0.024, "blade")
	elif kind == "sword2h_ornate":
		# A flamberge: a wavy blade, gilt guard with gems.
		p.tube(-0.24, 0.07, 0.024, 0.024, "handle")
		p.wraps(-0.22, 0.05, 0.027, 7, "trim")
		p.ball(-0.28, 0.04, "trim")
		p.gem(-0.28, 0, 0.03)
		p.box(0.08, 0, (0.05, 0.05, 0.1), "trim")
		p.gem(0.08, 0, 0.034, x=0.016)
		for z in (-1, 1):
			p.rod((0.08, 0.05 * z), (0.05, 0.17 * z), 0.018, 0.013, "trim")
			p.ball(0.05, 0.025, "trim", z=0.18 * z)
		top, bottom = [], []
		for i in range(9):
			y = 0.1 + i * 0.11
			wave = 0.018 * math.sin(i * math.pi / 2)
			w = 0.09 - i * 0.004
			top.append((y, wave + w / 2))
			bottom.append((y, wave - w / 2))
		p.flat(bottom + [(1.12, 0.0)] + top[::-1], 0.022, "blade")


def axe_kind(p, kind):
	if kind == "axe":
		# A bearded axe: the blade hooking down below the head, a socket and a
		# poll knob behind.
		p.tube(-0.12, 0.56, 0.021, 0.019, "handle")
		p.wraps(-0.1, 0.06, 0.024, 3)
		p.tube(-0.14, -0.12, 0.026, 0.024, "trim")
		p.box(0.48, 0, (0.045, 0.1, 0.06), "trim")
		p.flat([(0.44, 0.03), (0.52, 0.03), (0.58, 0.08), (0.6, 0.17), (0.52, 0.2), (0.42, 0.19), (0.38, 0.12), (0.43, 0.06)],
			   0.022, "blade", shade=1.0, rim="blade", rim_shade=1.25)
		p.box(0.48, -0.05, (0.04, 0.05, 0.05), "trim", shade=0.8)
	elif kind == "axe_hatchet":
		# A hatchet or tomahawk: a small head on a slim haft, bound on with
		# leather.
		p.tube(-0.12, 0.5, 0.019, 0.017, "handle")
		p.wraps(0.38, 0.5, 0.022, 3)
		p.flat([(0.42, 0.02), (0.5, 0.02), (0.52, 0.06), (0.55, 0.13), (0.43, 0.13), (0.42, 0.07)], 0.02, "blade",
			   rim="blade", rim_shade=1.25)
		p.flat([(0.44, -0.02), (0.48, -0.02), (0.46, -0.08)], 0.02, "trim")
	elif kind == "axe_double":
		# A double-bitted axe: two crescents either side of the head.
		p.tube(-0.12, 0.58, 0.021, 0.019, "handle")
		p.wraps(-0.1, 0.06, 0.024, 3)
		p.box(0.48, 0, (0.05, 0.08, 0.08), "trim")
		for z in (-1, 1):
			p.flat([(0.45, 0.035 * z), (0.51, 0.035 * z), (0.58, 0.15 * z), (0.48, 0.17 * z), (0.38, 0.15 * z)],
				   0.02, "blade", rim="blade", rim_shade=1.25)
		p.box(0.6, 0, (0.03, 0.03, 0.03), "trim")
	elif kind == "axe_pick":
		# A pick: a long curved spike to the front, a flat adze behind.
		p.tube(-0.12, 0.52, 0.021, 0.019, "handle")
		p.wraps(-0.1, 0.04, 0.024, 3)
		p.box(0.47, 0, (0.045, 0.07, 0.07), "trim")
		p.rod((0.47, 0.03), (0.5, 0.15), 0.022, 0.016, "blade")
		p.rod((0.5, 0.15), (0.45, 0.27), 0.016, 0.005, "blade")
		p.rod((0.47, -0.03), (0.47, -0.12), 0.02, 0.012, "blade")
	elif kind == "axe2h":
		# A great double axe: crescents either side, a spike on top.
		p.tube(-0.35, 0.9, 0.026, 0.024, "handle")
		p.wraps(-0.33, -0.05, 0.029, 6)
		p.box(0.78, 0, (0.06, 0.12, 0.09), "trim")
		for z in (-1, 1):
			p.flat([(0.72, 0.04 * z), (0.84, 0.04 * z), (0.98, 0.26 * z), (0.78, 0.29 * z), (0.58, 0.26 * z)],
				   0.026, "blade", rim="blade", rim_shade=1.25)
		p.rod((0.84, 0.0), (1.0, 0.0), 0.02, 0.004, "trim")
	elif kind == "axe2h_bearded":
		# A great bearded axe: one huge blade and a back spike.
		p.tube(-0.35, 0.92, 0.026, 0.024, "handle")
		p.wraps(-0.33, -0.05, 0.029, 6)
		p.box(0.8, 0, (0.06, 0.13, 0.08), "trim")
		p.flat([(0.74, 0.04), (0.86, 0.04), (0.95, 0.14), (0.98, 0.3), (0.84, 0.33), (0.66, 0.3), (0.6, 0.2), (0.74, 0.1)],
			   0.028, "blade", rim="blade", rim_shade=1.25)
		p.rod((0.8, -0.04), (0.84, -0.2), 0.024, 0.005, "blade")
		p.box(0.94, 0, (0.03, 0.04, 0.03), "trim")
	elif kind == "axe2h_cleaver":
		# A cleaver: a broad square blade.
		p.tube(-0.35, 0.86, 0.026, 0.024, "handle")
		p.wraps(-0.33, -0.05, 0.029, 6)
		p.flat([(0.6, 0.03), (0.92, 0.03), (0.92, 0.3), (0.62, 0.28)], 0.026, "blade", rim="blade", rim_shade=1.25)
		for y in (0.66, 0.78, 0.88):
			p.box(y, 0.05, (0.034, 0.02, 0.02), "trim")


def mace_kind(p, kind):
	if kind == "mace":
		# A flanged mace: six flanges round the head, a knob on top.
		p.tube(-0.1, 0.5, 0.021, 0.019, "handle")
		p.wraps(-0.08, 0.06, 0.024, 3)
		p.tube(-0.13, -0.1, 0.03, 0.026, "trim")
		p.tube(0.44, 0.5, 0.03, 0.035, "trim")
		p.tube(0.5, 0.66, 0.04, 0.03, "blade")
		for k in range(6):
			a = math.tau * k / 6
			d = Vector((math.cos(a), 0, math.sin(a)))
			p.b.beam(p.at(0.5) + d * 0.04, p.at(0.66) + d * 0.04, 0.012, 0.075, p.bone, "blade", taper=0.8,
					 up=tuple(d.cross(Vector((0, 1, 0)))))
		p.ball(0.69, 0.02, "trim")
	elif kind == "mace_club":
		# A club: a knotty branch thickening to its end, nail heads in it.
		p.b.loft([(p.at(-0.12), 0.022, 0.022, p.bone), (p.at(0.2), 0.026, 0.026, p.bone),
				  (p.at(0.46), 0.05, 0.048, p.bone), (p.at(0.6), 0.055, 0.052, p.bone), (p.at(0.64), 0.035, 0.035, p.bone)],
				 ["handle", "handle", "handle", "handle"], sides=7)
		p.box(0.3, 0.03, (0.03, 0.03, 0.03), "handle", shade=0.8)
		for y, z in ((0.5, 0.05), (0.55, -0.05), (0.58, 0.02)):
			p.box(y, z, (0.018, 0.018, 0.018), "trim")
	elif kind == "mace_hammer":
		# A hammer: a square head with a spike behind.
		p.tube(-0.1, 0.52, 0.021, 0.019, "handle")
		p.wraps(-0.08, 0.06, 0.024, 3)
		p.b.beam(p.at(0.53, -0.05), p.at(0.53, 0.09), 0.075, 0.075, p.bone, "blade", up=(0, 1, 0))
		p.b.beam(p.at(0.53, 0.09), p.at(0.53, 0.11), 0.088, 0.088, p.bone, "blade", up=(0, 1, 0))
		p.b.beam(p.at(0.53, -0.012), p.at(0.53, 0.012), 0.082, 0.082, p.bone, "trim", up=(0, 1, 0))
		p.rod((0.53, -0.05), (0.54, -0.16), 0.03, 0.004, "blade")
	elif kind == "mace_spiked":
		# A morningstar: a round head studded with spikes.
		p.tube(-0.1, 0.48, 0.021, 0.019, "handle")
		p.wraps(-0.08, 0.06, 0.024, 3)
		p.tube(0.44, 0.5, 0.028, 0.032, "trim")
		p.ball(0.57, 0.065, "blade", sides=8)
		for d in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1), (0, 1, 0), (0.7, 0.4, 0.7), (-0.7, 0.4, -0.7),
				  (0.7, 0.4, -0.7), (-0.7, 0.4, 0.7)):
			v = Vector(d).normalized()
			p.b.tube(p.at(0.57) + v * 0.05, p.at(0.57) + v * 0.11, 0.016, 0.003, p.bone, "trim", sides=4)
	elif kind == "mace_scepter":
		# A scepter: a slender gilt rod, a crowned head round a gem.
		p.tube(-0.1, 0.48, 0.018, 0.016, "trim")
		p.wraps(-0.08, 0.06, 0.021, 3, "handle")
		p.ball(-0.12, 0.025, "trim")
		p.tube(0.46, 0.5, 0.022, 0.04, "trim")
		p.ball(0.56, 0.045, "gem")
		for k in range(4):
			a = math.tau * k / 4 + math.pi / 4
			d = Vector((math.cos(a), 0, math.sin(a)))
			p.b.tube(p.at(0.5) + d * 0.035, p.at(0.62) + d * 0.03, 0.01, 0.006, p.bone, "trim", sides=4)
		p.ball(0.63, 0.015, "trim")
	elif kind == "mace2h":
		# A great flanged mace.
		p.tube(-0.35, 0.85, 0.026, 0.024, "handle")
		p.wraps(-0.33, -0.05, 0.029, 6)
		p.tube(0.78, 1.02, 0.06, 0.045, "blade")
		for k in range(8):
			a = math.tau * k / 8
			d = Vector((math.cos(a), 0, math.sin(a)))
			p.b.beam(p.at(0.78) + d * 0.06, p.at(1.02) + d * 0.055, 0.016, 0.1, p.bone, "blade", taper=0.85,
					 up=tuple(d.cross(Vector((0, 1, 0)))))
		p.tube(0.74, 0.79, 0.04, 0.05, "trim")
		p.ball(1.06, 0.03, "trim")
	elif kind == "mace2h_maul":
		# A maul: a great block of a head, banded.
		p.tube(-0.35, 0.84, 0.026, 0.024, "handle")
		p.wraps(-0.33, -0.05, 0.029, 6)
		p.b.beam(p.at(0.82, -0.12), p.at(0.82, 0.12), 0.16, 0.16, p.bone, "blade", up=(0, 1, 0))
		for z in (-0.1, 0.1):
			p.b.beam(p.at(0.82, z - 0.012), p.at(0.82, z + 0.012), 0.17, 0.17, p.bone, "trim", up=(0, 1, 0))
	elif kind == "mace2h_club":
		# A great club: a heavy log with knots and iron studs.
		p.b.loft([(p.at(-0.35), 0.026, 0.026, p.bone), (p.at(0.3), 0.034, 0.034, p.bone),
				  (p.at(0.78), 0.075, 0.07, p.bone), (p.at(0.98), 0.08, 0.076, p.bone), (p.at(1.04), 0.05, 0.05, p.bone)],
				 ["handle", "handle", "handle", "handle"], sides=7)
		p.wraps(-0.33, -0.05, 0.03, 4)
		for y, z in ((0.5, 0.05), (0.62, -0.06), (0.8, 0.075), (0.86, -0.075), (0.95, 0.03), (0.92, -0.02)):
			p.box(y, z, (0.024, 0.024, 0.024), "trim")
	elif kind == "mace2h_shovel":
		# A shovel.
		p.tube(-0.35, 0.72, 0.024, 0.022, "handle")
		p.b.beam(p.at(-0.36, -0.06), p.at(-0.36, 0.06), 0.03, 0.03, p.bone, "handle", up=(0, 1, 0))
		p.tube(0.7, 0.78, 0.03, 0.034, "trim")
		p.flat([(0.76, -0.1), (1.04, -0.11), (1.12, 0.0), (1.04, 0.11), (0.76, 0.1)], 0.016, "blade")


def dagger_kind(p, kind):
	if kind == "dagger":
		p.tube(-0.08, 0.06, 0.019, 0.019, "handle")
		p.wraps(-0.07, 0.05, 0.022, 3)
		p.ball(-0.1, 0.026, "trim")
		p.box(0.065, 0, (0.03, 0.03, 0.12), "trim")
		p.flat(blade_outline(0.08, 0.26, 0.05, 0.04, 0.08), 0.014, "blade")
		p.flat(blade_outline(0.09, 0.24, 0.01, 0.008, 0.02), 0.018, "blade", shade=0.6)
	elif kind == "dagger_knife":
		# A knife: one edge, no guard, a riveted wooden grip.
		p.flat([(-0.09, -0.018), (0.06, -0.018), (0.06, 0.018), (-0.09, 0.016)], 0.034, "handle")
		for y in (-0.05, 0.02):
			p.box(y, 0, (0.038, 0.012, 0.012), "trim")
		p.flat([(0.06, -0.022), (0.2, -0.022), (0.28, 0.02), (0.06, 0.024)], 0.012, "blade")
	elif kind == "dagger_curved":
		# A curved knife, its point swept up.
		p.tube(-0.08, 0.06, 0.019, 0.019, "handle")
		p.wraps(-0.07, 0.05, 0.022, 3)
		p.box(-0.09, 0, (0.03, 0.03, 0.04), "trim")
		p.box(0.065, 0, (0.03, 0.03, 0.08), "trim")
		p.flat(blade_outline(0.07, 0.26, 0.045, 0.05, 0.07, curve=0.07, steps=5), 0.013, "blade")
	elif kind == "dagger_stiletto":
		# A stiletto: a needle blade, a ring guard.
		p.tube(-0.09, 0.06, 0.017, 0.017, "handle")
		p.wraps(-0.08, 0.05, 0.02, 4)
		p.ball(-0.11, 0.022, "trim")
		p.tube(0.06, 0.075, 0.04, 0.04, "trim", sides=8)
		p.b.beam(p.at(0.07), p.at(0.3), 0.024, 0.024, p.bone, "blade", taper=0.6)
		p.b.beam(p.at(0.3), p.at(0.36), 0.0144, 0.0144, p.bone, "blade", taper=0.05)


def staff_kind(p, kind):
	if kind == "staff":
		# A staff: shod at the foot, wrapped at the grip, a crystal held in
		# claws at its head.
		p.tube(-0.75, 0.72, 0.026, 0.024, "handle")
		p.wraps(-0.12, 0.12, 0.029, 4)
		p.tube(-0.78, -0.7, 0.03, 0.028, "trim")
		p.tube(0.68, 0.74, 0.028, 0.034, "trim")
		for k in range(3):
			a = math.tau * k / 3
			d = Vector((math.cos(a), 0, math.sin(a)))
			p.b.tube(p.at(0.73) + d * 0.025, p.at(0.84) + d * 0.045, 0.01, 0.006, p.bone, "trim", sides=4)
		p.ball(0.83, 0.045, "blade", long=1.4)
	elif kind == "staff_gnarled":
		# A gnarled staff: a crooked branch with knots, curling at the top
		# round a small stone.
		pts = [(-0.76, 0.0), (-0.4, 0.015), (0.0, -0.01), (0.35, 0.02), (0.62, 0.0), (0.78, 0.05), (0.86, 0.13),
			   (0.84, 0.21), (0.77, 0.23), (0.72, 0.19)]
		radii = [0.024, 0.025, 0.026, 0.027, 0.028, 0.026, 0.022, 0.018, 0.015, 0.012]
		for (a, ra), (c, rc) in zip(zip(pts, radii), zip(pts[1:], radii[1:])):
			p.rod(a, c, ra, rc, "handle")
		for y, z in ((-0.45, 0.02), (0.1, -0.02), (0.45, 0.025)):
			p.box(y, z, (0.04, 0.04, 0.035), "handle", shade=0.8)
		p.ball(0.79, 0.03, "blade", z=0.14)
	elif kind == "staff_quarter":
		# A quarterstaff: plain, banded with iron at both ends.
		p.tube(-0.8, 0.8, 0.026, 0.026, "handle")
		for y in (-0.8, -0.68, 0.68, 0.8):
			p.tube(y - 0.02, y + 0.02, 0.03, 0.03, "trim")
		p.wraps(-0.25, 0.25, 0.029, 5)
	elif kind == "staff_runed":
		# A runed staff: a dark shaft with gilt bands, a crescent fork at the
		# head cradling an orb.
		p.tube(-0.75, 0.68, 0.025, 0.024, "handle")
		for y in (-0.5, -0.2, 0.2, 0.45):
			p.tube(y - 0.012, y + 0.012, 0.03, 0.03, "trim")
		p.tube(-0.8, -0.72, 0.022, 0.03, "trim")
		p.tube(0.66, 0.72, 0.03, 0.04, "trim")
		for z in (-1, 1):
			p.rod((0.72, 0.02 * z), (0.82, 0.1 * z), 0.018, 0.014, "trim")
			p.rod((0.82, 0.1 * z), (0.95, 0.07 * z), 0.014, 0.006, "trim")
		p.ball(0.85, 0.055, "blade")


def polearm_kind(p, kind):
	p.tube(-0.7, 0.95, 0.025, 0.024, "handle")
	p.wraps(-0.1, 0.15, 0.028, 4)
	p.tube(-0.74, -0.68, 0.028, 0.026, "trim")
	if kind == "polearm":
		# A spear: a leaf blade on a socket, a binding under it.
		p.tube(0.88, 0.98, 0.03, 0.026, "trim")
		p.wraps(0.8, 0.88, 0.029, 2)
		p.flat([(0.97, -0.02), (1.1, -0.06), (1.24, -0.03), (1.36, 0.0), (1.24, 0.03), (1.1, 0.06), (0.97, 0.02)],
			   0.02, "blade")
	elif kind == "polearm_halberd":
		# A halberd: an axe blade, a spike on top and a hook behind.
		p.tube(0.86, 1.08, 0.03, 0.028, "trim")
		p.flat([(0.9, 0.03), (1.06, 0.03), (1.1, 0.12), (1.06, 0.22), (0.86, 0.2), (0.86, 0.1)], 0.022, "blade",
			   rim="blade", rim_shade=1.25)
		p.flat([(1.06, -0.015), (1.38, 0.0), (1.06, 0.015)], 0.026, "blade")
		p.flat([(0.96, -0.03), (1.0, -0.03), (1.08, -0.16), (1.02, -0.13)], 0.02, "blade")
	elif kind == "polearm_glaive":
		# A glaive: a long single-edged blade curving back at its point.
		p.tube(0.9, 1.0, 0.03, 0.03, "trim")
		p.flat(blade_outline(0.98, 1.34, 0.07, 0.09, 0.08, curve=-0.06, steps=5), 0.02, "blade")
		p.flat([(1.02, 0.03), (1.08, 0.08), (1.1, 0.03)], 0.02, "blade")


def small_kind(p, kind):
	if kind == "wand":
		p.tube(-0.06, 0.24, 0.016, 0.012, "handle")
		p.wraps(-0.05, 0.05, 0.019, 3, "trim")
		p.tube(0.23, 0.27, 0.014, 0.022, "trim")
		p.ball(0.3, 0.025, "blade", long=1.5)
	elif kind == "wand_twisted":
		# A twisted wand of bone or root, a claw holding a stone.
		for i in range(5):
			y0, y1 = -0.06 + i * 0.06, 0.0 + i * 0.06
			p.rod((y0, 0.008 * (-1) ** i), (y1, 0.008 * (-1) ** (i + 1)), 0.017 - i * 0.001, 0.016 - i * 0.001, "handle")
		for k in range(3):
			a = math.tau * k / 3
			d = Vector((math.cos(a), 0, math.sin(a)))
			p.b.tube(p.at(0.24), p.at(0.3) + d * 0.03, 0.008, 0.004, p.bone, "trim", sides=4)
		p.ball(0.29, 0.022, "blade")
	elif kind == "fist":
		# A fist weapon: a knuckle plate on a grip bar, three claws.
		p.box(0.03, 0, (0.03, 0.03, 0.12), "handle")
		p.box(0.08, 0, (0.11, 0.05, 0.15), "blade")
		p.box(0.08, 0, (0.115, 0.03, 0.1), "trim")
		for z in (-0.045, 0.0, 0.045):
			p.flat([(0.1, z - 0.012), (0.24, z - 0.004), (0.26, z), (0.1, z + 0.012)], 0.016, "blade")
	elif kind == "orb":
		# An orb in a gilt cage on a short stem.
		p.tube(-0.09, 0.0, 0.016, 0.02, "trim")
		p.ball(0.06, 0.06, "blade", sides=8)
		for k in range(4):
			a = math.tau * k / 4
			d = Vector((math.cos(a), 0, math.sin(a)))
			p.b.tube(p.at(0.0) + d * 0.02, p.at(0.06) + d * 0.066, 0.007, 0.007, p.bone, "trim", sides=4)
			p.b.tube(p.at(0.06) + d * 0.066, p.at(0.12) + d * 0.02, 0.007, 0.007, p.bone, "trim", sides=4)
	elif kind == "orb_tome":
		# A book held in the hand: boards, pages, a clasp and a gem.
		p.box(0.06, 0.02, (0.05, 0.22, 0.17), "blade")
		p.box(0.065, 0.02, (0.04, 0.2, 0.155), "emblem")
		p.box(-0.05, 0.02, (0.058, 0.016, 0.17), "trim")
		p.gem(0.06, 0.02, 0.03, x=0.03)
	elif kind == "orb_stein":
		# A stein: a lidded tankard.
		p.tube(-0.02, 0.14, 0.05, 0.045, "handle", sides=8)
		for y in (0.0, 0.12):
			p.tube(y - 0.008, y + 0.008, 0.053, 0.053, "trim", sides=8)
		p.tube(0.14, 0.16, 0.052, 0.04, "trim", sides=8)
		p.rod((0.02, -0.05), (0.12, -0.05), 0.01, 0.01, "trim")
	elif kind == "orb_rod":
		# A short rod of carved wood, knobbed, a gem set in its head.
		p.tube(-0.1, 0.2, 0.017, 0.014, "handle")
		for y in (-0.06, 0.06, 0.16):
			p.tube(y - 0.01, y + 0.01, 0.022, 0.022, "trim")
		p.ball(0.24, 0.03, "blade")


WEAPON_KINDS = {
	"sword": ["sword", "sword_broad", "sword_curved", "sword_short", "sword_ornate"],
	"sword2h": ["sword2h", "sword2h_claymore", "sword2h_great", "sword2h_ornate"],
	"axe": ["axe", "axe_hatchet", "axe_double", "axe_pick"],
	"axe2h": ["axe2h", "axe2h_bearded", "axe2h_cleaver"],
	"mace": ["mace", "mace_club", "mace_hammer", "mace_spiked", "mace_scepter"],
	"mace2h": ["mace2h", "mace2h_maul", "mace2h_club", "mace2h_shovel"],
	"dagger": ["dagger", "dagger_knife", "dagger_curved", "dagger_stiletto"],
	"staff": ["staff", "staff_gnarled", "staff_quarter", "staff_runed"],
	"polearm": ["polearm", "polearm_halberd", "polearm_glaive"],
	"wand": ["wand", "wand_twisted"],
	"fist": ["fist"],
	"orb": ["orb", "orb_tome", "orb_stein", "orb_rod"],
}
WEAPON_BUILDERS = {
	"sword": sword_kind, "sword2h": sword_kind, "axe": axe_kind, "axe2h": axe_kind, "mace": mace_kind,
	"mace2h": mace_kind, "dagger": dagger_kind, "staff": staff_kind, "polearm": polearm_kind,
	"wand": small_kind, "fist": small_kind, "orb": small_kind,
}


def weapon(name, grip, bone, kind):
	"""A prop along +Y from the grip point: one of WEAPON_KINDS' shapes."""
	b = Builder(name)
	family = next(f for f, kinds in WEAPON_KINDS.items() if kind in kinds)
	# Axes' heads face down when held out, as their edge leads a chop.
	WEAPON_BUILDERS[family](Prop(b, grip, bone, flip=family in ("axe", "axe2h")), kind)
	return b


def shield(name, kind):
	"""Shields on the left forearm, their face to the outside (-X)."""
	b = Builder(name)
	x0, x1 = SHIELD_AT.x, SHIELD_AT.x - 0.04
	y, z = SHIELD_AT.y, SHIELD_AT.z
	face = x1 - 0.004

	def outline_ring(pts, width, slot="shield_trim"):
		"""A raised rim round an outline."""
		for (ay, az), (cy, cz) in zip(pts, pts[1:] + pts[:1]):
			b.beam((face, ay, az), (face, cy, cz), width, 0.02, "ShieldL", slot, up=(1, 0, 0))

	def circle(r, n=12, cy=0.0, cz=0.0):
		return [(y + cy + r * math.cos(a), z + cz + r * math.sin(a)) for a in (math.tau * k / n + math.pi / n for k in range(n))]

	def boss(r, h, slot="shield_trim", cy=0.0, cz=0.0, spike=0.0):
		b.loft([((face + 0.004, y + cy, z + cz), r, r, "ShieldL"), ((face - h * 0.6, y + cy, z + cz), r * 0.8, r * 0.8, "ShieldL"),
				((face - h, y + cy, z + cz), r * 0.35, r * 0.35, "ShieldL")], [slot, slot], sides=8)
		if spike:
			b.tube((face - h, y + cy, z + cz), (face - h - spike, y + cy, z + cz), r * 0.3, 0.004, "ShieldL", slot, sides=4)

	def rivets(pts, slot="shield_trim"):
		for py, pz in pts:
			b.box((face - 0.008, py, pz), (0.016, 0.022, 0.022), "ShieldL", slot)

	if kind == "round":
		# Boards behind an iron rim, a domed boss, rivets round the edge.
		pts = circle(0.29)
		b.plate(pts, x0, x1, "ShieldL", "shield", "shield_trim", axis=(0, 0, 1))
		outline_ring(pts, 0.035)
		boss(0.085, 0.05)
		rivets(circle(0.22, 8))
		b.box((x0 + 0.02, y, z), (0.03, 0.2, 0.04), "ShieldL", "strap")
	elif kind == "kite":
		# A kite shield: a long point below, a painted cross, rimmed.
		pts = [(y - 0.22, z + 0.3), (y + 0.22, z + 0.3), (y + 0.21, z + 0.02), (y + 0.12, z - 0.24), (y, z - 0.45),
			   (y - 0.12, z - 0.24), (y - 0.21, z + 0.02)]
		b.plate(pts, x0, x1, "ShieldL", "shield", "shield_trim", axis=(0, 0, 1))
		outline_ring(pts, 0.03)
		b.box((face - 0.002, y, z - 0.04), (0.006, 0.08, 0.6), "ShieldL", "emblem")
		b.box((face - 0.002, y, z + 0.1), (0.006, 0.36, 0.08), "ShieldL", "emblem")
	elif kind == "heater":
		# A heater: flat top, curving to a point, a painted band across.
		pts = [(y - 0.23, z + 0.27), (y + 0.23, z + 0.27), (y + 0.22, z), (y + 0.16, z - 0.18), (y, z - 0.33),
			   (y - 0.16, z - 0.18), (y - 0.22, z)]
		b.plate(pts, x0, x1, "ShieldL", "shield", "shield_trim", axis=(0, 0, 1))
		outline_ring(pts, 0.03)
		b.plate([(y - 0.22, z + 0.12), (y + 0.22, z + 0.12), (y + 0.22, z + 0.02), (y - 0.22, z + 0.02)],
				face, face - 0.006, "ShieldL", "emblem")
		boss(0.05, 0.03, cz=-0.06)
	elif kind == "buckler":
		# A buckler: small and all metal, a spiked boss, a raised rim.
		pts = circle(0.17)
		b.plate(pts, x0, x1, "ShieldL", "shield_trim", "shield_trim", axis=(0, 0, 1))
		outline_ring(pts, 0.025, "shield")
		boss(0.07, 0.05, slot="shield", spike=0.06)
	elif kind == "tower":
		# A tower shield: tall and squared, boards banded with iron.
		pts = [(y - 0.2, z + 0.36), (y + 0.2, z + 0.36), (y + 0.21, z - 0.42), (y - 0.21, z - 0.42)]
		b.plate(pts, x0, x1 + 0.01, "ShieldL", "shield", "shield_trim", axis=(0, 0, 1))
		outline_ring(pts, 0.035)
		for bz in (z + 0.18, z - 0.24):
			b.beam((face, y - 0.2, bz), (face, y + 0.2, bz), 0.04, 0.016, "ShieldL", "shield_trim", up=(0, 0, 1))
		boss(0.06, 0.035)
		rivets([(y + dy, z + dz) for dy in (-0.16, 0.16) for dz in (0.3, 0.0, -0.36)])
	return b


def helms():
	"""Head pieces by armour type, two or more shapes each, and a mask. Hair is
	hidden under all but the circlet."""
	out = []
	# Cloth: a hood, its point falling back; and a wide-brimmed hat.
	b = Builder("Helm_hood")
	b.loft([((0, 0.0, 1.73), 0.152, 0.165, "Head"), ((0, -0.02, 1.84), 0.148, 0.158, "Head"),
			((0, -0.05, 1.9), 0.09, 0.1, "Head"), ((0, -0.1, 1.92), 0.04, 0.05, "Head")], ["head", "head", "head"], sides=8)
	for x in (-1, 1):
		b.box((0.145 * x, -0.005, 1.66), (0.04, 0.22, 0.2), "Head", "head", top=(1.0, 1.0))
	b.box((0, -0.12, 1.6), (0.3, 0.07, 0.3), "Head", "head", top=(0.9, 1.0))
	b.loft([((0, -0.02, 1.44), 0.23, 0.18, "Head"), ((0, -0.02, 1.54), 0.15, 0.13, "Head")], ["head"], sides=8)
	out.append(b)
	b = Builder("Helm_hat")
	b.loft([((0, 0.0, 1.76), 0.27, 0.28, "Head"), ((0, 0.0, 1.78), 0.27, 0.28, "Head")], ["head"], sides=10)
	b.loft([((0, 0.0, 1.77), 0.145, 0.155, "Head"), ((0, -0.01, 1.86), 0.12, 0.13, "Head"),
			((0, -0.03, 1.98), 0.05, 0.06, "Head"), ((0, -0.08, 2.03), 0.015, 0.015, "Head")], ["head", "head", "head"], sides=8)
	b.loft([((0, 0.0, 1.785), 0.15, 0.16, "Head"), ((0, 0.0, 1.81), 0.14, 0.15, "Head")], ["helm_trim"], sides=8)
	out.append(b)
	# Leather: a cap with a stitched band; a cap with ear flaps.
	b = Builder("Helm_cap")
	b.loft([((0, -0.005, 1.74), 0.145, 0.158, "Head"), ((0, -0.01, 1.82), 0.142, 0.152, "Head"),
			((0, -0.01, 1.885), 0.08, 0.09, "Head")], ["head", "head"], sides=8)
	b.loft([((0, 0.0, 1.735), 0.17, 0.18, "Head"), ((0, 0.0, 1.755), 0.17, 0.18, "Head")], ["helm_trim"], sides=8)
	out.append(b)
	b = Builder("Helm_capflaps")
	b.loft([((0, -0.005, 1.74), 0.15, 0.162, "Head"), ((0, -0.01, 1.83), 0.145, 0.155, "Head"),
			((0, -0.01, 1.89), 0.085, 0.095, "Head")], ["head", "head"], sides=8)
	for x in (-1, 1):
		b.box((0.148 * x, 0.0, 1.66), (0.035, 0.11, 0.17), "Head", "head", top=(1.0, 0.8))
		b.box((0.15 * x, 0.0, 1.58), (0.03, 0.03, 0.03), "Head", "strap")
	b.box((0, -0.13, 1.68), (0.26, 0.04, 0.12), "Head", "head")
	b.loft([((0, 0.0, 1.745), 0.168, 0.178, "Head"), ((0, 0.0, 1.765), 0.168, 0.178, "Head")], ["strap"], sides=8)
	out.append(b)
	# Mail: a coif; a conical helm with a nasal over a coif.
	coif = [((0, -0.01, 1.74), 0.148, 0.16, "Head"), ((0, -0.015, 1.84), 0.142, 0.152, "Head"),
			((0, -0.02, 1.895), 0.08, 0.095, "Head")]
	b = Builder("Helm_coif")
	b.loft(coif, ["head", "head"], sides=8)
	for x in (-1, 1):
		b.box((0.138 * x, 0.0, 1.64), (0.035, 0.22, 0.24), "Head", "head")
	b.box((0, 0.1, 1.575), (0.26, 0.06, 0.07), "Head", "head")
	b.loft([((0, -0.01, 1.44), 0.2, 0.16, "Head"), ((0, -0.01, 1.6), 0.14, 0.14, "Head")], ["head"], sides=8)
	b.loft([((0, 0.0, 1.745), 0.152, 0.164, "Head"), ((0, 0.0, 1.765), 0.152, 0.164, "Head")], ["strap"], sides=8)
	out.append(b)
	b = Builder("Helm_nasal")
	b.loft(coif[:1] + [((0, -0.015, 1.8), 0.142, 0.152, "Head")], ["head"], sides=8)
	for x in (-1, 1):
		b.box((0.138 * x, 0.0, 1.64), (0.035, 0.22, 0.24), "Head", "head")
	b.loft([((0, -0.01, 1.44), 0.2, 0.16, "Head"), ((0, -0.01, 1.6), 0.14, 0.14, "Head")], ["head"], sides=8)
	b.loft([((0, 0.0, 1.76), 0.158, 0.17, "Head"), ((0, -0.005, 1.86), 0.13, 0.14, "Head"),
			((0, -0.01, 1.98), 0.02, 0.02, "Head")], ["helm_trim", "helm_trim"], sides=8)
	b.loft([((0, 0.0, 1.755), 0.165, 0.176, "Head"), ((0, 0.0, 1.78), 0.165, 0.176, "Head")], ["strap"], sides=8)
	b.box((0, 0.172, 1.7), (0.03, 0.016, 0.12), "Head", "helm_trim")
	out.append(b)
	# Plate: a closed great helm with a crest ridge and breaths; a visored
	# sallet with a plume. Open-faced races wear the open helm.
	b = Builder("Helm_plate")
	b.loft([((0, 0.0, 1.53), 0.12, 0.13, "Head"), ((0, 0.005, 1.6), 0.155, 0.17, "Head"),
			((0, 0.0, 1.8), 0.155, 0.17, "Head"), ((0, -0.005, 1.9), 0.09, 0.1, "Head")], ["head", "head", "head"], sides=8)
	b.box((0, 0.168, 1.71), (0.21, 0.02, 0.022), "Head", "eyes")
	b.box((0, 0.17, 1.65), (0.022, 0.02, 0.09), "Head", "helm_trim")
	for x in (-1, 1):
		for dz in (0.0, 0.03):
			b.box((0.06 * x, 0.16, 1.6 + dz), (0.03, 0.016, 0.01), "Head", "eyes")
	b.box((0, -0.005, 1.905), (0.035, 0.32, 0.06), "Head", "helm_trim")
	b.loft([((0, 0.0, 1.595), 0.16, 0.175, "Head"), ((0, 0.0, 1.615), 0.16, 0.175, "Head")], ["helm_trim"], sides=8)
	out.append(b)
	b = Builder("Helm_plate_visor")
	b.loft([((0, -0.01, 1.55), 0.14, 0.15, "Head"), ((0, 0.0, 1.62), 0.155, 0.17, "Head"),
			((0, -0.005, 1.82), 0.15, 0.165, "Head"), ((0, -0.03, 1.9), 0.09, 0.11, "Head")], ["head", "head", "head"], sides=8)
	b.box((0, -0.16, 1.62), (0.24, 0.08, 0.06), "Head", "head", top=(1.0, 1.6))
	b.box((0, 0.175, 1.7), (0.24, 0.05, 0.14), "Head", "head", top=(0.9, 0.6))
	b.box((0, 0.2, 1.715), (0.2, 0.02, 0.018), "Head", "eyes")
	for x in (-1, 1):
		b.box((0.155 * x, 0.03, 1.7), (0.03, 0.04, 0.04), "Head", "helm_trim")
	b.tube((0, -0.03, 1.9), (0, -0.04, 1.97), 0.02, 0.02, "Head", "helm_trim")
	b.loft([((0, -0.04, 1.96), 0.03, 0.04, "Head"), ((0, -0.12, 2.04), 0.045, 0.07, "Head"),
			((0, -0.26, 1.98), 0.03, 0.04, "Head"), ((0, -0.32, 1.86), 0.01, 0.015, "Head")], ["emblem"] * 3, sides=6)
	out.append(b)
	b = Builder("Helm_plate_open")
	b.loft([((0, -0.005, 1.73), 0.152, 0.166, "Head"), ((0, -0.01, 1.82), 0.15, 0.162, "Head"),
			((0, -0.01, 1.9), 0.09, 0.1, "Head")], ["head", "head"], sides=8)
	b.loft([((0, 0.0, 1.725), 0.165, 0.178, "Head"), ((0, 0.0, 1.75), 0.165, 0.178, "Head")], ["helm_trim"], sides=8)
	for x in (-1, 1):
		b.box((0.15 * x, 0.02, 1.64), (0.035, 0.12, 0.16), "Head", "head", top=(1.0, 0.8))
	b.box((0, -0.13, 1.6), (0.26, 0.06, 0.24), "Head", "head", top=(0.9, 1.0))
	b.box((0, -0.005, 1.9), (0.04, 0.3, 0.05), "Head", "helm_trim")
	out.append(b)
	# A brigand's mask: a cloth over the lower face, knotted behind, and a
	# head wrap.
	b = Builder("Helm_mask")
	b.loft([((0, -0.005, 1.74), 0.148, 0.16, "Head"), ((0, -0.01, 1.83), 0.143, 0.153, "Head"),
			((0, -0.02, 1.88), 0.09, 0.1, "Head")], ["head", "head"], sides=8)
	b.loft([((0, 0.005, 1.58), 0.135, 0.15, "Head"), ((0, 0.01, 1.675), 0.142, 0.158, "Head")], ["head"], sides=8)
	b.box((0, -0.16, 1.72), (0.05, 0.06, 0.05), "Head", "head")
	b.box((0, -0.19, 1.66), (0.05, 0.03, 0.12), "Head", "head", top=(0.6, 1.0))
	out.append(b)
	return out


def shoulders():
	"""Shoulder pieces by armour type: a rolled cloth mantle, layered leather,
	mail over a leather cap, and plate pauldrons."""
	out = []
	for kind in ("cloth", "leather", "mail", "plate"):
		b = Builder("Shoulders_" + kind)
		for side, x in (("Right", 1), ("Left", -1)):
			c = Vector(_side(x, (0.31, 0, 1.43)))
			bone = side + "Shoulder"
			if kind == "cloth":
				b.loft([(c + Vector((0, 0, -0.06)), 0.115, 0.115, bone), (c + Vector((0.01 * x, 0, 0.02)), 0.125, 0.12, bone),
						(c + Vector((0, 0, 0.065)), 0.07, 0.07, bone)], ["shoulders", "shoulders"], sides=8)
				b.loft([(c + Vector((-0.12 * x, 0, 0.06)), 0.035, 0.035, bone), (c + Vector((0.02 * x, 0, 0.075)), 0.045, 0.045, bone)],
					   ["helm_trim"], sides=6)
				for dy in (-0.06, 0.0, 0.06):
					b.box(c + Vector((0.11 * x, dy, -0.09)), (0.02, 0.025, 0.05), bone, "helm_trim")
			elif kind == "leather":
				for i, (dz, r) in enumerate(((0.06, 0.1), (0.0, 0.12), (-0.06, 0.125))):
					b.loft([(c + Vector((0.015 * i * x, 0, dz - 0.035)), r, r * 0.95, bone),
							(c + Vector((0.015 * i * x, 0, dz + 0.025)), r * 0.85, r * 0.8, bone)], ["shoulders"], sides=8,
						   shade=1.0 - 0.08 * i)
				b.box(c + Vector((-0.06 * x, 0, 0.09)), (0.12, 0.04, 0.02), bone, "strap")
				b.box(c + Vector((0.02 * x, 0, 0.09)), (0.03, 0.045, 0.03), bone, "trim")
			elif kind == "mail":
				b.loft([(c + Vector((0, 0, 0.02)), 0.12, 0.12, bone), (c + Vector((0, 0, 0.08)), 0.075, 0.075, bone)],
					   ["strap"], sides=8)
				b.loft([(c + Vector((0.01 * x, 0, -0.1)), 0.13, 0.125, bone), (c + Vector((0.005 * x, 0, 0.02)), 0.125, 0.12, bone)],
					   ["shoulders"], sides=8)
				b.loft([(c + Vector((0, 0, 0.015)), 0.128, 0.126, bone), (c + Vector((0, 0, 0.035)), 0.128, 0.126, bone)],
					   ["trim"], sides=8)
			else:
				for i, (dz, r) in enumerate(((0.07, 0.11), (0.0, 0.135), (-0.07, 0.14))):
					b.loft([(c + Vector((0.02 * i * x, 0, dz - 0.04)), r, r * 0.95, bone),
							(c + Vector((0.02 * i * x, 0, dz + 0.03)), r * 0.9, r * 0.85, bone)], ["shoulders"], sides=8,
						   shade=1.05 - 0.07 * i)
					b.loft([(c + Vector((0.02 * i * x, 0, dz - 0.045)), r + 0.006, r * 0.95 + 0.006, bone),
							(c + Vector((0.02 * i * x, 0, dz - 0.035)), r + 0.006, r * 0.95 + 0.006, bone)], ["helm_trim"], sides=8)
				b.beam(c + Vector((-0.05 * x, -0.06, 0.1)), c + Vector((-0.05 * x, 0.06, 0.1)), 0.05, 0.02, bone, "helm_trim")
				for dy in (-0.07, 0.07):
					b.box(c + Vector((0.12 * x, dy, 0.0)), (0.02, 0.02, 0.02), bone, "helm_trim")
		out.append(b)
	return out


def cloak():
	"""A cloak from the shoulders to the knees: a thin sheet hung on the three
	cape chains (CAPE_CHAINS) that the springs swing. Down its length a row
	at the middle of each bone and one at each joint shared half and half
	between the bones meeting there; across its width columns shared between
	the chains on either side by how near they are; so it curves and ripples
	like cloth rather than bending as a board. The top row is held by the
	chest."""
	b = Builder("Cloak")
	bones = len(CAPE_POINTS) - 1
	# Rows: (height point, {bone index: weight}), index -1 for the chest.
	rows = [((0, -0.1, 1.49), {-1: 1.0})]
	for i in range(bones):
		top, bottom = Vector(CAPE_POINTS[i]), Vector(CAPE_POINTS[i + 1])
		if i > 0:
			rows.append((tuple(top), {i - 1: 0.5, i: 0.5}))
		rows.append((tuple((top + bottom) / 2), {i: 1.0}))
	rows.append((CAPE_POINTS[-1], {bones - 1: 1.0}))
	columns = [-1.0, -0.5, 0.0, 0.5, 1.0]
	chains = sorted(CAPE_CHAINS.items(), key=lambda kv: kv[1])

	def column_weights(u):
		for (a, ua), (c, uc) in zip(chains, chains[1:]):
			if ua <= u <= uc:
				t = (u - ua) / (uc - ua)
				return [(a, 1.0 - t), (c, t)]
		return [(chains[-1][0], 1.0)]

	def weights(row, u):
		out = {}
		for index, wr in row[1].items():
			if index < 0:
				out["Chest"] = out.get("Chest", 0.0) + wr
				continue
			for chain, wc in column_weights(u):
				if wc * wr > 0.0:
					name = f"Cape{chain}{index + 1}"
					out[name] = out.get(name, 0.0) + wc * wr
		return tuple(out.items())

	half = 0.0075
	grid = []
	for row in rows:
		x0, y, z = row[0]
		width = 0.2 if row[1].get(-1) else cape_half_width(z)
		line = []
		for u in columns:
			line.append(((u * width, y + half, z), (u * width, y - half, z), weights(row, u)))
		grid.append(line)
	verts, groups, faces = [], [], []
	index = {}
	for r, line in enumerate(grid):
		for c, (outer, inner, w) in enumerate(line):
			for side, point in ((0, outer), (1, inner)):
				index[(r, c, side)] = len(verts)
				verts.append(point)
				groups.append(w)
	last_r, last_c = len(grid) - 1, len(columns) - 1
	for r in range(last_r):
		for c in range(last_c):
			faces.append([index[(r, c, 0)], index[(r + 1, c, 0)], index[(r + 1, c + 1, 0)], index[(r, c + 1, 0)]])
			faces.append([index[(r, c, 1)], index[(r, c + 1, 1)], index[(r + 1, c + 1, 1)], index[(r + 1, c, 1)]])
	# Close the edges so the sheet is a thin solid.
	for r in range(last_r):
		for c in (0, last_c):
			faces.append([index[(r, c, 0)], index[(r, c, 1)], index[(r + 1, c, 1)], index[(r + 1, c, 0)]])
	for c in range(last_c):
		for r in (0, last_r):
			faces.append([index[(r, c, 0)], index[(r, c + 1, 0)], index[(r, c + 1, 1)], index[(r, c, 1)]])
	b._add(verts, groups, faces, ["back"] * len(faces), [1.0] * len(faces))
	for x in (-1, 1):
		b.box((0.17 * x, -0.04, 1.47), (0.06, 0.06, 0.05), "Chest", "trim")
	return b


def ranged():
	"""Ranged weapons, drawn while shooting: bows in the left hand, guns,
	crossbows and throwing weapons in the right."""
	out = []

	def bow(name, half, bend, recurve):
		b = Builder(name)
		g = GRIP_L
		ys = [half * t for t in (-1.0, -0.8, -0.55, -0.3, -0.1, 0.1, 0.3, 0.55, 0.8, 1.0)]
		pts = []
		for y in ys:
			t = abs(y) / half
			z = bend * t * t - (recurve * max(0.0, t - 0.8) / 0.2 if recurve else 0.0)
			pts.append((y, z))
		for (y0, z0), (y1, z1) in zip(pts, pts[1:]):
			w = 0.045 - 0.02 * abs(y0 + y1) / (2 * half)
			b.beam(g + Vector((0, y0, z0)), g + Vector((0, y1, z1)), w, 0.032, "WeaponL", "ranged", up=(1, 0, 0))
		p = Prop(b, g, "WeaponL")
		p.wraps(-0.08, 0.08, 0.03, 4)
		b.beam(g + Vector((0, pts[0][0], pts[0][1] + 0.01)), g + Vector((0, pts[-1][0], pts[-1][1] + 0.01)), 0.01, 0.01,
			   "WeaponL", "ranged_trim", up=(1, 0, 0))
		for y, z in (pts[0], pts[-1]):
			b.box(g + Vector((0, y, z)), (0.03, 0.03, 0.03), "WeaponL", "ranged_trim")
		return b

	out.append(bow("Ranged_bow", 0.52, 0.14, 0.06))
	out.append(bow("Ranged_longbow", 0.72, 0.12, 0.0))
	g = GRIP_R
	# A rifle: a wooden stock, a long barrel bound to it, the lock.
	b = Builder("Ranged_gun")
	p = Prop(b, g, "WeaponR")
	p.flat([(-0.34, -0.1), (-0.12, -0.04), (-0.02, -0.04), (0.4, 0.0), (0.4, 0.04), (-0.05, 0.04), (-0.34, 0.0)], 0.05, "ranged")
	p.tube(-0.05, 0.62, 0.02, 0.018, "ranged_trim", z=0.05)
	for y in (0.15, 0.35):
		p.tube(y - 0.012, y + 0.012, 0.03, 0.03, "ranged_trim", z=0.035)
	p.box(-0.02, 0.05, (0.04, 0.06, 0.04), "ranged_trim")
	p.box(0.62, 0.075, (0.012, 0.02, 0.025), "ranged_trim")
	out.append(b)
	# A blunderbuss: a short stock and a barrel flaring to a bell.
	b = Builder("Ranged_blunderbuss")
	p = Prop(b, g, "WeaponR")
	p.flat([(-0.28, -0.11), (-0.1, -0.04), (0.0, -0.04), (0.3, 0.0), (0.3, 0.04), (-0.05, 0.04), (-0.28, 0.0)], 0.055, "ranged")
	p.b.loft([(p.at(-0.04, 0.05), 0.024, 0.024, p.bone), (p.at(0.36, 0.05), 0.026, 0.026, p.bone),
			  (p.at(0.46, 0.05), 0.045, 0.045, p.bone), (p.at(0.5, 0.05), 0.06, 0.06, p.bone)], ["ranged_trim"] * 3, sides=8)
	p.box(-0.02, 0.05, (0.045, 0.06, 0.04), "ranged_trim")
	p.tube(0.2, 0.22, 0.032, 0.032, "ranged_trim", z=0.045)
	out.append(b)
	# A crossbow: a stock, a bow across its front, the string drawn back.
	b = Builder("Ranged_crossbow")
	p = Prop(b, g, "WeaponR")
	p.flat([(-0.3, -0.07), (-0.05, -0.03), (0.42, 0.0), (0.42, 0.04), (-0.3, 0.02)], 0.05, "ranged")
	for z in (-1, 1):
		b.beam(p.at(0.4, 0.03), p.at(0.33, 0.03, 0.28 * z), 0.03, 0.02, "WeaponR", "ranged_trim", up=(0, 1, 0))
		b.beam(p.at(0.33, 0.03, 0.28 * z), p.at(0.1, 0.035), 0.008, 0.008, "WeaponR", "strap", up=(0, 1, 0))
	p.tube(0.42, 0.46, 0.035, 0.035, "ranged_trim", sides=6, z=0.02)
	p.box(0.05, -0.04, (0.012, 0.02, 0.06), "ranged_trim")
	out.append(b)
	b = Builder("Ranged_thrown")
	p = Prop(b, g, "WeaponR")
	p.tube(-0.06, 0.04, 0.017, 0.017, "handle")
	p.wraps(-0.05, 0.03, 0.02, 2)
	p.tube(-0.08, -0.06, 0.022, 0.022, "ranged_trim", sides=8)
	p.flat(blade_outline(0.04, 0.16, 0.05, 0.04, 0.07), 0.012, "ranged_trim")
	out.append(b)
	b = Builder("Ranged_thrown_axe")
	p = Prop(b, g, "WeaponR", flip=True)
	p.tube(-0.08, 0.26, 0.016, 0.015, "handle")
	p.flat([(0.2, 0.02), (0.27, 0.02), (0.3, 0.11), (0.2, 0.12), (0.18, 0.06)], 0.018, "ranged_trim")
	out.append(b)
	return out


ONE_HANDED = ["sword", "axe", "mace", "dagger", "fist"]


def held_props():
	"""Every weapon shape in the right hand; one-handers and off-hand items in
	the left (Off_...); and the shields."""
	out = []
	for family, kinds in WEAPON_KINDS.items():
		if family == "orb":
			continue
		for kind in kinds:
			out.append(weapon("Main_" + kind, GRIP_R, "WeaponR", kind))
	for family, kinds in WEAPON_KINDS.items():
		if family not in ONE_HANDED and family != "orb":
			continue
		for kind in kinds:
			b = weapon("Off_" + kind, GRIP_L, "WeaponL", kind)
			# Off-hand weapons take the off-hand colour slots: blade and trim
			# become shield_trim and shield.
			swap = {SLOT["blade"]: SLOT["shield_trim"], SLOT["trim"]: SLOT["shield"]}
			b.face_uv = [((swap.get(int(u * SLOT_COUNT), int(u * SLOT_COUNT)) + 0.5) / SLOT_COUNT, v) for u, v in b.face_uv]
			out.append(b)
	for kind in ("round", "kite", "heater", "buckler", "tower"):
		out.append(shield("Shield_" + kind, kind))
	return out


def props():
	return held_props() + helms() + [cloak()] + ranged()

# ---------------------------------------------------------------- animation

def both(part, rot):
	"""The right-side entry and its mirror for the left."""
	x, y, z = rot
	return {"Right" + part: (x, y, z), "Left" + part: (x, -y, -z)}


def pose(*parts, **bones):
	out = {}
	for p in parts:
		out.update(p)
	out.update(bones)
	return out


def mirror_pose(p):
	out = {}
	for name, value in p.items():
		if name == "loc":
			out["loc"] = {k: (-v[0], v[1], v[2]) for k, v in value.items()}
			continue
		if name.startswith("Right"):
			name = "Left" + name[5:]
		elif name.startswith("Left"):
			name = "Right" + name[4:]
		x, y, z = value
		out[name] = (x, -y, -z)
	return out


def blend(a, b, t):
	out = {}
	for name in set(a) | set(b):
		if name == "loc":
			continue
		va, vb = a.get(name, (0, 0, 0)), b.get(name, (0, 0, 0))
		out[name] = tuple(va[i] + (vb[i] - va[i]) * t for i in range(3))
	la, lb = a.get("loc", {}), b.get("loc", {})
	out["loc"] = {k: tuple(la.get(k, (0, 0, 0))[i] + (lb.get(k, (0, 0, 0))[i] - la.get(k, (0, 0, 0))[i]) * t for i in range(3))
				  for k in set(la) | set(lb)}
	return out


def hips(z=0.0, x=0.0, y=0.0):
	return {"loc": {"Hips": (x, y, z)}}


def with_loc(p, **locs):
	p = dict(p)
	p["loc"] = dict(p.get("loc", {}))
	for k, v in locs.items():
		p["loc"][k] = v
	return p


# Standing, arms relaxed.
STAND = pose(both("UpperArm", (4, -5, 0)), both("LowerArm", (12, 0, 0)), both("Hand", (0, 0, 0)))
# Combat ready: knees bent, weapon forward.
READY = pose(
	both("UpperLeg", (14, -6, 0)), both("LowerLeg", (-26, 0, 0)), both("Foot", (12, 0, 0)),
	both("UpperArm", (28, -12, 0)), both("LowerArm", (55, 0, 0)),
	Spine=(-6, 0, 0), Chest=(-4, 0, 0), Head=(8, 0, 0), loc={"Hips": (0, 0, -0.05)})
# Combat ready with a two-handed weapon: held up across the body (the left
# hand joins it on the handle by IK).
READY_2H = pose(READY, {"RightUpperArm": (32, 22, 0), "RightLowerArm": (62, 0, 0), "RightHand": (-28, 0, 0)},
				Chest=(-4, 0, -12), Spine=(-6, 0, -4))
SIT = pose(
	both("UpperLeg", (80, -24, 0)), both("LowerLeg", (-118, 0, 0)), both("Foot", (30, 0, 0)),
	both("UpperArm", (30, -10, 0)), both("LowerArm", (40, 0, 0)),
	Spine=(-6, 0, 0), Chest=(-4, 0, 0), Head=(4, 0, 0), loc={"Hips": (0, -0.05, -0.74)})
DEAD = pose(
	both("UpperArm", (10, -55, 0)), both("LowerArm", (20, 0, 0)), both("UpperLeg", (4, -8, 0)),
	both("LowerLeg", (-6, 0, 0)), both("Foot", (-20, 0, 0)),
	Root=(90, 0, 0), Head=(-6, 0, 20), loc={"Root": (0, 0, 0.14)})


def walk():
	contact = pose(
		{"RightUpperLeg": (26, 0, 0), "RightLowerLeg": (-6, 0, 0), "RightFoot": (-10, 0, 0),
		 "LeftUpperLeg": (-20, 0, 0), "LeftLowerLeg": (-22, 0, 0), "LeftFoot": (20, 0, 0),
		 "RightUpperArm": (-24, -5, 0), "LeftUpperArm": (26, 5, 0)},
		# The hips turn with the leading leg, the shoulders against them.
		both("LowerArm", (18, 0, 0)), Hips=(0, 0, 6), Chest=(0, 0, -11), Spine=(-3, 0, 0), Head=(0, 0, 4),
		loc={"Hips": (0, 0, -0.028)})
	passing = pose(
		{"RightUpperLeg": (0, 0, 0), "RightLowerLeg": (-6, 0, 0), "LeftUpperLeg": (8, 0, 0),
		 "LeftLowerLeg": (-45, 0, 0), "LeftFoot": (10, 0, 0)},
		both("UpperArm", (2, -5, 0)), both("LowerArm", (14, 0, 0)), Spine=(-2, 0, 0), loc={"Hips": (0, 0, 0.01)})
	return [(0, contact), (8, passing), (15, mirror_pose(contact)), (23, mirror_pose(passing)), (30, contact)]


def run():
	stride = pose(
		{"RightUpperLeg": (48, 0, 0), "RightLowerLeg": (-20, 0, 0), "RightFoot": (-10, 0, 0),
		 "LeftUpperLeg": (-32, 0, 0), "LeftLowerLeg": (-75, 0, 0), "LeftFoot": (30, 0, 0),
		 "RightUpperArm": (-46, -8, 0), "LeftUpperArm": (56, 8, 0),
		 "RightLowerArm": (70, 0, 0), "LeftLowerArm": (90, 0, 0)},
		Hips=(0, 0, 5), Spine=(-12, 0, 0), Chest=(-2, 0, -8), Head=(11, 0, 3), loc={"Hips": (0, 0, -0.03)})
	flight = pose(
		{"RightUpperLeg": (12, 0, 0), "RightLowerLeg": (-25, 0, 0), "LeftUpperLeg": (24, 0, 0),
		 "LeftLowerLeg": (-105, 0, 0), "LeftFoot": (20, 0, 0)},
		both("UpperArm", (6, -8, 0)), both("LowerArm", (80, 0, 0)),
		Spine=(-12, 0, 0), Head=(11, 0, 0), loc={"Hips": (0, 0, 0.018)})
	return [(0, stride), (5, flight), (10, mirror_pose(stride)), (15, mirror_pose(flight)), (20, stride)]


def reverse(keys):
	end = keys[-1][0]
	return sorted(((end - f, p) for f, p in keys), key=lambda k: k[0])


def backpedal():
	keys = []
	for f, p in walk():
		p = dict(p)
		p["Spine"] = (4, 0, 0)
		keys.append((f, p))
	return reverse(keys)


def strafe(direction):
	# The legs run to the side, the body twisted back to face forward.
	twist = -42 if direction == "right" else 42
	keys = []
	for f, p in run():
		p = dict(p)
		p["Hips"] = (0, 0, twist)
		p["Spine"] = (-6, 0, -twist * 0.55)
		p["Chest"] = (0, 0, -twist * 0.45)
		keys.append((f, p))
	return keys


def idle():
	"""Breathing (the chest lifting, the shoulders rising), the weight swaying
	slowly from side to side, and a look about."""
	breath_in = pose(STAND, both("Shoulder", (0, -3, 0)), both("UpperArm", (6, -6, 0)), Chest=(3, 0, 0), Head=(-2, 0, 0),
					 loc={"Hips": (0, 0, 0.004)})
	lean_l = pose(STAND, Spine=(0, 2, 0), Chest=(0, -1, 0), Head=(0, 0, -6))
	lean_r = pose(STAND, Spine=(0, -2, 0), Chest=(0, 1, 0), Head=(0, 0, 6))
	look = pose(breath_in, Spine=(0, -2, 0), Head=(-4, 0, 16))
	return [(0, STAND), (25, breath_in), (50, lean_l), (75, breath_in), (100, lean_r), (125, look), (150, STAND)]


def ready():
	b = pose(READY, Chest=(-2, 0, 0), loc={"Hips": (0, 0, -0.06)})
	return [(0, READY), (20, b), (40, READY)]


def one_shot(*keys, start=READY, end=None):
	end = end if end is not None else start
	out = [(0, start)]
	out += list(keys)
	last = keys[-1][0] if keys else 0
	out.append((last + 8, end))
	return out


def attacks():
	a = {}
	wind = pose(READY, {"RightUpperArm": (155, -32, 0), "RightLowerArm": (65, 0, 0), "RightHand": (-25, 0, 0)},
				Hips=(0, 0, -8), Chest=(4, 0, -22), Spine=(0, 0, -8), Head=(4, 0, 12), loc={"Hips": (0, -0.03, -0.05)})
	strike = pose(READY, {"RightUpperArm": (40, 14, 0), "RightLowerArm": (12, 0, 0), "RightHand": (20, 0, 0)},
				  Hips=(0, 0, 10), Chest=(-10, 0, 24), Spine=(-12, 0, 10), Head=(10, 0, -12), loc={"Hips": (0, 0.06, -0.08)})
	follow = pose(strike, {"RightUpperArm": (22, 30, 0), "RightLowerArm": (20, 0, 0), "RightHand": (30, 0, 0)},
				  Hips=(0, 0, 13), Chest=(-12, 0, 30), Spine=(-14, 0, 12), loc={"Hips": (0, 0.07, -0.09)})
	a["attack_1h"] = one_shot((6, wind), (9, strike), (13, follow))
	wind_b = pose(READY, {"RightUpperArm": (85, -78, 0), "RightLowerArm": (40, 0, 0)},
				  Hips=(0, 0, -10), Chest=(2, 0, -32), Spine=(0, 0, -8), loc={"Hips": (0, -0.02, -0.05)})
	strike_b = pose(READY, {"RightUpperArm": (80, 35, 0), "RightLowerArm": (10, 0, 0)},
					Hips=(0, 0, 10), Chest=(-6, 0, 32), Spine=(-8, 0, 8), loc={"Hips": (0, 0.05, -0.07)})
	follow_b = pose(strike_b, {"RightUpperArm": (70, 55, 0), "RightLowerArm": (20, 0, 0)}, Hips=(0, 0, 13), Chest=(-8, 0, 40))
	a["attack_1h_b"] = one_shot((6, wind_b), (9, strike_b), (13, follow_b))
	# Two-handed: the right arm places the weapon; the left hand is put on the
	# handle afterwards by IK (two_hand_ik), so only the right arm is posed.
	wind2 = pose(READY_2H, {"RightUpperArm": (165, 10, 0), "RightLowerArm": (60, 0, 0), "RightHand": (-20, 0, 0)},
				 Hips=(0, 0, -6), Spine=(8, 0, -4), Chest=(6, 0, -12), loc={"Hips": (0, -0.03, -0.04)})
	strike2 = pose(READY_2H, {"RightUpperArm": (40, 18, 0), "RightLowerArm": (10, 0, 0), "RightHand": (10, 0, 0)},
				   Hips=(0, 0, 6), Spine=(-22, 0, 4), Chest=(-8, 0, 14), loc={"Hips": (0, 0.06, -0.12)})
	follow2 = pose(strike2, {"RightUpperArm": (28, 20, 0), "RightHand": (16, 0, 0)}, Spine=(-26, 0, 6), loc={"Hips": (0, 0.07, -0.13)})
	a["attack_2h"] = one_shot((8, wind2), (12, strike2), (17, follow2), start=READY_2H)
	sweep_wind = pose(READY_2H, {"RightUpperArm": (75, -55, 0), "RightLowerArm": (55, 0, 0), "RightHand": (-30, 0, 0)},
					  Chest=(0, 0, -40), Spine=(0, 0, -10))
	sweep = pose(READY_2H, {"RightUpperArm": (75, 50, 0), "RightLowerArm": (30, 0, 0), "RightHand": (-30, 0, 0)},
				 Chest=(-4, 0, 42), Spine=(-6, 0, 12), loc={"Hips": (0, 0.03, -0.07)})
	a["attack_2h_b"] = one_shot((7, sweep_wind), (12, sweep), (15, sweep), start=READY_2H)
	parry2 = pose(READY_2H, {"RightUpperArm": (75, 28, 0), "RightLowerArm": (80, 0, 0), "RightHand": (-15, 0, 0)}, Chest=(0, 0, 12))
	a["parry_2h"] = one_shot((3, parry2), (9, parry2), start=READY_2H)
	hit2 = pose(READY_2H, Spine=(12, 0, 0), Chest=(6, 0, 0), Head=(12, 0, 0), loc={"Hips": (0, -0.04, -0.05)})
	a["hit_2h"] = one_shot((2, hit2), (5, hit2), start=READY_2H)
	a["ready_2h"] = [(0, READY_2H), (20, pose(READY_2H, Chest=(-2, 0, -12), loc={"Hips": (0, 0, -0.06)})), (40, READY_2H)]
	a["attack_off"] = [(f, mirror_pose(p)) for f, p in a["attack_1h"]]
	jab = pose(READY, {"RightUpperArm": (82, 8, 0), "RightLowerArm": (8, 0, 0)}, Chest=(-4, 0, 24), Spine=(-6, 0, 0))
	a["punch"] = one_shot((4, jab), (7, jab))
	block = pose(READY, {"LeftUpperArm": (70, -36, 0), "LeftLowerArm": (75, 0, 0)}, Chest=(0, 0, -10), Spine=(-8, 0, 0))
	a["block"] = one_shot((3, block), (10, block))
	parry = pose(READY, {"RightUpperArm": (95, 22, 0), "RightLowerArm": (75, 0, 0), "RightHand": (-30, 0, 0)}, Chest=(0, 0, 14))
	a["parry"] = one_shot((3, parry), (9, parry))
	dodge = pose(READY, Spine=(-4, 0, 0), Chest=(0, 0, 20), loc={"Hips": (-0.12, -0.03, -0.06)})
	a["dodge"] = one_shot((4, dodge), (9, dodge))
	hit = pose(READY, both("UpperArm", (10, -20, 0)), Spine=(12, 0, 0), Chest=(6, 0, 0), Head=(12, 0, 0),
			   loc={"Hips": (0, -0.04, -0.05)})
	a["hit"] = one_shot((2, hit), (5, hit))
	return a


def shooting():
	a = {}
	# The bow: side on, left arm out holding the bow upright; the right
	# elbow out and back, the hand at the string by the chin.
	aim_bow = pose(READY, {"LeftUpperArm": (88, 4, 26), "LeftLowerArm": (0, 0, 0), "LeftHand": (0, 0, 0),
						   "RightUpperArm": (0, -78, -15), "RightLowerArm": (150, 0, 0), "RightHand": (0, 0, 0)},
				   Chest=(0, 0, -26), Spine=(-4, 0, 0), Head=(0, 0, 26))
	draw = pose(aim_bow, {"RightUpperArm": (0, -80, -40), "RightLowerArm": (162, 0, 0)})
	loose = pose(aim_bow, {"RightUpperArm": (0, -80, -55), "RightLowerArm": (110, 0, 0)})
	a["aim_bow"] = [(0, aim_bow), (20, pose(aim_bow, Chest=(1, 0, -26))), (40, aim_bow)]
	a["shoot_bow"] = [(0, aim_bow), (5, draw), (10, draw), (12, loose), (20, aim_bow)]
	# A gun: shouldered, the hand turned down so the barrel points ahead.
	aim_gun = pose(READY, {"RightUpperArm": (85, 30, 0), "RightLowerArm": (60, 0, 0), "RightHand": (-145, 0, 0),
						   "LeftUpperArm": (88, 30, 0), "LeftLowerArm": (22, 0, 0)},
				   Chest=(0, 0, -10), Head=(-6, 0, 10))
	recoil = pose(aim_gun, {"RightUpperArm": (95, 30, 0), "RightHand": (-158, 0, 0)}, Chest=(6, 0, -10), Head=(2, 0, 10))
	a["aim_gun"] = [(0, aim_gun), (20, pose(aim_gun, Chest=(1, 0, -10))), (40, aim_gun)]
	a["shoot_gun"] = [(0, aim_gun), (2, recoil), (10, aim_gun)]
	wind = pose(READY, {"RightUpperArm": (150, -30, 0), "RightLowerArm": (70, 0, 0)}, Chest=(0, 0, -22))
	release = pose(READY, {"RightUpperArm": (60, 12, 0), "RightLowerArm": (10, 0, 0)}, Chest=(-6, 0, 26))
	a["throw"] = one_shot((5, wind), (9, release), (11, release))
	point = pose(READY, {"RightUpperArm": (86, 8, 0), "RightLowerArm": (8, 0, 0), "RightHand": (-20, 0, 0)}, Chest=(0, 0, 10))
	flick = pose(point, {"RightHand": (10, 0, 0)})
	a["shoot_wand"] = one_shot((4, point), (6, flick), (10, point))
	return a


def casting():
	a = {}
	# The hands drawn in before the chest and a little forward, the body leaning
	# in over them, gathering in slow circles.
	c1 = pose(STAND, both("UpperArm", (38, 30, 0)), both("LowerArm", (112, 0, 0)), both("Hand", (-15, 0, 0)),
			  both("UpperLeg", (6, -4, 0)), both("LowerLeg", (-10, 0, 0)), both("Foot", (4, 0, 0)),
			  Spine=(-5, 0, 0), Chest=(-3, 0, 0), Head=(4, 0, 0), loc={"Hips": (0, 0, -0.015)})
	c2 = pose(c1, {"RightUpperArm": (46, 26, 0), "LeftUpperArm": (32, 34, 0)}, Chest=(-4, 0, 4))
	c3 = pose(c1, {"RightUpperArm": (32, 34, 0), "LeftUpperArm": (46, 26, 0)}, Chest=(-4, 0, -4))
	a["cast"] = [(0, c1), (8, c2), (16, c1), (24, c3), (32, c1)]
	# Release: a quick draw back, then both arms pushed out, the body leaning
	# into it with a half step.
	gather = pose(c1, both("UpperArm", (30, 34, 0)), both("LowerArm", (125, 0, 0)), Spine=(2, 0, 0), Chest=(2, 0, 0),
				  loc={"Hips": (0, -0.02, -0.015)})
	thrust = pose(READY, both("UpperArm", (84, 10, 0)), both("LowerArm", (6, 0, 0)), both("Hand", (-25, 0, 0)),
				  Spine=(-14, 0, 0), Chest=(-6, 0, 0), Head=(8, 0, 0), loc={"Hips": (0, 0.05, -0.06)})
	a["cast_release"] = one_shot((3, gather), (6, thrust), (10, thrust), start=c1, end=STAND)
	ch = pose(STAND, both("UpperArm", (75, -6, 0)), both("LowerArm", (25, 0, 0)), both("Hand", (-30, 0, 0)), Spine=(-4, 0, 0))
	ch2 = pose(ch, both("UpperArm", (78, -8, 0)), Chest=(1, 0, 0))
	a["channel"] = [(0, ch), (10, ch2), (20, ch)]
	return a


def full_body():
	a = {}
	a["jump"] = [(0, STAND), (3, pose(STAND, both("UpperLeg", (30, 0, 0)), both("LowerLeg", (-55, 0, 0)), both("Foot", (25, 0, 0)),
									   Spine=(-12, 0, 0), loc={"Hips": (0, 0, -0.12)})),
				 (8, pose(STAND, both("UpperArm", (40, -20, 0)), both("Foot", (-25, 0, 0)), Spine=(4, 0, 0)))]
	fall = pose(both("UpperArm", (20, -45, 0)), both("LowerArm", (30, 0, 0)),
				{"RightUpperLeg": (34, 0, 0), "RightLowerLeg": (-60, 0, 0), "LeftUpperLeg": (8, 0, 0), "LeftLowerLeg": (-28, 0, 0)},
				Spine=(-4, 0, 0))
	fall2 = pose(fall, both("UpperArm", (24, -52, 0)), {"RightUpperLeg": (28, 0, 0), "LeftUpperLeg": (14, 0, 0)})
	a["fall"] = [(0, fall), (10, fall2), (20, fall)]
	crouch = pose(STAND, both("UpperLeg", (34, -4, 0)), both("LowerLeg", (-62, 0, 0)), both("Foot", (28, 0, 0)),
				  both("UpperArm", (20, -20, 0)), Spine=(-14, 0, 0), loc={"Hips": (0, 0, -0.14)})
	a["land"] = [(0, crouch), (3, crouch), (10, STAND)]
	a["sit_down"] = [(0, STAND), (5, pose(crouch, loc={"Hips": (0, 0, -0.3)})), (12, SIT)]
	a["stand_up"] = [(0, SIT), (6, pose(crouch, loc={"Hips": (0, 0, -0.3)})), (12, STAND)]
	sit2 = pose(SIT, Chest=(-2, 0, 0), Head=(2, 0, 6))
	a["sit"] = [(0, SIT), (45, sit2), (90, SIT)]
	knees = pose(READY, both("UpperLeg", (40, -6, 0)), both("LowerLeg", (-80, 0, 0)), both("Foot", (40, 0, 0)),
				 both("UpperArm", (20, -40, 0)), Spine=(-20, 0, 0), Head=(-10, 0, 0), loc={"Hips": (0, 0, -0.3)})
	falling = pose(DEAD, both("UpperLeg", (30, -6, 0)), both("LowerLeg", (-50, 0, 0)), Root=(50, 0, 0), loc={"Root": (0, -0.1, 0.12)})
	settle = pose(DEAD, Root=(84, 0, 0))
	a["death"] = [(0, READY), (3, pose(READY, Spine=(14, 0, 0), Head=(16, 0, 0))), (8, knees), (14, falling), (19, DEAD),
				  (22, settle), (26, DEAD)]
	a["dead"] = [(0, DEAD), (10, DEAD)]
	slump = pose(STAND, both("UpperArm", (6, -2, 0)), both("LowerArm", (6, 0, 0)), both("UpperLeg", (10, -4, 0)),
				 both("LowerLeg", (-18, 0, 0)), Spine=(-14, 0, 6), Head=(-24, 0, 10), loc={"Hips": (0, 0, -0.04)})
	a["stunned"] = [(0, slump), (20, pose(slump, Spine=(-14, 0, -6), Head=(-24, 0, -12))), (40, slump)]
	# Emotes.
	up = pose(STAND, {"RightUpperArm": (150, -40, 0), "RightLowerArm": (30, 0, 0)}, Head=(4, 0, 0))
	wave_a = pose(up, {"RightLowerArm": (30, 0, 25)})
	wave_b = pose(up, {"RightLowerArm": (30, 0, -25)})
	a["wave"] = [(0, STAND), (6, up), (11, wave_a), (16, wave_b), (21, wave_a), (26, wave_b), (31, up), (38, STAND)]
	bow = pose(STAND, {"RightUpperArm": (40, 40, 0), "RightLowerArm": (90, 0, 0)}, both("UpperLeg", (24, 0, 0)),
			   Spine=(-30, 0, 0), Chest=(-16, 0, 0), Head=(-10, 0, 0), loc={"Hips": (0, -0.08, 0)})
	a["bow"] = [(0, STAND), (8, bow), (20, bow), (30, STAND)]
	cheer = pose(STAND, both("UpperArm", (165, -42, 0)), both("LowerArm", (10, 0, 0)), Head=(16, 0, 0), loc={"Hips": (0, 0, 0.06)})
	cheer2 = pose(cheer, both("UpperArm", (155, -50, 0)), loc={"Hips": (0, 0, 0.0)})
	a["cheer"] = [(0, STAND), (5, cheer2), (9, cheer), (14, cheer2), (18, cheer), (24, cheer2), (32, STAND)]
	nod = pose(STAND, Head=(-22, 0, 0), Neck=(-6, 0, 0))
	a["nod"] = [(0, STAND), (5, nod), (10, STAND), (15, nod), (22, STAND)]
	laugh = pose(STAND, both("UpperArm", (30, 30, 0)), both("LowerArm", (80, 0, 0)), Spine=(10, 0, 0), Head=(18, 0, 0))
	laugh2 = pose(laugh, Spine=(4, 0, 0), Head=(10, 0, 0))
	a["laugh"] = [(0, STAND)] + [(4 + 5 * i, laugh if i % 2 == 0 else laugh2) for i in range(6)] + [(40, STAND)]
	cry = pose(STAND, both("UpperArm", (120, 38, 0)), both("LowerArm", (135, 0, 0)), Spine=(-10, 0, 0), Head=(-26, 0, 0))
	cry2 = pose(cry, Chest=(-4, 0, 0), Head=(-22, 0, 0))
	a["cry"] = [(0, STAND)] + [(6 + 5 * i, cry if i % 2 == 0 else cry2) for i in range(8)] + [(52, STAND)]
	d1 = pose(STAND, {"RightUpperArm": (120, -50, 0), "LeftUpperArm": (40, 50, 0)}, both("LowerArm", (60, 0, 0)),
			  {"RightUpperLeg": (20, -10, 0), "RightLowerLeg": (-40, 0, 0)}, Hips=(0, 0, 10), Chest=(0, 0, -10),
			  loc={"Hips": (0.05, 0, -0.03)})
	a["dance"] = [(0, d1), (10, pose(STAND, Chest=(0, 0, 0), loc={"Hips": (0, 0, 0.02)})), (20, mirror_pose(d1)),
				  (30, pose(STAND, loc={"Hips": (0, 0, 0.02)})), (40, d1)]
	return a


def all_animations():
	anims = {
		"idle": idle(), "ready": ready(), "walk": walk(), "run": run(), "backpedal": backpedal(),
		"strafe_left": strafe("left"), "strafe_right": strafe("right"),
	}
	anims.update(attacks())
	anims.update(casting())
	anims.update(shooting())
	anims.update(full_body())
	return anims


# Animations whose left hand holds the two-handed weapon's handle.
TWO_HAND_ANIMS = ["ready_2h", "attack_2h", "attack_2h_b", "parry_2h", "hit_2h"]
TWO_HAND_BONES = ["LeftUpperArm", "LeftLowerArm"]


def two_hand_ik(arm, names):
	"""Puts the left wrist on the GripL bone (the handle) in each of these
	animations by IK, baked into their keyframes."""
	bpy.context.view_layer.objects.active = arm
	arm.select_set(True)
	bpy.ops.object.mode_set(mode="POSE")
	ik = arm.pose.bones["LeftLowerArm"].constraints.new("IK")
	ik.target = arm
	ik.subtarget = "GripL"
	ik.chain_count = 2
	ik.use_tail = True
	for bone in arm.data.bones:
		bone.select = bone.name in TWO_HAND_BONES
	for name in names:
		action = bpy.data.actions[name]
		arm.animation_data.action = action
		start, end = (int(f) for f in action.frame_range)
		bpy.ops.nla.bake(frame_start=start, frame_end=end, step=1, only_selected=True, visual_keying=True,
						 clear_constraints=False, use_current_action=True, bake_types={"POSE"})
	arm.pose.bones["LeftLowerArm"].constraints.remove(ik)
	arm.animation_data.action = None
	bpy.ops.object.mode_set(mode="OBJECT")


def key_animations(arm, anims):
	pose_bones = arm.pose.bones
	rest = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}
	for b in pose_bones:
		b.rotation_mode = "QUATERNION"
	arm.animation_data_create()
	for name, keys in anims.items():
		action = bpy.data.actions.new(name)
		action.use_fake_user = True
		arm.animation_data.action = action
		for frame, p in keys:
			locs = p.get("loc", {})
			for b in pose_bones:
				r = rest[b.name]
				x, y, z = p.get(b.name, (0, 0, 0))
				d = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix()
				b.rotation_quaternion = (r.inverted() @ d @ r).to_quaternion()
				b.keyframe_insert("rotation_quaternion", frame=frame)
				if b.name in ("Root", "Hips"):
					x, y, z = locs.get(b.name, (0, 0, 0))
					w = RACE["width"]
					offset = Vector((x * w, y * w, z * (RACE["legs"] if b.name == "Hips" else w)))
					b.location = r.inverted() @ offset
					b.keyframe_insert("location", frame=frame)
		track = arm.animation_data.nla_tracks.new()
		track.name = name
		track.strips.new(name, int(keys[0][0]), action)
		track.mute = True
		arm.animation_data.action = None
	# Rest pose shown in the .blend.
	for b in pose_bones:
		b.rotation_quaternion = Quaternion()
		b.location = Vector()

# ---------------------------------------------------------------- main

def main():
	"""Builds every race, or those named after `--` (`-- orc troll`)."""
	global RACE
	import sys
	only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	for race, shape in RACES.items():
		if only and race not in only:
			continue
		RACE = shape
		build(race)


def build(race):
	out = os.path.join(ROOT, "assets", "models", race, race + ".glb")
	blend = os.path.join(HERE, race + ".blend")
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.fps = FPS
	arm = build_armature()
	material = bpy.data.materials.new("Character")
	if RACE.get("species"):
		parts = [body("BodyMale", False)] + species_parts(RACE["species"]) + held_props()
	else:
		parts = [body("BodyMale", False), body("BodyFemale", True)] + shoulders() + race_parts() + hairs() + props()
	tris = {}
	for builder in parts:
		obj = builder.build(arm, material)
		tris[builder.name] = sum(len(f) - 2 for f in builder.faces)
	key_animations(arm, all_animations())
	two_hand_ik(arm, TWO_HAND_ANIMS)
	os.makedirs(os.path.dirname(out), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=blend)
	bpy.ops.export_scene.gltf(
		filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
		export_skins=True, export_morph=False, export_yup=True, export_apply=False,
		export_optimize_animation_size=False,
	)
	print("triangles:", tris)
	print("wrote", out)


if __name__ == "__main__":
	main()
