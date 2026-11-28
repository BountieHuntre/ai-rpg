"""The comments beside each entry of the zones' layout tables, and the flats'
code names (their index constants), for extract_content.gd to keep as each
entry's name or note: build/zone_notes.json. One use, while the tables were
still in the zone scripts.

	python tools/content/zone_notes.py
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
TABLES = ['PLACES', 'FLATS', 'HILLS', 'STREAM', 'ROADS', 'WOODS', 'SPAWNS', 'CHESTS', 'QUEST_OBJECTS', 'ENCLOSURES',
	'SPELL_FOCUSES']


def entry_notes(lines, first):
	"""Each top-level entry's trailing comment (on any of its lines), for the
	table opened on line `first`."""
	notes = []
	depth = 1
	current = None  # [comment] while inside an entry
	for line in lines[first + 1:]:
		code, _, comment = line.partition('#')
		comment = comment.strip()
		in_string = False
		started_here = False
		for c in code:
			if c == '"':
				in_string = not in_string
			if in_string:
				continue
			if depth == 1 and current is None and not c.isspace() and c not in ',]':
				current = ['']
				started_here = True
			if c in '[({':
				depth += 1
			elif c in '])}':
				depth -= 1
				if depth == 0:
					break
			elif c == ',' and depth == 1 and current is not None:
				notes.append(current)
				current = None
		# The comment belongs to the entry on this line (the last one begun or
		# ended here).
		if comment and code.strip():
			target = current if current is not None else (notes[-1] if notes else None)
			if target is not None and target[0] == '':
				target[0] = comment
		if depth == 0:
			if current is not None:
				notes.append(current)
			return [n[0] for n in notes]
	return [n[0] for n in notes]


def main():
	out = {}
	levels = os.path.join(ROOT, 'scenes', 'levels')
	for folder in sorted(os.listdir(levels)):
		path = os.path.join(levels, folder, folder + '.gd')
		if not os.path.isfile(path):
			continue
		lines = open(path, encoding='utf-8').read().replace('\r\n', '\n').split('\n')
		zone = {}
		for table in TABLES:
			for n, line in enumerate(lines):
				if line.startswith('const ' + table + ' := ['):
					zone[table] = entry_notes(lines, n)
		text = '\n'.join(lines)
		zone['FLAT_KEYS'] = {int(v): k for k, v in re.findall(r'^static var ([A-Z_]+) := (\d+)\s*$', text, re.M)
			if k not in ('SEED', 'TREE_ATTEMPTS', 'ROCK_ATTEMPTS') and not k.endswith('_VARIANTS')}
		out[folder] = zone
	os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
	with open(os.path.join(ROOT, 'build', 'zone_notes.json'), 'w', encoding='utf-8') as f:
		json.dump(out, f, indent='\t')
	print('notes for', len(out), 'zones')


main()
