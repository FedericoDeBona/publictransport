local bakedRoutes = {}
local vehicles = {}

-- Initialize all the routes
Citizen.CreateThread(function()
	-- TODO: test
	-- https://forum.cfx.re/t/help-triggerclientevent-on-resourcestart/683698
	while not GetResourceState(GetCurrentResourceName()) == "started" do Wait(0) end
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
	local targetPos = GetEntityCoords(GetPlayerPed(target))
	local vehicle = Citizen.InvokeNative(GetHashKey("CREATE_AUTOMOBILE"), GetHashKey(hash), pos, heading, true, false)
	while not DoesEntityExist(vehicle) do Wait(0) end
	--  Always suppose the owner of the vehicle is the server at the beginning
	local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
	table.insert(vehicles["server"], {position = pos, vehicleNetId = vehicleNetId, pedNetId = nil, routeId = routeId, nextStop = 2, color = Config.Routes[routeId].info.color})
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
	local pos = vector3(vehicles["server"][index].position.x, vehicles["server"][index].position.y, vehicles["server"][index].position.z)
	local nextPosition = GetClosestNodeIdFromVehicle(pos, route[nextBusStop])
	
	local time = Config.BakeStepUnits / 60.0
	local actualTime = 0.0

	local ped = GetPedInVehicleSeat(NetToEnt(vehicleNetId), -1)
	if DoesEntityExist(ped) then DeleteEntity(ped) end
	if index == nil then 
		print("ERROR: vehicle not found in the table")
		print(json.encode(vehicles["server"]), vehicleNetId)
		return
	end
	while NetworkGetEntityOwner(NetToEnt(vehicleNetId)) <= 0 do
		if actualTime >= time then
			actualTime = 0
			local node = route[nextBusStop][nextPosition]
			local pos = vector3(node.x, node.y, node.z)
			-- Need to fake the movement of the bus even if it exists, since SetEntityCoords is a RPC, so if no one is near the bus, it won't work
			vehicles["server"][index].position = pos
			
			-- TODO: test with IncrementIndex
			nextPosition = (nextPosition+1)%(#route[nextBusStop]+1)
			TriggerClientEvent("publictransport:addBlipForCoords", -1, routeId, vehicles["server"][index].position, vehicleNetId, Config.Routes[routeId].info.color)
			
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
		end
		Wait(100)
		actualTime = actualTime + 0.1
	end
	print("Server lost control of the vehicle, passing control to player " .. NetworkGetEntityOwner(NetToEnt(vehicleNetId)))
	-- At this point owner changed, so the vehicle gets managed by a client
	ClientStartRoute(routeId, vehicleNetId, IncrementIndex(nextBusStop, #route))
end

-- Given the vehicle, the route id and the bus stop to reach, this function will create the ped inside the vehicle,
-- and tells the client to start the route
function ClientStartRoute(routeId, vehicleNetId, nextBusStop)
	local target = NetworkGetEntityOwner(NetToEnt(vehicleNetId))
	if vehicles[target] == nil then
		vehicles[target] = {}
	end
	-- If there is no ped inside the vehicle, create one
	local ped = GetPedInVehicleSeat(NetToEnt(vehicleNetId), -1)
	if not DoesEntityExist(ped) then
		ped = CreatePedInsideVehicle(NetToEnt(vehicleNetId), 0, GetHashKey("s_m_m_gentransport"), -1, true, false)
		while not DoesEntityExist(ped) do Wait(0) end
	end
	local pedNetId = NetworkGetNetworkIdFromEntity(ped)
	local index = FindRouteInTable("server", vehicleNetId)
	table.insert(vehicles[target], vehicles["server"][index])
	table.remove(vehicles["server"], index) 
	vehicles[target][#vehicles[target]].pedNetId = pedNetId
	TriggerClientEvent("publictransport:restoreRoute", target, vehicleNetId, routeId, nextBusStop, vehicles[target][#vehicles[target]].position)
end

function ManageOwnerChanged(src, vehicleNetId, position)
	while NetworkGetEntityOwner(NetToEnt(vehicleNetId)) == src do Wait(0) end
	local target = NetworkGetEntityOwner(NetToEnt(vehicleNetId))

	local index = FindRouteInTable(src, vehicleNetId)
	vehicles[src][index].position = position
	local data = vehicles[src][index]
	print("Managing owner changed", src, target, jso)
	if target <= 0 then
		table.insert(vehicles["server"], data)
		table.remove(vehicles[src], index) 
		if DoesEntityExist(NetToEnt(vehicles["server"][index].pedNetId)) then
			DeleteEntity(NetToEnt(vehicles["server"][index].pedNetId))
		end
		ServerManageRoute(data.routeId, vehicleNetId, DecrementIndex(data.nextStop, #Config.Routes[data.routeId].busStops))
	else
		if vehicles[target] == nil then
			vehicles[target] = {}
		end
		table.insert(vehicles[target], data)
		table.remove(vehicles[src], index)
		TriggerClientEvent("publictransport:restoreRoute", target, vehicleNetId, routeId, nextStop)
	end
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

function NetToEnt(netId)
	return NetworkGetEntityFromNetworkId(netId)
end

function IncrementIndex(num, length)
	if num+1 > length then
		return 1
	else
		return num+1
	end
end

function DecrementIndex(num, length)
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

function CleanUp()
	for id, playerData in pairs(vehicles) do
		for i,data in ipairs(playerData) do
			local veh = NetToEnt(data.vehicleNetId)
			local ped = NetToEnt(data.pedNetId)
			if DoesEntityExist(veh) then
				DeleteEntity(veh)
			end
			if DoesEntityExist(ped) then
				DeleteEntity(ped)
			end
		end
	end
	vehicles = {}
	bakedRoutes = {}
end

-- =========================
-- 			EVENTS
-- =========================
-- Event that takes the baked path of a specific route and save it to file
RegisterNetEvent("spaw_test:saveRouteToFile")
AddEventHandler("spaw_test:saveRouteToFile", function(routeId, path)
	SaveResourceFile(GetCurrentResourceName(), "bake_data/baked_routes/route_"..routeId..".json", json.encode(path), -1)
end)

RegisterNetEvent("publictransport:ownerChanged")
AddEventHandler("publictransport:ownerChanged", function(vehicleNetId, lastKnownPosition)
	local src = source
	ManageOwnerChanged(src, vehicleNetId, lastKnownPosition)
end)

RegisterNetEvent("publictransport:playerNearVehicle")
AddEventHandler("publictransport:playerNearVehicle", function(routeId, vehicleNetId, position, heading)
	if NetworkGetEntityOwner(NetToEnt(vehicleNetId)) > 0 then
		print("Entity is owned by a client, ignoring the playerNearVehicle")
		return
	end
	print("Player near vehicle", vehicleNetId, position, heading)
	local src = source
	local hash = Config.Routes[routeId].info.hash
	local index = FindRouteInTable("server", vehicleNetId)
	DeleteEtity(NetToEnt(vehileNetId))
	local vehicle = Citizen.InvokeNative(GetHashKey("CREATE_AUTOMOBILE"), GetHashKey(hash), position, heading, true, false)
	while not DoesEntityExist(vehicle) do Wait(0) end
	local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
	vehicles["server"][index].vehicleNetId = vehicleNetId
	print("Done setting the vehicle")
end)

RegisterNetEvent("publictransport:updateNextStop")
AddEventHandler("publictransport:updateNextStop", function(vehicleNetId, nextStop)
	local src = source
	if vehicles[src] == nil then
		print("ERROR: vehicles[src] is nil. How?")
		return
	end
	local index = FindRouteInTable(src, vehicleNetId)
	vehicles[src][index].nextStop = nextStop
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