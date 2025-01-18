fx_version "cerulean"
game "gta5"

-- [ Description ] --

author "L'kid Workshop"
description "Towing script by bone attachment"
version "1.0"

-- [ Scripts ] --

shared_scripts {
	"shared/config.lua",
}
client_scripts {
	"client/client.lua",
}

-- [ Escrow ] --

escrow_ignore {
    "shared/config.lua"
}
lua54 "yes"
dependency '/assetpacks'