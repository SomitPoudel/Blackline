class_name Arsenal
extends RefCounted

# All numeric statistics are game balance values, not real-world specifications.
const WEAPONS = {
	"pistol":
	{
		"name": "P9 / Service pistol",
		"price": 0,
		"rep": 0,
		"capacity": 15,
		"interval": 0.42,
		"reload": 1.65,
		"damage": 26.0,
		"spread": 0.055,
		"noise": 14.0,
		"reach": 15.0,
		"pellets": 1,
		"weight": 1.0,
		"suppressed": false
	},
	"smg":
	{
		"name": "S9 / Compact SMG",
		"price": 650,
		"rep": 1,
		"capacity": 25,
		"interval": 0.14,
		"reload": 2.1,
		"damage": 20.0,
		"spread": 0.065,
		"noise": 18.0,
		"reach": 16.0,
		"pellets": 1,
		"weight": 2.5,
		"suppressed": false
	},
	"shotgun":
	{
		"name": "M12 / Patrol shotgun",
		"price": 850,
		"rep": 2,
		"capacity": 6,
		"interval": 0.9,
		"reload": 0.7,
		"damage": 10.0,
		"spread": 0.12,
		"noise": 25.0,
		"reach": 13.0,
		"pellets": 6,
		"weight": 3.2,
		"suppressed": false
	},
	"carbine":
	{
		"name": "C5 / Patrol carbine",
		"price": 1200,
		"rep": 4,
		"capacity": 24,
		"interval": 0.24,
		"reload": 2.3,
		"damage": 34.0,
		"spread": 0.035,
		"noise": 26.0,
		"reach": 22.0,
		"pellets": 1,
		"weight": 3.3,
		"suppressed": false
	},
	"suppressed":
	{
		"name": "S9-S / Suppressed SMG",
		"price": 1600,
		"rep": 7,
		"capacity": 25,
		"interval": 0.16,
		"reload": 2.1,
		"damage": 20.0,
		"spread": 0.05,
		"noise": 8.0,
		"reach": 16.0,
		"pellets": 1,
		"weight": 3.0,
		"suppressed": true
	}
}
const GEAR = {
	"armour":
	{
		"name": "Protective vest",
		"price": 500,
		"rep": 1,
		"description": "Adds 40 armour; movement is slightly slower."
	},
	"nvg":
	{
		"name": "Low-light goggles",
		"price": 950,
		"rep": 3,
		"description": "Improves detection in dark rooms. Walls still block vision."
	},
	"thermal":
	{
		"name": "Thermal viewer",
		"price": 1500,
		"rep": 8,
		"description": "Detects visible heat signatures. No vision through walls."
	},
	"jammer":
	{
		"name": "Local radio jammer",
		"price": 1200,
		"rep": 5,
		"description": "6-unit fictional field. 90-second battery. Blocks both teams' radio."
	},
	"medkit":
	{
		"name": "Field medical kit",
		"price": 350,
		"rep": 0,
		"description": "One treatment per officer per mission, restores 35 HP."
	},
	"knife":
	{
		"name": "Utility knife",
		"price": 150,
		"rep": 0,
		"description": "Cuts nearby evidence seals quietly; short-range utility tool."
	}
}
const NAMES = ["REYES", "PARK", "MASON", "SHAH"]
