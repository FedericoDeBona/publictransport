local blips = {}

-- Create the bus stop blips
Citizen.CreateThread(function()
	-- todo:remove
	DisableIdleCamera(true)
	
	for _, route in ipairs(Config.Routes) do
		for _, curr in ipairs(route.busStops) do
			if curr.stop == true then 
				local blip = AddBlipForCoord(curr.pos)
				SetBlipSprite (blip, 513)
				SetBlipColour (blip, route.info.color)
				SetBlipScale(blip, 0.5)
				SetBlipAsShortRange(blip, true)
				BeginTextCommandSetBlipName('STRING')
				AddTextComponentSubstringPlayerName("Bus stop")
				EndTextCommandSetBlipName(blip)
			end
		end
	end
end)

-- ===========================
-- 			FUNCTIONS
-- ===========================
-- This function is called when the client has the control of the bus, thus it will make the bus moving
-- as long as the bus exists on the clint
function DoDriverJob(routeId, busNum, ped, vehicle, busStop)
	local lastKnownPosition = GetEntityCoords(vehicle)
	while CanGoOn(vehicle) do
		local routeInfo = Config.Routes[routeId].busStops[busStop]
		local coords = routeInfo.pos		
		-- Starting the bus. In a loop since sometimes the bus doesn't start
		repeat 
			SetVehicleOnGroundProperly(vehicle, 5.0)
			ClearPedTasks(ped)
			TaskVehicleDriveToCoord(ped, vehicle, coords.x, coords.y, coords.z, 70.0, 0, GetEntityModel(vehicle), Config.DriveStyle, 1.0, false) -- last bool looks like avoidHighway
			
			--TaskVehicleDriveToCoordLongrange(ped, vehicle, coords, speed, Config.DriveStyle, 18.0)
			DoStuckCheck(vehicle)
			Wait(500)
		until not CanGoOn(vehicle) or GetScriptTaskStatus(ped, 0x93A5526E) > 1 or GetEntitySpeed(vehicle) > 1.0
			--until not CanGoOn(vehicle) or GetScriptTaskStatus(ped, 567490903) > 1 or GetEntitySpeed(vehicle) > 1.0
		-- The bus started, now it's driving to the coords
		while CanGoOn(vehicle) and GetScriptTaskStatus(ped, 0x93A5526E) ~= 7 and math.abs(Vdist2(GetEntityCoords(vehicle), coords)) > 6400.0 do 
			lastKnownPosition = GetEntityCoords(vehicle)
			DoStuckCheck(vehicle)
			Wait(500)
		end
		-- The bus is near the bus stop, now it tries to park
		if CanGoOn(vehicle) and routeInfo.stop == true then
			TaskVehiclePark(ped, vehicle, coords, GetEntityHeading(vehicle), 3, 30.0, true)
			local timer = GetGameTimer()
			local exit = true
			-- If there are problems parking, the task get cleared
			while CanGoOn(vehicle) and GetScriptTaskStatus(ped, -272084098) ~= 7 and exit do
				lastKnownPosition = GetEntityCoords(vehicle)
				if GetGameTimer() - timer > 4000 then
					exit = false
					ClearPedTasks(ped)
				end
				Wait(500)
			end
			-- Waiting at the bus stop
			Wait(Config.WaitTimeAtBusStop*1000)
		end
		-- Before starting the next loop, the bus stop is incremented and it's updated on the server
		if CanGoOn(vehicle) then
			busStop = ((busStop+1) > #Config.Routes[routeId].busStops) and 1 or (busStop+1)
			TriggerServerEvent("publictransport:updateNextStop", routeId, busNum, busStop)
		end
	end
	-- If we are here the bus doesn't exist on this client, and the server gets notified about it
	TriggerServerEvent("publictransport:ownerChanged", routeId, busNum, lastKnownPosition)
end

-- Function to check if the bus exists on the client and the client has the control of it
function CanGoOn(vehicle)
	return DoesEntityExist(vehicle) and NetworkHasControlOfNetworkId(VehToNet(vehicle))
end

-- Function will make the vehicle indestructible, the ped invicible and not carjackable
function SetupPedAndVehicle(ped, vehicle, position)
	SetEntityCanBeDamaged(vehicle, false)
	SetVehicleDamageModifier(vehicle, 0.0)
	SetVehicleEngineCanDegrade(vehicle, false)
	SetVehicleEngineOn(vehicle, true, true, false)
	SetVehicleLights(vehicle, 0)
	-- Not sure but this should make the driver able to set vehicle on wheels again (like players can do when vehicle goes upside down)
	if not DoesVehicleHaveStuckVehicleCheck(vehicle) then -- From doc: Maximum amount of vehicles with vehicle stuck check appears to be 16.  
		AddVehicleStuckCheckWithWarp(vehicle, 10.0, 1000, false, false, false, -1)
	end
	SetEntityCanBeDamaged(ped, false)
	SetPedCanBeTargetted(ped, false)
	SetDriverAbility(ped, 1.0)
	SetDriverAggressiveness(ped, 0.0)
	SetBlockingOfNonTemporaryEvents(ped, true)
	SetPedConfigFlag(ped, 251, true)
	SetPedConfigFlag(ped, 64, true)
	SetPedStayInVehicleWhenJacked(ped, true)
	SetPedCanBeDraggedOut(ped, false)
	SetEntityCleanupByEngine(ped, false)
	SetEntityCleanupByEngine(vehicle, false)
	SetPedComponentVariation(ped, 3, 1, 2, 0)
	SetPedComponentVariation(ped, 4, 0, 2, 0)
end

-- Check if vehicle is stuck while driving, if it is, teleport it to the closest road
function DoStuckCheck(vehicle)
	if IsVehicleStuckTimerUp(vehicle, 0, 4000) or IsVehicleStuckTimerUp(vehicle, 1, 4000) or IsVehicleStuckTimerUp(vehicle, 2, 4000) or IsVehicleStuckTimerUp(vehicle, 3, 4000) then
		SetEntityCollision(vehicle, false, true)
		local vehPos = GetEntityCoords(vehicle)
		local ret, outPos = GetPointOnRoadSide(vehPos.x, vehPos.y, vehPos.z, -1)
		local ret, pos, heading = GetClosestVehicleNodeWithHeading(outPos.x, outPos.y, outPos.z, 1, 3.0, 0)
		if ret then
			SetEntityCoords(vehicle, pos)
			SetEntityHeading(vehicle, heading)
			SetEntityCollision(vehicle, true, true)
			SetVehicleOnGroundProperly(vehicle, 5.0)
		end
	end
end

-- Function to load collision around the bus and ped
function LoadCollision(ped, vehicle)
	SetEntityLoadCollisionFlag(ped, true, 1)
	SetEntityLoadCollisionFlag(vehicle, true, 1)
	while not HasCollisionLoadedAroundEntity(vehicle) or not HasCollisionLoadedAroundEntity(ped) do Wait(0) end
end

function DoRequestNetControl(netId)
	if NetworkDoesNetworkIdExist(netId) then
		while not NetworkHasControlOfNetworkId(netId) do 
			NetworkRequestControlOfNetworkId(netId)
			Wait(0)
		end
	end
end

function CleanUp()
	for routeId, bs in ipairs(blips) do
		for busNum, blip in ipairs(bs) do
			RemoveBlip(blip)
		end
	end
	blips = {}
end

-- =========================
-- 			EVENTS
-- =========================
RegisterNetEvent("publictransport:restoreRoute")
AddEventHandler("publictransport:restoreRoute", function(routeId, busNum, vehicleNetId, nextStop, position)
	while not NetworkDoesNetworkIdExist(vehicleNetId) do Wait(0) end
	local vehicle = NetToVeh(vehicleNetId)
	if not DoesEntityExist(vehicle) then
		print("On restoureRoute vehicle does not exist")
		return
	end
	local ped = GetPedInVehicleSeat(vehicle, -1)
	local pedNetId = PedToNet(ped)
	DoRequestNetControl(pedNetId)
	DoRequestNetControl(vehicleNetId)
	if DoesEntityExist(ped) and DoesEntityExist(vehicle) then
		LoadCollision(ped, vehicle)
		SetVehicleOnGroundProperly(vehicle, 5.0)
		ClearPedTasks(ped)
		SetupPedAndVehicle(ped, vehicle, position)
		--TriggerEvent("publictransport:addBlipForVehicle", routeId, busNum, vehicleNetId, Config.Routes[routeId].info.color)
		TriggerServerEvent("publictransport:addBlipsForEveryone", routeId, busNum, vehicleNetId)
		DoDriverJob(routeId, busNum, ped, vehicle, nextStop)
	else
		print("ERROR: Vehicle or ped does not exist")
	end
end)

RegisterNetEvent("publictransport:addBlipForVehicle")
AddEventHandler("publictransport:addBlipForVehicle", function(routeId, busNum, vehicleNetId, color)
	if blips[routeId] == nil then blips[routeId] = {} end
	if blips[routeId][busNum] ~= nil then
		RemoveBlip(blips[routeId][busNum])
	end
	while not NetworkDoesNetworkIdExist(vehicleNetId) do Wait(0) end
	local vehicle = NetToVeh(vehicleNetId)
	local blip = AddBlipForEntity(vehicle)
	SetBlipSprite(1, 463)
	SetBlipColour(blip, color)
	SetBlipScale(blip, 0.5)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName("Bus " .. color)
	EndTextCommandSetBlipName(blip)
	blips[routeId][busNum] = blip
end)

RegisterNetEvent("publictransport:addBlipForCoords")
AddEventHandler("publictransport:addBlipForCoords", function(routeId, busNum, position, nextNodePosition, color, checkForDistance)
	if NetworkGetEntityOwner()
	if blips[routeId] == nil then blips[routeId] = {} end
	if not DoesBlipExist(blips[routeId][busNum]) then	
		local blip = AddBlipForCoord(position)
		SetBlipSprite(1, 463)
		SetBlipColour(blip, color)
		SetBlipScale(blip, 0.5)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName("Bus " .. color)
		EndTextCommandSetBlipName(blip)
		blips[routeId][busNum] = blip
	else
		SetBlipCoords(blips[routeId][busNum], position.x, position.y, position.z)
	end
	if checkForDistance and #(GetEntityCoords(PlayerPedId()) - position) < 350.0 then -- the default culling range is 424 units
		local ret, outPos, heading = GetNthClosestVehicleNodeFavourDirection(position.x, position.y, position.z, nextNodePosition.x, nextNodePosition.y, nextNodePosition.z, 1, 1, 3.0, 0)
		if ret then
			TriggerServerEvent("publictransport:playerNearVehicle", routeId, busNum, outPos, heading)
		else
			print("ERROR: Could not get closest node")
		end
	end
end)

AddEventHandler("onResourceStop", function(resName)
	if GetCurrentResourceName() == resName then
		CleanUp()
	end
end)

-- todo:remove
RegisterCommand("draw", function()
	local targetCoords = vector3(2907.32, 4153.93, 50.39)
	local ret, pos = GetPointOnRoadSide(targetCoords.x, targetCoords.y, targetCoords.z, 1) -- 0 left side, 1 right side, -1 random
	local ret, outPos, heading = GetClosestVehicleNodeWithHeading(pos.x, pos.y, pos.z, 1, 0.0, 3.0)
	SetEntityHeading(PlayerPedId(), heading)
	while true do
		DrawSphere(pos, 1.0, 255.0, 0.0, 0.0, 1.0)
		Wait(0)
	end
end)

-- Todo:remove
RegisterCommand("stop", function()
	SetEntityCoords(PlayerPedId(), vector3(2907.32, 4153.93, 50.39))
end)
