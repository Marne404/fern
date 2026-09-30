class_name MusicTracks
extends RefCounted
## Generated automatically from loudness measurements (ffmpeg EBU R128). Level matching to ~-18 LUFS, max. +10 dB.

## Title -> [path, level adjustment dB, length s]
const TRACKS := {
	"Action 1": ["res://assets/music/fantasy_rpg/mp3/Action 1 (Loop).mp3", 5.2, 103.4],
	"Action 3": ["res://assets/music/fantasy_rpg/mp3/Action 3 (Loop).mp3", 6.9, 80.0],
	"Action 4": ["res://assets/music/fantasy_rpg/mp3/Action 4 (Loop).mp3", 4.3, 96.0],
	"Ambient 1": ["res://assets/music/fantasy_rpg/mp3/Ambient 1.mp3", 8.7, 198.9],
	"Ambient 10": ["res://assets/music/fantasy_rpg/mp3/Ambient 10 .mp3", 9.6, 161.0],
	"Ambient 2": ["res://assets/music/fantasy_rpg/mp3/Ambient 2.mp3", 6.6, 231.0],
	"Ambient 3": ["res://assets/music/fantasy_rpg/mp3/Ambient 3.mp3", 9.9, 179.3],
	"Ambient 4": ["res://assets/music/fantasy_rpg/mp3/Ambient 4.mp3", 8.0, 211.0],
	"Ambient 5": ["res://assets/music/fantasy_rpg/mp3/Ambient 5.mp3", 6.8, 228.0],
	"Ambient 6": ["res://assets/music/fantasy_rpg/mp3/Ambient 6.mp3", 6.3, 183.4],
	"Ambient 7": ["res://assets/music/fantasy_rpg/mp3/Ambient 7.mp3", 7.9, 208.0],
	"Ambient 8": ["res://assets/music/fantasy_rpg/mp3/Ambient 8.mp3", 7.7, 176.0],
	"Ambient 9": ["res://assets/music/fantasy_rpg/mp3/Ambient 9.mp3", 10.0, 177.2],
	"Ash and Oasis": ["res://assets/music/desert/Tracks/ogg/6. Ash and Oasis.ogg", 5.9, 186.0],
	"Beyond Mist": ["res://assets/music/fairytale/ogg/4. Beyond Mist (Intense, Ambient)/Beyond Mist (Full).ogg", -1.1, 187.3],
	"Beyond Mist (intense)": ["res://assets/music/fairytale/ogg/4. Beyond Mist (Intense, Ambient)/Beyond Mist (Intense Part).ogg", -1.7, 87.8],
	"Beyond Mist (quiet)": ["res://assets/music/fairytale/ogg/4. Beyond Mist (Intense, Ambient)/Beyond Mist (Quiet Part).ogg", 4.1, 58.5],
	"Canyon Echoes": ["res://assets/music/desert/Tracks/ogg/4. Canyon Echoes.ogg", 1.2, 177.6],
	"Dreamspire": ["res://assets/music/fantasy_ambient/Tracks/ogg/6. Dreamspire.ogg", 6.8, 177.0],
	"Dunes of Silence": ["res://assets/music/desert/Tracks/ogg/1. Dunes of Silence.ogg", 2.7, 184.8],
	"Eldertide": ["res://assets/music/fantasy_ambient/Tracks/ogg/1. Eldertide.ogg", 0.3, 190.3],
	"Forgotten Waters": ["res://assets/music/fairytale/ogg/12. Forgotten Waters (Ambient)/12. Forgotten Waters (Full).ogg", 0.6, 183.9],
	"Frostfire": ["res://assets/music/fantasy_ambient/Tracks/ogg/3. Frostfire.ogg", 5.4, 192.0],
	"Frozen Hollow": ["res://assets/music/fairytale/ogg/7. Frozen Hollow (Ambient)/7. Frozen Hollow (Full).ogg", -0.1, 128.0],
	"Hidden Springs": ["res://assets/music/fairytale/ogg/3. Hidden Springs (Ambient)/3. Hidden Springs (Full).ogg", 0.0, 190.6],
	"Hollow Vale": ["res://assets/music/fairytale/ogg/2. Hollow Vale (Half Intense)/2. Hollow Vale (Full).ogg", -1.0, 200.0],
	"Light Ambient 1": ["res://assets/music/fantasy_rpg/mp3/Light Ambient 1 (Loop).mp3", 10.0, 104.0],
	"Light Ambient 2": ["res://assets/music/fantasy_rpg/mp3/Light Ambient 2 (Loop).mp3", 10.0, 128.0],
	"Light Ambient 3": ["res://assets/music/fantasy_rpg/mp3/Light Ambient 3 (Loop).mp3", 10.0, 128.0],
	"Light Ambient 4": ["res://assets/music/fantasy_rpg/mp3/Light Ambient 4 (Loop).mp3", 10.0, 128.0],
	"Light Ambient 5": ["res://assets/music/fantasy_rpg/mp3/Light Ambient 5 (Loop).mp3", 10.0, 128.0],
	"Moonlight": ["res://assets/music/fairytale/ogg/1. Moonlight (Abmient, Intense)/1. Moonlight (Full).ogg", -3.3, 148.0],
	"Moonlight (intense)": ["res://assets/music/fairytale/ogg/1. Moonlight (Abmient, Intense)/1. Moonlight (Intense Part).ogg", -4.4, 84.0],
	"Moonlight (quiet)": ["res://assets/music/fairytale/ogg/1. Moonlight (Abmient, Intense)/1. Moonlight (Quiet Part).ogg", -0.9, 67.0],
	"Moonshadow": ["res://assets/music/fantasy_ambient/Tracks/ogg/2. Moonshadow.ogg", 1.4, 194.6],
	"Night Ambient 1": ["res://assets/music/fantasy_rpg/mp3/Night Ambient 1.mp3", 10.0, 197.2],
	"Night Ambient 2": ["res://assets/music/fantasy_rpg/mp3/Night Ambient 2 (Loop).mp3", 10.0, 100.0],
	"Night Ambient 3": ["res://assets/music/fantasy_rpg/mp3/Night Ambient 3 (Loop).mp3", 10.0, 128.0],
	"Night Ambient 4": ["res://assets/music/fantasy_rpg/mp3/Night Ambient 4 (Loop).mp3", 10.0, 128.0],
	"Night Ambient 5": ["res://assets/music/fantasy_rpg/mp3/Night Ambient 5 (Loop).mp3", 10.0, 108.0],
	"Pale Waters": ["res://assets/music/fairytale/ogg/6. Pale Waters (Lyrical Intense)/6. Pale Waters (Full).ogg", 3.6, 179.2],
	"Pale Waters (intense)": ["res://assets/music/fairytale/ogg/6. Pale Waters (Lyrical Intense)/6. Pale Waters (Intense Part).ogg", 1.5, 83.2],
	"Sapphire Glade": ["res://assets/music/fairytale/ogg/8. Sapphire Glade (Half Intense).mp3/8. Sapphire Glade (Full).ogg", 1.8, 141.0],
	"Scorchlight Mirage": ["res://assets/music/desert/Tracks/ogg/2. Scorchlight Mirage.ogg", 1.2, 171.6],
	"Shrouded Waters": ["res://assets/music/fairytale/ogg/10. Shrouded Waters (Lyrical Ambient)/10. Shrouded Waters (Full).ogg", 2.0, 148.0],
	"Silent Reach": ["res://assets/music/fairytale/ogg/11. Silent Reach (Half Intense)/11. Silent Reach (Full).ogg", 0.5, 192.0],
	"Silent Reach (intense)": ["res://assets/music/fairytale/ogg/11. Silent Reach (Half Intense)/11. Silent Reach (Intense Part).ogg", 0.1, 157.7],
	"Starforge": ["res://assets/music/fantasy_ambient/Tracks/ogg/4. Starforge.ogg", 2.9, 192.0],
	"Starforge (instrumental)": ["res://assets/music/fantasy_ambient/Tracks/ogg/4. Starforge (No Vocals).ogg", 3.2, 192.0],
	"Sunblade Horizon": ["res://assets/music/desert/Tracks/ogg/5. Sunblade Horizon.ogg", 2.6, 184.8],
	"Whispering Pines": ["res://assets/music/fairytale/ogg/5. Whispering Pines (Ambientce)/5. Whispering Pines (Full).ogg", 0.8, 144.0],
	"Whispers in the Sand": ["res://assets/music/desert/Tracks/ogg/3. Whispers in the Sand.ogg", 8.1, 177.6],
	"White Moss": ["res://assets/music/fairytale/ogg/9. White Moss (Ambient, Half Intense)/9. White Moss (Full).ogg", -1.2, 181.9],
	"White Moss (intense)": ["res://assets/music/fairytale/ogg/9. White Moss (Ambient, Half Intense)/9. White Moss (Intense Part).ogg", -2.3, 106.1],
	"White Moss (quiet)": ["res://assets/music/fairytale/ogg/9. White Moss (Ambient, Half Intense)/9. White Moss (Quiet Part).ogg", 1.8, 57.5],
	"Wraithsong": ["res://assets/music/fantasy_ambient/Tracks/ogg/5. Wraithsong.ogg", 7.6, 200.0],
	# round 16: more of the packs (level: the same measurement, about -22.5 LUFS - loudness, max +10)
	"Action 2": ["res://assets/music/fantasy_rpg/mp3/Action 2 (Loop).mp3", 8.7, 89.0],
	"Action 5": ["res://assets/music/fantasy_rpg/mp3/Action 5 (Loop).mp3", 9.0, 96.0],
	"Pale Waters (slow end)": ["res://assets/music/fairytale/ogg/6. Pale Waters (Lyrical Intense)/6. Pale Waters (Intense Part Slow End).ogg", 2.3, 110.0],
	"White Moss (slow end)": ["res://assets/music/fairytale/ogg/9. White Moss (Ambient, Half Intense)/9. White Moss (Intense Part Slow End).ogg", -2.6, 129.0],
}

