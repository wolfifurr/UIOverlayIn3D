@tool
extends EditorPlugin

var options: OptionButton
var optionsList: OptionButton
var dock: VBoxContainer

var viewportIndecies: Array[int]
var current_viewport : int = 0

var canvas_rid : RID
var viewport_rid : RID

var scaling_method : int = 0

const SELECTED_VIEWPORT_KEY = "plugin/uioverlay3d/selected_viewport"
const SELECTED_SCALING_KEY = "plugin/uioverlay3d/scaling_method"

func _save_settings() -> void:
	var editor_settings = EditorInterface.get_editor_settings()
	editor_settings.set_setting(SELECTED_VIEWPORT_KEY,current_viewport)
	editor_settings.set_setting(SELECTED_SCALING_KEY,scaling_method)

func _load_settings() -> void:
	var editor_settings = EditorInterface.get_editor_settings()
	if editor_settings.has_setting(SELECTED_VIEWPORT_KEY):
		current_viewport=editor_settings.get_setting(SELECTED_VIEWPORT_KEY)
		if options:
			options.select(current_viewport)
	if editor_settings.has_setting(SELECTED_SCALING_KEY):
		scaling_method=editor_settings.get_setting(SELECTED_SCALING_KEY)
		if optionsList:
			optionsList.select(scaling_method)
	_change_viewport(current_viewport)

func _enter_tree():
	options = OptionButton.new()
	options.size = Vector2(1,1)
	options.add_item("None")
	options.add_item("1st Viewport")
	options.add_item("2nd Viewport")
	options.add_item("3rd Viewport")
	options.add_item("4th Viewport")
	
	options.item_selected.connect(_change_viewport)
	scene_changed.connect(_scene_changed_signal)
	
	viewportIndecies = [-1,0,1,2,3]
	
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,options)
	
	dock = VBoxContainer.new()
	dock.name="UI In 3d"
	var optionsListLabel = Label.new()
	dock.add_child(optionsListLabel)
	optionsListLabel.text="Scale option"
	optionsList = OptionButton.new()
	dock.add_child(optionsList)
	optionsList.add_item("Fit to Height")
	optionsList.add_item("Fit to Width")
	optionsList.add_item("Fit to Screen")
	optionsList.add_item("Fill Screen")
	optionsList.add_item("Stretch")
	
	optionsList.item_selected.connect(_change_scaling_method)
	
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR,dock)
	
	_load_settings()

func _change_scaling_method(i: int):
	scaling_method=i
	_change_viewport(current_viewport)

func _scene_changed_signal(_scene_root: Node):
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
	
	var scale_factory = float(viewportSize.y) / float(base_h)
	var scale_factorx = float(viewportSize.x) / float(base_w)
	
	var scaled_w = float(base_w)*scale_factory
	var offset_x = (float(viewportSize.x)-scaled_w)*0.5
	
	var scaled_h = float(base_h)*scale_factorx
	var offset_y = (float(viewportSize.y)-scaled_h)*0.5
	
	match scaling_method:
		0:
			return Transform2D(Vector2(scale_factory,0),Vector2(0,scale_factory),Vector2(offset_x,0))
		1:
			return Transform2D(Vector2(scale_factorx,0),Vector2(0,scale_factorx),Vector2(0,offset_y))
		2:
			var scale_factor = min(scale_factorx,scale_factory)
			
			scaled_w = float(base_w)*scale_factor
			offset_x = (float(viewportSize.x)-scaled_w)*0.5
			
			scaled_h = float(base_h)*scale_factor
			offset_y = (float(viewportSize.y)-scaled_h)*0.5
			
			return Transform2D(Vector2(scale_factor,0),Vector2(0,scale_factor),Vector2(offset_x,offset_y))
		3:
			var scale_factor = max(scale_factorx,scale_factory)
			
			scaled_w = float(base_w)*scale_factor
			offset_x = (float(viewportSize.x)-scaled_w)*0.5
			
			scaled_h = float(base_h)*scale_factor
			offset_y = (float(viewportSize.y)-scaled_h)*0.5
			
			return Transform2D(Vector2(scale_factor,0),Vector2(0,scale_factor),Vector2(offset_x,offset_y))
		_:
			scaled_w = float(base_w)*scale_factorx
			offset_x = (float(viewportSize.x)-scaled_w)*0.5
			
			scaled_h = float(base_h)*scale_factory
			offset_y = (float(viewportSize.y)-scaled_h)*0.5
			
			return Transform2D(Vector2(scale_factorx,0),Vector2(0,scale_factory),Vector2(offset_x,offset_y))

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
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	if scene_changed.is_connected(_scene_changed_signal):
		scene_changed.disconnect(_scene_changed_signal)
	if viewport_rid.is_valid() and canvas_rid.is_valid():
		RenderingServer.viewport_remove_canvas(viewport_rid,canvas_rid)
	
	_save_settings()

func _get_plugin_name():
	return "UI Overlay In 3D"

func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
