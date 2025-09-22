class_name GameColors
extends Resource

# Inner classes for organization
class Stats:
	const damage = Color("#ff4444")         # Red
	const shield = Color("#6699ff")         # Blue
	const agility = Color("#ffdd44")        # Yellow
	const hit_points = Color("#44ff44")     # Green
	const gold = Color("#ffaa00")           # Gold
	const strikes = Color("#ff66ff")        # Purple
	const burn = Color("#ff6600")           # Orange
	const poison = Color("#88ff00")         # Lime
	const thorns = Color("#996633")         # Brown
	const acid = Color("#aaff00")           # Yellow-green
	const regeneration = Color("#00ff88")   # Teal
	const stun = Color("#ffff99")           # Light yellow

class Rarity:
	const common = Color("#49AFD1")         # Gray
	const uncommon = Color("#60D149")       # Green
	const rare = Color("#D1C849")           # Blue
	const unique = Color("#D16249")         # Orange
	const legendary = Color("#9F49D1")      # Magenta
	const mysterious = Color("#6649D1")     # Purple

class Room:
	const starter = Color("#4d4663ff")        # Brown
	const hallway = Color("#707e4fff")        # Brown
	const tomb = Color("#605070")             # Dark purple
	const royal = Color("#9e801eff")          # Gold
	const forge = Color("#994431ff")          # Red-orange
	const coven = Color("#3b7733ff")          # Purple
	const boss = Color("#811111ff")           # Red

class Difficulty:
	const very_easy = Color("#ffff66")      # Yellow
	const easy = Color("#66ff66")           # Green
	const medium = Color("#6666ff")         # Blue
	const hard = Color("#ff66ff")           # Purple
	const very_hard = Color("#ff6666")      # Red

class Interf:
	const background = Color("#1a1a2e")     # Dark blue
	const panel = Color("#16213e")          # Darker blue
	const text_primary = Color("#ffffff")   # White
	const text_secondary = Color("#cccccc") # Light gray
	const highlight = Color("#ffd700")      # Gold
	const error = Color("#ff4444")          # Red
	const success = Color("#44ff44")        # Green
	const disabled = Color("#666666")       # Gray

# Static references to inner classes
static var stats = Stats
static var rarity = Rarity
static var room = Room
static var difficulty = Difficulty
static var ui = Interf