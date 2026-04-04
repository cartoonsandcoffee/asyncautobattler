class_name GameColors
extends Resource

# Inner classes for organization
class Stats:
	const damage = Color("#ff4444")         # Red
	const shield = Color("#6699ff")         # Blue
	const agility = Color("#ffdd44")        # Yellow
	const hit_points = Color("#44ff44")     # Green
	const gold = Color("#ffaa00")           # Gold
	const strikes = Color("#d0db9eff")        # Purple
	const burn = Color("#ff6600")           # Orange
	const poison = Color("#a749a7")         # Lime
	const thorns = Color("#996633")         # Brown
	const acid = Color("#aaff00")           # Yellow-green
	const regeneration = Color("#00ff88")   # Teal
	const stun = Color("#bdb280ff")           # Light brown
	const blessing = Color("#99dfffff")           # Light yellow
	const blind = Color("#fff5cf")           # Light yellow
	const wounded = Color("#af4545")           # Light yellow
	const exposed = Color("#96b6c9")           # Light yellow
	const singularity = Color("#f0f1eb")           # Light yellow

class Rarity:
	const common = Color("#49AFD1")         # Gray
	const uncommon = Color("#60D149")       # Green
	const rare = Color("#D1C849")           # Blue
	const unique = Color("#D16249")         # Orange
	const legendary = Color("#9F49D1")      # Magenta
	const mysterious = Color("#6649D1")     # Purple
	const golden = Color("#e0b300")		# Golden
	const diamond = Color("#00e0dd")		# Diamond
	const crafted = Color("#7e806a")			# brown

class Room:
	const rank_1 = Color("#967caf")        	# Brown
	const rank_2 = Color("#97bd85")        	# Brown
	const rank_3 = Color("#96a6d3")         	# Dark purple
	const rank_4 = Color("#cc6a54")      		# Red-orange
	const rank_5 = Color("#68ac82")      		# Purple
	const rank_6 = Color("#cf7b7b")     		# Red

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

class Bundles:
	const revenge = Color("#d32222")       # Red
	const honor = Color("#6699ff")         # Blue
	const chaos = Color("#4cc940")     	# Green
	const greed = Color("#ffaa00")         # Gold
	const shame = Color("#ff66ff")         # Lime
	const duty = Color("#996633")         	# Brown
	const general = Color("#c7c7c7")   	# grey

# Static references to inner classes
static var stats = Stats
static var rarity = Rarity
static var room = Room
static var difficulty = Difficulty
static var ui = Interf
static var bundles = Bundles

func get_bundle_color(_bundle: Enums.ItemBundles) -> Color:
	match _bundle:
		Enums.ItemBundles.GENERAL:
			return bundles.general
		Enums.ItemBundles.REVENGE:
			return bundles.revenge
		Enums.ItemBundles.GREED:
			return bundles.greed
		Enums.ItemBundles.HONOR:
			return bundles.honor
		Enums.ItemBundles.DUTY:
			return bundles.duty
		Enums.ItemBundles.SHAME:
			return bundles.shame
		Enums.ItemBundles.CHAOS:
			return bundles.chaos
		_:
			return Color.WHITE

func get_rank_color(_rank: int) -> Color:
	match _rank:
		1:
			return Room.rank_1
		2:
			return Room.rank_2
		3:
			return Room.rank_3
		4:
			return Room.rank_4
		5:
			return Room.rank_5
		6:
			return Room.rank_6
		_:
			return Room.rank_1