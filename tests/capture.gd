extends SceneTree

func _initialize() -> void:
 call_deferred("capture")

func capture() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.size=Vector2i(1440,900)
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://previews")
 root.get_texture().get_image().save_png("res://previews/01-headquarters.png")
 main.campaign()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://previews/02-campaign.png")
 main.armoury()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://previews/03-armoury.png")
 main.start_mission(1)
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://previews/04-deployment.png")
 # An architectural inspection view; marked as a cutaway preview in the README.
 main.op.visible.fill(true)
 main.op.explored.fill(true)
 main.world.fog_clock=0
 main.world.sync(0.2)
 main.world.camera_zoom=25
 main.world.position_camera()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://previews/05-environment-cutaway.png")
 print("Captured five actual Godot renders.")
 quit()
