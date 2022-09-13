local ownership = {}
local blips = {}
-- TODO: change to true before release
local firstSpawn = false

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
function DoDriverJob(ped, vehicle, routeId, busStop)
	while not ownership[VehToNet(vehicle)] do 
		local routeInfo = Config.Routes[routeId].busStops[busStop]
		local coords = routeInfo.pos
		ClearPedTasks(ped)
		ForceEntityAiAndAnimationUpdate(ped)
		
		repeat 
			if ownership[VehToNet(vehicle)] then return end
			SetVehicleOnGroundProperly(vehicle, 5.0)
			TaskVehicleDriveToCoordLongrange(ped, vehicle, coords, Config.Speed*1.0, Config.DriveStyle, 18.0)
			DoStuckCheck(vehicle)
			Wait(1500)
		until GetScriptTaskStatus(ped, 567490903) > 1 or GetEntitySpeed(vehicle) > 1.0
		while GetScriptTaskStatus(ped, 567490903) ~= 7 do
			if ownership[VehToNet(vehicle)] then return end		
			DoStuckCheck(vehicle)
			Wait(100)
		end
		if routeInfo.stop == true then
			LoadCollision(ped, vehicle)
			TaskVehiclePark(ped, vehicle, coords, GetEntityHeading(vehicle), 1, 20.0, true)
			local timer = GetGameTimer()
			local exit = true
			while GetScriptTaskStatus(ped, -272084098) ~= 7 and exit do
				if ownership[VehToNet(vehicle)] then return end
				if GetGameTimer() - timer > 10000 then
					exit = false
					ClearPedTasks(ped)
				end
				Wait(100)
			end		
			Wait(Config.WaitTimeAtBusStop*1000)
		end
		if ownership[VehToNet(vehicle)] then return end
		busStop = ((busStop+1) > #Config.Routes[routeId].busStops) and 1 or (busStop+1)
		TriggerServerEvent("publictransport:updateNextStop", VehToNet(vehicle), busStop)
	end
end

function StartOwnershipCheck(vehicleNetId)
	ownership[vehicleNetId] = false
	local lastKnownPosition = GetEntityCoords(NetToVeh(vehicleNetId))
	Citizen.CreateThread(function()
		while true do
			lastKnownPosition = GetEntityCoords(NetToVeh(vehicleNetId))
			if not NetworkHasControlOfNetworkId(vehicleNetId) then
				ownership[vehicleNetId] = true
				print("Lost control of vehicle")
				TriggerServerEvent("publictransport:ownerChanged", vehicleNetId, lastKnownPosition)
				return
			end
		end
		Wait(0)
	end)
end

function SetupPedAndVehicle(ped, vehicle, position)
	if position ~= nil then
		SetEntityCoords(vehicle, position)
		-- TODO: test
		local ret, nodePos = GetPointOnRoadSide(position.x, position.y, position.z, 1) -- used also 0 and -1
		local ret, outPos, heading = GetClosestVehicleNodeWithHeading(nodePos, 1, 3.0, 0)
		SetEntityHeading(vehicle, heading)
	end
	SetEntityCanBeDamaged(vehicle, false)
	SetVehicleDamageModifier(vehicle, 0.0)
	SetVehicleEngineCanDegrade(vehicle, false)
	SetVehicleEngineOn(vehicle, true, true, false)
	SetVehicleLights(vehicle, 0)
	-- Not sure but this should make the driver able to set vehicle on wheels again (like players can do when vehicle goes upside down)
	if not DoesVehicleHaveStuckVehicleCheck(vehicle) then
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

-- Check if vehicle is stuck while driving, if so tp it to the closest road
function DoStuckCheck(vehicle)
	if IsVehicleStuckTimerUp(vehicle, 0, 7000) or IsVehicleStuckTimerUp(vehicle, 1, 7000) or IsVehicleStuckTimerUp(vehicle, 2, 7000) or IsVehicleStuckTimerUp(vehicle, 2, 7000) then
		SetEntityCollision(vehicle, false, true)
		local vehPos = GetEntityCoords(vehicle)
		--local ret, pos = GetClosestRoad(vehPos.x, vehPos.y, vehPos.z, 1.0, 1, false)
		local ret, pos = GetPointOnRoadSide(vehPos.x, vehPos.y, vehPos.z, 1) -- used also 0 and -1
		if ret then
			SetEntityCoords(vehicle, pos)
			vehPos = GetEntityCoords(vehicle)
			local ret2, pos2, heading = GetClosestVehicleNodeWithHeading(vehPos.x, vehPos.y, vehPos.z, 1, 3.0, 0)
			if ret2 then
				SetEntityHeading(vehicle, heading)
				SetEntityCollision(vehicle, true, true)
			end
		end
	end
end

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
	for i,v in ipairs(blips) do
		RemoveBlip(v)
	end
	blips = {}
	ownership = {}
end

-- =========================
-- 			EVENTS
-- =========================
RegisterNetEvent("publictransport:restoreRoute")
AddEventHandler("publictransport:restoreRoute", function(vehicleNetId, routeId, nextStop, position)
	local ped = GetPedInVehicleSeat(NetToVeh(vehicleNetId), -1)
	local vehicle = NetToVeh(vehicleNetId)
	local pedNetId = PedToNet(ped)
	DoRequestNetControl(pedNetId)
	DoRequestNetControl(vehicleNetId)
	StartOwnershipCheck(vehicleNetId)
	if DoesEntityExist(ped) and DoesEntityExist(vehicle) then
		LoadCollision(ped, vehicle)
		SetVehicleOnGroundProperly(vehicle, 5.0)
		ClearPedTasks(ped)
		SetupPedAndVehicle(ped, vehicle, position)
		TriggerEvent("publictransport:addBlipForVehicle", vehicleNetId, Config.Routes[routeId].info.color)
		DoDriverJob(ped, vehicle, routeId, nextStop)
	else
		print("ERROR: Vehicle or ped does not exist")
	end
end)

RegisterNetEvent("publictransport:addBlipForVehicle")
AddEventHandler("publictransport:addBlipForVehicle", function(vehicleNetId, color)
	if firstSpawn then return end
	if blips[vehicleNetId] ~= nil then
		RemoveBlip(blips[vehicleNetId])
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
	blips[vehicleNetId] = blip
end)

RegisterNetEvent("publictransport:addBlipForCoords")
AddEventHandler("publictransport:addBlipForCoords", function(position, vehicleNetId, color)
	if firstSpawn then return end
	if blips[vehicleNetId] ~= nil then
		RemoveBlip(blips[vehicleNetId])
	end
	local blip = AddBlipForCoord(position)
	SetBlipSprite(1, 463)
	SetBlipColour(blip, color)
	SetBlipScale(blip, 0.5)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName("Bus " .. color)
	EndTextCommandSetBlipName(blip)
	blips[vehicleNetId] = blip
	
	if #(GetEntityCoords(PlayerPedId()) - position) < 350.0 then -- the culling range is 424 units
		print("Player close enough")
		--TriggerServerEvent("publictransport:playerNearVehicle", vehicleNetId, position)
	end
	
end)

RegisterNetEvent("publictransport:forceSetAllVehicleBlips")
AddEventHandler("publictransport:forceSetAllVehicleBlips", function(vehiclesList)
	for id, playerData in pairs(vehiclesList) do
		for i,data in ipairs(playerData) do
			while not NetworkDoesNetworkIdExist(data.vehicleNetId) do Wait(0) end
			local vehicle = NetToVeh(data.vehicleNetId)
			if DoesEntityExist(vehicle) then
				local blip = AddBlipForEntity(vehicle)
				SetBlipSprite(1, 463)
				SetBlipColour(blip, data.color)
				SetBlipScale(blip, 0.5)
				SetBlipAsShortRange(blip, true)
				BeginTextCommandSetBlipName('STRING')
				AddTextComponentSubstringPlayerName("Bus " .. data.color)
				EndTextCommandSetBlipName(blip)
			end
		end
	end
end)

AddEventHandler("playerSpawned", function(spawnInfo)
	if firstSpawn then
		TriggerServerEvent("publictransport:onPlayerSpawn")
		firstSpawn = false
	end
end)

AddEventHandler("onResourceStop", function(resName)
	if GetCurrentResourceName() == resName then
		CleanUp()
	end
end)