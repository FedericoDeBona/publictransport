fx_version 'cerulean'
game 'gta5'

name "publictransport"
description "Auto driven transports with in-game AI"
author "Scorpion01"
version "2.2"

client_scripts {
	'client/main.lua',
	'client/bake.lua',
	'config.lua'
}

server_scripts {
	'server/main.lua',
	'config.lua'
}

files {
	"bake_data/node_links.json",
	"bake_data/vehicle_nodes.json",
}
