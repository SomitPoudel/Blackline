class_name Career
extends RefCounted

const FILE = "user://career.json"
var credits = 900
var reputation = 0
var unlocked = 1
var owned = ["pistol"]
var results = {}
var loadouts = []


func _init() -> void:
	for i in range(4):
		loadouts.append({"weapon": "pistol", "gear": []})
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			credits = int(d.get("credits", 900))
			reputation = int(d.get("reputation", 0))
			unlocked = clampi(int(d.get("unlocked", 1)), 1, 50)
			owned = d.get("owned", ["pistol"])
			results = d.get("results", {})
			var ls = d.get("loadouts", [])
			if ls.size() == 4:
				loadouts = ls


func save() -> void:
	var f = FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_string(
			JSON.stringify(
				{
					"credits": credits,
					"reputation": reputation,
					"unlocked": unlocked,
					"owned": owned,
					"results": results,
					"loadouts": loadouts
				}
			)
		)


func purchase(id: String) -> bool:
	if id in owned:
		return true
	var item = Arsenal.WEAPONS.get(id, Arsenal.GEAR.get(id, {}))
	if item.is_empty() or credits < item.price or reputation < item.rep:
		return false
	credits -= item.price
	owned.append(id)
	save()
	return true


func equip(id: String, officer: int) -> void:
	if id not in owned:
		return
	if id in Arsenal.WEAPONS:
		loadouts[officer].weapon = id
	else:
		var gear = loadouts[officer].gear
		if id in gear:
			gear.erase(id)
		elif gear.size() < 3:
			gear.append(id)
	save()


func reward(mission: int, score: int, arrested: int, rescued: int, alive: int) -> int:
	var key = str(mission)
	var first = not results.has(key)
	var amount = 180 + mission * 15 + arrested * 35 + rescued * 50 + alive * 25
	if not first:
		amount = int(amount * 0.35)
	else:
		reputation += 1
	credits += amount
	for loadout in loadouts:
		loadout["experience"]=int(loadout.get("experience",0))+(60 if first else 20)
	results[key] = maxi(score, int(results.get(key, 0)))
	unlocked = mini(50, maxi(unlocked, mission + 1))
	save()
	return amount
