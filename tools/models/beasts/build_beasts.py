"""Builds the beast models: a four-legged rig shared by the wolf, boar and
bear, and an eight-legged spider, each with its animations, exported to
assets/models/<species>/<species>.glb (a .blend of each saved beside this
script).

Run headless:
  "C:\\Program Files\\Blender Foundation\\Blender 4.5\\blender.exe" --background --python tools/models/beasts/build_beasts.py

It reuses the humanoid script's mesh builder, colour slots and keyframing
(tools/models/human/build_human.py): the same conventions hold. Beasts stand
at the origin facing +Y; poses are degrees about the armature's axes,
relative to the parent (+X swings a hanging leg forward; for right-side legs
-Y lifts them out to the side; left-side entries are mirrored by `both`).
Colours: "skin" is the coat, "hair" the darker markings (mane, back, tail
tip), "chest" the lighter belly, "eyes", and "trim" for teeth, tusks and
claws. Each species' shape is the wolf's reshaped by SPECIES (leg length,
body length, width), as the races are in the humanoid script.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "human"))
import build_human as bh  # noqa: E402

ROOT = bh.ROOT
FPS = 30

# Shape of each species, from the wolf's: legs (heights below the body),
# length (along the body), width, and the head's size.
SPECIES = {
	"wolf": {"legs": 1.0, "length": 1.0, "width": 1.0, "head": 1.0},
	"boar": {"legs": 0.7, "length": 0.95, "width": 1.3, "head": 1.15},
	"bear": {"legs": 0.95, "length": 1.15, "width": 1.45, "head": 1.2},
}
SHAPE = SPECIES["wolf"]
BODY_Z = 0.62


def beast_point(v):
	v = Vector(v)
	z = v.z * SHAPE["legs"] if v.z <= BODY_Z else BODY_Z * SHAPE["legs"] + (v.z - BODY_Z) * SHAPE["width"]
	return Vector((v.x * SHAPE["width"], v.y * SHAPE["length"], z))


def _side(x, v):
	return (v[0] * x, v[1], v[2])


QUAD_BONES = [
	("Root", (0, 0, 0), (0, 0, 0.2), None),
	("Pelvis", (0, -0.32, 0.62), (0, -0.05, 0.64), "Root"),
	("Chest", (0, -0.05, 0.64), (0, 0.3, 0.66), "Pelvis"),
	("Neck", (0, 0.3, 0.66), (0, 0.45, 0.8), "Chest"),
	("Head", (0, 0.45, 0.8), (0, 0.72, 0.78), "Neck"),
	("Tail", (0, -0.36, 0.64), (0, -0.7, 0.5), "Pelvis"),
]
for side, x in (("Right", 1), ("Left", -1)):
	QUAD_BONES += [
		(side + "FrontUpper", _side(x, (0.13, 0.27, 0.58)), _side(x, (0.13, 0.3, 0.32)), "Chest"),
		(side + "FrontLower", _side(x, (0.13, 0.3, 0.32)), _side(x, (0.13, 0.28, 0.06)), side + "FrontUpper"),
		(side + "FrontPaw", _side(x, (0.13, 0.28, 0.06)), _side(x, (0.13, 0.36, 0.02)), side + "FrontLower"),
		(side + "BackUpper", _side(x, (0.13, -0.3, 0.58)), _side(x, (0.13, -0.22, 0.34)), "Pelvis"),
		(side + "BackLower", _side(x, (0.13, -0.22, 0.34)), _side(x, (0.13, -0.32, 0.07)), side + "BackUpper"),
		(side + "BackPaw", _side(x, (0.13, -0.32, 0.07)), _side(x, (0.13, -0.25, 0.02)), side + "BackLower"),
	]

# The spider: a body low to the ground and eight legs fanning out.
SPIDER_LEG_ANGLES = [40, 12, -14, -40]
SPIDER_BONES = [
	("Root", (0, 0, 0), (0, 0, 0.2), None),
	("Thorax", (0, -0.05, 0.32), (0, 0.18, 0.32), "Root"),
	("Abdomen", (0, -0.05, 0.34), (0, -0.4, 0.42), "Thorax"),
]
for side, x in (("Right", 1), ("Left", -1)):
	for i, angle in enumerate(SPIDER_LEG_ANGLES):
		a = math.radians(angle)
		hip = (0.09 * x, 0.06 + 0.04 * math.sin(a), 0.32)
		knee = (x * (0.09 + 0.3 * math.cos(a)), 0.06 + 0.3 * math.sin(a), 0.55)
		foot = (x * (0.09 + 0.55 * math.cos(a)), 0.06 + 0.55 * math.sin(a), 0.0)
		SPIDER_BONES += [
			(f"{side}Leg{i + 1}Upper", hip, knee, "Thorax"),
			(f"{side}Leg{i + 1}Lower", knee, foot, f"{side}Leg{i + 1}Upper"),
		]


# ---------------------------------------------------------------- meshes

def quad_body(species):
	b = bh.Builder("Body")
	w = {"wolf": 1.0, "boar": 1.25, "bear": 1.3}[species]
	rings = [((0, -0.42, 0.62), 0.07 * w, 0.08 * w, "Pelvis"), ((0, -0.32, 0.62), 0.13 * w, 0.15 * w, "Pelvis"),
			 ((0, -0.08, 0.63), 0.14 * w, 0.16 * w, "Pelvis"), ((0, 0.12, 0.65), 0.15 * w, 0.18 * w, "Chest"),
			 ((0, 0.3, 0.67), 0.12 * w, 0.15 * w, "Chest")]
	b.loft(rings, ["skin"] * 4, sides=8)
	b.box((0, 0.1, 0.5), (0.18 * w, 0.32, 0.06), "Chest", "chest")
	if species == "boar":
		b.box((0, -0.05, 0.82), (0.05, 0.6, 0.06), "Chest", "hair", top=(0.5, 0.9))
	if species == "wolf":
		b.box((0, 0.2, 0.7), (0.2, 0.18, 0.2), "Chest", "hair", top=(0.8, 0.8))
	# Neck.
	b.loft([((0, 0.26, 0.68), 0.09 * w, 0.1 * w, "Neck"), ((0, 0.46, 0.8), 0.075 * w, 0.08 * w, "Neck")], ["skin"], sides=6)
	# Head and snout along +Y.
	if species == "wolf":
		head = [((0, 0.42, 0.82), 0.085, 0.09, "Head"), ((0, 0.53, 0.84), 0.095, 0.09, "Head"),
				((0, 0.63, 0.8), 0.05, 0.05, "Head"), ((0, 0.74, 0.77), 0.03, 0.03, "Head")]
		ears = ((0.055, 0.47, 0.94), (0.035, 0.05, 0.1), (0.3, 0.4))
	elif species == "boar":
		head = [((0, 0.38, 0.72), 0.11, 0.12, "Head"), ((0, 0.5, 0.72), 0.1, 0.11, "Head"),
				((0, 0.64, 0.66), 0.065, 0.065, "Head"), ((0, 0.72, 0.63), 0.06, 0.055, "Head")]
		ears = ((0.07, 0.42, 0.84), (0.03, 0.06, 0.08), (1.0, 1.4))
	else:
		head = [((0, 0.4, 0.82), 0.11, 0.11, "Head"), ((0, 0.52, 0.84), 0.12, 0.11, "Head"),
				((0, 0.62, 0.8), 0.07, 0.065, "Head"), ((0, 0.68, 0.78), 0.05, 0.045, "Head")]
		ears = ((0.08, 0.44, 0.95), (0.05, 0.03, 0.05), (1.2, 1.0))
	b.loft(head, ["skin", "skin", "skin"], sides=8, cap_slots=("skin", "eyes"))
	tip = Vector(head[-1][0])
	for x in (-1, 1):
		ex, ey, ez = ears[0]
		b.box((ex * x, ey, ez), ears[1], "Head", "skin", top=ears[2], shade=0.9)
		eye_y = head[1][0][1] + 0.02
		b.box((0.06 * x * (1.2 if species != "wolf" else 1.0), eye_y, head[1][0][2] + 0.03), (0.025, 0.025, 0.02), "Head", "eyes")
		if species == "boar":
			b.beam((0.055 * x, tip.y - 0.04, tip.z - 0.02), (0.08 * x, tip.y + 0.02, tip.z + 0.07), 0.025, 0.025, "Head", "trim", taper=0.3)
		else:
			b.box((0.025 * x, tip.y - 0.03, tip.z - 0.035), (0.012, 0.012, 0.03), "Head", "trim")
	# Legs and paws.
	leg = {"wolf": 0.045, "boar": 0.055, "bear": 0.085}[species]
	for side, x in (("Right", 1), ("Left", -1)):
		for end in ("Front", "Back"):
			up = [bb for bb in QUAD_BONES if bb[0] == side + end + "Upper"][0]
			low = [bb for bb in QUAD_BONES if bb[0] == side + end + "Lower"][0]
			paw = [bb for bb in QUAD_BONES if bb[0] == side + end + "Paw"][0]
			b.tube(Vector(up[1]) + Vector((0, 0, 0.06)), up[2], leg * 1.4, leg, up[0], "skin")
			b.tube(low[1], low[2], leg, leg * 0.8, low[0], "skin")
			b.box(Vector(paw[1]) + Vector((0, 0.03, -0.03)), (leg * 2.2, leg * 2.6, 0.05), paw[0], "skin", shade=0.8)
			for c in (-1, 1):
				b.box(Vector(paw[1]) + Vector((c * leg * 0.6, 0.03 + leg * 1.4, -0.035)), (0.012, 0.025, 0.012), paw[0], "trim")
	# Tail.
	if species == "wolf":
		b.loft([((0, -0.38, 0.64), 0.03, 0.03, "Tail"), ((0, -0.5, 0.6), 0.055, 0.055, "Tail"),
				((0, -0.66, 0.52), 0.045, 0.045, "Tail"), ((0, -0.74, 0.48), 0.02, 0.02, "Tail")],
			   ["skin", "skin", "hair"], sides=6)
	elif species == "boar":
		b.beam((0, -0.42, 0.66), (0, -0.52, 0.6), 0.02, 0.02, "Tail", "skin", taper=0.5)
	else:
		b.box((0, -0.45, 0.68), (0.07, 0.06, 0.07), "Tail", "skin")
	return b


def spider_body():
	b = bh.Builder("Body")
	b.loft([((0, -0.02, 0.3), 0.08, 0.06, "Thorax"), ((0, 0.08, 0.32), 0.13, 0.08, "Thorax"),
			((0, 0.2, 0.31), 0.09, 0.06, "Thorax"), ((0, 0.26, 0.3), 0.05, 0.04, "Thorax")],
		   ["skin", "skin", "skin"], sides=8)
	b.loft([((0, -0.06, 0.36), 0.09, 0.08, "Abdomen"), ((0, -0.2, 0.44), 0.2, 0.17, "Abdomen"),
			((0, -0.38, 0.44), 0.18, 0.15, "Abdomen"), ((0, -0.5, 0.38), 0.07, 0.06, "Abdomen")],
		   ["skin", "skin", "skin"], sides=8)
	b.box((0, -0.25, 0.6), (0.12, 0.2, 0.03), "Abdomen", "hair", top=(0.6, 0.6))
	for x in (-1, 1):
		b.box((0.035 * x, 0.25, 0.34), (0.025, 0.02, 0.025), "Thorax", "eyes")
		b.box((0.06 * x, 0.23, 0.36), (0.02, 0.02, 0.02), "Thorax", "eyes")
		b.beam((0.03 * x, 0.27, 0.28), (0.035 * x, 0.32, 0.2), 0.025, 0.025, "Thorax", "trim", taper=0.3)
	for name, head, tail, _parent in SPIDER_BONES:
		if "Leg" in name:
			lower = name.endswith("Lower")
			b.beam(head, tail, 0.035 if not lower else 0.028, 0.035 if not lower else 0.028, name,
				   "skin" if not lower else "hair", taper=0.6, up=(0, 1, 0))
	return b


# ---------------------------------------------------------------- animation

both = bh.both
pose = bh.pose
mirror_pose = bh.mirror_pose


def legs(name_angles):
	out = {}
	for name, rot in name_angles.items():
		out[name] = rot
	return out


def quad_gait(frames, phases, swing, lift, spine=0.0, bob=0.0):
	"""A looping gait: each leg swings by a sine with its phase; the lower leg
	bends while the leg comes forward."""
	keys = []
	for f in range(0, frames + 1, 2):
		t = f / frames
		p = {}
		for leg, phase in phases.items():
			a = math.sin(math.tau * (t + phase))
			fwd = math.cos(math.tau * (t + phase))
			p[leg + "Upper"] = (swing * a, 0, 0)
			bend = -lift * max(0.0, fwd) if "Front" in leg else lift * max(0.0, fwd)
			p[leg + "Lower"] = (bend, 0, 0)
			p[leg + "Paw"] = (-bend * 0.5, 0, 0)
		p["Chest"] = (spine * math.sin(math.tau * t * 2), 0, 0)
		p["Pelvis"] = (-spine * 0.5 * math.sin(math.tau * t * 2), 0, 0)
		p["Head"] = (-spine * 0.4 * math.sin(math.tau * t * 2), 0, 0)
		p["Tail"] = (0, 0, 8 * math.sin(math.tau * t))
		p["loc"] = {"Root": (0, 0, bob * abs(math.sin(math.tau * t * 2)))}
		keys.append((f, p))
	return keys


def quad_animations():
	a = {}
	stand = {}
	breathe = pose(stand, Chest=(2, 0, 0), Head=(-3, 0, 6), Tail=(0, 0, 10))
	a["idle"] = [(0, stand), (30, breathe), (45, pose(stand, Head=(0, 0, -10), Tail=(0, 0, -8))), (60, stand)]
	a["walk"] = quad_gait(32, {"RightFront": 0.0, "LeftBack": 0.0, "LeftFront": 0.5, "RightBack": 0.5}, 20, 35)
	a["run"] = quad_gait(16, {"RightFront": 0.0, "LeftFront": 0.1, "RightBack": 0.5, "LeftBack": 0.6}, 38, 60, spine=8, bob=0.06)
	ready = pose(stand, both("FrontUpper", (8, -4, 0)), both("BackUpper", (-6, -4, 0)), Neck=(-10, 0, 0), Head=(8, 0, 0),
				 loc={"Root": (0, 0, -0.04)})
	lunge = pose(ready, both("FrontUpper", (25, -4, 0)), both("BackUpper", (-20, 0, 0)), Neck=(-22, 0, 0), Head=(18, 0, 0),
				 loc={"Root": (0, 0.16, -0.02)})
	a["ready"] = [(0, ready), (20, pose(ready, Chest=(2, 0, 0))), (40, ready)]
	a["attack"] = [(0, ready), (6, lunge), (9, lunge), (18, ready)]
	flinch = pose(ready, Chest=(8, 0, 0), Neck=(10, 0, 0), Head=(8, 0, 0), loc={"Root": (0, -0.06, 0)})
	a["hit"] = [(0, ready), (3, flinch), (10, ready)]
	slump = pose(stand, both("FrontUpper", (40, -10, 0)), both("FrontLower", (-60, 0, 0)), both("BackUpper", (-30, -10, 0)),
				 both("BackLower", (60, 0, 0)), Neck=(-20, 0, 0), loc={"Root": (0, 0, -0.25)})
	dead = pose(both("FrontUpper", (30, -20, 0)), both("BackUpper", (-20, -20, 0)), Neck=(-10, 0, 10), Head=(-10, 0, 0),
				Tail=(0, 0, 20), Root=(0, 90, 0), loc={"Root": (0, 0, 0.16)})
	a["death"] = [(0, ready), (6, slump), (14, pose(dead, Root=(0, 70, 0))), (18, dead), (21, pose(dead, Root=(0, 84, 0))), (24, dead)]
	a["dead"] = [(0, dead), (10, dead)]
	return a


def spider_gait(frames, swing, lift):
	keys = []
	for f in range(0, frames + 1, 2):
		t = f / frames
		p = {}
		for side, x in (("Right", 1), ("Left", -1)):
			for i in range(4):
				group = (i + (0 if x > 0 else 1)) % 2
				a = math.sin(math.tau * (t + group * 0.5))
				up = max(0.0, math.cos(math.tau * (t + group * 0.5)))
				# Swing forward and back about the vertical, lifting while it swings forward.
				rot = (0, -lift * up, swing * a)
				p[f"{side}Leg{i + 1}Upper"] = rot if x > 0 else (rot[0], -rot[1], -rot[2])
		p["Abdomen"] = (2 * math.sin(math.tau * t * 2), 0, 3 * math.sin(math.tau * t))
		keys.append((f, p))
	return keys


def spider_animations():
	a = {}
	stand = {}
	a["idle"] = [(0, stand), (30, pose(stand, Abdomen=(4, 0, 0))), (60, stand)]
	a["walk"] = spider_gait(24, 14, 18)
	a["run"] = spider_gait(14, 18, 24)
	ready = pose(stand, both("Leg1Upper", (0, -20, 0)), Thorax=(-4, 0, 0))
	a["ready"] = [(0, ready), (20, pose(ready, Abdomen=(4, 0, 0))), (40, ready)]
	strike = pose(stand, both("Leg1Upper", (0, -50, 15)), both("Leg2Upper", (0, -15, 0)), Thorax=(10, 0, 0),
				  loc={"Root": (0, 0.12, 0.04)})
	bite = pose(stand, both("Leg1Upper", (0, -10, -10)), Thorax=(-12, 0, 0), loc={"Root": (0, 0.16, -0.02)})
	a["attack"] = [(0, ready), (5, strike), (8, bite), (16, ready)]
	a["hit"] = [(0, ready), (3, pose(ready, Thorax=(10, 0, 0), loc={"Root": (0, -0.06, 0)})), (10, ready)]
	curled = {}
	for i in range(4):
		curled.update(both(f"Leg{i + 1}Upper", (0, -55, 0)))
		curled.update(both(f"Leg{i + 1}Lower", (0, -50, 0)))
	dead = pose(curled, loc={"Root": (0, 0, -0.16)})
	a["death"] = [(0, ready), (5, pose(ready, Thorax=(14, 0, 0))), (14, dead), (20, dead)]
	a["dead"] = [(0, dead), (10, dead)]
	return a


# ---------------------------------------------------------------- main

def build(species, bones, parts_fn, anims):
	out = os.path.join(ROOT, "assets", "models", species, species + ".glb")
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.scene.render.fps = FPS
	bh.BONES = bones
	arm = bh.build_armature()
	material = bpy.data.materials.new("Character")
	part = parts_fn()
	part.build(arm, material)
	bh.key_animations(arm, anims)
	os.makedirs(os.path.dirname(out), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, species + ".blend"))
	bpy.ops.export_scene.gltf(
		filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
		export_skins=True, export_morph=False, export_yup=True, export_apply=False,
		export_optimize_animation_size=False,
	)
	print(species, "triangles:", sum(len(f) - 2 for f in part.faces))
	print("wrote", out)


def main():
	global SHAPE
	# Beasts aren't reshaped by the humanoid races: the species shape instead.
	bh.place = lambda v, group: beast_point(v)
	for species, shape in SPECIES.items():
		SHAPE = shape
		build(species, QUAD_BONES, lambda: quad_body(species), quad_animations())
	SHAPE = {"legs": 1.0, "length": 1.0, "width": 1.0, "head": 1.0}
	build("spider", SPIDER_BONES, spider_body, spider_animations())


if __name__ == "__main__":
	main()
