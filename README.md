# Public Transport
This resource will make public transport aviable managed by the game AI.

# No more out of scope entity management
If one or more players are close enough to a bus, you will see a bus driving around.<br>
When no players are close enough to a bus, the server will simulate its position based on the baked data.

# No requirements
Completely standalone, no framework or resources needed

# Add custom routes
1. Open **config.lua** and create a new route like in the example.<br>
    **IMPORTANT NOTES**: 
    * always add the route at the end of the Config.Routes table
    * when adding a new stop in the busStops array, **avoid** to get the position in the middle of a crossroad
2. Once you've done it, restart the resource and use the command ```/bake routeId```, where **routeId** is the position of the route in the Config.Routes table.
3. As soon as the bake is done (check client console for errors), you will see on the map some blips indicating the route just calculated (for few seconds) and a file will be saved in /bake_data/baked_routes/.
4. Do a ```/refresh``` since there are a new files, and ```/restart publictransprot```.
5. You are done. Everything should start working fine.<br>
**Tip:** once you have done baking the new routes, remove from the fxmanifest.lua file ```'client/bake.lua'``` line, so no one will be able to run the ```/bake```