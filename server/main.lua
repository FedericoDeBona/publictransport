currentClient = nil
serviceStarted = false
entitiesList = {}
blips = {}
-- players[i]: true -> player online but created no ped; {1, 3, 5} -> player online and created a ped
players = {}

RegisterCommand("busstop", function(source, args)
	local ped = GetPlayerPed(source)
	print("{ pos = " .. GetEntityCoords(ped) .. ", heading = " .. GetEntityHeading(ped) .. ", stop = true },")
end)

Citizen.CreateThread(function()
	-- TODO: remove --> uncommnet next line and set as your id in the server
	-- if you want to test by restarting the resource
	-- players[1] = true
	while true do
		if GetPlayerNum() == 0 then
			-- Waiting for first spawn
			Wait(30000)
		elseif serviceStarted == false then
			print("Starting service")
			serviceStarted = true
			StartService()
		else
			-- Everything is working. Waiting.
			Wait(10000)
		end
		Wait(0)
	end
end)
RegisterCommand("bussme", function(source)
	local src = source
	while GetPlayerPed(src) == 0 do Wait(0) end

	-- TODO: Find better solution to wait the player to be spawned
	Wait(10000)
	while IsEntityVisible(GetPlayerPed(src)) == false do
		Wait(10000)
	end
	
	players[src] = true

	-- TODO: find a better solution
	if serviceStarted == false then
		SetPlayerCullingRadius(src, 999999999.0)
	end
end)
RegisterNetEvent("playerJoining")
AddEventHandler("playerJoining", function(oldId)
	local src = source
	while GetPlayerPed(src) == 0 do Wait(0) end

	-- TODO: Find better solution to wait the player to be spawned
	Wait(10000)
	while IsEntityVisible(GetPlayerPed(src)) == false do
		Wait(10000)
	end
	
	players[src] = true

	-- TODO: find a better solution
	if serviceStarted == false then
		SetPlayerCullingRadius(src, 999999999.0)
	end
end)

AddEventHandler('playerDropped', function (reason)
	local src = source
	print("Dropped " .. src)
	if players[src] ~= nil and players[src] ~= false then
		print("Player " .. src .. " had " .. #players[src] .. " peds")
	end

	local busInfo = players[src]
	players[src] = nil
	if GetPlayerNum() == 0 then --GetNumPlayerIndices()
		print("No clients connected. Cleaning up.")
		CleanUp()
	else
		-- restore the service of the dropped player
		local player = GetFirstFreePlayer()
		if player ~= nil then
			SetPlayerCullingRadius(player, 999999999.0)
			for k,v in pairs(busInfo) do
				TriggerClientEvent("publictransport:restoreService", player, v)
			end
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	CleanUp()
	-- TODO: Reset SetPlayerCullingRadius ??
end)

RegisterNetEvent("publictransport:updateService")
AddEventHandler("publictransport:updateService", function(pedId, nextStop)
	local src = source
	if players[src] == nil then print("ERROR TABLE EMPTY") end

	for k,v in pairs(players[src]) do
		if v.pedId == pedId then
			v.nextStop = nextStop
		end
	end
end)

function CleanUp()
	for _, entity in ipairs(entitiesList) do
		if DoesEntityExist(entity) then
			DeleteEntity(entity)
		end
	end
	currentClient = nil
	serviceStarted = false
	entitiesList = {}
	blipsInfo = {}
	players = {}
end

function StartService()
	for i, route in ipairs(Config.Routes) do
		Citizen.CreateThread(function()
			local numOfBus = 0
			while numOfBus < route.info.busNum do
				local position = route[1].spawn
				local heading = route[1].sheading
				local blipColor = route.info.color
				local hash = route.info.hash
				
				local vehicle = CreateVehicle(GetHashKey(hash), position, heading, true, true)
				local ped = CreatePedInsideVehicle(vehicle, 0, GetHashKey("ig_prolsec_02"), -1, true, false)

				while not DoesEntityExist(vehicle) or not DoesEntityExist(ped) do
					Wait(100)
				end

				local pedOwner = NetworkGetEntityOwner(ped)
				
				if players[pedOwner] == nil then
					print("ERROR PLAYER NILL")
				end
				if players[pedOwner] == true then
					players[pedOwner] = {}
				end
				table.insert(players[pedOwner], {pedNetId = NetworkGetNetworkIdFromEntity(ped), routeNumebr = i, busNumebr = numOfBus, nextStop = -1})

				-- Solve the problem of out of scope management of entities
				SetEntityDistanceCullingRadius(vehicle, 999999999.0)
				SetEntityDistanceCullingRadius(ped, 999999999.0)
				-- Added to table for cleanUp()
				table.insert(entitiesList, ped)
				table.insert(entitiesList, vehicle)

				local clientInfoPed = {
					routeNumber = i,
					routeBusNumber = numOfBus,
					pedNetId = NetworkGetNetworkIdFromEntity(ped),
					nextStop = 2
				}
				
				TriggerClientEvent("publictransport:setUpClient", pedOwner, clientInfoPed)

				local blipsInfo = {busNetId = NetworkGetNetworkIdFromEntity(vehicle), color = blipColor}
				TriggerClientEvent("publictransport:registerBusBlip", -1, blipsInfo)
				table.insert(blips, blipsInfo)

				numOfBus = numOfBus + 1
				if route.info.busNum > 1 then
					Wait(route.info.timeBetweenBus*1000)
				end
			end
		end)
	end
end

function GetPlayerNum()
	local cont = 0
	for k,v in pairs(players) do
		cont = cont + 1
	end
	return cont
end

function GetFirstFreePlayer()
	for k, v in pairs(players) do
		if v == true then
			return k
		end
	end
	return nil
end