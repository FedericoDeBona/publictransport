local bakedRoutes = {}
local vehicles = {}

-- Initialize all the routes
Citizen.CreateThread(function()
	-- Mandatory wait or the "publictransport:addBlipForVehicle" won't be triggered
	-- But why?
	Wait(500) 
	vehicles["server"] = {}
	for routeId, v in pairs(Config.Routes) do
		Citizen.CreateThread(function()
			for i=1, v.info.busNum do
				StartNewRoute(routeId)
				Wait(v.info.timeBetweenBus*1000)
			end
		end)
	end
end)

-- ===========================
-- 			FUNCTIONS
-- ===========================
function StartNewRoute(routeId)
	local route = Config.Routes[routeId]
	local hash = route.info.hash
	local pos = route.busStops[1].pos
	local heading = route.info.startHeading
	local vehicle = Citizen.InvokeNative(GetHashKey("CREATE_AUTOMOBILE"), GetHashKey(hash), pos, heading, true, false)
	while not DoesEntityExist(vehicle) do Wait(0) end
	--  Always suppose the owner of the vehicle is the server at the beginning
	local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
	table.insert(vehicles["server"], {position = pos, vehicleNetId = vehicleNetId, pedNetId = nil, routeId = routeId, nextStop = 2, color = Config.Routes[routeId].info.color})
	TriggerClientEvent("publictransport:addBlipForVehicle", -1, vehicleNetId, Config.Routes[routeId].info.color)
	ServerManageRoute(routeId, vehicleNetId, 1)
end