## Own playlist per biome (index as in BiomeDefs.all())
const BIOMES := [
	["Hollow Vale", "Eldertide", "Ambient 2", "Ambient 5", "Light Ambient 2", "Sapphire Glade", "Ambient 6", "Starforge (instrumental)"],   # Autumn Meadow
	["Whispering Pines", "White Moss", "Ambient 3", "Ambient 7", "Light Ambient 1", "Light Ambient 5", "Starforge (instrumental)", "Hollow Vale"],   # Forest Trail
	["Dunes of Silence", "Scorchlight Mirage", "Whispers in the Sand", "Canyon Echoes", "Sunblade Horizon", "Ash and Oasis", "Ambient 9"],   # Desert Valley
	["Sapphire Glade", "Dreamspire", "Moonshadow", "Light Ambient 4", "Ambient 10", "Hidden Springs", "Moonlight (quiet)"],   # Blossom Grove
	["Hidden Springs", "Sapphire Glade", "Eldertide", "Ambient 1", "Ambient 4", "Light Ambient 2", "Dreamspire"],   # Spring Meadow
	["Hollow Vale", "Frostfire", "Ambient 6", "Ambient 8", "White Moss", "Starforge", "Light Ambient 5"],   # Red Maple Wood
	["Frozen Hollow", "Frostfire", "Silent Reach", "Ambient 8", "Light Ambient 3", "Starforge (instrumental)", "Canyon Echoes"],   # Mountain Pines
	["Wraithsong", "Night Ambient 1", "Night Ambient 3", "Beyond Mist (quiet)", "Moonlight (quiet)", "Shrouded Waters", "White Moss (quiet)"],   # Deadwood Bog
	["Pale Waters", "Forgotten Waters", "Shrouded Waters", "Dreamspire", "Sunblade Horizon", "Night Ambient 4", "Moonshadow"],   # Sunset Coast
	["Silent Reach", "Eldertide", "Canyon Echoes", "Ambient 2", "Hollow Vale", "Starforge", "Ambient 4"],   # Cliff Lands
	["Moonlight", "Moonshadow", "Beyond Mist", "Night Ambient 2", "Night Ambient 5", "White Moss (quiet)", "Wraithsong"],   # Glowing Forest
	["Forgotten Waters", "Pale Waters", "Hidden Springs", "Light Ambient 4", "Ambient 10", "Sapphire Glade", "Shrouded Waters"],   # Lake Country
	["Sapphire Glade", "Dreamspire", "Hidden Springs", "Light Ambient 2", "Ambient 1", "Eldertide", "Sunblade Horizon"],   # Lavender Hills
	["White Moss", "Whispering Pines", "Hollow Vale", "Light Ambient 1", "Ambient 3", "Ambient 7", "Light Ambient 5"],   # Birch Wood
	["Silent Reach", "Frozen Hollow", "Beyond Mist", "Ambient 8", "Light Ambient 3", "Canyon Echoes", "Night Ambient 3"],   # Heather Highlands
	["Whispering Pines", "White Moss", "Beyond Mist", "Ambient 7", "Light Ambient 1", "Hollow Vale", "Night Ambient 1"],   # Giants' Old Forest
	["Moonshadow", "Dreamspire", "Moonlight", "Night Ambient 2", "Sapphire Glade", "Light Ambient 4", "Beyond Mist (quiet)"],   # Mushroom Wood
	["Eldertide", "Hidden Springs", "Sunblade Horizon", "Light Ambient 2", "Ambient 1", "Sapphire Glade", "Ambient 5"],   # Wheat Fields
	["Sapphire Glade", "Moonshadow", "Hidden Springs", "Light Ambient 4", "Dreamspire", "Pale Waters", "Moonlight (quiet)"],   # Cherry Valley
	["Hollow Vale", "Eldertide", "Silent Reach", "Ambient 2", "Light Ambient 5", "Frostfire", "Ambient 6"],   # Golden Birch Slopes
	["Canyon Echoes", "Silent Reach", "Hidden Springs", "Ambient 8", "Forgotten Waters", "Frozen Hollow", "Light Ambient 3"],   # Rock Gorge
	["Moonlight", "Sapphire Glade", "Beyond Mist", "Night Ambient 5", "Light Ambient 4", "Moonshadow", "White Moss (quiet)"],   # Blue Fern Hollow
]

