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
	"back", "ranged", "ranged_trim", "helm_trim",
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
	and props keep their shape, scaled about the joint they hang from."""
	v = Vector(v)
	if group == "Head":
		return body_point(HEAD_AT) + (v - HEAD_AT) * HEAD_SCALE * RACE["head"]
	if group in WRIST:
		return body_point(WRIST[group]) + (v - WRIST[group]) * HAND_SCALE * RACE["hands"]
	if group in ("WeaponR", "WeaponL"):
		grip = GRIP_R if group == "WeaponR" else GRIP_L
		return place(grip, "RightHand" if group == "WeaponR" else "LeftHand") + (v - grip) * RACE["props"]
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

class Builder:
	"""Geometry for one mesh object, in armature space."""

	def __init__(self, name):
		self.name = name
		self.verts = []
		self.groups = []
		self.faces = []
		self.face_uv = []

	def _add(self, verts, groups, faces, slots, shades):
		base = len(self.verts)
		self.verts += [Vector(v) for v in verts]
		self.groups += groups
		for face, slot, shade in zip(faces, slots, shades):
			self.faces.append([base + i for i in face])
			self.face_uv.append(((SLOT[slot] + 0.5) / SLOT_COUNT, shade / 2.0))

	def loft(self, rings, slots, sides=8, turn=None, cap_slots=None, shade=1.0):
		"""Rings of (center, rx, ry, bone) joined into a capped tube along
		any direction. `slots` gives each band's slot (one per ring gap);
		rings lie flat in the plane across the tube."""
		if turn is None:
			turn = math.pi / sides
		verts, groups, faces, fslots = [], [], [], []
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
			for k in range(sides):
				a = turn + math.tau * k / sides
				verts.append(center + side * math.cos(a) * rx + fwd * math.sin(a) * ry)
				groups.append(bone)
		for i in range(len(rings) - 1):
			for k in range(sides):
				a, b = i * sides + k, i * sides + (k + 1) % sides
				faces.append([a, b, b + sides, a + sides])
				fslots.append(slots[i])
		caps = cap_slots or (slots[0], slots[-1])
		faces.append(list(range(sides))[::-1])
		fslots.append(caps[0])
		last = (len(rings) - 1) * sides
		faces.append([last + k for k in range(sides)])
		fslots.append(caps[1])
		self._add(verts, groups, faces, fslots, [shade] * len(faces))

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
		self._add(verts, [bone] * 8, faces, [slot] * 6, [shade] * 6)

	def plate(self, outline, x0, x1, bone, slot, rim_slot=None):
		"""A flat shape in the YZ plane (outline of (y, z)) from x0 to x1."""
		n = len(outline)
		verts = [(x0, y, z) for y, z in outline] + [(x1, y, z) for y, z in outline]
		faces = [list(range(n))[::-1], [n + k for k in range(n)]]
		slots = [slot, slot]
		for k in range(n):
			faces.append([k, (k + 1) % n, n + (k + 1) % n, n + k])
			slots.append(rim_slot or slot)
		self._add(verts, [bone] * len(verts), faces, slots, [1.0] * len(faces))

	def build(self, arm, material):
		mesh = bpy.data.meshes.new(self.name)
		bm = bmesh.new()
		bverts = [bm.verts.new(place(v, g)) for v, g in zip(self.verts, self.groups)]
		uv_layer = bm.loops.layers.uv.new("UVMap")
		for face, uv in zip(self.faces, self.face_uv):
			f = bm.faces.new([bverts[i] for i in face])
			f.smooth = False
			for loop in f.loops:
				loop[uv_layer].uv = uv
		# Every part is a closed shell: turn its faces outward (the mirrored
		# left side and some lofts are built inside out).
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		bm.normal_update()
		bm.to_mesh(mesh)
		bm.free()
		obj = bpy.data.objects.new(self.name, mesh)
		bpy.context.scene.collection.objects.link(obj)
		mesh.materials.append(material)
		for bone in set(self.groups):
			group = obj.vertex_groups.new(name=bone)
			group.add([i for i, g in enumerate(self.groups) if g == bone], 1.0, "REPLACE")
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
		((0, 0.015, 1.37), 0.21 if f else 0.29, 0.135 if f else 0.165, "Chest"),
		((0, 0.0, 1.45), 0.2 if f else 0.28, 0.125 if f else 0.145, "Chest"),
		((0, 0, 1.51), 0.1, 0.08, "Chest"),
	]
	b.loft(rings, ["legs", "waist", "waist", "chest", "chest", "chest", "chest"], sides=8)
	# Belt buckle.
	b.box((0, 0.125, 1.0), (0.06, 0.02, 0.05), "Hips", "trim")
	if f:
		b.box((0, 0.11, 1.32), (0.27, 0.1, 0.12), "Chest", "chest", top=(0.85, 0.6), shift=(0, -0.02))
	# Neck and head.
	b.tube((0, 0, 1.46), (0, 0.01, 1.6), 0.062 if f else 0.08, 0.056 if f else 0.072, "Neck", "skin")
	hw = 0.92 if f else 1.0
	head = [
		((0, 0.04, 1.565), 0.06 * hw, 0.06, "Head"),
		((0, 0.03, 1.615), 0.11 * hw if f else 0.125, 0.115, "Head"),
		((0, 0.01, 1.7), 0.125 * hw, 0.135, "Head"),
		((0, 0.0, 1.78), 0.12 * hw, 0.13, "Head"),
		((0, -0.005, 1.835), 0.075 * hw, 0.085, "Head"),
	]
	b.loft(head, ["skin"] * 4, sides=8)
	for x in (-1, 1):
		b.box((0.045 * x, 0.128, 1.705), (0.038, 0.02, 0.022), "Head", "eyes")
		b.box((0.045 * x, 0.126, 1.737), (0.055, 0.025, 0.016), "Head", "hair")
		b.box((0.122 * hw * x, 0.0, 1.7), (0.03, 0.05, 0.065), "Head", "skin", shade=0.9)
	b.box((0, 0.14, 1.668), (0.035, 0.045, 0.06), "Head", "skin", top=(0.8, 0.6), shift=(0, -0.01), shade=0.95)
	b.box((0, 0.128, 1.625), (0.05, 0.015, 0.012), "Head", "skin", shade=0.6)
	# Arms, hands and legs on both sides.
	arm_r = 1.0 if f else 1.3
	for side, x in (("Right", 1), ("Left", -1)):
		sh = Vector(_side(x, (0.28, 0, 1.42)))
		el = Vector(_side(x, (0.32, 0, 1.14)))
		wr = Vector(_side(x, (0.34, 0.03, 0.89)))
		b.loft([(sh + Vector((0, 0, 0.03)), 0.075 * arm_r, 0.075 * arm_r, side + "UpperArm"),
				(el, 0.06 * arm_r, 0.06 * arm_r, side + "UpperArm")], ["chest"], sides=6)
		b.loft([(el + Vector((0, 0, 0.02)), 0.058 * arm_r, 0.058 * arm_r, side + "LowerArm"),
				(wr + Vector((0, 0, 0.0)), 0.048 * arm_r, 0.048 * arm_r, side + "LowerArm")], ["wrists"], sides=6)
		hand = 0.85 if f else 1.0
		b.box(_side(x, (0.345, 0.035, 0.83)), (0.085 * hand, 0.1 * hand, 0.12 * hand), side + "Hand", "hands", top=(1.0, 0.9))
		b.box(_side(x, (0.32, 0.085, 0.86)), (0.035, 0.035, 0.06), side + "Hand", "hands")
		leg = 1.0 if f else 1.2
		hip = Vector(_side(x, (0.1, 0, 0.97)))
		knee = Vector(_side(x, (0.12, 0, 0.52)))
		b.loft([(hip, 0.1 * leg, 0.105 * leg, side + "UpperLeg"),
				(knee + Vector((0, 0, 0.02)), 0.07 * leg, 0.072 * leg, side + "UpperLeg")], ["legs"], sides=6)
		b.loft([(knee + Vector((0, 0, 0.02)), 0.068 * leg, 0.07 * leg, side + "LowerLeg"),
				(Vector(_side(x, (0.12, -0.01, 0.35))), 0.058 * leg, 0.058 * leg, side + "LowerLeg"),
				(Vector(_side(x, (0.12, -0.01, 0.345))), 0.075 * leg, 0.078 * leg, side + "LowerLeg"),
				(Vector(_side(x, (0.12, -0.02, 0.1))), 0.064 * leg, 0.066 * leg, side + "LowerLeg")],
			   ["legs", "feet", "feet"], sides=6)
		b.box(_side(x, (0.12, 0.04, 0.055)), (0.12 * leg, 0.26, 0.11), side + "Foot", "feet", top=(0.9, 0.62), shift=(0, -0.04))
		b.box(_side(x, (0.12, 0.04, 0.008)), (0.125 * leg, 0.265, 0.016), side + "Foot", "feet", shade=0.55)
	return b


def shoulders():
	b = Builder("Shoulders")
	for side, x in (("Right", 1), ("Left", -1)):
		c = Vector(_side(x, (0.31, 0, 1.43)))
		b.loft([(c + Vector((0, 0, -0.07)), 0.12, 0.12, side + "Shoulder"),
				(c + Vector((0.01 * x, 0, 0.02)), 0.13, 0.125, side + "Shoulder"),
				(c + Vector((0, 0, 0.08)), 0.07, 0.07, side + "Shoulder")], ["shoulders", "shoulders"], sides=8)
		b.box(c + Vector((0.11 * x, 0, -0.02)), (0.03, 0.1, 0.03), side + "Shoulder", "trim")
	return b


def hair_cap(b, back=1.66, back_depth=0.16):
	b.loft([((0, -0.005, 1.715), 0.13, 0.145, "Head"),
			((0, -0.01, 1.8), 0.132, 0.145, "Head"),
			((0, -0.01, 1.865), 0.08, 0.095, "Head")], ["hair", "hair"], sides=8)
	b.box((0, -0.1, back), (0.23, 0.07, back_depth), "Head", "hair", top=(1.05, 1.0))


def hairs():
	out = []
	b = Builder("HairShort")
	hair_cap(b)
	out.append(b)
	b = Builder("HairLong")
	hair_cap(b, 1.56, 0.34)
	for x in (-1, 1):
		b.box((0.128 * x, 0.02, 1.66), (0.035, 0.09, 0.18), "Head", "hair", top=(1.0, 1.0))
	out.append(b)
	b = Builder("HairCrest")
	b.box((0, -0.01, 1.86), (0.06, 0.27, 0.09), "Head", "hair", top=(0.8, 0.85))
	b.box((0, -0.12, 1.75), (0.06, 0.06, 0.16), "Head", "hair")
	out.append(b)
	b = Builder("HairFLong")
	hair_cap(b, 1.52, 0.42)
	for x in (-1, 1):
		b.box((0.125 * x, 0.04, 1.6), (0.04, 0.09, 0.28), "Head", "hair", top=(1.1, 1.0))
	out.append(b)
	b = Builder("HairFTail")
	hair_cap(b)
	b.beam((0, -0.15, 1.76), (0, -0.2, 1.42), 0.08, 0.07, "Head", "hair", taper=0.55, up=(1, 0, 0))
	b.box((0, -0.14, 1.77), (0.05, 0.04, 0.04), "Head", "trim")
	out.append(b)
	b = Builder("HairFBun")
	hair_cap(b)
	b.loft([((0, -0.13, 1.75), 0.05, 0.05, "Head"), ((0, -0.2, 1.8), 0.075, 0.075, "Head"),
			((0, -0.25, 1.84), 0.04, 0.04, "Head")], ["hair", "hair"], sides=6)
	out.append(b)
	b = Builder("BeardShort")
	b.box((0, 0.105, 1.6), (0.21, 0.07, 0.08), "Head", "hair", top=(1.1, 1.0))
	b.box((0, 0.13, 1.645), (0.1, 0.03, 0.025), "Head", "hair")
	out.append(b)
	b = Builder("BeardLong")
	b.box((0, 0.105, 1.6), (0.22, 0.08, 0.09), "Head", "hair", top=(1.1, 1.0))
	b.beam((0, 0.12, 1.57), (0, 0.13, 1.42), 0.14, 0.06, "Head", "hair", taper=0.5, up=(1, 0, 0))
	b.box((0, 0.13, 1.645), (0.11, 0.03, 0.025), "Head", "hair")
	out.append(b)
	return out


def weapon(name, grip, bone, kind):
	"""A prop along +Y from the grip point."""
	b = Builder(name)
	g = Vector(grip)
	fw = lambda d: g + Vector((0, d, 0))
	up = lambda d, z: g + Vector((0, d, z))
	if kind == "sword":
		b.tube(fw(-0.1), fw(0.07), 0.022, 0.022, bone, "handle")
		b.box(fw(-0.12), (0.045, 0.045, 0.045), bone, "trim")
		b.box(fw(0.08), (0.04, 0.04, 0.2), bone, "trim")
		b.beam(fw(0.1), fw(0.7), 0.075, 0.02, bone, "blade", taper=0.8)
		b.beam(fw(0.7), fw(0.8), 0.06, 0.016, bone, "blade", taper=0.1)
	elif kind == "sword2h":
		b.tube(fw(-0.24), fw(0.07), 0.025, 0.025, bone, "handle")
		b.box(fw(-0.26), (0.05, 0.05, 0.05), bone, "trim")
		b.box(fw(0.08), (0.05, 0.05, 0.3), bone, "trim")
		b.beam(fw(0.1), fw(1.05), 0.11, 0.025, bone, "blade", taper=0.8)
		b.beam(fw(1.05), fw(1.2), 0.088, 0.02, bone, "blade", taper=0.1)
	elif kind == "axe":
		b.tube(fw(-0.12), fw(0.56), 0.022, 0.02, bone, "handle")
		b.box(up(0.47, -0.07), (0.03, 0.1, 0.11), bone, "blade", top=(1.0, 1.0))
		b.beam(up(0.47, -0.11), up(0.47, -0.2), 0.2, 0.025, bone, "blade", taper=1.3, up=(0, 1, 0))
		b.box(fw(0.565), (0.04, 0.04, 0.04), bone, "trim")
	elif kind == "axe2h":
		b.tube(fw(-0.35), fw(0.9), 0.027, 0.025, bone, "handle")
		for z in (-1, 1):
			b.beam(up(0.78, 0.04 * z), up(0.78, 0.24 * z), 0.2, 0.03, bone, "blade", taper=1.6, up=(0, 1, 0))
		b.box(fw(0.78), (0.06, 0.1, 0.09), bone, "trim")
	elif kind == "mace":
		b.tube(fw(-0.1), fw(0.5), 0.022, 0.02, bone, "handle")
		b.loft([(fw(0.46), 0.04, 0.04, bone), (fw(0.53), 0.075, 0.075, bone), (fw(0.62), 0.075, 0.075, bone),
				(fw(0.68), 0.04, 0.04, bone)], ["blade", "blade", "blade"], sides=6)
		b.box(fw(-0.11), (0.045, 0.045, 0.045), bone, "trim")
	elif kind == "mace2h":
		b.tube(fw(-0.35), fw(0.85), 0.027, 0.025, bone, "handle")
		b.loft([(fw(0.78), 0.06, 0.06, bone), (fw(0.86), 0.11, 0.11, bone), (fw(0.98), 0.11, 0.11, bone),
				(fw(1.05), 0.06, 0.06, bone)], ["blade", "blade", "blade"], sides=6)
		b.box(fw(1.08), (0.04, 0.04, 0.06), bone, "trim")
	elif kind == "dagger":
		b.tube(fw(-0.08), fw(0.06), 0.02, 0.02, bone, "handle")
		b.box(fw(0.07), (0.035, 0.035, 0.12), bone, "trim")
		b.beam(fw(0.08), fw(0.32), 0.055, 0.016, bone, "blade", taper=0.15)
	elif kind == "staff":
		b.tube(fw(-0.75), fw(0.75), 0.027, 0.025, bone, "handle")
		b.loft([(fw(0.72), 0.035, 0.035, bone), (fw(0.8), 0.06, 0.06, bone), (fw(0.9), 0.035, 0.035, bone)],
			   ["blade", "blade"], sides=6)
		b.box(fw(-0.77), (0.04, 0.04, 0.04), bone, "trim")
	elif kind == "polearm":
		b.tube(fw(-0.7), fw(0.95), 0.025, 0.024, bone, "handle")
		b.beam(fw(0.92), fw(1.3), 0.09, 0.022, bone, "blade", taper=0.2)
		b.beam(up(1.0, 0.0), up(1.08, -0.16), 0.05, 0.02, bone, "blade", taper=0.3, up=(0, 1, 0))
		b.box(fw(0.92), (0.05, 0.05, 0.06), bone, "trim")
	elif kind == "wand":
		b.tube(fw(-0.06), fw(0.26), 0.016, 0.012, bone, "handle")
		b.box(fw(0.28), (0.035, 0.035, 0.035), bone, "blade")
	elif kind == "fist":
		b.box(g + Vector((0, 0.07, 0)), (0.1, 0.06, 0.14), bone, "blade")
		for z in (-0.04, 0.0, 0.04):
			b.beam(up(0.09, z), up(0.17, z), 0.02, 0.015, bone, "blade", taper=0.2)
	elif kind == "orb":
		b.loft([(g + Vector((0, 0.04, -0.08)), 0.04, 0.04, bone), (g + Vector((0, 0.04, -0.03)), 0.08, 0.08, bone),
				(g + Vector((0, 0.04, 0.05)), 0.08, 0.08, bone), (g + Vector((0, 0.04, 0.1)), 0.04, 0.04, bone)],
			   ["blade", "blade", "blade"], sides=6)
	return b


def shield(name, kind):
	b = Builder(name)
	x0, x1 = SHIELD_AT.x, SHIELD_AT.x - 0.04
	y, z = SHIELD_AT.y, SHIELD_AT.z
	if kind == "round":
		pts = [(y + 0.27 * math.cos(a), z + 0.27 * math.sin(a)) for a in (math.tau * k / 8 + math.pi / 8 for k in range(8))]
		b.plate(pts, x0, x1, "ShieldL", "shield", "shield_trim")
		b.box((x1 - 0.02, y, z), (0.04, 0.09, 0.09), "ShieldL", "shield_trim")
	else:
		pts = [(y - 0.22, z + 0.3), (y + 0.22, z + 0.3), (y + 0.2, z - 0.05), (y, z - 0.42), (y - 0.2, z - 0.05)]
		b.plate(pts, x0, x1, "ShieldL", "shield", "shield_trim")
		b.box((x1 - 0.015, y, z + 0.05), (0.03, 0.06, 0.4), "ShieldL", "shield_trim")
		b.box((x1 - 0.015, y, z + 0.12), (0.03, 0.3, 0.06), "ShieldL", "shield_trim")
	return b


def helms():
	"""Head pieces by armour type; hair is hidden under any of them."""
	out = []
	b = Builder("Helm_hood")
	b.loft([((0, -0.01, 1.74), 0.15, 0.16, "Head"), ((0, -0.015, 1.84), 0.145, 0.155, "Head"),
			((0, -0.02, 1.9), 0.085, 0.1, "Head")], ["head", "head"], sides=8)
	for x in (-1, 1):
		b.box((0.14 * x, 0.0, 1.66), (0.04, 0.2, 0.2), "Head", "head", top=(1.0, 1.0))
	b.box((0, -0.12, 1.6), (0.3, 0.07, 0.3), "Head", "head", top=(0.9, 1.0))
	b.loft([((0, -0.02, 1.46), 0.22, 0.17, "Head"), ((0, -0.02, 1.54), 0.15, 0.13, "Head")], ["head"], sides=8)
	out.append(b)
	b = Builder("Helm_cap")
	b.loft([((0, -0.005, 1.74), 0.145, 0.158, "Head"), ((0, -0.01, 1.82), 0.142, 0.152, "Head"),
			((0, -0.01, 1.885), 0.08, 0.09, "Head")], ["head", "head"], sides=8)
	b.loft([((0, 0.0, 1.735), 0.17, 0.18, "Head"), ((0, 0.0, 1.755), 0.17, 0.18, "Head")], ["helm_trim"], sides=8)
	out.append(b)
	b = Builder("Helm_coif")
	b.loft([((0, -0.01, 1.74), 0.148, 0.16, "Head"), ((0, -0.015, 1.84), 0.142, 0.152, "Head"),
			((0, -0.02, 1.895), 0.08, 0.095, "Head")], ["head", "head"], sides=8)
	for x in (-1, 1):
		b.box((0.138 * x, 0.0, 1.64), (0.035, 0.22, 0.24), "Head", "head")
	b.box((0, 0.1, 1.575), (0.26, 0.06, 0.07), "Head", "head")
	b.loft([((0, -0.01, 1.44), 0.2, 0.16, "Head"), ((0, -0.01, 1.6), 0.14, 0.14, "Head")], ["head"], sides=8)
	out.append(b)
	b = Builder("Helm_plate")
	b.loft([((0, 0.0, 1.53), 0.12, 0.13, "Head"), ((0, 0.005, 1.6), 0.15, 0.165, "Head"),
			((0, 0.0, 1.8), 0.15, 0.165, "Head"), ((0, -0.005, 1.9), 0.09, 0.1, "Head")],
		   ["head", "head", "head"], sides=8)
	b.box((0, 0.162, 1.71), (0.2, 0.02, 0.025), "Head", "eyes")
	b.box((0, 0.165, 1.65), (0.025, 0.02, 0.08), "Head", "eyes")
	b.box((0, -0.005, 1.9), (0.04, 0.3, 0.05), "Head", "helm_trim")
	out.append(b)
	return out


def cloak():
	"""A cloak from the shoulders to the knees, each row on the bone at its
	height, so it bends with the back."""
	b = Builder("Cloak")
	rows = [((0, -0.1, 1.49), 0.2, "Chest"), ((0, -0.17, 1.32), 0.25, "Chest"), ((0, -0.19, 1.12), 0.26, "Spine"),
			((0, -0.21, 0.92), 0.27, "Hips"), ((0, -0.26, 0.6), 0.28, "Hips")]
	b.loft([(c, w / 0.707, 0.015 / 0.707, bone) for c, w, bone in rows], ["back"] * 4, sides=4, turn=math.pi / 4)
	for x in (-1, 1):
		b.box((0.17 * x, -0.04, 1.47), (0.06, 0.06, 0.05), "Chest", "trim")
	return b


def ranged():
	"""Ranged weapons, drawn while shooting: a bow in the left hand, a gun or
	a throwing knife in the right."""
	out = []
	b = Builder("Ranged_bow")
	g = GRIP_L
	points = [(y, 0.13 * (y / 0.55) ** 2) for y in (-0.55, -0.4, -0.22, -0.06, 0.06, 0.22, 0.4, 0.55)]
	for (y0, z0), (y1, z1) in zip(points, points[1:]):
		b.beam(g + Vector((0, y0, z0)), g + Vector((0, y1, z1)), 0.04, 0.03, "WeaponL", "ranged", up=(1, 0, 0))
	b.box(g, (0.045, 0.1, 0.045), "WeaponL", "handle")
	b.beam(g + Vector((0, -0.55, 0.14)), g + Vector((0, 0.55, 0.14)), 0.012, 0.012, "WeaponL", "ranged_trim", up=(1, 0, 0))
	out.append(b)
	b = Builder("Ranged_gun")
	g = GRIP_R
	b.tube(g + Vector((0, 0.0, 0.03)), g + Vector((0, 0.6, 0.03)), 0.026, 0.024, "WeaponR", "ranged_trim")
	b.beam(g + Vector((0, -0.3, -0.03)), g + Vector((0, 0.3, 0.0)), 0.075, 0.05, "WeaponR", "ranged", up=(0, 0, 1))
	b.box(g + Vector((0, 0.6, 0.03)), (0.07, 0.04, 0.07), "WeaponR", "ranged_trim")
	out.append(b)
	b = Builder("Ranged_thrown")
	b.tube(g + Vector((0, -0.06, 0)), g + Vector((0, 0.04, 0)), 0.018, 0.018, "WeaponR", "handle")
	b.beam(g + Vector((0, 0.04, 0)), g + Vector((0, 0.22, 0)), 0.05, 0.014, "WeaponR", "ranged_trim", taper=0.15)
	out.append(b)
	return out


WEAPONS = ["sword", "sword2h", "axe", "axe2h", "mace", "mace2h", "dagger", "staff", "polearm", "wand", "fist"]
OFF_HAND = ["sword", "axe", "mace", "dagger", "fist", "orb"]


def props():
	out = []
	for kind in WEAPONS:
		out.append(weapon("Main_" + kind, GRIP_R, "WeaponR", kind))
	for kind in OFF_HAND:
		b = weapon("Off_" + kind, GRIP_L, "WeaponL", kind)
		# Off-hand weapons take the off-hand colour slots.
		# Off-hand weapons take the off-hand colour slots: blade and trim
		# become shield_trim and shield.
		swap = {SLOT["blade"]: SLOT["shield_trim"], SLOT["trim"]: SLOT["shield"]}
		b.face_uv = [((swap.get(int(u * SLOT_COUNT), int(u * SLOT_COUNT)) + 0.5) / SLOT_COUNT, v) for u, v in b.face_uv]
		out.append(b)
	out.append(shield("Shield_round", "round"))
	out.append(shield("Shield_kite", "kite"))
	return out + helms() + [cloak()] + ranged()

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
		 "RightUpperArm": (-16, -5, 0), "LeftUpperArm": (18, 5, 0)},
		both("LowerArm", (16, 0, 0)), Chest=(0, 0, -4), Spine=(-2, 0, 0), loc={"Hips": (0, 0, -0.025)})
	passing = pose(
		{"RightUpperLeg": (0, 0, 0), "RightLowerLeg": (-6, 0, 0), "LeftUpperLeg": (8, 0, 0),
		 "LeftLowerLeg": (-45, 0, 0), "LeftFoot": (10, 0, 0)},
		both("UpperArm", (2, -5, 0)), both("LowerArm", (14, 0, 0)), Spine=(-2, 0, 0), loc={"Hips": (0, 0, 0.01)})
	return [(0, contact), (8, passing), (15, mirror_pose(contact)), (23, mirror_pose(passing)), (30, contact)]


def run():
	stride = pose(
		{"RightUpperLeg": (48, 0, 0), "RightLowerLeg": (-20, 0, 0), "RightFoot": (-10, 0, 0),
		 "LeftUpperLeg": (-32, 0, 0), "LeftLowerLeg": (-75, 0, 0), "LeftFoot": (30, 0, 0),
		 "RightUpperArm": (-38, -8, 0), "LeftUpperArm": (48, 8, 0),
		 "RightLowerArm": (70, 0, 0), "LeftLowerArm": (85, 0, 0)},
		Spine=(-10, 0, 0), Chest=(-2, 0, -8), Head=(10, 0, 6), loc={"Hips": (0, 0, -0.045)})
	flight = pose(
		{"RightUpperLeg": (12, 0, 0), "RightLowerLeg": (-25, 0, 0), "LeftUpperLeg": (24, 0, 0),
		 "LeftLowerLeg": (-105, 0, 0), "LeftFoot": (20, 0, 0)},
		both("UpperArm", (6, -8, 0)), both("LowerArm", (80, 0, 0)),
		Spine=(-10, 0, 0), Head=(10, 0, 0), loc={"Hips": (0, 0, 0.03)})
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
	a = STAND
	b = pose(STAND, both("UpperArm", (6, -6, 0)), Chest=(2, 0, 0), Head=(-2, 0, 0), loc={"Hips": (0, 0, -0.005)})
	c = pose(STAND, Chest=(0, 0, 0), Head=(0, 0, 14))
	return [(0, a), (30, b), (60, a), (75, c), (90, a)]


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
	wind = pose(READY, {"RightUpperArm": (150, -30, 0), "RightLowerArm": (60, 0, 0), "RightHand": (-20, 0, 0)},
				Chest=(2, 0, -18), Spine=(-2, 0, -6))
	strike = pose(READY, {"RightUpperArm": (40, 14, 0), "RightLowerArm": (12, 0, 0), "RightHand": (20, 0, 0)},
				  Chest=(-8, 0, 22), Spine=(-10, 0, 8), loc={"Hips": (0, 0.03, -0.07)})
	a["attack_1h"] = one_shot((5, wind), (9, strike), (12, strike))
	wind_b = pose(READY, {"RightUpperArm": (85, -75, 0), "RightLowerArm": (35, 0, 0)}, Chest=(0, 0, -30))
	strike_b = pose(READY, {"RightUpperArm": (80, 35, 0), "RightLowerArm": (10, 0, 0)}, Chest=(-4, 0, 32))
	a["attack_1h_b"] = one_shot((5, wind_b), (9, strike_b), (12, strike_b))
	wind2 = pose(READY, both("UpperArm", (160, -6, 0)), both("LowerArm", (70, 0, 0)),
				 {"LeftUpperArm": (160, -20, 0)}, Spine=(6, 0, 0), Chest=(4, 0, 0))
	strike2 = pose(READY, both("UpperArm", (30, 8, 0)), both("LowerArm", (10, 0, 0)), {"LeftUpperArm": (40, -30, 0)},
				   Spine=(-20, 0, 0), Chest=(-6, 0, 0), loc={"Hips": (0, 0.04, -0.1)})
	a["attack_2h"] = one_shot((7, wind2), (12, strike2), (16, strike2))
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
	c1 = pose(STAND, both("UpperArm", (45, 22, 0)), both("LowerArm", (95, 0, 0)), both("Hand", (-10, 0, 0)),
			  Spine=(3, 0, 0), Head=(-4, 0, 0))
	c2 = pose(c1, {"RightUpperArm": (52, 18, 0), "LeftUpperArm": (40, 26, 0)}, Chest=(2, 0, 3))
	c3 = pose(c1, {"RightUpperArm": (40, 26, 0), "LeftUpperArm": (52, 18, 0)}, Chest=(2, 0, -3))
	a["cast"] = [(0, c1), (8, c2), (16, c1), (24, c3), (32, c1)]
	thrust = pose(READY, both("UpperArm", (82, 12, 0)), both("LowerArm", (8, 0, 0)), Spine=(-10, 0, 0), Chest=(-4, 0, 0))
	a["cast_release"] = one_shot((4, thrust), (8, thrust), start=c1, end=STAND)
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
	global RACE
	for race, shape in RACES.items():
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
	parts = [body("BodyMale", False), body("BodyFemale", True), shoulders()] + hairs() + props()
	tris = {}
	for builder in parts:
		obj = builder.build(arm, material)
		tris[builder.name] = sum(len(f) - 2 for f in builder.faces)
	key_animations(arm, all_animations())
	os.makedirs(os.path.dirname(out), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=blend)
	bpy.ops.export_scene.gltf(
		filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
		export_skins=True, export_morph=False, export_yup=True, export_apply=False,
		export_optimize_animation_size=False,
	)
	print("triangles:", tris)
	print("wrote", out)


main()
