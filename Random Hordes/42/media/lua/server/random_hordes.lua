local debug = getSandboxOptions():getOptionByName(
	"RandomHordes.ConsoleDebug"):getValue();

LuaEventManager.AddEvent("OnRandomHordeSurvived")

local tickBeforeNextZed = 10; -- Ticks to spawn a zed
local actualTick = 0;         -- Actual server tick used with tickBeforeNextZed

-- playerUsername => zombiesRemaining
local outgoingHordes = {};

-- table list of rare zombies to spawn
local rareZombiesList = {}

local rareZombiesListStr = getSandboxOptions():getOptionByName("RandomHordes.RareZombies"):getValue();
for item in rareZombiesListStr:gmatch("[^/]+") do
	table.insert(rareZombiesList, item);
end

local function SpawnZombieToPlayer(player)
	local square = player:getCurrentSquare();
	local zLocationX = 0;
	local zLocationY = 0;
	local canSpawn = true;
	local distance = getSandboxOptions():getOptionByName("RandomHordes.SpawnDistance"):getValue();

	-- Pickup spawn position
	for i = 0, 100 do
		canSpawn = true;
		if ZombRand(2) == 0 then
			zLocationX = ZombRand(10) - 10 + distance;
			zLocationY = ZombRand(distance * 2) - distance;
			if ZombRand(2) == 0 then
				zLocationX = 0 - zLocationX;
			end
		else
			zLocationY = ZombRand(10) - 10 + distance;
			zLocationX = ZombRand(distance * 2) - distance;
			if ZombRand(2) == 0 then
				zLocationY = 0 - zLocationY;
			end
		end
		zLocationX = zLocationX + square:getX();
		zLocationY = zLocationY + square:getY();

		local zombieSquare = getWorld():getCell():getGridSquare(zLocationX, zLocationY, 0);
		if canSpawn and not zombieSquare then
			if debug then
				DebugPrintRandomHorde(player:getUsername() ..
					" cannot spawn zombie in X:" .. zLocationX .. " Y: " .. zLocationY .. ", not a valid square");
			end
			canSpawn = false;
		end

		if canSpawn and SafeHouse.getSafeHouse(zombieSquare) then
			if debug then
				DebugPrintRandomHorde(player:getUsername() ..
					" cannot spawn zombie in X:" .. zLocationX .. " Y: " .. zLocationY .. ", is a safehouse");
			end
			canSpawn = false;
		end

		if canSpawn and not zombieSquare:isSafeToSpawn() then
			if debug then
				DebugPrintRandomHorde(player:getUsername() ..
					" cannot spawn zombie in X:" .. zLocationX .. " Y: " .. zLocationY .. ", is not safe to spawn");
			end
			canSpawn = false;
		end

		if canSpawn and not zombieSquare:isOutside() then
			if debug then
				DebugPrintRandomHorde(player:getUsername() ..
					" cannot spawn zombie in X:" .. zLocationX .. " Y: " .. zLocationY .. ", is not outside");
			end
			canSpawn = false;
		end

		if canSpawn then
			break;
		end
	end

	outgoingHordes[player:getUsername()] = outgoingHordes[player:getUsername()] - 1;

	if not canSpawn then
		if debug then
			DebugPrintRandomHorde(player:getUsername() .. " ZOMBIE NOT SPAWNED!");
		end
		return;
	end

	-- Rare Zombie Spawn
	if ZombRand(0, 1000) <= getSandboxOptions():getOptionByName("RandomHordes.RareZombiesChance"):getValue() then
		if debug then
			DebugPrintRandomHorde(player:getUsername() ..
				" RARE ZOMBIE SPAWNED! X: " .. zLocationX .. " Y: " .. zLocationY);
		end

		local outfit = rareZombiesList[ZombRand(0, #rareZombiesList) + 1];

		addZombiesInOutfit(zLocationX, zLocationY, 0, 1, outfit, 50, false, false, false, false, false, false, 1.0, false,
			0);
	else -- Normal Zombie SPawn
		if debug then
			DebugPrintRandomHorde(player:getUsername() .. " ZOMBIE SPAWNED! X: " .. zLocationX .. " Y: " .. zLocationY);
		end
		addZombiesInOutfit(zLocationX, zLocationY, 0, 1, nil, 50, false, false, false, false, false, false, 1.0, false,
			0);
	end

	addSound(player, player:getX(), player:getY(), player:getZ(), 200, 10);
end

local function CheckRandomHorde()
	local chance = ZombRand(0, 1000) + 1;

	if debug then
		DebugPrintRandomHorde("[CheckRandomHorde] " ..
			getSandboxOptions():getOptionByName("RandomHordes.Frequency"):getValue() .. " >= " .. chance);
	end

	if getSandboxOptions():getOptionByName("RandomHordes.Frequency"):getValue() >= chance then
		if RandomHordeIsSinglePlayer then
			local player = getPlayer();

			outgoingHordes[player:getUsername()] = ZombRand(
				getSandboxOptions():getOptionByName("RandomHordes.MinimumQuantity"):getValue(),
				getSandboxOptions():getOptionByName("RandomHordes.MaximumQuantity"):getValue() + 1);

			DebugPrintRandomHorde(player:getUsername() ..
				" HORDE STARTED AND SPAWNING: " .. outgoingHordes[player:getUsername()] .. " ZOMBIES!");

			-- Alert sound
			local alarmSound = "zombierand" .. tostring(ZombRand(10));
			local sound = getSoundManager():PlaySound(alarmSound, false, 0);
			getSoundManager():PlayAsMusic(alarmSound, sound, false, 0);

			-- You should awake the player if a horde is coming right?
			player:forceAwake();

			-- And speed to normal if the player is fast forwarding
			setGameSpeed(1);
		else
			local onlinePlayers = getOnlinePlayers();
			for i = 0, onlinePlayers:size() - 1 do
				local player = onlinePlayers:get(i);

				outgoingHordes[player:getUsername()] = ZombRand(
					getSandboxOptions():getOptionByName("RandomHordes.MinimumQuantity"):getValue(),
					getSandboxOptions():getOptionByName("RandomHordes.MaximumQuantity"):getValue() + 1);

				DebugPrintRandomHorde(player:getUsername() ..
					" HORDE STARTED AND SPAWNING: " .. outgoingHordes[player:getUsername()] .. " ZOMBIES!");

				sendServerCommand(player, "RandomHordes", "hordeIncoming",
					{ quantity = outgoingHordes[player:getUsername()] });
			end
		end
	end
end

local function CheckZombiesToSpawn()
	actualTick = actualTick + 1;
	if actualTick >= tickBeforeNextZed then
		actualTick = 0;

		if RandomHordeIsSinglePlayer then
			local player = getPlayer();
			if player:isDead() then
				outgoingHordes[player:getUsername()] = nil
			elseif (outgoingHordes[player:getUsername()] or 0) > 0 then
				SpawnZombieToPlayer(player);
			else
				outgoingHordes[player:getUsername()] = nil
				triggerEvent("OnRandomHordeSurvived", player)
			end
		else
			for playerUsername, zombiesRemaining in pairs(outgoingHordes) do
				local player = nil;
				local onlinePlayers = getOnlinePlayers();
				for i = 0, onlinePlayers:size() - 1 do
					local playerIteration = onlinePlayers:get(i);
					if playerIteration:getUsername() == playerUsername then
						player = playerIteration;
						break;
					end
				end
				if not player or player:isDead() then
					outgoingHordes[playerUsername] = nil;
				elseif (outgoingHordes[playerUsername] or 0) > 0 then
					SpawnZombieToPlayer(player);
				else
					outgoingHordes[playerUsername] = nil;
					triggerEvent("OnRandomHordeSurvived", player)
				end
			end
		end
	end
end

Events.EveryHours.Add(CheckRandomHorde);
Events.OnTick.Add(CheckZombiesToSpawn);
