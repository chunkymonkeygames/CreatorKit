Creating a map is quite an easy process.  


To begin creating a map, open the creatortools tab and enter the name of your map in the text box  
Then press New Level  
You can now edit your map.  
**Do not add scripts to your map or material settings not compatible with gltf as they will not be preserved**  


## Map settings
* Expand your scenes rootnode (the Node3D at the top of the nodelist)  
* Expand the metadata tab
* Click on the MapInfo resource object
* Change the level name and level version
* Add tags if needed


## Exporting
To export your map, there are only a couple of steps

First, open your main map scene in godot and make sure it is the currently open scene.  
Then go to the CreatorTools menu and press Build map  
This will compile your map to gltf after expanding all packed scenes in the map

> Note that this may be buggy and may not work with complex scenes and resources  


The exported folder will be opened in file explorer.

