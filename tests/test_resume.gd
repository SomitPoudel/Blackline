extends SceneTree

func _initialize() -> void:
 var missions=JSON.parse_string(FileAccess.get_file_as_string("res://data/missions.json"))
 var loadouts=[]
 for i in range(4):
  loadouts.append({"weapon":"pistol","gear":["jammer"]})
 var sim=Operation.new()
 sim.new_mission(missions[10],loadouts)
 sim.paused=false
 sim.units[4].alert=3
 sim.lights[0].broken=true
 sim.lights[0].on=false
 sim.units[0].jammer=true
 sim.messages.append({"sender":4,"pos":Vector2(4.5,11.5),"deliver":2.0})
 sim.save_run()
 var loaded=Operation.new()
 assert(loaded.load_run())
 assert(loaded.units[4].alert==3)
 assert(loaded.lights[0].broken)
 assert(loaded.units[0].jammer)
 assert(loaded.messages.size()==1)
 assert(loaded.paused)
 loaded.paused=false
 for i in range(60):
  loaded.step(.05)
 assert(loaded.units[0].battery<90)
 assert(loaded.messages.is_empty())
 loaded.group=true
 loaded.order_move(Vector2(7.5,11.5))
 for i in range(100):
  loaded.step(.05)
 assert(loaded.units[0].pos.x>4)
 print("PASS: actual save/reload, delayed radio, jammer battery and resumed movement")
 # Test runs must not leave the game pointing at an artificial snapshot.
 DirAccess.remove_absolute(Operation.SAVE)
 quit()
