"""Builds the beast models: a four-legged rig shared by the wolf, boar, bear,
tiger and thunder lizard (whose long tail adds two bones, LIZARD_BONES), and
the eight-legged spider, scorpion and crab (the spider's legs, `eight_legs`,
with pincer arms, `claw_bones`, and the scorpion's tail of five segments),
the two-legged birds (`BIRDS`: tallbird, swoop, owl and the raptor, one rig proportioned
per species) and the hovering bat, each with its animations, exported to assets/models/<species>/<species>.glb
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


# The birds: two legs bending back at the ankle, a neck and beaked head, a
# fanned tail, and wings folded back along the body (spread about Z, raised
# about X). Each species is the same rig with its own proportions: hip height,
# body length and girth, how upright it stands, neck, head, beak and wing.
BIRDS = {
	# A tall flightless strider: long legs, long neck, stubby wings, a crest.
	"tallbird": {"hip": 0.62, "length": 0.5, "girth": 0.2, "upright": 0.08, "neck": (0.08, 0.36), "head": 0.08,
				 "beak": 0.15, "hook": 0.0, "wing": 0.28, "tail": 0.14, "leg": 0.03},
	# A big hunting bird walking the plains: hooked beak, long wings, a ruff.
	"swoop": {"hip": 0.3, "length": 0.52, "girth": 0.17, "upright": 0.1, "neck": (0.1, 0.12), "head": 0.09,
			  "beak": 0.09, "hook": 0.05, "wing": 0.6, "tail": 0.26, "leg": 0.03},
	# An owl, standing upright: a round body, a big flat-faced head with ear
	# tufts and great eyes, a short hooked beak.
	"owl": {"hip": 0.22, "length": 0.2, "girth": 0.19, "upright": 0.42, "neck": (0.02, 0.06), "head": 0.14,
			"beak": 0.04, "hook": 0.03, "wing": 0.4, "tail": 0.12, "leg": 0.03},
	# A raptor on the same rig (`arms`): a level body, a long stiff tail, a
	# toothed snout for the beak, small clawed arms on the wing bones, a quill
	# crest, stripes down its back and a sickle claw on each foot (raptor_body).
	"raptor": {"hip": 0.52, "length": 0.72, "girth": 0.19, "upright": 0.04, "neck": (0.2, 0.12), "head": 0.11,
			   "beak": 0.17, "hook": 0.0, "wing": 0.2, "tail": 0.85, "leg": 0.045, "arms": True},
}


# The bat: a small furry body hovering at BAT_HOVER, big ears, and membrane
# wings on two bones a side, held out (the rest pose is spread; flapping is
# about Y), feet hanging behind.
BAT_HOVER = 0.95
BAT_BONES = [
	("Root", (0, 0, 0), (0, 0, 0.2), None),
	("Body", (0, -0.1, BAT_HOVER), (0, 0.08, BAT_HOVER + 0.02), "Root"),
	("Head", (0, 0.08, BAT_HOVER + 0.02), (0, 0.2, BAT_HOVER + 0.03), "Body"),
	("Tail", (0, -0.1, BAT_HOVER), (0, -0.2, BAT_HOVER - 0.03), "Body"),
]
for _side_name, _x in (("Right", 1), ("Left", -1)):
	BAT_BONES += [
		(_side_name + "WingUpper", (_x * 0.05, 0.04, BAT_HOVER + 0.03), (_x * 0.26, 0.06, BAT_HOVER + 0.07), "Body"),
		(_side_name + "WingLower", (_x * 0.26, 0.06, BAT_HOVER + 0.07), (_x * 0.58, -0.02, BAT_HOVER + 0.02), _side_name + "WingUpper"),
		(_side_name + "Foot", (_x * 0.04, -0.08, BAT_HOVER - 0.03), (_x * 0.05, -0.16, BAT_HOVER - 0.1), "Body"),
	]


def bird_bones(p):
	h, l, r, up = p["hip"], p["length"], p["girth"], p["upright"]
	back = (0, -l * 0.4, h + r * 0.55)
	mid = (0, 0.0, h + r * 0.65 + up * 0.5)
	front = (0, l * 0.4, h + r * 0.75 + up)
	nf, nu = p["neck"]
	neck_top = (0, front[1] + nf, front[2] + nu + r * 0.2)
	head_tip = (0, neck_top[1] + p["head"] * 1.3, neck_top[2] + p["head"] * 0.2)
	bones = [
		("Root", (0, 0, 0), (0, 0, 0.2), None),
		("Pelvis", back, mid, "Root"),
		("Chest", mid, front, "Pelvis"),
		("Neck", front, neck_top, "Chest"),
		("Head", neck_top, head_tip, "Neck"),
		("Tail", back, (0, back[1] - p["tail"], back[2] + p["tail"] * (0.05 if p.get("arms") else 0.15)), "Pelvis"),
	]
	for side, x in (("Right", 1), ("Left", -1)):
		hip = (x * r * 0.45, -l * 0.08, h + r * 0.2)
		knee = (x * r * 0.5, l * 0.06, h * 0.55)
		ankle = (x * r * 0.45, -l * 0.04, h * 0.1)
		toe = (x * r * 0.45, l * 0.18, 0.0)
		shoulder = (x * r * 0.8, l * 0.3, h + r * 1.05 + up * 0.85)
		elbow = (x * r * 0.92, l * 0.3 - p["wing"] * 0.45, h + r * 1.0 + up * 0.5)
		tip = (x * r * 0.8, l * 0.3 - p["wing"], h + r * 0.85 + up * 0.15)
		if p.get("arms"):
			# Arms, not wings: down and forward from the front of the chest.
			shoulder = (x * r * 0.6, l * 0.36, h + r * 0.55 + up)
			elbow = (x * r * 0.78, l * 0.36 + p["wing"] * 0.3, h + r * 0.55 + up - p["wing"] * 0.55)
			tip = (x * r * 0.7, l * 0.36 + p["wing"] * 0.85, h + r * 0.55 + up - p["wing"] * 0.75)
		bones += [
			(side + "Thigh", hip, knee, "Pelvis"),
			(side + "Shin", knee, ankle, side + "Thigh"),
			(side + "Foot", ankle, toe, side + "Shin"),
			(side + "WingUpper", shoulder, elbow, "Chest"),
			(side + "WingLower", elbow, tip, side + "WingUpper"),
		]
	return bones


# ---------------------------------------------------------------- meshes

def bird_body(species):
	"""Plumage is "skin", the darker wings, tail and markings "hair", the
	breast and face "chest", the beak, legs and claws "trim"."""
	p = BIRDS[species]
	at = {name: (Vector(head), Vector(tail)) for name, head, tail, _parent in bird_bones(p)}
	r = p["girth"]
	if p.get("arms"):
		return raptor_body(p, at)
	b = bh.Builder("Body")
	back0, mid = at["Pelvis"]
	_m, front = at["Chest"]
	# The body: narrow at the tail, round in the middle, up to the neck.
	b.loft([(back0 + (back0 - mid) * 0.35, r * 0.35, r * 0.3, "Pelvis"), (back0, r * 0.8, r * 0.75, "Pelvis"),
			(mid, r, r * 0.95, "Pelvis"), (mid + (front - mid) * 0.6, r * 0.95, r * 0.9, "Chest"),
			(front, r * 0.6, r * 0.6, "Chest")], ["skin"] * 4, sides=8)
	# The breast, paler.
	b.loft([(mid + Vector((0, 0.02, -r * 0.25)), r * 0.7, r * 0.6, "Chest"),
			(mid + (front - mid) * 0.7 + Vector((0, 0.03, -r * 0.15)), r * 0.65, r * 0.55, "Chest")], ["chest"], sides=8)
	# Neck and head.
	n0, n1 = at["Neck"]
	neck_r = r * (0.32 if species == "tallbird" else 0.5)
	b.loft([(n0, neck_r * 1.2, neck_r * 1.2, "Neck"), (n0 + (n1 - n0) * 0.5, neck_r, neck_r, "Neck"),
			(n1, neck_r * 1.05, neck_r * 1.05, "Neck")], ["skin", "skin"], sides=6)
	h0, h1 = at["Head"]
	hs = p["head"]
	face = "chest" if species == "owl" else "skin"
	b.loft([(h0 - (h1 - h0) * 0.15, hs * 0.85, hs * 0.85, "Head"), (h0 + (h1 - h0) * 0.3, hs * 1.05, hs * 1.0, "Head"),
			(h0 + (h1 - h0) * 0.75, hs * 0.85, hs * 0.85, "Head"), (h1, hs * 0.45, hs * 0.5, "Head")],
		   ["skin", "skin", face], sides=8)
	# The beak, from the face forward, hooking down for the hunters.
	tip = h1 + Vector((0, p["beak"], -p["beak"] * 0.25))
	b.beam(h1 - Vector((0, hs * 0.1, hs * 0.05)), tip, hs * 0.55, hs * 0.5, "Head", "trim", taper=0.2, up=(1, 0, 0))
	if p["hook"]:
		b.beam(tip - Vector((0, p["hook"] * 0.4, 0)), tip + Vector((0, p["hook"] * 0.15, -p["hook"])), hs * 0.25, hs * 0.22,
			   "Head", "trim", taper=0.3, up=(1, 0, 0))
	eye_size = hs * (0.42 if species == "owl" else 0.22)
	for x in (-1, 1):
		ey = h0 + (h1 - h0) * (0.62 if species == "owl" else 0.5)
		ex = hs * (0.48 if species == "owl" else 0.85)
		b.box((x * ex, ey.y + (hs * 0.25 if species == "owl" else 0), ey.z + hs * 0.25), (eye_size, eye_size * 0.6, eye_size),
			  "Head", "eyes")
		if species == "owl":
			# Ear tufts, and the facial disc's dark rim.
			b.beam((x * hs * 0.55, h0.y + hs * 0.2, h0.z + hs * 0.75), (x * hs * 0.8, h0.y - hs * 0.05, h0.z + hs * 1.45),
				   hs * 0.35, hs * 0.12, "Head", "hair", taper=0.2)
			b.box((x * hs * 0.5, ey.y + hs * 0.2, ey.z + hs * 0.25), (eye_size * 1.5, eye_size * 0.3, eye_size * 1.5),
				  "Head", "hair")
	if species == "tallbird":
		# A crest swept back from the brow.
		for k in range(3):
			b.beam(h0 + Vector((0, hs * 0.3 - k * hs * 0.25, hs * 0.75)), h0 + Vector((0, -hs * 0.6 - k * hs * 0.3, hs * 1.4 - k * hs * 0.2)),
				   hs * 0.3, hs * 0.12, "Head", "hair", taper=0.2, up=(1, 0, 0))
	if species == "swoop":
		# A ruff of pale feathers round the base of the neck.
		b.loft([(n0 + Vector((0, -0.02, -0.02)), neck_r * 1.9, neck_r * 1.7, "Neck"), (n0 + (n1 - n0) * 0.45, neck_r * 1.5, neck_r * 1.4, "Neck")],
			   ["chest"], sides=8)
	# Wings: each a flat sheet in two parts, the long flight feathers ending
	# in points at the tip.
	for side, x in (("Right", 1), ("Left", -1)):
		s0, e = at[side + "WingUpper"]
		_e, t = at[side + "WingLower"]
		wide = r * (1.1 if species != "tallbird" else 0.8)
		b.beam(s0, e, wide, r * 0.14, side + "WingUpper", "hair", taper=0.95, up=(1, 0, -0.35 * x))
		b.beam(e, t, wide * 0.95, r * 0.1, side + "WingLower", "hair", taper=0.45, up=(1, 0, -0.35 * x))
		b.beam(s0 + Vector((0, -0.01, 0.01)), s0 + (e - s0) * 0.7, wide * 0.8, r * 0.16, side + "WingUpper", "skin", taper=0.8,
			   up=(1, 0, -0.35 * x))
		for k, off in enumerate((-0.35, 0.0, 0.35)):
			edge = Vector((x * wide * off, 0, 0))
			b.beam(e + (t - e) * 0.5 + edge, t + edge + (t - e) * (0.25 - 0.08 * abs(k - 1)), wide * 0.3, r * 0.06,
				   side + "WingLower", "hair", taper=0.3, up=(1, 0, -0.35 * x), shade=0.85)
	# The tail fan.
	t0, t1 = at["Tail"]
	for k, spread in enumerate((-1, 0, 1)):
		b.beam(t0 + Vector((spread * r * 0.15, 0, 0)), t1 + Vector((spread * r * 0.45, 0, 0)), r * 0.45, r * 0.08, "Tail", "hair",
			   taper=0.75, up=(1, 0, 0), shade=0.9 + 0.05 * k)
	# Legs: a feathered thigh, a bare shin and foot, three toes and a spur.
	leg = p["leg"]
	for side, x in (("Right", 1), ("Left", -1)):
		k0, k1 = at[side + "Thigh"]
		s1 = at[side + "Shin"][1]
		f1 = at[side + "Foot"][1]
		if species == "tallbird":
			# Feathered only near the body, bare down to the knee.
			feathered = k0 + (k1 - k0) * 0.4
			b.tube(k0, feathered, leg * 2.4, leg * 1.5, side + "Thigh", "skin")
			b.tube(feathered - (k1 - k0) * 0.05, k1, leg * 1.15, leg * 1.0, side + "Thigh", "trim")
		else:
			b.tube(k0, k1, leg * 2.6, leg * 1.6, side + "Thigh", "skin")
		b.tube(k1, s1, leg, leg * 0.85, side + "Shin", "trim")
		for toe in (-1, 0, 1):
			end = Vector((f1.x + toe * leg * 2.2, f1.y - (0.02 if toe else 0.0), 0.012))
			b.beam(s1, end, leg * 0.8, leg * 0.8, side + "Foot", "trim", taper=0.4)
		b.beam(s1, s1 + Vector((0, -leg * 3, -s1.z + 0.012)), leg * 0.6, leg * 0.6, side + "Foot", "trim", taper=0.4)
	return b


def raptor_body(p, at):
	"""A raptor: scales are "skin", stripes and quills "hair", the belly and
	throat "chest", teeth and claws "trim"."""
	r = p["girth"]
	b = bh.Builder("Body")
	back0, mid = at["Pelvis"]
	_m, front = at["Chest"]
	t0, t1 = at["Tail"]
	# One line of body from the tail's tip to the neck: the tail tapering to a
	# point, the haunches deep, the chest narrower.
	along = t1 - t0
	b.loft([(t1, r * 0.08, r * 0.08, "Tail"), (t0 + along * 0.7, r * 0.25, r * 0.28, "Tail"),
			(t0 + along * 0.35, r * 0.5, r * 0.55, "Tail"), (back0, r * 0.85, r * 0.9, "Pelvis"),
			(mid, r, r * 1.0, "Pelvis"), (mid + (front - mid) * 0.6, r * 0.85, r * 0.9, "Chest"),
			(front, r * 0.62, r * 0.66, "Chest")], ["skin"] * 6, sides=8)
	b.loft([(back0 + Vector((0, 0.02, -r * 0.35)), r * 0.6, r * 0.5, "Pelvis"),
			(mid + (front - mid) * 0.8 + Vector((0, 0, -r * 0.3)), r * 0.55, r * 0.45, "Chest")], ["chest"], sides=8)
	# Stripes across the back and down the tail.
	for k in range(6):
		c = back0 + (front - back0) * (k / 5.0) + Vector((0, 0, r * 0.8))
		b.box(c, (r * 1.15, r * 0.16, r * 0.1), "Pelvis" if k < 3 else "Chest", "hair", top=(0.7, 1.0))
	for k in range(4):
		c = t0 + along * (0.15 + 0.18 * k) + Vector((0, 0, r * (0.44 - 0.1 * k)))
		b.box(c, (r * (0.85 - 0.15 * k), r * 0.14, r * 0.08), "Tail", "hair", top=(0.7, 1.0))
	# Neck, a long head with a toothed snout and a lower jaw, a quill crest.
	n0, n1 = at["Neck"]
	nr = r * 0.48
	b.loft([(n0, nr * 1.25, nr * 1.3, "Neck"), (n0 + (n1 - n0) * 0.5, nr, nr * 1.05, "Neck"),
			(n1, nr * 0.95, nr, "Neck")], ["skin", "skin"], sides=6)
	b.loft([(n0 + Vector((0, 0.02, -nr * 0.5)), nr * 0.8, nr * 0.7, "Neck"),
			(n1 + Vector((0, 0.0, -nr * 0.45)), nr * 0.6, nr * 0.5, "Neck")], ["chest"], sides=6)
	h0, h1 = at["Head"]
	hs = p["head"]
	snout = h1 + Vector((0, p["beak"], -hs * 0.2))
	b.loft([(h0 - (h1 - h0) * 0.2, hs * 0.8, hs * 0.8, "Head"), (h0 + (h1 - h0) * 0.35, hs * 0.95, hs * 0.95, "Head"),
			(h1, hs * 0.72, hs * 0.7, "Head"), (snout, hs * 0.42, hs * 0.4, "Head")], ["skin"] * 3, sides=8,
		   cap_slots=("skin", "skin"))
	jaw0 = h0 + Vector((0, hs * 0.2, -hs * 0.55))
	jaw1 = snout + Vector((0, -hs * 0.15, -hs * 0.35))
	b.beam(jaw0, jaw1, hs * 0.75, hs * 0.3, "Head", "chest", taper=0.55)
	for k in range(5):
		f = 0.25 + k * 0.17
		top = h1 + (snout - h1) * f
		for x in (-1, 1):
			tooth = Vector((x * hs * (0.42 - 0.12 * f), top.y - hs * 0.4 * (1 - f), top.z - hs * 0.42))
			b.beam(tooth, tooth + Vector((0, 0.008, -hs * 0.2)), hs * 0.09, hs * 0.09, "Head", "trim", taper=0.2)
	for x in (-1, 1):
		ey = h0 + (h1 - h0) * 0.45
		b.box((x * hs * 0.82, ey.y, ey.z + hs * 0.22), (hs * 0.22, hs * 0.14, hs * 0.18), "Head", "eyes")
		b.box((x * hs * 0.7, ey.y + hs * 0.05, ey.z + hs * 0.42), (hs * 0.35, hs * 0.5, hs * 0.1), "Head", "skin", shade=0.8)
	for k in range(4):
		base = h0 + (h1 - h0) * (0.3 - 0.3 * k) + Vector((0, 0, hs * (0.8 - 0.05 * k)))
		b.beam(base, base + Vector((0, -hs * (0.9 + 0.2 * k), hs * (0.55 - 0.1 * k))), hs * 0.28, hs * 0.1, "Head", "hair",
			   taper=0.2, up=(1, 0, 0))
	# Small arms ending in three hooked claws.
	for side, x in (("Right", 1), ("Left", -1)):
		s0, e = at[side + "WingUpper"]
		_e, t = at[side + "WingLower"]
		b.tube(s0, e, r * 0.22, r * 0.17, side + "WingUpper", "skin")
		b.tube(e, t, r * 0.16, r * 0.12, side + "WingLower", "skin")
		for k in (-1, 0, 1):
			b.beam(t, t + Vector((x * k * r * 0.12, r * 0.15, -r * 0.3)), r * 0.07, r * 0.07, side + "WingLower", "trim",
				   taper=0.2)
	# Legs: heavy thighs, scaled shins, three toes, the inner one raising a
	# sickle claw.
	leg = p["leg"]
	for side, x in (("Right", 1), ("Left", -1)):
		k0, k1 = at[side + "Thigh"]
		s1 = at[side + "Shin"][1]
		f1 = at[side + "Foot"][1]
		b.loft([(k0, leg * 3.2, leg * 3.8, side + "Thigh"), (k0 + (k1 - k0) * 0.55, leg * 2.6, leg * 2.9, side + "Thigh"),
				(k1, leg * 1.5, leg * 1.5, side + "Thigh")], ["skin", "skin"], sides=8)
		b.tube(k1, s1, leg * 1.2, leg * 0.9, side + "Shin", "skin")
		for toe in (-1, 0, 1):
			end = Vector((f1.x + toe * leg * 1.8, f1.y + 0.04 - (0.03 if toe else 0.0), 0.015))
			b.beam(s1, end, leg * 0.9, leg * 0.9, side + "Foot", "skin", taper=0.5)
			b.beam(end, end + Vector((0, leg * 1.2, -0.01)), leg * 0.5, leg * 0.5, side + "Foot", "trim", taper=0.2)
		sickle = s1 + Vector((-x * leg * 0.8, leg * 2.2, -s1.z + leg * 1.2))
		b.beam(s1 + Vector((0, leg * 0.5, -s1.z * 0.4)), sickle, leg * 0.6, leg * 0.6, side + "Foot", "skin", taper=0.7)
		b.beam(sickle, sickle + Vector((0, leg * 1.6, leg * 0.9)), leg * 0.55, leg * 0.45, side + "Foot", "trim", taper=0.15)
	return b


def bat_body():
	"""Fur is "skin", the wing membranes "hair", the ears' insides and face
	"chest", the fangs and claws "trim"."""
	b = bh.Builder("Body")
	at = {name: (Vector(head), Vector(tail)) for name, head, tail, _parent in BAT_BONES}
	z = BAT_HOVER
	b.loft([((0, -0.15, z - 0.01), 0.03, 0.03, "Body"), ((0, -0.08, z), 0.07, 0.065, "Body"),
			((0, 0.02, z + 0.01), 0.085, 0.08, "Body"), ((0, 0.09, z + 0.02), 0.06, 0.06, "Body")], ["skin"] * 3, sides=8)
	# The head: round, a short snout, fangs, and the great ears.
	b.loft([((0, 0.08, z + 0.03), 0.055, 0.055, "Head"), ((0, 0.13, z + 0.035), 0.065, 0.06, "Head"),
			((0, 0.18, z + 0.025), 0.04, 0.035, "Head"), ((0, 0.21, z + 0.015), 0.02, 0.02, "Head")],
		   ["skin", "skin", "chest"], sides=8)
	for x in (-1, 1):
		b.beam((x * 0.035, 0.12, z + 0.07), (x * 0.07, 0.1, z + 0.18), 0.06, 0.012, "Head", "skin", taper=0.25, up=(0, 1, 0))
		b.beam((x * 0.035, 0.125, z + 0.075), (x * 0.066, 0.108, z + 0.16), 0.035, 0.014, "Head", "chest", taper=0.25, up=(0, 1, 0))
		b.box((x * 0.03, 0.175, z + 0.05), (0.016, 0.012, 0.016), "Head", "eyes")
		b.beam((x * 0.012, 0.2, z + 0.005), (x * 0.012, 0.205, z - 0.025), 0.01, 0.01, "Head", "trim", taper=0.3)
		# The wing: a membrane from the body out along both bones, finger
		# ribs fanning from the wrist to the trailing edge, a thumb claw.
		side = "Right" if x > 0 else "Left"
		s0, e = at[side + "WingUpper"]
		_e, t = at[side + "WingLower"]
		b.beam(s0 + Vector((0, -0.07, -0.01)), e + Vector((0, -0.08, -0.005)), 0.2, 0.012, side + "WingUpper", "hair", taper=0.95,
			   up=(0, 1, 0))
		b.beam(e + Vector((0, -0.08, -0.005)), t + Vector((0, -0.05, 0)), 0.2, 0.01, side + "WingLower", "hair", taper=0.35,
			   up=(0, 1, 0))
		b.tube(s0, e, 0.018, 0.014, side + "WingUpper", "skin")
		b.tube(e, t, 0.012, 0.006, side + "WingLower", "skin")
		for k, back in enumerate((0.1, 0.18, 0.24)):
			out = 0.3 - 0.08 * k
			b.beam(e, e + Vector((x * out, -back, -0.01)), 0.012, 0.012, side + "WingLower", "skin", taper=0.4)
		b.beam(e, e + Vector((0, 0.03, 0.03)), 0.012, 0.012, side + "WingLower", "trim", taper=0.3)
		f0, f1 = at[side + "Foot"]
		b.tube(f0, f1, 0.012, 0.009, side + "Foot", "skin")
		b.box(f1, (0.02, 0.03, 0.012), side + "Foot", "trim")
	# The tail membrane between the feet.
	b.beam((0, -0.12, z - 0.02), (0, -0.22, z - 0.07), 0.12, 0.01, "Tail", "hair", taper=0.5, up=(1, 0, 0))
	return b


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
	if arms:
		# A raptor holds its arms in, lunges jaws first and lashes its tail.
		ready = pose(stand, both("WingUpper", (35, 0, 0)), both("WingLower", (-30, 0, 0)), both("Thigh", (14, 0, 0)),
					 both("Shin", (-20, 0, 0)), Neck=(-8, 0, 0), Head=(6, 0, 0), Tail=(8, 0, 0), loc={"Root": (0, 0, -h * 0.1)})
		a["ready"] = [(0, ready), (12, pose(ready, Tail=(8, 0, 12))), (24, ready), (36, pose(ready, Tail=(8, 0, -12))), (48, ready)]
		wind = pose(ready, both("WingUpper", (60, 0, 0)), Neck=(22, 0, 0), Head=(-15, 0, 0), Tail=(14, 0, 0),
					loc={"Root": (0, -0.08, 0)})
		bite = pose(ready, both("WingUpper", (75, 0, 0)), both("WingLower", (-10, 0, 0)), Neck=(-6, 0, 0), Head=(12, 0, 0),
					Pelvis=(-4, 0, 0), Tail=(-6, 0, 0), loc={"Root": (0, 0.3, -h * 0.02)})
		a["attack"] = [(0, ready), (5, wind), (8, bite), (11, bite), (20, ready)]
		flinch = pose(ready, Neck=(28, 0, 0), Head=(10, 0, 0), Tail=(20, 0, 0), loc={"Root": (0, -0.1, 0)})
		a["hit"] = [(0, ready), (3, flinch), (10, ready)]
		dead = pose(dead, both("WingUpper", (60, 0, 0)), RightWingUpper=(40, 0, 20))
		a["death"] = [(0, ready), (5, pose(fall, both("WingUpper", (60, 0, 0)))), (13, pose(dead, Root=(0, 75, 0))), (17, dead),
					  (20, pose(dead, Root=(0, 84, 0))), (23, dead)]
		a["dead"] = [(0, dead), (10, dead)]
		ruffle = pose(stand, Tail=(0, 0, 15), Head=(10, 0, 0))
		a["idle"] = [(0, stand), (14, look_left), (28, stand), (40, ruffle), (46, stand), (58, look_right), (72, stand)]
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


def bat_flap(frames, beat, lean=0.0, bob=0.05, head=None):
	"""Wings beating: the upper wing down and up about Y, the outer part
	lagging behind it; the body bobbing against the beat."""
	keys = []
	for f in range(0, frames + 1, 2):
		t = f / frames
		w = math.sin(math.tau * t)
		lag = math.sin(math.tau * t - 0.9)
		p = {}
		p.update(both("WingUpper", (0, beat * w, 0)))
		p.update(both("WingLower", (0, beat * 0.6 * lag, -6 * lag)))
		p.update(both("Foot", (-10 - 6 * w, 0, 0)))
		p["Body"] = (lean, 0, 0)
		p["Head"] = head if head else (-lean * 0.7 + 4 * w, 0, 0)
		p["Tail"] = (8 * w, 0, 0)
		p["loc"] = {"Root": (0, 0, -bob * w)}
		keys.append((f, p))
	return keys


def bat_animations():
	a = {}
	a["idle"] = bat_flap(16, 38)
	a["ready"] = bat_flap(14, 42, head=(-6, 0, 0))
	a["walk"] = bat_flap(12, 45, lean=-14, bob=0.04)
	a["run"] = bat_flap(10, 52, lean=-24, bob=0.04)
	# The bite: a beat up, then a dive forward at the target, fangs first.
	ready0 = a["ready"][0][1]
	up = pose(ready0, both("WingUpper", (0, -55, 0)), both("WingLower", (0, -20, 0)), Body=(12, 0, 0), Head=(10, 0, 0),
			  loc={"Root": (0, -0.08, 0.1)})
	dive = pose(ready0, both("WingUpper", (0, 45, 0)), both("WingLower", (0, 25, 0)), Body=(-25, 0, 0), Head=(-15, 0, 0),
				loc={"Root": (0, 0.22, -0.12)})
	a["attack"] = [(0, ready0), (4, up), (8, dive), (11, dive), (18, ready0)]
	knocked = pose(ready0, both("WingUpper", (0, -40, 0)), Body=(20, 0, 0), loc={"Root": (0, -0.1, 0.05)})
	a["hit"] = [(0, ready0), (3, knocked), (10, ready0)]
	# Death: wings crumple and it drops to the ground, lying spread on its
	# back.
	crumple = pose(both("WingUpper", (0, -60, 25)), both("WingLower", (0, -50, 0)), Body=(30, 0, 0), loc={"Root": (0, 0, -0.3)})
	dead = pose(both("WingUpper", (0, 8, 8)), both("WingLower", (0, 5, 0)), both("Foot", (30, 0, 0)), Head=(0, 0, 25),
				Body=(0, 170, 0), loc={"Root": (0, 0, -BAT_HOVER + 0.07)})
	a["death"] = [(0, ready0), (4, crumple), (12, pose(dead, Body=(0, 150, 0), loc={"Root": (0, 0, -BAT_HOVER + 0.15)})),
				  (15, dead), (18, pose(dead, loc={"Root": (0, 0, -BAT_HOVER + 0.11)})), (20, dead)]
	a["dead"] = [(0, dead), (10, dead)]
	return a


def bird_gait(frames, swing, lift, nod, bob, wings=0.0):
	"""Two legs in turn: the thigh swings about X, the shin folds back to lift
	the foot while it comes forward; the head nods with each step."""
	keys = []
	for f in range(0, frames + 1, 2):
		t = f / frames
		p = {}
		for side, phase in (("Right", 0.0), ("Left", 0.5)):
			a = math.sin(math.tau * (t + phase))
			fwd = max(0.0, math.cos(math.tau * (t + phase)))
			p[side + "Thigh"] = (swing * a, 0, 0)
			p[side + "Shin"] = (-lift * fwd, 0, 0)
			p[side + "Foot"] = (lift * 0.6 * fwd, 0, 0)
		step = math.sin(math.tau * t * 2)
		p["Neck"] = (-nod * max(0.0, step), 0, 0)
		p["Head"] = (nod * 0.6 * max(0.0, step), 0, 0)
		p["Tail"] = (0, 0, 6 * math.sin(math.tau * t))
		p["Pelvis"] = (0, 3 * math.sin(math.tau * t), 0)
		if wings:
			p.update(both("WingUpper", (-wings * 0.5, 0, wings)))
		p["loc"] = {"Root": (0, 0, bob * abs(step))}
		keys.append((f, p))
	return keys


def bird_animations(species):
	p = BIRDS[species]
	h, r = p["hip"], p["girth"]
	tall = species == "tallbird"
	arms = p.get("arms", False)
	a = {}
	stand = {}
	look_left = pose(stand, Head=(0, 0, 25), Neck=(0, 0, 10))
	look_right = pose(stand, Head=(0, 0, -25), Neck=(0, 0, -10))
	ruffle = pose(stand, both("WingUpper", (-8, 0, 12)), Tail=(-10, 0, 0))
	a["idle"] = [(0, stand), (14, look_left), (28, stand), (40, ruffle), (46, stand), (58, look_right), (72, stand)]
	a["walk"] = bird_gait(28, 26 if tall else 30, 40, 12 if tall else 6, 0.03)
	a["run"] = bird_gait(14, 40 if tall else 44, 70, 10, 0.07, wings=0 if tall or arms else 25)
	# Ready: crouched, wings half open, the head low and forward.
	ready = pose(stand, both("WingUpper", (-25, 0, 55)), both("WingLower", (0, 0, 15)), both("Thigh", (12, 0, 0)),
				 both("Shin", (-16, 0, 0)), Neck=(-18 if tall else -10, 0, 0), Head=(10, 0, 0), Tail=(-8, 0, 0),
				 loc={"Root": (0, 0, -h * 0.08)})
	a["ready"] = [(0, ready), (20, pose(ready, both("WingUpper", (-35, 0, 60)))), (40, ready)]
	# Attack: the wings thrown up, then the peck down and forward.
	wind = pose(ready, both("WingUpper", (-70, 0, 75)), both("WingLower", (-10, 0, 20)), Neck=(18, 0, 0), Head=(10, 0, 0),
				loc={"Root": (0, -0.04, 0)})
	peck = pose(ready, both("WingUpper", (-10, 0, 80)), Neck=(-50 if tall else -30, 0, 0), Head=(-25, 0, 0), Pelvis=(-10, 0, 0),
				loc={"Root": (0, 0.14, -h * 0.05)})
	a["attack"] = [(0, ready), (5, wind), (9, peck), (12, peck), (20, ready)]
	flinch = pose(ready, both("WingUpper", (-60, 0, 70)), Neck=(25, 0, 0), Head=(10, 0, 0), loc={"Root": (0, -0.08, 0)})
	a["hit"] = [(0, ready), (3, flinch), (10, ready)]
	# Death: wings flung up, then over onto its side, legs drawn up.
	fall = pose(ready, both("WingUpper", (-80, 0, 85)), Neck=(30, 0, 0), loc={"Root": (0, 0, -h * 0.3)})
	dead = pose(both("Thigh", (50, 0, 0)), both("Shin", (-70, 0, 0)), both("Foot", (40, 0, 0)), both("WingUpper", (10, 0, 40)),
				RightWingUpper=(-40, 0, 70), Neck=(40, 0, 25), Head=(-20, 0, 0), Tail=(0, 0, 15), Root=(0, 90, 0),
				loc={"Root": (-(h + r) * 0.75, 0, r * 0.75)})
	a["death"] = [(0, ready), (5, fall), (13, pose(dead, Root=(0, 75, 0))), (17, dead), (20, pose(dead, Root=(0, 84, 0))), (23, dead)]
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
	if not only or "bat" in only:
		build("bat", BAT_BONES, bat_body, bat_animations())
	for species in BIRDS:
		if not only or species in only:
			build(species, bird_bones(BIRDS[species]), lambda: bird_body(species), bird_animations(species))


if __name__ == "__main__":
	main()
