"""Builds the beast models: a four-legged rig shared by the wolf, boar, bear,
tiger and thunder lizard (whose long tail adds two bones, LIZARD_BONES), and
the eight-legged spider, scorpion and crab (the spider's legs, `eight_legs`,
with pincer arms, `claw_bones`, and the scorpion's tail of five segments),
each with its animations, exported to assets/models/<species>/<species>.glb
(a .blend of each saved beside this script).

Run headless (`-- tiger crab` after it builds only those):
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
	"tiger": {"legs": 0.95, "length": 1.18, "width": 1.08, "head": 1.05},
	# Low-slung and long, its tail three bones (LIZARD_BONES).
	"thunder_lizard": {"legs": 0.55, "length": 1.3, "width": 1.15, "head": 1.1},
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

# The thunder lizard's long tail goes on past the Tail bone in two more.
LIZARD_BONES = QUAD_BONES + [
	("Tail2", (0, -0.7, 0.5), (0, -1.0, 0.4), "Tail"),
	("Tail3", (0, -1.0, 0.4), (0, -1.32, 0.33), "Tail2"),
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


def eight_legs(angles, hip_x, hip_y, hip_z, knee, foot, knee_z):
	"""The spider's eight legs for another body: each fans out at its angle
	from the hip, its knee `knee` out and `knee_z` up, its foot `foot` out."""
	bones = []
	for side, x in (("Right", 1), ("Left", -1)):
		for i, angle in enumerate(angles):
			a = math.radians(angle)
			hip = (hip_x * x, hip_y + 0.04 * math.sin(a), hip_z)
			k = (x * (hip_x + knee * math.cos(a)), hip_y + knee * math.sin(a), knee_z)
			f = (x * (hip_x + foot * math.cos(a)), hip_y + foot * math.sin(a), 0.0)
			bones += [
				(f"{side}Leg{i + 1}Upper", hip, k, "Thorax"),
				(f"{side}Leg{i + 1}Lower", k, f, f"{side}Leg{i + 1}Upper"),
			]
	return bones


def claw_bones(shoulder, elbow, wrist, tip):
	"""A pincer arm on each side: upper and lower arm, and the pincer's
	moving jaw (the fixed jaw is on the lower arm)."""
	bones = []
	for side, x in (("Right", 1), ("Left", -1)):
		bones += [
			(side + "ClawUpper", _side(x, shoulder), _side(x, elbow), "Thorax"),
			(side + "ClawLower", _side(x, elbow), _side(x, wrist), side + "ClawUpper"),
			(side + "Pincer", _side(x, wrist), _side(x, tip), side + "ClawLower"),
		]
	return bones


# The scorpion: a long low body on eight legs, pincers reaching forward and a
# tail of five segments curling up over its back to the stinger.
SCORPION_TAIL = [(0, -0.4, 0.27), (0, -0.56, 0.38), (0, -0.64, 0.56), (0, -0.6, 0.74), (0, -0.48, 0.86), (0, -0.33, 0.84)]
SCORPION_BONES = [
	("Root", (0, 0, 0), (0, 0, 0.2), None),
	("Thorax", (0, -0.05, 0.24), (0, 0.2, 0.24), "Root"),
	("Abdomen", (0, -0.05, 0.25), (0, -0.4, 0.27), "Thorax"),
] + eight_legs([28, 6, -16, -38], 0.1, -0.02, 0.22, 0.26, 0.46, 0.42) + claw_bones(
	(0.08, 0.2, 0.24), (0.22, 0.36, 0.27), (0.2, 0.56, 0.27), (0.19, 0.7, 0.27)) + [
	(f"Tail{i + 1}" if i < 4 else "Stinger", SCORPION_TAIL[i], SCORPION_TAIL[i + 1], "Abdomen" if i == 0 else f"Tail{i}")
	for i in range(5)
]

# The crab: a wide flat shell, its legs out to the sides and back, and two big
# claws held up in front.
CRAB_BONES = [
	("Root", (0, 0, 0), (0, 0, 0.2), None),
	("Thorax", (0, -0.08, 0.3), (0, 0.14, 0.3), "Root"),
	("Abdomen", (0, -0.08, 0.26), (0, -0.24, 0.22), "Thorax"),
] + eight_legs([12, -10, -32, -54], 0.22, -0.05, 0.26, 0.26, 0.5, 0.42) + claw_bones(
	(0.2, 0.14, 0.3), (0.34, 0.32, 0.4), (0.26, 0.56, 0.44), (0.22, 0.76, 0.44))


# ---------------------------------------------------------------- meshes

def quad_body(species):
	b = bh.Builder("Body")
	w = {"wolf": 1.0, "boar": 1.25, "bear": 1.3, "tiger": 1.1, "thunder_lizard": 1.15}[species]
	rings = [((0, -0.42, 0.62), 0.07 * w, 0.08 * w, "Pelvis"), ((0, -0.32, 0.62), 0.13 * w, 0.15 * w, "Pelvis"),
			 ((0, -0.08, 0.63), 0.14 * w, 0.16 * w, "Pelvis"), ((0, 0.12, 0.65), 0.15 * w, 0.18 * w, "Chest"),
			 ((0, 0.3, 0.67), 0.12 * w, 0.15 * w, "Chest")]
	b.loft(rings, ["skin"] * 4, sides=8)
	b.box((0, 0.1, 0.5), (0.18 * w, 0.32, 0.06), "Chest", "chest")
	if species == "boar":
		b.box((0, -0.05, 0.82), (0.05, 0.6, 0.06), "Chest", "hair", top=(0.5, 0.9))
	if species == "wolf":
		b.box((0, 0.2, 0.7), (0.2, 0.18, 0.2), "Chest", "hair", top=(0.8, 0.8))
	if species == "tiger":
		# Stripes across the back and down the flanks.
		for y in (-0.36, -0.24, -0.12, 0.0, 0.12, 0.24):
			bone = "Pelvis" if y < 0.0 else "Chest"
			top = 0.62 + 0.165 * w + 0.005 + (0.02 if y > 0 else 0.0)
			b.box((0, y, top), (0.2 * w, 0.035, 0.025), bone, "hair")
			for x in (-1, 1):
				b.box((x * 0.145 * w, y + 0.01, 0.66), (0.02, 0.03, 0.15), bone, "hair", top=(1.0, 0.6))
	if species == "thunder_lizard":
		# The crest: a row of plates from the neck down the back.
		for y, z, h, bone in ((0.3, 0.84, 0.09, "Chest"), (0.18, 0.86, 0.12, "Chest"), (0.04, 0.84, 0.13, "Chest"),
							  (-0.1, 0.82, 0.13, "Pelvis"), (-0.24, 0.81, 0.11, "Pelvis"), (-0.36, 0.78, 0.09, "Pelvis")):
			b.beam((0, y, z - 0.06), (0, y - 0.05, z + h), 0.09, 0.03, bone, "hair", taper=0.2, up=(0, 1, 0))
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
	elif species == "tiger":
		head = [((0, 0.42, 0.8), 0.1, 0.1, "Head"), ((0, 0.52, 0.82), 0.11, 0.1, "Head"),
				((0, 0.61, 0.78), 0.075, 0.065, "Head"), ((0, 0.67, 0.76), 0.05, 0.045, "Head")]
		ears = ((0.07, 0.45, 0.92), (0.045, 0.03, 0.05), (0.7, 0.8))
	elif species == "thunder_lizard":
		# Long and flat, wide at the jaw, a crest on the brow.
		head = [((0, 0.42, 0.74), 0.08, 0.075, "Head"), ((0, 0.54, 0.76), 0.1, 0.075, "Head"),
				((0, 0.68, 0.72), 0.07, 0.05, "Head"), ((0, 0.8, 0.7), 0.04, 0.032, "Head")]
		ears = None
	else:
		head = [((0, 0.4, 0.82), 0.11, 0.11, "Head"), ((0, 0.52, 0.84), 0.12, 0.11, "Head"),
				((0, 0.62, 0.8), 0.07, 0.065, "Head"), ((0, 0.68, 0.78), 0.05, 0.045, "Head")]
		ears = ((0.08, 0.44, 0.95), (0.05, 0.03, 0.05), (1.2, 1.0))
	b.loft(head, ["skin", "skin", "skin"], sides=8, cap_slots=("skin", "eyes"))
	tip = Vector(head[-1][0])
	for x in (-1, 1):
		if ears:
			ex, ey, ez = ears[0]
			b.box((ex * x, ey, ez), ears[1], "Head", "skin", top=ears[2], shade=0.9)
		eye_y = head[1][0][1] + 0.02
		b.box((0.06 * x * (1.2 if species != "wolf" else 1.0), eye_y, head[1][0][2] + 0.03), (0.025, 0.025, 0.02), "Head", "eyes")
		if species == "tiger":
			# Fangs, cheek ruffs and the stripes over the brow.
			b.beam((0.03 * x, tip.y - 0.03, tip.z - 0.02), (0.03 * x, tip.y - 0.02, tip.z - 0.08), 0.016, 0.016, "Head", "trim", taper=0.3)
			b.beam((0.09 * x, 0.46, 0.78), (0.14 * x, 0.44, 0.72), 0.06, 0.03, "Head", "chest", taper=0.3)
			b.box((0.04 * x, 0.5, 0.91), (0.025, 0.06, 0.015), "Head", "hair")
		elif species == "thunder_lizard":
			# A row of teeth along the jaw, horns back from the brow.
			for k in range(3):
				b.box((0.06 * x - 0.008 * k * x, 0.58 + 0.07 * k, 0.69 - 0.01 * k), (0.012, 0.02, 0.025), "Head", "trim")
			b.beam((0.06 * x, 0.46, 0.8), (0.1 * x, 0.36, 0.86), 0.03, 0.03, "Head", "trim", taper=0.3)
		elif species == "boar":
			b.beam((0.055 * x, tip.y - 0.04, tip.z - 0.02), (0.08 * x, tip.y + 0.02, tip.z + 0.07), 0.025, 0.025, "Head", "trim", taper=0.3)
		else:
			b.box((0.025 * x, tip.y - 0.03, tip.z - 0.035), (0.012, 0.012, 0.03), "Head", "trim")
	# Legs and paws.
	if species == "thunder_lizard":
		b.box((0, 0.6, 0.82), (0.03, 0.2, 0.06), "Head", "hair", top=(1.0, 0.5))
		b.box((0, 0.56, 0.69), (0.16, 0.2, 0.025), "Head", "chest", top=(0.7, 0.8))
	leg = {"wolf": 0.045, "boar": 0.055, "bear": 0.085, "tiger": 0.06, "thunder_lizard": 0.075}[species]
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
	elif species == "tiger":
		b.loft([((0, -0.38, 0.64), 0.035, 0.035, "Tail"), ((0, -0.52, 0.58), 0.035, 0.035, "Tail"),
				((0, -0.62, 0.53), 0.033, 0.033, "Tail"), ((0, -0.72, 0.48), 0.03, 0.03, "Tail"),
				((0, -0.8, 0.46), 0.02, 0.02, "Tail")],
			   ["skin", "hair", "skin", "hair"], sides=6)
	elif species == "thunder_lizard":
		# The tail, thick at the hips, tapering to a point down three bones, a
		# crest along it.
		b.loft([((0, -0.38, 0.64), 0.1, 0.1, "Tail"), ((0, -0.7, 0.5), 0.08, 0.075, "Tail2"),
				((0, -1.0, 0.4), 0.05, 0.045, "Tail3"), ((0, -1.32, 0.33), 0.015, 0.015, "Tail3")],
			   ["skin", "skin", "skin"], sides=8)
		for y, z, h, bone in ((-0.5, 0.69, 0.08, "Tail"), (-0.66, 0.6, 0.07, "Tail"), (-0.84, 0.52, 0.06, "Tail2"),
							  (-1.0, 0.46, 0.05, "Tail2"), (-1.16, 0.4, 0.04, "Tail3")):
			b.beam((0, y, z - 0.04), (0, y - 0.04, z + h), 0.07, 0.025, bone, "hair", taper=0.2, up=(0, 1, 0))
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


def _arthropod_legs(b, bones, upper, lower):
	for name, head, tail, _parent in bones:
		if "Leg" in name:
			low = name.endswith("Lower")
			r = lower if low else upper
			b.beam(head, tail, r, r, name, "hair" if low else "skin", taper=0.55, up=(0, 1, 0))


def _claws(b, bones, arm, claw, jaw):
	"""Each pincer arm: the arm in segments, a swollen claw on the lower arm
	ending in its fixed jaw, and the moving jaw beside it."""
	at = {name: (Vector(head), Vector(tail)) for name, head, tail, _parent in bones}
	for side, x in (("Right", 1), ("Left", -1)):
		up0, up1 = at[side + "ClawUpper"]
		lo0, lo1 = at[side + "ClawLower"]
		p0, p1 = at[side + "Pincer"]
		b.beam(up0, up1, arm, arm, side + "ClawUpper", "skin", taper=0.8, up=(0, 0, 1))
		b.beam(lo0, lo0 + (lo1 - lo0) * 0.35, arm * 0.9, arm * 0.9, side + "ClawLower", "skin", taper=1.3, up=(0, 0, 1))
		mid = lo0 + (lo1 - lo0) * 0.65
		b.loft([(lo0 + (lo1 - lo0) * 0.3, claw * 0.6, claw * 0.45, side + "ClawLower"),
				(mid, claw, claw * 0.7, side + "ClawLower"),
				(lo1, claw * 0.75, claw * 0.55, side + "ClawLower")], ["skin", "skin"], sides=6)
		# The fixed jaw on the inside, the moving one on the outside.
		inner = Vector((-x * jaw * 0.6, 0, 0))
		outer = Vector((x * jaw * 0.6, 0, 0))
		b.beam(lo1 + inner, p1 + inner + (p1 - p0) * 0.2, jaw, jaw * 0.8, side + "ClawLower", "trim", taper=0.3)
		b.beam(p0 + outer, p1 + outer + (p1 - p0) * 0.2, jaw, jaw * 0.8, side + "Pincer", "trim", taper=0.3)


def scorpion_body():
	b = bh.Builder("Body")
	# Head and thorax under a shield, then the segmented abdomen.
	b.loft([((0, -0.04, 0.24), 0.11, 0.06, "Thorax"), ((0, 0.08, 0.25), 0.13, 0.065, "Thorax"),
			((0, 0.2, 0.24), 0.09, 0.05, "Thorax"), ((0, 0.25, 0.23), 0.05, 0.03, "Thorax")],
		   ["skin", "skin", "skin"], sides=8)
	b.loft([((0, -0.04, 0.26), 0.12, 0.065, "Abdomen"), ((0, -0.16, 0.27), 0.15, 0.07, "Abdomen"),
			((0, -0.3, 0.27), 0.12, 0.065, "Abdomen"), ((0, -0.42, 0.27), 0.06, 0.05, "Abdomen")],
		   ["skin", "skin", "skin"], sides=8)
	for y in (-0.1, -0.2, -0.3):
		b.box((0, y, 0.33), (0.2 if y > -0.25 else 0.15, 0.035, 0.02), "Abdomen", "hair")
	b.box((0, 0.06, 0.2), (0.2, 0.3, 0.03), "Thorax", "chest")
	for x in (-1, 1):
		b.box((0.03 * x, 0.16, 0.29), (0.02, 0.02, 0.02), "Thorax", "eyes")
		b.box((0.07 * x, 0.2, 0.27), (0.015, 0.015, 0.015), "Thorax", "eyes")
		b.beam((0.025 * x, 0.25, 0.23), (0.03 * x, 0.3, 0.2), 0.02, 0.02, "Thorax", "trim", taper=0.4)
	_arthropod_legs(b, SCORPION_BONES, 0.03, 0.024)
	_claws(b, SCORPION_BONES, 0.045, 0.09, 0.03)
	# The tail: segments thinning up the curl, a bulb and the stinger.
	for i in range(4):
		h, t = Vector(SCORPION_TAIL[i]), Vector(SCORPION_TAIL[i + 1])
		r = 0.06 - 0.007 * i
		b.loft([(h + (t - h) * 0.05, r * 0.8, r * 0.8, f"Tail{i + 1}"), (h + (t - h) * 0.5, r, r, f"Tail{i + 1}"),
				(t - (t - h) * 0.05, r * 0.8, r * 0.8, f"Tail{i + 1}")], ["skin", "skin"], sides=6)
	sh, st = Vector(SCORPION_TAIL[4]), Vector(SCORPION_TAIL[5])
	b.loft([(sh, 0.04, 0.04, "Stinger"), (sh + (st - sh) * 0.4, 0.06, 0.055, "Stinger"),
			(sh + (st - sh) * 0.8, 0.035, 0.035, "Stinger")], ["chest", "chest"], sides=6)
	b.beam(sh + (st - sh) * 0.75, st + Vector((0, 0.04, -0.1)), 0.03, 0.03, "Stinger", "trim", taper=0.15)
	return b


def crab_body():
	b = bh.Builder("Body")
	# A wide flat shell with a rim, a pale underside.
	b.loft([((0, -0.26, 0.28), 0.12, 0.05, "Thorax"), ((0, -0.18, 0.31), 0.27, 0.08, "Thorax"),
			((0, -0.02, 0.33), 0.32, 0.09, "Thorax"), ((0, 0.12, 0.31), 0.27, 0.075, "Thorax"),
			((0, 0.2, 0.28), 0.14, 0.04, "Thorax")],
		   ["skin", "skin", "skin", "skin"], sides=8)
	b.box((0, -0.04, 0.4), (0.3, 0.22, 0.03), "Thorax", "hair", top=(0.7, 0.7))
	b.box((0, -0.04, 0.24), (0.46, 0.34, 0.04), "Thorax", "chest", top=(1.1, 1.1))
	b.box((0, -0.2, 0.25), (0.16, 0.12, 0.05), "Abdomen", "chest")
	for x in (-1, 1):
		# Eyes on stalks, and the bumps along the shell's edge.
		b.beam((0.05 * x, 0.16, 0.34), (0.065 * x, 0.2, 0.45), 0.02, 0.02, "Thorax", "skin")
		b.box((0.065 * x, 0.2, 0.46), (0.035, 0.035, 0.035), "Thorax", "eyes")
		for y in (-0.1, 0.04):
			b.box((0.3 * x, y, 0.33), (0.05, 0.05, 0.04), "Thorax", "hair", top=(0.4, 0.4))
		b.box((0.03 * x, 0.2, 0.26), (0.025, 0.03, 0.02), "Thorax", "trim")
	_arthropod_legs(b, CRAB_BONES, 0.04, 0.03)
	_claws(b, CRAB_BONES, 0.065, 0.17, 0.055)
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


def lizard_animations():
	"""The four-legged animations, the tail's sway carried on down its
	other two bones, and a lower head."""
	out = {}
	for name, keys in quad_animations().items():
		out[name] = []
		for frame, p in keys:
			p = dict(p)
			sway = p.get("Tail", (0, 0, 0))
			p["Tail"] = (sway[0] + 8, sway[1], sway[2])
			p["Tail2"] = (sway[0] * 0.5 - 6, 0, sway[2] * 1.2)
			p["Tail3"] = (-4, 0, sway[2] * 1.4)
			out[name].append((frame, p))
	return out


def arthropod_animations(kind):
	"""The spider's leg animations, with the pincers and (the scorpion's)
	tail: raised in a fight, snapping and stinging on an attack."""
	base = spider_animations()
	scorpion = kind == "scorpion"
	rest = pose(both("ClawUpper", (6, 0, 0)), both("Pincer", (0, 0, -6)))
	ready = pose(both("ClawUpper", (22, 0, -6)), both("ClawLower", (-6, 0, 0)), both("Pincer", (0, 0, -18)))
	if scorpion:
		ready.update({"Tail2": (-8, 0, 0), "Tail3": (-6, 0, 0)})
	idle_sway = pose(both("ClawUpper", (10, 0, 4)), both("Pincer", (0, 0, -12)), Tail1=(-3, 0, 4), Tail3=(0, 0, -4))
	a = {}
	a["idle"] = [(0, pose(base["idle"][0][1], rest)), (30, pose(base["idle"][1][1], idle_sway)), (60, pose(base["idle"][2][1], rest))]
	a["walk"] = [(f, pose(p, rest, Tail1=(0, 0, 4 * math.sin(math.tau * f / 24)))) for f, p in base["walk"]]
	a["run"] = [(f, pose(p, rest, Tail1=(0, 0, 5 * math.sin(math.tau * f / 14)))) for f, p in base["run"]]
	r0 = pose(base["ready"][0][1], ready)
	a["ready"] = [(0, r0), (20, pose(base["ready"][1][1], ready, both("Pincer", (0, 0, -24)))), (40, r0)]
	if scorpion:
		# Pincers open and the tail drawn back, then the sting forward over
		# the head as the pincers snap shut.
		wind = pose(r0, both("ClawUpper", (28, 0, -14)), both("Pincer", (0, 0, -30)), Tail2=(8, 0, 0), Tail3=(6, 0, 0),
					Tail4=(6, 0, 0), Thorax=(-4, 0, 0))
		strike = pose(r0, both("ClawUpper", (14, 0, 6)), both("Pincer", (0, 0, 4)), Tail1=(-10, 0, 0), Tail2=(-28, 0, 0),
					  Tail3=(-24, 0, 0), Tail4=(-18, 0, 0), Stinger=(-20, 0, 0), Thorax=(6, 0, 0), loc={"Root": (0, 0.06, 0)})
	else:
		# Both claws up and open, then down together, snapping.
		wind = pose(r0, both("ClawUpper", (45, 0, -12)), both("ClawLower", (-20, 0, 0)), both("Pincer", (0, 0, -34)),
					Thorax=(-6, 0, 0))
		strike = pose(r0, both("ClawUpper", (-6, 0, 10)), both("ClawLower", (4, 0, 0)), both("Pincer", (0, 0, 4)),
					  Thorax=(6, 0, 0), loc={"Root": (0, 0.08, 0)})
	a["attack"] = [(0, r0), (5, wind), (9, strike), (12, strike), (20, r0)]
	a["hit"] = [(0, r0), (3, pose(r0, Thorax=(10, 0, 0), Tail2=(8, 0, 0), loc={"Root": (0, -0.06, 0)})), (10, r0)]
	limp = pose(both("ClawUpper", (-12, 0, -20)), both("ClawLower", (-10, 0, 0)), both("Pincer", (0, 0, -20)))
	if scorpion:
		limp.update({"Tail1": (20, 0, 10), "Tail2": (24, 0, 6), "Tail3": (16, 0, 0), "Tail4": (10, 0, 0)})
	dead = pose(base["dead"][0][1], limp)
	a["death"] = [(0, r0), (5, pose(base["death"][1][1], ready)), (14, dead), (20, dead)]
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
	"""Builds every beast, or those named after `--` (`-- tiger crab`)."""
	global SHAPE
	only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	# Beasts aren't reshaped by the humanoid races: the species shape instead.
	bh.place = lambda v, group: beast_point(v)
	for species, shape in SPECIES.items():
		if only and species not in only:
			continue
		SHAPE = shape
		if species == "thunder_lizard":
			build(species, LIZARD_BONES, lambda: quad_body(species), lizard_animations())
		else:
			build(species, QUAD_BONES, lambda: quad_body(species), quad_animations())
	SHAPE = {"legs": 1.0, "length": 1.0, "width": 1.0, "head": 1.0}
	for species, bones, body, anims in (("spider", SPIDER_BONES, spider_body, spider_animations),
										("scorpion", SCORPION_BONES, scorpion_body, lambda: arthropod_animations("scorpion")),
										("crab", CRAB_BONES, crab_body, lambda: arthropod_animations("crab"))):
		if not only or species in only:
			build(species, bones, body, anims())


if __name__ == "__main__":
	main()
