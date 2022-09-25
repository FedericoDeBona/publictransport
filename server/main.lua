local bakedRoutes = {}
local routes = {}

-- Initialize all the routes
Citizen.CreateThread(function()
	-- https://forum.cfx.re/t/help-triggerclientevent-on-resourcestart/683698
	while not GetResourceState(GetCurrentResourceName()) == "started" do Wait(0) end

	for routeId, v in pairs(Config.Routes) do
		routes[routeId] = {}
		Citizen.CreateThread(function()
			for i=1, v.info.numberOfBuses do
				StartNewRoute(routeId, i)
				Wait(v.info.timeBetweenBus*1000)
			end
		end)
	end
end)

-- ===========================
-- 			FUNCTIONS
-- ===========================
function StartNewRoute(routeId, busNum)
	local route = Config.Routes[routeId]
	local hash = route.info.hash
	local pos = route.busStops[1].pos
	local heading = route.info.startHeading
	routes[routeId][busNum] = {owner = "server", position = pos, changingOwner = false, vehicleNetId = 0, pedNetId = nil, routeId = routeId, busNum = busNum, nextStop = 2, color = Config.Routes[routeId].info.color}
	ServerManageRoute(routes[routeId][busNum], 1)
end

-- Given the data relative to the bus, this function will simulate its movements based
-- on the baked data. In case a player enters the scope of a bus, this will give the control to the player
function ServerManageRoute(data, bakedRoutePart)
	if bakedRoutes[data.routeId] == nil then
		bakedRoutes[data.routeId] = json.decode(LoadResourceFile(GetCurrentResourceName(), "bake_data/baked_routes/route_"..data.routeId..".json"))
		if bakedRoutes[data.routeId] == nil then
			print("File not found for route "..data.routeId .. "\nBake the path using /bake ".. data.routeId .. " , then /refresh and restart the resource")
			return
		end
	end
	local route = bakedRoutes[data.routeId]
	local nextPosition = GetClosestNodeIdFromVehicle(data.position, route[bakedRoutePart])
	local time = Config.BakeStepUnits / Config.AverageSpeed
	local actualTime = time

	-- Delete the ped and bus
	local vehicle = NetToEnt(data.vehicleNetId)
	local ped = GetPedInVehicleSeat(vehicle, -1)
	while DoesEntityExist(ped) do
		DeleteEntity(ped)
		Wait(0)
	end
	while DoesEntityExist(vehicle) do
		DeleteEntity(vehicle)
		Wait(0)
	end
	
	while data.owner == "server" do
		if data.changingOwner == false and actualTime >= time then
			actualTime = 0
			local node = route[bakedRoutePart][nextPosition]
			-- Need to fake the movement of the bus even if it exists, since SetEntityCoords is a RPC, so if no one is near the bus, it won't work
			data.position = vector3(node.x, node.y, node.z)
			nextPosition = IncrementIndex(nextPosition, #route[bakedRoutePart])
			-- Reached the next bus stop
			if nextPosition == 1 then
				bakedRoutePart = IncrementIndex(bakedRoutePart, #route)
				data.nextStop = IncrementIndex(bakedRoutePart, #route)
			end
			local nextNodePosition = vector3(route[bakedRoutePart][nextPosition].x, route[bakedRoutePart][nextPosition].y, route[bakedRoutePart][nextPosition].z)
			TriggerClientEvent("publictransport:addBlipForCoords", -1, data.routeId, data.busNum, data.position, nextNodePosition, Config.Routes[data.routeId].info.color, true)
			-- Reached a bus stop, waiting if needed
			if nextPosition == 1 and Config.Routes[data.routeId].busStops[bakedRoutePart].stop == true then Wait(Config.WaitTimeAtBusStop*1000.0) end
		end
		Wait(100)
		actualTime = actualTime + 0.1
	end
end

function ManageOwnerChanged(data, position)
	while NetworkGetEntityOwner(NetToEnt(data.vehicleNetId)) == data.owner do Wait(0) end
	local owner = NetworkGetEntityOwner(NetToEnt(data.vehicleNetId))
	data.position = position
	
	print("Managing owner changed, now " .. owner)
	if owner == 0 then
		print("Error: owner is 0")
		return
	end
	if owner < 0 then
		data.owner = "server"
		local ped = NetToEnt(data.pedNetId)
		if DoesEntityExist(ped) then
			DeleteEntity(ped)
		end
		ServerManageRoute(data, DecrementIndex(data.nextStop, #Config.Routes[data.routeId].busStops))
	else
		data.owner = owner
		TriggerClientEvent("publictransport:restoreRoute", data.owner, data.routeId, data.busNum, data.vehicleNetId, data.nextStop, data.position)
	end
end

-- Utility function to get the closest node from a position using the baked data
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

-- Utility function to have clean code
function NetToEnt(netId)
	return NetworkGetEntityFromNetworkId(netId)
end

-- Utility function to increment an index, looping back to 1 if needed
function IncrementIndex(num, length)
	if num+1 > length then
		return 1
	else
		return num+1
	end
end

-- Utility function to decrement an index, looping back to length if needed
function DecrementIndex(num, length)
	if num-1 <= 0 then
		return length
	else
		return num-1
	end
end

function CleanUp()
	for routeId, buses in ipairs(routes) do
		for busNum, data in ipairs(buses) do
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
	routes = {}
	bakedRoutes = {}
end

-- =========================
-- 			EVENTS
-- =========================
-- Takes the baked path of a specific route and save it to file
RegisterNetEvent("spaw_test:saveRouteToFile")
AddEventHandler("spaw_test:saveRouteToFile", function(routeId, path)
	SaveResourceFile(GetCurrentResourceName(), "bake_data/baked_routes/route_"..routeId..".json", json.encode(path), -1)
end)

-- Triggered when a client loses the ownership of a bus
RegisterNetEvent("publictransport:ownerChanged")
AddEventHandler("publictransport:ownerChanged", function(routeId, busNum, lastKnownPosition)
	ManageOwnerChanged(routes[routeId][busNum], lastKnownPosition)
end)

-- Triggered when a client is close enough to a bus to take control of it
RegisterNetEvent("publictransport:playerNearVehicle")
AddEventHandler("publictransport:playerNearVehicle", function(routeId, busNum, position, heading)
	local src = source
	local data = routes[routeId][busNum]
	local vehicle = NetToEnt(data.vehicleNetId)
	-- If vehicle already exist or someone is already changing the owner, do nothing
	if (DoesEntityExist(vehicle) and DoesEntityExist(GetPedInVehicleSeat(vehicle, -1))) or data.changingOwner then
		return
	end
	data.changingOwner = true
	local hash = Config.Routes[routeId].info.hash
	vehicle = CreateVehicle(GetHashKey(hash), position, heading, true, false)
	
	while not DoesEntityExist(vehicle) do Wait(0) end
	local attempts = 0
	local ped = nil
	while not DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) do 
		ped = CreatePedInsideVehicle(vehicle, 0, GetHashKey("s_m_m_gentransport"), -1, true, false)
		attempts = attempts + 1
		if attempts > 30 then
			print("Error: couldn't create ped in vehicle, source: " .. src)
			data.changingOwner = false
			DeleteEntity(vehicle)
			return
		end
		Wait(100)
	end
	
	local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
	local owner = NetworkGetEntityOwner(vehicle)
	if owner < 0 then
		owner = "server"
	end
	data.vehicleNetId = vehicleNetId
	data.owner = owner
	data.position = position
	data.changingOwner = false
	TriggerClientEvent("publictransport:restoreRoute", data.owner, data.routeId, data.busNum, data.vehicleNetId, data.nextStop, data.position)
end)

RegisterNetEvent("publictransport:addBlipsForEveryone")
AddEventHandler("publictransport:addBlipsForEveryone", function(routeId, busNum, vehicleNetId, color)
	local veh = NetToEnt(vehicleNetId)
	while routes[routeId][busNum].owner == "server" do Wait(0) end
	while DoesEntityExist(veh) and routes[routeId][busNum].owner ~= "server" do
		TriggerClientEvent("publictransport:addBlipForCoords", -1, routeId, busNum, GetEntityCoords(veh), nil, color, false)
		Wait(2500)
	end
end)

RegisterNetEvent("publictransport:updateNextStop")
AddEventHandler("publictransport:updateNextStop", function(routeId, busNum, nextStop)
	routes[routeId][busNum].nextStop = nextStop
end)

AddEventHandler('playerDropped', function (reason)
	local src = source
	for routeId, buses in ipairs(routes) do
		for busNum, data in ipairs(buses) do
			if data.owner == src then
				ManageOwnerChanged(data, data.position)
			end
		end
	end
end)

AddEventHandler("onResourceStop", function(resName)
	if GetCurrentResourceName() == resName then
		CleanUp()
	end
end)
