# Public Transport
This resource will make public transport aviable managed by the game AI.

Of course, you can create your [custom routes](#instructions-if-you-want-to-add-a-new-route).
# No requirements
Completely standalone, no framework or resources needed

# Instructions if you want to add a new route
1. Open **config.lua** and create a new route like in the example. 
   
    **IMPORTANT NOTES**: 
    * always add the route at the end of the Config.Routes table
    * when adding a new stop in the busStops array, **avoid** to get the position in the middle of a crossroad
2. Once you've done it, restart the resource and use the command ```/bake routeId```, where **routeId** is the position of the route in the Config.Routes table.
3. As soon as the bake is done (check client console for errors), you will see on the map some blips indicating the route just calculated (for few seconds) and a file will be saved in /bake_data/baked_routes/.
4. Do a ```/refresh``` since there are a new files, and ```/restart publictransprot```.
5. You are done. Everything should start working fine.