## Situations that override the biome playlist
const SITUATIONS := {
	"menu": ["Hidden Springs", "Dreamspire", "Sapphire Glade", "Moonshadow"],
	"spannung": ["Silent Reach (intense)", "Beyond Mist (intense)", "Moonlight (intense)", "White Moss (intense)", "Pale Waters (intense)", "Action 1", "Action 2", "Action 3", "Action 4", "Action 5"],
	# after an obstacle: the tension resolves
	"geschafft": ["Pale Waters (slow end)", "White Moss (slow end)"],
	"ruhe": ["Beyond Mist (quiet)", "Moonlight (quiet)", "White Moss (quiet)", "Light Ambient 3", "Light Ambient 1", "Night Ambient 2"],
	"wasser": ["Shrouded Waters", "Forgotten Waters", "Pale Waters", "Night Ambient 4"],
}


## Generated by the round-16 measurement (ffmpeg: spectral centroid and flatness, EBU R128 loudness) and the
## titles: how well each track fits the six parts of the day (dawn, morning, midday, golden hour, dusk, night)
## and which landscapes it belongs to. [bands, families, brightness, energy]
const MOODS := {
	"Ambient 1": [[0.87, 1.00, 0.93, 0.46, 0.50, 0.50], ["forest", "meadow"], 0.87, 0.46],
	"Ambient 10": [[0.86, 1.00, 0.90, 0.36, 0.42, 0.43], ["open", "forest"], 0.96, 0.44],
	"Ambient 2": [[0.85, 0.98, 1.00, 0.68, 0.65, 0.59], ["open", "forest"], 0.73, 0.56],
	"Ambient 3": [[0.95, 0.91, 0.83, 0.82, 1.00, 0.95], ["autumn", "meadow"], 0.50, 0.41],
	"Ambient 4": [[0.83, 1.00, 0.95, 0.39, 0.39, 0.38], ["meadow", "forest"], 0.98, 0.51],
	"Ambient 5": [[0.81, 1.00, 0.97, 0.40, 0.36, 0.35], ["forest", "meadow"], 1.00, 0.55],
	"Ambient 6": [[0.83, 0.95, 1.00, 0.76, 0.72, 0.64], ["open", "forest"], 0.67, 0.59],
	"Ambient 7": [[0.76, 0.71, 0.73, 0.91, 1.00, 0.91], ["autumn", "meadow"], 0.38, 0.50],
	"Ambient 8": [[0.82, 1.00, 0.98, 0.44, 0.41, 0.40], ["meadow", "forest"], 0.95, 0.54],
	"Ambient 9": [[1.00, 0.96, 0.71, 0.42, 0.72, 0.76], ["forest", "meadow"], 0.70, 0.20],
	"Ash and Oasis": [[0.32, 0.36, 0.39, 1.00, 0.66, 0.27], ["desert"], 0.69, 0.63],
	"Beyond Mist": [[1.00, 0.29, 0.42, 0.47, 0.77, 0.28], ["moor", "magic", "open"], 0.43, 0.95],
	"Beyond Mist (intense)": [[0.28, 0.35, 0.51, 0.56, 1.00, 0.32], ["moor"], 0.46, 0.97],
	"Beyond Mist (quiet)": [[1.00, 0.31, 0.36, 0.38, 0.34, 0.77], ["moor", "magic"], 0.48, 0.69],
	"Canyon Echoes": [[0.30, 0.36, 1.00, 0.86, 0.30, 0.26], ["desert", "cliff", "mountain"], 0.65, 0.80],
	"Dreamspire": [[0.56, 0.27, 0.28, 0.33, 1.00, 0.83], ["blossom", "magic"], 0.36, 0.51],
	"Dunes of Silence": [[1.00, 0.51, 0.57, 0.38, 0.99, 0.65], ["desert"], 0.87, 0.73],
	"Eldertide": [[0.24, 0.56, 0.36, 1.00, 0.28, 0.23], ["meadow", "open", "mountain"], 0.55, 0.85],
	"Forgotten Waters": [[0.70, 0.17, 0.27, 0.46, 1.00, 0.34], ["water", "coast"], 0.06, 0.83],
	"Frostfire": [[0.73, 0.41, 0.44, 0.92, 1.00, 0.34], ["mountain", "forest", "autumn"], 0.62, 0.60],
	"Frozen Hollow": [[1.00, 0.31, 0.42, 0.43, 0.33, 0.67], ["mountain", "open"], 0.52, 0.89],
	"Hidden Springs": [[0.82, 1.00, 0.33, 0.54, 0.46, 0.38], ["meadow", "water", "blossom"], 0.11, 0.86],
	"Hollow Vale": [[0.16, 0.17, 0.54, 1.00, 0.32, 0.26], ["meadow", "forest", "open"], 0.21, 0.93],
	"Light Ambient 1": [[0.35, 1.00, 0.24, 0.34, 0.44, 0.43], ["forest", "meadow"], 0.25, 0.27],
	"Light Ambient 2": [[0.39, 1.00, 0.88, 0.25, 0.31, 0.31], ["meadow", "blossom"], 0.72, 0.35],
	"Light Ambient 3": [[1.00, 0.51, 0.38, 0.18, 0.32, 0.67], ["mountain", "open"], 0.90, 0.06],
	"Light Ambient 4": [[0.74, 1.00, 0.26, 0.30, 0.40, 0.39], ["blossom", "water", "magic"], 0.38, 0.25],
	"Light Ambient 5": [[0.38, 0.73, 0.25, 1.00, 0.51, 0.50], ["forest", "autumn"], 0.17, 0.26],
	"Moonlight": [[0.18, 0.21, 0.35, 0.48, 0.75, 1.00], ["magic", "forest"], 0.25, 1.00],
	"Moonlight (intense)": [[0.15, 0.15, 0.30, 0.50, 0.39, 1.00], ["magic"], 0.07, 1.00],
	"Moonlight (quiet)": [[0.64, 0.41, 0.52, 0.40, 0.27, 1.00], ["magic", "blossom"], 0.79, 0.94],
	"Moonshadow": [[0.19, 0.18, 0.28, 0.44, 0.91, 1.00], ["magic", "blossom", "water"], 0.12, 0.80],
	"Night Ambient 1": [[0.29, 0.19, 0.13, 0.29, 0.43, 1.00], ["moor", "forest"], 0.00, 0.11],
	"Night Ambient 2": [[0.39, 0.35, 0.26, 0.23, 0.62, 1.00], ["magic", "forest"], 0.55, 0.13],
	"Night Ambient 3": [[0.47, 0.46, 0.33, 0.16, 0.30, 1.00], ["moor", "open"], 0.87, 0.02],
	"Night Ambient 4": [[0.44, 0.40, 0.28, 0.18, 0.68, 1.00], ["coast", "water"], 0.70, 0.00],
	"Night Ambient 5": [[0.63, 0.41, 0.34, 0.23, 0.31, 1.00], ["magic", "blossom"], 0.75, 0.25],
	"Pale Waters": [[0.24, 0.24, 0.31, 0.96, 1.00, 0.33], ["water", "coast"], 0.26, 0.72],
	"Pale Waters (intense)": [[0.24, 0.26, 0.36, 0.48, 1.00, 0.34], ["water", "coast"], 0.27, 0.82],
	"Sapphire Glade": [[0.25, 1.00, 0.75, 0.46, 0.40, 0.34], ["blossom", "meadow", "magic"], 0.28, 0.79],
	"Scorchlight Mirage": [[0.23, 0.27, 1.00, 0.37, 0.30, 0.25], ["desert"], 0.48, 0.84],
	"Shrouded Waters": [[1.00, 0.27, 0.38, 0.52, 0.45, 0.92], ["water", "moor", "coast"], 0.26, 0.80],
	"Silent Reach": [[1.00, 0.33, 0.96, 0.56, 0.45, 0.38], ["open", "mountain", "cliff"], 0.36, 0.86],
	"Silent Reach (intense)": [[0.24, 0.26, 1.00, 0.52, 0.42, 0.35], ["cliff", "mountain"], 0.25, 0.88],
	"Starforge": [[0.23, 0.24, 0.30, 1.00, 0.67, 0.29], ["open", "mountain", "forest"], 0.34, 0.74],
	"Starforge (instrumental)": [[0.22, 0.21, 0.28, 1.00, 0.76, 0.30], ["open", "mountain", "forest"], 0.26, 0.72],
	"Sunblade Horizon": [[0.28, 0.32, 1.00, 0.73, 0.26, 0.23], ["desert", "coast", "open"], 0.67, 0.72],
	"Whispering Pines": [[0.81, 1.00, 0.36, 0.59, 0.51, 0.43], ["forest", "mountain"], 0.09, 0.84],
	"Whispers in the Sand": [[0.36, 0.39, 0.38, 0.29, 1.00, 0.75], ["desert"], 0.72, 0.50],
	"White Moss": [[0.84, 0.94, 0.39, 0.71, 1.00, 0.47], ["forest", "moor"], 0.00, 0.96],
	"White Moss (intense)": [[0.18, 0.18, 1.00, 0.70, 0.56, 0.44], ["forest"], 0.00, 1.00],
	"White Moss (quiet)": [[1.00, 0.20, 0.32, 0.53, 0.47, 0.82], ["forest", "moor", "magic"], 0.08, 0.83],
	"Wraithsong": [[0.23, 0.17, 0.19, 0.38, 0.76, 1.00], ["moor", "magic"], 0.00, 0.50],
}

