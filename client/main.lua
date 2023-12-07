local blips = {}

-- Create the bus stop blips
Citizen.CreateThread(function()
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
			--ClearPedSecondaryTask(ped)
			TaskVehicleDriveToCoordLongrange(ped, vehicle, coords, 70.0, Config.DriveStyle, 50.0)
			DoStuckCheck(vehicle)
			Wait(500)
		until not CanGoOn(vehicle) or GetScriptTaskStatus(ped, 567490903) > 1 or GetEntitySpeed(vehicle) > 1.0
		-- The bus started, now it's driving to the coords
		while CanGoOn(vehicle) and GetScriptTaskStatus(ped, 567490903) ~= 7 do
			lastKnownPosition = GetEntityCoords(vehicle)
			DoStuckCheck(vehicle)
			Wait(500)
		end
		-- The bus is near the bus stop, now it tries to park	
		if routeInfo.stop == true then
			TaskVehicleDriveToCoord(ped, vehicle, coords, 7.0, 0, GetEntityModel(vehicle), Config.DriveStyle, 1.0)
			local timer = GetGameTimer()
			while CanGoOn(vehicle) and not IsVehicleStopped(vehicle) and (GetGameTimer()-timer<4000) do
				Wait(100)
			end
			-- Waiting at the bus stop
			local timer = GetGameTimer()
			while CanGoOn(vehicle) and ((GetGameTimer()-timer)<(Config.WaitTimeAtBusStop*1000)) do
				Wait(100)
			end
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
	local ped = GetPedInVehicleSeat(vehicle, -1)
	return DoesEntityExist(vehicle) and NetworkHasControlOfNetworkId(VehToNet(vehicle)) and DoesEntityExist(ped) and NetworkHasControlOfNetworkId(PedToNet(ped))
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
	local ped = GetPedInVehicleSeat(vehicle, -1, true)
	
	local pedNetId = PedToNet(ped)
	DoRequestNetControl(pedNetId)
	DoRequestNetControl(vehicleNetId)
	if DoesEntityExist(ped) and DoesEntityExist(vehicle) then
		LoadCollision(ped, vehicle)
		SetVehicleOnGroundProperly(vehicle, 5.0)
		ClearPedTasks(ped)
		SetupPedAndVehicle(ped, vehicle, position)
		TriggerServerEvent("publictransport:addBlipsForEveryone", routeId, busNum, vehicleNetId, Config.Routes[routeId].info.color)
		DoDriverJob(routeId, busNum, ped, vehicle, nextStop)
	else
		print("ERROR: Vehicle or ped does not exist")
	end
end)

RegisterNetEvent("publictransport:addBlipForCoords")
AddEventHandler("publictransport:addBlipForCoords", function(routeId, busNum, position, nextNodePosition, color, checkForDistance)
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

AddEventHandler("onResourceStart", function(resName)
	if GetCurrentResourceName() == resName then
		while not HasModelLoaded(GetHashKey("s_m_m_gentransport")) do 
			RequestModel(GetHashKey("s_m_m_gentransport"))
			Wait(0)
		end
	end
end)