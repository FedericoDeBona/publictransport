Config = {}
Config.WaitTimeAtBusStop = 8 -- In seconds
-- If you want to change this go here https://www.vespura.com/fivem/drivingstyle/
-- There are some problems with traffic lights, sometimes the vehicle takes a weird path
Config.DriveStyle = 2103615 
-- ========================
-- BAKE PARAMS
-- Distance between points in the baked path
Config.BakeStepUnits = 70.0
Config.AverageSpeed = 20.0 -- in m/s - about 72 km/h

Config.Routes = {
	{
		-- routeId = 1
		info = { 
			color = 84, -- Route color https://wiki.gtanet.work/index.php?title=Blips#Blip_Colors
			hash = "bus", -- name of vehicle to use https://wiki.gtanet.work/index.php?title=Vehicle_Models
			numberOfBuses = 4, -- number of buses per route (>= 1)
			timeBetweenBus = 40, -- Time between buses in seconds. In this case there will be 4 buses in total for this route, one every 40 seconds
			startHeading = 68.031 -- Spawn heding
		},
		busStops = {
			{ pos = vector3(234.9626, -829.2527, 29.98755), stop = true }, -- The first bus stop is also the spawn point
			{ pos = vector3(-11.06, -875.13, 30.09), stop = false },  -- stop = false -> the bus won't stop but is forced to pass here
			{ pos = vector3(-232.1934, -983.7758, 28.60583), stop = true },
			{ pos = vector3(-68.75604, -1078.668, 26.97144), stop = true },
			{ pos = vector3(176.8747, -1030.365, 29.3136), stop = false },
			{ pos = vector3(270.3956, -848.2022, 29.33044), stop = false },
		}
	},
	{
		-- routeId = 2
		info = { 
			color = 22, 
			hash = "coach",
			numberOfBuses = 3,
			timeBetweenBus = 120,
			startHeading = 215.433,
		},
		busStops = {
			{ pos = vector3(227.26, -853.93, 29.94), stop = true },
			{ pos = vector3(2896.43, 4151.39, 50.31), stop = true },
			{ pos = vector3(202.79, 6567.09, 32.01), stop = true },
			{ pos = vector3(-2733.92, 2275.52, 20.01), stop = true },
			{ pos = vector3(-1873.32, -565.0, 11.64), stop = false }
		}
	},
	{
		-- routeId = 3
		info = { 
			color = 24, 
			hash = "bus", 
			numberOfBuses = 2,
			timeBetweenBus = 60, 
			startHeading = 215.433 
		},
		busStops = {
			{ pos = vector3(-1167.943, -1471.187, 3.634399), stop = true },
			{ pos = vector3(-1107.257, -1467.336, 4.342163), stop = false },
			{ pos = vector3(-808.1934, -1029.653, 12.48059), stop = true },
			{ pos = vector3(-560.1099, -843.8505, 26.75244), stop = true },
			{ pos = vector3(-248.822, -881.9077, 29.95386), stop = true },
			{ pos = vector3(194.5978, -789.3494, 30.96484), stop = true },
			{ pos = vector3(131.578, -578.3077, 43.07983), stop = false },
			{ pos = vector3(-757.6219, -936.4088, 17.33337), stop = true },
		}
	},
}