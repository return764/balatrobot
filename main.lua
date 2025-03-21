--- STEAMODDED HEADER
--- MOD_NAME: Balatrobot
--- MOD_ID: Balatrobot-v0.3
--- MOD_AUTHOR: [Besteon]
--- MOD_DESCRIPTION: A botting API for Balatro

function SMODS.INIT.BALATROBOT()
	mw = SMODS.findModByID("Balatrobot-v0.3")

	-- Load the mod configuration
	assert(load(NFS.read(mw.path .. "config.lua")))()
	if not BALATRO_BOT_CONFIG.enabled then
		return
	end

	-- External libraries
	assert(load(NFS.read(mw.path .. "lib/list.lua")))()
	assert(load(NFS.read(mw.path .. "lib/hook.lua")))()
	assert(load(NFS.read(mw.path .. "lib/bitser.lua")))()
	assert(load(NFS.read(mw.path .. "lib/sock.lua")))()
	assert(load(NFS.read(mw.path .. "lib/json.lua")))()

	-- Mod specific files
	assert(load(NFS.read(mw.path .. "lib/utils.lua")))()
	assert(load(NFS.read(mw.path .. "lib/middleware.lua")))()
	assert(load(NFS.read(mw.path .. "lib/api.lua")))()

	sendDebugMessage("Balatrobot v0.3 loaded")

	Middleware.hookbalatro()
	BalatrobotAPI.init()
end
