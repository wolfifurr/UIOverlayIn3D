@tool
extends EditorPlugin

var options: OptionButton

var viewportIndecies: Array[int]
var current_viewport : int = 0

var canvas_rid : RID
var viewport_rid : RID

func _enter_tree():
	options = OptionButton.new()
	options.add_item("None")
	options.add_item("Viewport")
	options.add_item("2 Viewports")
	options.add_item("2 Viewports (Sideways)")
	options.add_item("3 Viewports")
	options.add_item("3 Viewports (Sideways)")
	options.add_item("4 Viewports")
	
	options.item_selected.connect(_change_viewport)
	
	scene_changed.connect(_scene_changed_signal)
	
	viewportIndecies = [-1,0,1,1,2,2,3]
	
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,options)

func _scene_changed_signal():
	_change_viewport(current_viewport)

func _change_viewport(i: int):	
	if current_viewport>=0 and viewportIndecies[current_viewport]>=0:
		var prevx = viewportIndecies[current_viewport]
		if prevx>=0:
			var prev = EditorInterface.get_editor_viewport_3d(prevx)
			if prev and prev.size_changed.is_connected(viewport_size_change):
				prev.size_changed.disconnect(viewport_size_change)
	
	if viewport_rid.is_valid() and canvas_rid.is_valid():
		RenderingServer.viewport_remove_canvas(viewport_rid,canvas_rid)
		viewport_rid=RID()
		canvas_rid=RID()
	
	if viewportIndecies[i] != -1:
		var root : Node = EditorInterface.get_edited_scene_root()
		if not root:
			return
		
		var children : Array[Node] = root.find_children("*","CanvasLayer",true,false)
		if root is CanvasLayer:
			children.append(root)
		
		if children.is_empty():
			return
		
		var viewport = EditorInterface.get_editor_viewport_3d(viewportIndecies[i])
		if not viewport:
			return
		
		canvas_rid = (children[0] as CanvasLayer).get_canvas()
		viewport_rid = viewport.get_viewport_rid()
		RenderingServer.viewport_attach_canvas(viewport_rid,canvas_rid)
		
		var transform = _calculate_size(viewport.size)
		
		RenderingServer.viewport_set_canvas_transform(viewport_rid,canvas_rid,transform)
		
		viewport.size_changed.connect(viewport_size_change)
	
	current_viewport=i

func _calculate_size(viewportSize : Vector2) -> Transform2D:
	var base_w = ProjectSettings.get_setting("display/window/size/viewport_width")
	var base_h = ProjectSettings.get_setting("display/window/size/viewport_height")
	
	var scale_factor = float(viewportSize.y) / float(base_h)
	
	var scaled_w = float(base_w)*scale_factor
	var offset_x = (float(viewportSize.x)-scaled_w)*0.5
	
	return Transform2D(Vector2(scale_factor,0),Vector2(0,scale_factor),Vector2(offset_x,0))

func viewport_size_change():
	if not viewport_rid.is_valid() or not canvas_rid.is_valid() or viewportIndecies[current_viewport]==-1:
		return
	
	var viewport = EditorInterface.get_editor_viewport_3d(viewportIndecies[current_viewport])
	if viewport:
		var transform = _calculate_size(viewport.size)
		RenderingServer.viewport_set_canvas_transform(viewport_rid,canvas_rid,transform)

func _exit_tree():
	if current_viewport>=0 and current_viewport < viewportIndecies.size():
		var prevx = viewportIndecies[current_viewport]
		if prevx>=0:
			var prev = EditorInterface.get_editor_viewport_3d(prevx)
			if prev and prev.size_changed.is_connected(viewport_size_change):
				prev.size_changed.disconnect(viewport_size_change)
	
	if options:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,options)
		options.queue_free()
	if scene_changed.is_connected(_scene_changed_signal):
		scene_changed.disconnect(_scene_changed_signal)
	if viewport_rid.is_valid() and canvas_rid.is_valid():
		RenderingServer.viewport_remove_canvas(viewport_rid,canvas_rid)

func _get_plugin_name():
	return "UI Overlay In 3D"

func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
