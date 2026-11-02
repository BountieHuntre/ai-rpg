extends Node
## The player's character and progress. Lives outside the scene so it survives
## the restart after death. Saving it to disk comes later.

var race := ClassicData.Race.HUMAN
var char_class := ClassicData.CharClass.PALADIN
var level := 1
var xp := 0