## Landscapes of each biome (index as in BiomeDefs.all()): tracks of these families fit too, not only the list
const BIOME_FAMILIES := [
	["meadow", "autumn", "open"], ["forest"], ["desert"], ["blossom", "meadow"], ["meadow", "blossom"], ["autumn", "forest"],
	["mountain", "forest"], ["moor"], ["coast", "water"], ["cliff", "open", "mountain"], ["magic", "forest"], ["water", "meadow"],
	["meadow", "blossom", "open"], ["forest", "meadow"], ["open", "moor", "mountain"], ["forest", "moor"], ["magic", "forest"],
	["meadow", "open", "autumn"], ["blossom", "water"], ["autumn", "open", "mountain"], ["cliff", "mountain", "water"], ["magic", "forest", "water"],
]
const BAND_HOURS := [6.2, 9.0, 13.0, 17.4, 20.0, 1.0]


## How well a track fits the hour (0..1): its band weights, blended between the bands' centers
static func band_fit(title: String, hour: float) -> float:
	if not MOODS.has(title):
		return 0.5
	var w: Array = MOODS[title][0]
	# the two bands around the hour (on a circle of 24 h)
	var best := 0.0
	var total := 0.0
	for i in 6:
		var d := absf(fposmod(hour - BAND_HOURS[i] + 12.0, 24.0) - 12.0)
		var k := maxf(0.0, 1.0 - d / 4.5)
		best += float(w[i]) * k
		total += k
	return best / maxf(total, 0.001)


