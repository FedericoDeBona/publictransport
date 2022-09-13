# Public Transport
This resource will make public transport aviable managed by the game AI.

Of course, you can create your [custom routes](#instructions-if-you-want-to-add-a-new-route).
# Requirements
* *spawnmanager*

This resource doesn't require any framework.
# Instructions if you want to add a new route
1. Open **config.lua** and create a new route like in the example. **IMPORTANT**: always add the route at the end of the Config.Routes table
2. Once you've done it, restart the resource and use the command ```/bake routeId```, where **routeId** is the position of the route in the Config.Routes table.
3. As soon as the bake is done, you will see on the map some blips indicating the route just calculated (for few seconds) and a file will be saved in /bake_data/baked_routes/. If you don't see all the blips, don't worry. Most likely the problem is you have reached the maximum number of blips that can be displayed due to the length of the route.
4. Do a ```/refresh``` since there is a new file, and ```/restart publictransprot```.
5. You are done. Everything should start working fine.