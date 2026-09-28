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
]

## Situations that override the biome playlist
const SITUATIONS := {
	"menu": ["Hidden Springs", "Dreamspire", "Sapphire Glade", "Moonshadow"],
	"spannung": ["Silent Reach (intense)", "Beyond Mist (intense)", "Moonlight (intense)", "White Moss (intense)", "Pale Waters (intense)", "Action 1", "Action 3", "Action 4"],
	"ruhe": ["Beyond Mist (quiet)", "Moonlight (quiet)", "White Moss (quiet)", "Light Ambient 3", "Light Ambient 1", "Night Ambient 2"],
	"wasser": ["Shrouded Waters", "Forgotten Waters", "Pale Waters", "Night Ambient 4"],
}
