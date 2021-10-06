-- for debug
state = {'Driving to bus stop', 'Parking', 'Waiting'}

Citizen.CreateThread(function()
	for _, route in ipairs(Config.Routes) do
		for _, curr in ipairs(route) do
			if curr.stop == true then  
				local blip = AddBlipForCoord(curr.pos)

				SetBlipSprite (blip, 513)
				SetBlipColour (blip, route.info.color)
				SetBlipScale(blip, 0.5)
				SetBlipAsShortRange(blip, true)
			
				BeginTextCommandSetBlipName('STRING')
				AddTextComponentSubstringPlayerName("".. route.info.name)
				EndTextCommandSetBlipName(blip)
			end
		end
	end
end)

RegisterNetEvent("publictransport:setUpClient")
AddEventHandler("publictransport:setUpClient", function(info)
	ManageService(info)
end)

RegisterNetEvent("publictransport:restoreService")
AddEventHandler("publictransport:restoreService", function(info)
	ManageService(info)
end)

function ManageService(info)
	while not NetworkDoesEntityExistWithNetworkId(info.pedNetId) do
		Wait(10)
	end

	local busDriver = NetToPed(info.pedNetId)
	local bus = GetVehiclePedIsIn(busDriver, false)
	while bus == 0 do
		Wait(10)
		bus = GetVehiclePedIsIn(busDriver, false)
	end

	if bus == 0 or not IsVehicleDriveable(bus, false) then
		print("SOMETHING IS WRONG WITH BUS ", info.routeNumber, info.routeBusNumber)
	end

	SetEntityAsMissionEntity(busDriver, true, true)
	SetEntityAsMissionEntity(bus, true, true)
	SetEntityCanBeDamaged(bus, false)
	SetVehicleDamageModifier(bus, 0.0)
	SetVehicleEngineCanDegrade(bus, false)

	SetEntityCanBeDamaged(busDriver, false)
	SetPedCanBeTargetted(busDriver, false)
	
	SetDriverAbility(busDriver, 0.8)
	SetBlockingOfNonTemporaryEvents(busDriver, true)
	SetPedConfigFlag(busDriver, 251, true)
	SetPedConfigFlag(busDriver, 64, true) -- CPED_CONFIG_FLAG_AttachedToVehicle 
	SetPedStayInVehicleWhenJacked(busDriver, true)

	local path = {}
	local firstStop = info.nextStop
	for i=firstStop, #Config.Routes[info.routeNumber], 1 do
		local curr = Config.Routes[info.routeNumber][i]
		table.insert(path, {pos = curr.pos, heading = curr.heading, stop = curr.stop})
	end
	for i=(firstStop-1), 1, -1 do
		local curr = Config.Routes[info.routeNumber][i]
		table.insert(path, {pos = curr.pos, heading = curr.heading, stop = curr.stop})
	end

	local task = OpenSequenceTask()
	for i=1, #path do
		TaskVehicleDriveToCoordLongrange(0, bus, path[i].pos, 50.0, 537395639, 40.0) -- speed 20.0
		
		if path[i].stop == true then
			TaskVehicleDriveToCoordLongrange(0, bus, path[i].pos, 9.0, 60, 6.0)
			TaskPause(0, Config.WaitTimeAtBusStop*1000)
		elseif path[i].stop == false then
			TaskVehicleDriveToCoordLongrange(0, bus, path[i].pos, 50.0, 537395639, 15.0)
			TaskPause(0, 1)
		end
	end
	SetSequenceToRepeat(task, true)
	CloseSequenceTask(task)
	TaskPerformSequence(busDriver, task)

	while GetSequenceProgress(busDriver) == -1 do Wait(0) end

	local oldStatus = -1
	local nextStop = 1
	while true do
		local status = (GetSequenceProgress(busDriver)%3) + 1
		
		if oldStatus ~= status then
			if status == 2 and Config.Routes[info.routeNumber][nextStop].stop == true then -- Vehicle parking
				Citizen.CreateThread(function()
					Wait(Config.WaitTimeAtBusStop*1000 * 1.5)
					local st = (GetSequenceProgress(busDriver)%3) + 1
					if st == 2 then -- Task stucked
						SetVehicleOnGroundProperly(bus)
						--print("GO TO NEXT PROGRESS", "sequence: ", GetSequenceProgress(busDriver))
						local sequence = GetSequenceProgress(busDriver)
						ClearPedTasks(busDriver)
						TaskPerformSequenceFromProgress(busDriver, task, sequence+2, sequence+3)
					end
				end)
			elseif status == 1 then
				nextStop = (nextStop%#Config.Routes[info.routeNumber]) + 1
				TriggerServerEvent("publictransport:updateService", info.pedNetId, nextStop)
			end
			-- Debug print
			-- print(state[status])	
		end
		oldStatus = status
		Wait(1000)
	end
end

RegisterNetEvent("publictransport:registerBusBlip")
AddEventHandler("publictransport:registerBusBlip", function(info)
	--print("Ped exist on blip register", DoesEntityExist(NetworkGetEntityFromNetworkId(info.busNetId)))
	local busBlip = AddBlipForEntity(NetworkGetEntityFromNetworkId(info.busNetId))
	SetBlipSprite (1, 463)
	SetBlipColour (busBlip, info.color)
	SetBlipScale(busBlip, 0.5)
	SetBlipAsShortRange(busBlip, true)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName("Bus " .. info.color)
	EndTextCommandSetBlipName(busBlip)
end)

RegisterNetEvent("publictransport:updateBusBlips")
AddEventHandler("publictransport:updateBusBlips", function(blipsInfo)
	print("Updating " .. #blipsInfo .. " blips")
	for _, curr in pairs(blipsInfo) do
		local busBlip = AddBlipForEntity(NetworkGetEntityFromNetworkId(curr.busNetId))
		SetBlipSprite (1, 463)
		SetBlipColour (busBlip, curr.color)
		SetBlipScale(busBlip, 0.5)
		SetBlipAsShortRange(busBlip, true)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName("Bus " .. curr.color)
		EndTextCommandSetBlipName(busBlip)
	end
end)

-- PED s_m_m_gentransport

-- Add Markers to bus stops, tells you missing time to next bus


local doors = {
  {"seat_dside_f", -1},
  {"seat_pside_f", 0},
  {"seat_dside_r", 1},
  {"seat_pside_r", 2}
}

function VehicleInFront()
    local pos = GetEntityCoords(GetPlayerPed(-1))
    local entityWorld = GetOffsetFromEntityInWorldCoords(GetPlayerPed(-1), 0.0, 5.0, 0.0)
    local rayHandle = CastRayPointToPoint(pos.x, pos.y, pos.z, entityWorld.x, entityWorld.y, entityWorld.z, 10, GetPlayerPed(-1), 0)
    local _, _, _, _, result = GetRaycastResult(rayHandle)
    return result
end

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    DisablePlayerVehicleRewards(PlayerId())
    if IsControlJustReleased(0, 23) and running ~= true and GetVehiclePedIsIn(GetPlayerPed(-1), false) == 0 then
      local vehicle = VehicleInFront()
      running = true
      if vehicle ~= nil then
        local plyCoords = GetEntityCoords(GetPlayerPed(-1), false)
        local doorDistances = {}
        for k, door in pairs(doors) do
          local doorBone = GetEntityBoneIndexByName(vehicle, door[1])
          local doorPos = GetWorldPositionOfEntityBone(vehicle, doorBone)
          local distance = Vdist(plyCoords.x, plyCoords.y, plyCoords.z, doorPos.x, doorPos.y, doorPos.z)
          table.insert(doorDistances, distance)
        end
        local key, min = 1, doorDistances[1]
        for k, v in ipairs(doorDistances) do
          if doorDistances[k] < min then
            key, min = k, v
          end
        end
        TaskEnterVehicle(GetPlayerPed(-1), vehicle, -1, doors[key][2], 1.0, 1, 0)
      end
      running = false
    end
  end
end)
