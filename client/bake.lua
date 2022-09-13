--[[
Consider the roads system as a graph, so we have G=(V,E) where V are the nodes (saved in bake_data/vehicle_nodes.json)
and E are the edges (saved in bake_data/nodeLinks.json). Specifically G is an undirected, unwieghted graph.
Now, the ideal solution would be using Dijkstra's algorithm to find the shortest path between two nodes, but
I didn't managed to make it work, so instead I used a naive approach that works well enough.
This approach uses the CalculateRouteBetweenTwoPoints native, so the problem is reduced to finding the closest
node, in the adjacency list of the current node, to the destination node. 
Now, iterating this alogrithm until we are close enough to the destination node, we will end up with a path.
This path will be saved in a file and the server will use it to simulate the vehicle movement when no players
are in the vehicle scope.
]]

local vehicleNodes
local nodeLinks
-- HOW TO USE: /bake routeId where routeId is the id of the route in the Config.Routes table
RegisterCommand("bake", function(source, args)
	if #args ~= 1 then
		print("Error: you need to specify the route id")
		return
	end
	local routeId = tonumber(args[1])
	if routeId > #Config.Routes then
		print("Error: route id is too big")
		return
	end
	vehicleNodes = json.decode(LoadResourceFile(GetCurrentResourceName(), "bake_data/vehicle_nodes.json"))
	nodeLinks = json.decode(LoadResourceFile(GetCurrentResourceName(), "bake_data/node_links.json"))
	
	-- Load the nodes from all the map (used for the CalculateTravelDistanceBetweenPoints native)
	while not AreNodesLoadedForArea(-8192.0, -8192.0, 8192.0, 8192.0) do 
		RequestPathsPreferAccurateBoundingstruct(-8192.0, -8192.0, 8192.0, 8192.0)
		Wait(0) 
	end
	print("Nodes loaded")
	local i = 2
	local currRoute = Config.Routes[routeId]
	local path = {}
	print("STARTING BAKE")
	while i <= #currRoute.busStops do
		table.insert(path, CalculateRouteBetweenTwoPoints(currRoute.busStops[i-1].pos, currRoute.busStops[i].pos))
		print("PROGRESS: " .. (i-1) .. "/" .. #currRoute.busStops)
		i = i + 1
	end
	-- Process the path from last busStop to the first one, since we started from the second one
	print("PROGRESS: " .. (i-1) .. "/" .. #currRoute.busStops)
	table.insert(path, CalculateRouteBetweenTwoPoints(currRoute.busStops[i-1].pos, currRoute.busStops[1].pos))
	print("DONE BAKING")
	-- At this point in 'path' you have all the nodes that the bus will follow, divided by bus stops
	TriggerServerEvent("spaw_test:saveRouteToFile", routeId, path)
	if Config.BakeDebug then
		local blips = {}
		for _, nodes in pairs(path) do
			for _, node in pairs(nodes) do
				table.insert(blips, AddBlipForCoord(node.x, node.y, node.z))
			end
		end
		Wait(5000)
		for _, blip in ipairs(blips) do
			RemoveBlip(blip)
		end
	end
end)

-- Given a start and end position, it will return a table of nodes that build the path distantiated by the step
function CalculateRouteBetweenTwoPoints(startPos, endPos)
	local path = {}
	local step = Config.BakeStepUnits
	local node = CustomGetClosestVehicleNode(startPos)
	local prevNode = node
	table.insert(path, vector3(node.x, node.y, node.z))
	
	while CalculateTravelDistanceBetweenPoints(node.x, node.y, node.z, endPos) > 20.0 do
		local minJ = -1
		-- If the node has more than one node in his adjacency, search the one that minimize the distance to the destination
		for j=1, #nodeLinks[node.id] do
			local curr = vehicleNodes[nodeLinks[node.id][j]]
			if curr.id ~= prevNode.id and CalculateTravelDistanceBetweenPoints(curr.x, curr.y, curr.z, endPos) < CalculateTravelDistanceBetweenPoints(node.x, node.y, node.z, endPos) then
				minJ = j
			end
		end
		-- In some case no minJ is found (the cause seems to be CalculateTravelDistanceBetweenPoints, since for two different nodes returns the same distance)
		if minJ == -1 then
			-- If the node i'm currently at has only 2 adjacent nodes, the next node is the one that is not the previous
			if #nodeLinks[node.id] == 2 then
				if prevNode.id == nodeLinks[node.id][1] then
					minJ = 2
				else
					minJ = 1	
				end
			-- If the node has more than 2 adjacent nodes, a random node is choosen, hoping that after few iterations the right one is picked
			-- Not the best solution for sure
			else 
				minJ = math.random(#nodeLinks[node.id])
			end
		end
		prevNode = node
		node = vehicleNodes[nodeLinks[node.id][minJ]]

		-- By doing this the path will have fewer equidisantiated nodes
		step = step - #(vector3(node.x, node.y, node.z) - vector3(path[#path].x, path[#path].y, path[#path].z))
		if step <= 0 then
			table.insert(path, vector3(node.x, node.y, node.z))
			step = Config.BakeStepUnits
		end		
	end
	return path
end

-- Custom implementation of GetClosestVehicleNode, since the original one would require additional data
-- to find the id of the found node (note: GetNthClosestVehicleNodeId won't return the expected id)
function CustomGetClosestVehicleNode(position)
	local closestNode = nil
	for i=1, #vehicleNodes do
		local currNode = vehicleNodes[i]
		local currNodePos = vector3(currNode.x, currNode.y, currNode.z)
		if closestNode == nil then
			closestNode = currNode
		else
			local closestNodePos = vector3(closestNode.x, closestNode.y, closestNode.z)
			if #(position - currNodePos) < #(position - closestNodePos) then
				closestNode = currNode
			end
		end
	end
	return closestNode
end