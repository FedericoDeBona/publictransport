Config = {}
Config.WaitTimeAtBusStop = 30 -- In seconds

--	Route #4   Leagion(rt #12 transfer), Grove, Air Port, Arena
--	Route #12  Leagion(rt #4 transfer), Mt Zonah Medical Center, Great Ocean Highway Loop, Highway Loop Gas Station (rt #69 transfer), Bolingbroke Prison
--	Route #69  Bolingbroke Prison, Route 68, Animal Ark, Sandy Medical Center, Grapeseed, Utool, Highway Loop Gas Station(rt #12 transfer)


Config.Routes = {
	{ 	-- First spawn point - Vechileshop - Central Garage
		info = { 
			color = 84, 
			hash = "bus", 		--bus model name
			name ="Route 4", 	--map blip
			busNum = 2,    		-- max buses on rute
			timeBetweenBus = 300, -- In second 
		},
		---#### bus spawn####--- 
		{ spawn = vector3(425.3148, -661.8354, 28.22534), sheading = 181.21881103516, stop = false },
		---#### bus spawn####---
		
		{ pos = vector3(251.8333, -923.6326, 28.55233), heading = 160.54768371582, stop = true },
		{ pos = vector3(218.9534, -1224.029, 28.82712), heading = 188.88729858398, stop = false },
		{ pos = vector3(211.0958, -1263.026, 29.28326), heading = 170.23724365234, stop = true },
		{ pos = vector3(236.1234, -1182.083, 28.69823), heading = 87.782234191895, stop = false},
		{ pos = vector3(81.00227, -1462.578, 28.69499), heading = 140.40844726562, stop = true },
		{ pos = vector3(-107.7338, -1686.924, 28.6909), heading = 138.79309082031, stop = true },
		{ pos = vector3(-826.6936, -2227.266, 16.85736), heading = 127.33377838135, stop = false},
		{ pos = vector3(-1027.188, -2732.008, 19.62904), heading = 239.38418579102, stop = true },
		{ pos = vector3(-868.4469, -2649.57, 18.19466), heading = 331.89254760742, stop = false},
		{ pos = vector3(-686.7936, -2128.008, 13.11308), heading = 318.0188293457, stop = false},
		{ pos = vector3(-166.2563, -2101.937, 24.54652), heading = 295.56048583984, stop = false},
		{ pos = vector3(-152.1647, -2030.012, 22.19954), heading = 348.32580566406, stop = true },
		{ pos = vector3(280.5829, -1550.186, 28.56914), heading = 299.48260498047, stop = true },
		{ pos = vector3(428.3232, -1461.478, 28.73788), heading = 299.10577392578, stop = true },
		{ pos = vector3(525.6581, -1433.737, 28.82745), heading = 271.63790893555, stop = false},
		{ pos = vector3(502.9461, -963.9166, 26.76926), heading = 0.34373396635056, stop = false},
		{ pos = vector3(424.666, -951.9762, 28.73418), heading = 91.422798156738, stop = true },
		{ pos = vector3(408.1241, -870.8449, 28.78101), heading = 356.42642211914, stop = false},
	},
		{ 	
		info = { 
			color = 60, 
			hash = "bus3",  --bus model name
			name ="Route 12", --map blip
			busNum = 2, -- max buses on rute
			timeBetweenBus = 300, -- In second 
		},
		---#### bus spawn####---
		{ spawn = vector3(425.0042, -632.4023, 27.92597), sheading = 180.54792785645, stop = false },
		---#### bus spawn####---
		
		{ pos = vector3(376.9481, -671.1337, 28.70369), heading = 76.458724975586, stop = false },
		{ pos = vector3(118.2637, -786.2177, 31.32615), heading = 68.641036987305, stop = true },
		{ pos = vector3(-218.9823, -577.9937, 34.53056), heading = 338.66510009766, stop = true },
		{ pos = vector3(-535.03, -332.74, 35.04424), heading = 30.995735168457, stop = true },
		{ pos = vector3(-652.4438, -608.3334, 33.17287), heading = 181.03221130371, stop = true },
		{ pos = vector3(-708.4246, -827.8771, 23.48634), heading = 90.17366027832, stop = true },
		{ pos = vector3(-1204.355, -857.5109, 13.70634), heading = 125.65648651123, stop = true },
		{ pos = vector3(-1667.833, -543.5755, 34.90822), heading = 55.829132080078, stop = true },
		{ pos = vector3(-2112.026, -355.143, 12.96052), heading = 68.13695526123, stop = true },
		{ pos = vector3(-2976.711, 455.8702, 15.15045), heading = 358.10360717773, stop = true },
		{ pos = vector3(-3222.285, 1032.314, 11.64459), heading = 353.41296386719, stop = true },
		{ pos = vector3(-3110.101, 1316.615, 20.15075), heading = 263.85028076172, stop = false },
		{ pos = vector3(-2467.822, 3617.673, 14.12114), heading = 351.4553527832, stop = true },
		{ pos = vector3(-2205.164, 4302.671, 48.35155), heading = 332.03378295898, stop = true },
		{ pos = vector3(-1495.422, 4994.365, 62.80574), heading = 315.42468261719, stop = true },
		{ pos = vector3(-157.9969, 6205.595, 31.21993), heading = 319.27139282227, stop = true },
		{ pos = vector3(1509.752, 6420.758, 22.99914), heading = 248.75689697266, stop = true },
		{ pos = vector3(2703.73, 3257.449, 55.00704), heading = 152.6870880127, stop = true },
		{ pos = vector3(2378.395, 2964.768, 49.16267), heading = 99.481391906738, stop = false },
		{ pos = vector3(1907.26, 2609.93, 45.80218), heading = 88.140319824219, stop = false},
		{ pos = vector3(1860.937, 2589.201, 45.68473), heading = 178.58990478516, stop = true },
		{ pos = vector3(1860.421, 2625.354, 45.68404), heading = 180.87734985352, stop = false},
		{ pos = vector3(2206.625, 2998.296, 45.58517), heading = 310.20489501953, stop = false},
		{ pos = vector3(308.7285, -763.9323, 29.27755), heading = 161.89477539062, stop = true },
		
		
		
		
		
	},
	--To make a new route use /busstop to get a bus stop ready to be pasted here.  Make sure to edit name, hash and amount of buses if needed 
	{
		info = { 
			color = 12, 
			hash = "gm5303",  --bus model name
			name ="Route 69",	--map blip
			busNum = 2, 		-- max buses on rute
			timeBetweenBus = 300, -- In second 
		},
		---#### bus spawn####---
		{ spawn = vector3(416.27, -627.2843, 27.92882), sheading = 268.78564453125, stop = false },
		---#### bus spawn####---
		
		{ pos = vector3(2334.941, 2982.493, 48.07115), heading = 62.051963806152, stop = false },		
		{ pos = vector3(2376.828, 2966.138, 48.74396), heading = 97.65731048584, stop = false },
		{ pos = vector3(1859.606, 2588.188, 45.30012), heading = 179.89149475098, stop = true },
		{ pos = vector3(1860.473, 2656.615, 45.29933), heading = 179.36946105957, stop = false },
		{ pos = vector3(1229.2, 2689.11, 37.17344), heading = 88.789916992188, stop = true },
		{ pos = vector3(541.2209, 2696.024, 41.83293), heading = 95.161354064941, stop = true },
		{ pos = vector3(297.0441, 2642.614, 44.27278), heading = 106.5472869873, stop = false },
		{ pos = vector3(922.0824, 3533.229, 33.66491), heading = 270.12353515625, stop = false },
		{ pos = vector3(1507.961, 3726.627, 34.05081), heading = 299.80865478516, stop = true },
		{ pos = vector3(1665.368, 3561.373, 35.20516), heading = 209.62133789062, stop = false },
		{ pos = vector3(1895.208, 3680.405, 32.80594), heading = 297.11529541016, stop = true },
		{ pos = vector3(2480.599, 4048.391, 37.16983), heading = 338.40139770508, stop = true },
		{ pos = vector3(1676.627, 4818.565, 41.64514), heading = 5.2453031539917, stop = true },
		{ pos = vector3(1953.583, 5140.288, 43.07061), heading = 245.34295654297, stop = false },
		{ pos = vector3(2468.54, 5110.069, 46.10844), heading = 241.21199035645, stop = false },
		{ pos = vector3(2789.836, 3446.882, 55.14616), heading = 158.25053405762, stop = true },
		{ pos = vector3(2701.951, 3255.37, 54.57192), heading = 153.96618652344, stop = true },
	},
}