-- Given the vehicle, the route id and the bus stop to reach, this function will simulate the bus movements based
-- on the baked data. In case a player enters the scope of a bus, this will give the control to the player
function ServerManageRoute(routeId, vehicleNetId, nextBusStop)
	if bakedRoutes[routeId] == nil then
		bakedRoutes[routeId] = json.decode(LoadResourceFile(GetCurrentResourceName(), "bake_data/baked_routes/route_"..routeId..".json"))
	end
	local route = bakedRoutes[routeId]
	-- TODO : nextBusStop-1 could be 0 -> manage this case
	local index = FindRouteInTable("server", vehicleNetId)
	local nextPosition = GetClosestNodeIdFromVehicle(vehicles["server"][index].position, route[nextBusStop])
	
	local time = Config.BakeStepUnits / 60.0
	local actualTime = 0.0
	
	while NetworkGetEntityOwner(NetToVeh(vehicleNetId)) <= 0 do
		if actualTime >= time then
			actualTime = 0
			local node = route[nextBusStop][nextPosition]
			local pos = vector3(node.x, node.y, node.z)
			-- Need to fake the movement of the bus even if it exists, since SetEntityCoords is a RPC, so if no one is near the bus, it won't work
			vehicles["server"][index].position = pos

			-- TODO: così facendo salto l'ultimo punto di ogni path fino al busStop?
			nextPosition = (nextPosition+1)%(#route[nextBusStop]+1)
			TriggerClientEvent("publictransport:addBlipForCoords", -1, vehicles["server"][index].position, Config.Routes[routeId].info.color)
			
			if nextPosition == 0 then
				nextBusStop = (nextBusStop+1)%#route
				if nextBusStop == 0 then
					nextBusStop = 1
				end
				local index = FindRouteInTable("server", vehicleNetId)
				if nextBusStop+1 > #route then
					vehicles["server"][index].nextStop = 1
				else
					vehicles["server"][index].nextStop = nextBusStop+1
				end
				nextPosition = 1
			end
			print("Next position: "..nextPosition)
			-- TODO: test if true
			-- No need to notify the clients, since the vehicle is created usine CREATE_AUTOMOBILE and sync between
			-- every client, hence the clients will see the vehicle moving by AddBlipForEntity native
		end
		Wait(100)
		actualTime = actualTime + 0.1
	end
	print("Server lost control of the vehicle, passing control to the player")
	-- At this point owner changed, so the vehicle is now managed by a client
	ClientStartRoute(routeId, vehicleNetId, CalculateModule(nextBusStop, #route))
end

function ClientStartRoute(routeId, vehicleNetId, nextBusStop)
	local target = NetworkGetEntityOwner(NetToVeh(vehicleNetId))
	if vehicles[target] == nil then
		vehicles[target] = {}
	end
	local ped = CreatePedInsideVehicle(NetToVeh(vehicleNetId), 0, GetHashKey("s_m_m_gentransport"), -1, true, false)
	while not DoesEntityExist(ped) do Wait(0) end
	local pedNetId = NetworkGetNetworkIdFromEntity(ped)
	local index = FindRouteInTable("server", vehicleNetId)
	table.insert(vehicles[target], vehicles["server"][index])
	-- Dangerous operation. This will shift all the elements, so if another thread is accessing the table
	-- at a certan index, it will get the wrong element or nil
	-- Very unlikely to happen, but still possible
	table.remove(vehicles["server"], index) 
	vehicles[target][#vehicles[target]].pedNetId = pedNetId
	TriggerClientEvent("publictransport:restoreRoute", target, vehicleNetId, routeId, nextBusStop, vehicles[target][#vehicles[target]].position)
end

function ManageOwnerChanged(src, vehicleNetId)
	print("Managing owner changed", src, vehicleNetId)
	while NetworkGetEntityOwner(NetToVeh(vehicleNetId)) == src do Wait(0) end
	local target = NetworkGetEntityOwner(NetToVeh(vehicleNetId))

	local index = FindRouteInTable(src, vehicleNetId)
	local data = vehicles[src][index]
	if target <= 0 then
		table.insert(vehicles["server"], data)
		table.remove(vehicles[src], index) 
		ServerManageRoute(data.routeId, vehicleNetId, CalculateModuleInverse(data.nextStop, #Config.Routes[data.routeId].busStops))
	else
		if vehicles[target] == nil then
			vehicles[target] = {}
		end
		table.insert(vehicles[target], data)
		table.remove(vehicles[src], index)
		TriggerClientEvent("publictransport:restoreRoute", target, vehicleNetId, routeId, nextStop)
	end
end

function NetToVeh(netId)
	return NetworkGetEntityFromNetworkId(netId)
end

function CalculateModule(num, length)
	if num+1 > length then
		return 1
	else
		return num+1
	end
end

function CalculateModuleInverse(num, length)
	if num-1 <= 0 then
		return length
	else
		return num-1
	end
end

function FindRouteInTable(owner, vehicleNetId)
	for i, v in ipairs(vehicles[owner]) do
		if v.vehicleNetId == vehicleNetId then
			return i
		end
	end
	print("ERROR: HOW CAN FINDROUTEINTABLE RETURN NIL?????")
	return nil
end

function GetClosestNodeIdFromVehicle(position, vehNodes)
	local closestNode = nil
	local index = nil
	for i=1, #vehNodes do
		local currNode = vehNodes[i]
		local currNodePos = vector3(currNode.x, currNode.y, currNode.z)
		if closestNode == nil then
			closestNode = currNode
			index = i
		else
			local closestNodePos = vector3(closestNode.x, closestNode.y, closestNode.z)
			if #(position - currNodePos) < #(position - closestNodePos) then
				closestNode = currNode
				index = i
			end
		end
	end
	return index
end

function CleanUp()
	for id, playerData in pairs(vehicles) do
		for i,data in ipairs(playerData) do
			local veh = NetToVeh(data.vehicleNetId)
			local ped = NetToVeh(data.pedNetId)
			if DoesEntityExist(veh) and DoesEntityExist(ped) then
				DeleteEntity(veh)
				DeleteEntity(ped)
			end
		end
	end
	vehicles = {}
end

-- TODO: execute again and remove (files too)
-- function CreateNodesFiles()
-- 	local vehicleNodes = json.decode(LoadResourceFile(GetCurrentResourceName(), "vehicle_nodes_original.json"))
-- 	local nodeLinks = json.decode(LoadResourceFile(GetCurrentResourceName(), "node_links_original.json"))
-- 	local newVehicleNodes = {}
-- 	local newLinks = {}
-- 	for i=1, #vehicleNodes do
-- 		newVehicleNodes[i] = {
-- 			id = i,
-- 			x = vehicleNodes[i][1],
-- 			y = vehicleNodes[i][2],
-- 			z = vehicleNodes[i][3],
-- 		}
-- 	end
-- 	for i=1, #nodeLinks do
-- 		local from = nodeLinks[i][1]+1
-- 		local to = nodeLinks[i][2]+1
-- 		if newLinks[from] == nil then
-- 			newLinks[from] = {}
-- 		end
-- 		table.insert(newLinks[from],to)
-- 		if newLinks[to] == nil then
-- 			newLinks[to] = {}
-- 		end
-- 		table.insert(newLinks[to],from)
-- 	end

-- 	local ret1 = SaveResourceFile(GetCurrentResourceName(), "bake_data/vehicle_nodes.json", json.encode(newVehicleNodes), -1)
-- 	local ret3 = SaveResourceFile(GetCurrentResourceName(), "bake_data/node_links.json", json.encode(newLinks), -1)
-- 	if not (ret1 or ret2 or ret3) then
-- 		print("ERROR SAVING FILES")
-- 	else
-- 		print("FILES SAVED")
-- 	end
-- end

-- =========================
-- 			EVENTS
-- =========================
-- Event that takes the baked path of a specific route and save it to file
RegisterNetEvent("spaw_test:saveRouteToFile")
AddEventHandler("spaw_test:saveRouteToFile", function(routeId, path)
	SaveResourceFile(GetCurrentResourceName(), "bake_data/baked_routes/route_"..routeId..".json", json.encode(path), -1)
end)

RegisterNetEvent("publictransport:ownerChanged")
AddEventHandler("publictransport:ownerChanged", function(vehicleNetId)
	local src = source
	if vehicles[src] ~= nil then
		ManageOwnerChanged(src, vehicleNetId)
	end
end)

RegisterNetEvent("publictransport:updateNextStop")
AddEventHandler("publictransport:updateNextStop", function(vehicleNetId, nextStop)
	local s = source
	if vehicles[s] == nil then
		return
	end
	local index = FindRouteInTable(s, vehicleNetId)
	vehicles[s][index].nextStop = nextStop
end)

RegisterNetEvent("publictransport:onPlayerSpawn")
AddEventHandler("publictransport:onPlayerSpawn", function()
	local s = source
	TriggerClientEvent("publictransport:forceSetAllVehicleBlips", s, vehicles)
end)

AddEventHandler('playerDropped', function (reason)
	local src = source
	if vehicles[src] ~= nil then
		for i, data in ipairs(vehicles[src]) do
			ManageOwnerChanged(src, data.vehicleNetId)
		end
	end
end)

AddEventHandler("onResourceStop", function(resName)
	if GetCurrentResourceName() == resName then
		CleanUp()
	end
end)