## Candidates for a biome at an hour: {title: score}. The hand-made list is the core; tracks of the biome's
## families join with less weight; everything is weighted by how well it fits the part of the day.
static func biome_scores(biome: int, hour: float) -> Dictionary:
	var out := {}
	var own: Array = BIOMES[biome % BIOMES.size()]
	var fams: Array = BIOME_FAMILIES[biome % BIOME_FAMILIES.size()]
	for title in MOODS:
		var base := 0.0
		if own.has(title):
			base = 1.0
		else:
			for f in MOODS[title][1]:
				if fams.has(f):
					base = maxf(base, 0.5)
		if base <= 0.0:
			continue
		var fit := band_fit(title, hour)
		var sc := base * fit * fit
		if sc > 0.06:
			out[title] = sc
	return out


## Weighted pick; avoid: recent titles (never picked when something else fits)
static func pick(scores: Dictionary, avoid: Array, rng: RandomNumberGenerator) -> String:
	var mx := 0.0
	for t in scores:
		mx = maxf(mx, scores[t])
	var pool := {}
	for t in scores:
		if scores[t] >= mx * 0.3 and not avoid.has(t):
			pool[t] = scores[t]
	if pool.is_empty():
		for t in scores:
			if not avoid.slice(maxi(avoid.size() - 2, 0)).has(t):
				pool[t] = scores[t]
	if pool.is_empty():
		pool = scores
	var total := 0.0
	for t in pool:
		total += pool[t]
	var r := rng.randf() * total
	for t in pool:
		r -= pool[t]
		if r <= 0.0:
			return t
	return pool.keys()[0] if not pool.is_empty() else ""
