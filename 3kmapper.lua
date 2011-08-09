---------------------
--  Area Handling  --
---------------------

-- Set the active area
-- Returns the areaname on success, "" otherwise
function setArea(areaname)
	local t = getAreaTable()
	--display(t)
	if table.contains(t, areaname) then
		echo("[[setArea: Setting active area to '" .. areaname .. "']]\n")
		return areaname
	else
		echo("[[setArea: No such area as '"..areaname.."'. Please 'createarea' first]]\n")
	end

	return ""
end

-- Return an id for the given area name, nil if area doesn't exist
function getAreaId(areaname)
	local t = getAreaTable()
	local id = t[areaname]

	if id then
		echo("[[getAreaId: Found area id of "..id.." for area name '"..areaname.."']]\n")
		return id
	else
		echo("[[getAreaId: No id found for that area!]]\n")
	end

	return nil
end

-- Remove all rooms in the given area
function resetArea(areaname)
	local area_id = getAreaId(areaname)

	if area_id then
		local t = getAreaRooms(area_id)
		for k,v in pairs(t) do
			deleteRoom(v)
		end

		prior_room = 0
		current_room = 0
		echo("[[resetArea: All rooms removed]]")
	else
		echo("[[resetArea: Invalid area - no rooms removed]]")
	end
end



----------------------
--   Room Handling  --
----------------------

-- Clean up a room name of the form "Room Name (exit, exit, exit)      "
-- to just "Room Name"
function parseRoomName(roomname)
	local fixname = roomname
	fixname = fixname:gsub("  %s+.?","")
	fixname = fixname:gsub("%([%a+,?]+%)", "")
	fixname = fixname:trim()
	--echo("\n"..fixname)
	return fixname
end

-- Take a full exit line and break it down to a table of actual exits
function parseExitLine(exitline)
	local t = {}
	exitline = exitline:trim()
	exitline = exitline:gsub("There %w+ %w+ obvious exit.?:","")
	exitline = exitline:gsub("No obvious exits.", "")

	t = exitline:split(",")
	for k, v in pairs(t) do
		t[k] = string.trim(v)
	end

	--echo("Cleaned exit line:" .. exitline)
	--display(t)

	return t
end

-- Given a room id, set the map to that location
function setRoomById(room_id)
	centerview(room_id)
	current_x, current_y, current_z = getRoomCoordinates(room_id)
	current_room = room_id
	prior_room = room_id
	current_area = getRoomAreaName(getRoomArea(room_id))
end

-- Given a roomname and roomdesc, attempt to find that room and move the map to it
function setRoomByLook(roomname, roomdesc)
	-- Try to find the room just by roomname alone
	local all_rooms = getRooms()
	local match_rooms = {}

	-- Find all matching rooms in the area by name
	for id, name in pairs(all_rooms) do
		if name == roomname then match_rooms[id]=name end
	end

	display(match_rooms)

	-- Can't find anything relevant
	if table.size(match_rooms) == 0 then
		echo("[[setRoomByLook: Can't find any matching rooms!]]\n")
		return
	end

	-- Found a single instance of it, good enough!
	if table.size(match_rooms) == 1 then
		for id, name in pairs(match_rooms) do
			echo("[[setRoom: Found a matching room! Setting map to location]]\n")
			setRoomById(id)
		end
		return
	end

	-- Found multiple rooms, try to narrow it down by using the room desc
	for id, name in pairs(match_rooms) do
		local desc = getRoomUserData(id, "description")
		if desc == roomdesc then
			echo("[[setRoombyLook: Found a match by description, moving map there]]\n")
			setRoomById(id)
			return
		end
	end

	echo("[[setRoomByLook: Unable to find exact room match]]\n")

end

function createNewRoom(roomname, roomdesc, roomexits)

	prior_room = current_room

	if current_area == "" then
		echo("[[createNewRoom: No area set! Use 'setarea <name>' first.]]\n")
		return
	end

	local area_id = getAreaId(current_area)
	if area_id == nil then
		echo("[[createNewRoom: Failed to find area id, room creation aborted]]\n")
		return
	end

	-- Start creating a new room
	local room_id = createRoomID()
	addRoom(room_id)
	setRoomName(room_id, roomname)
	setRoomUserData(room_id, "description", roomdesc)
	setRoomCoordinates(room_id, current_x, current_y, current_z)


	-- If it ends up being a duplicate, throw it out
	if checkDuplicateRoom(area_id, room_id) then
		echo("[[createNewRoom: Duplicate/overlapping rooms found, no new room created]]\n")
		deleteRoom(room_id)
		return
	end

	connectExitToHere(room_id)

	-- Otherwise, add it to the current area
	current_room = room_id
	setRoomArea(room_id, area_id)


	createFakeExits(room_id, roomexits)

	echo("[[createNewRoom: Created new room with id: "..room_id.."]]\n")
	centerview(room_id)
	return room_id
end

function connectExitToHere(room_id)
	local direction = command

	-- Make the bad assumption that exits will always be two way when
	-- they are cardinal directions. 
	local opposite_direction = getOppositeDirection(direction)
	--echo("[[connectExit: Orig. direction: "..direction.." Opposite: "..opposite_direction.."]]\n")

	-- If we don't know what our prior room was, bail
	if(prior_room == 0) then
		echo("[[connectExit: No prior room defined, no exit creation.]]\n")
		return
	end

	-- Is there already an exit connected?
	echo("[[connectExit:Prior room id: "..prior_room.."]]\n")
	local t = getRoomExits(prior_room)
	if t[direction] == room_id then
		echo("[[connectExit: Room exit already found to here. No action.\n")
	else
		setExit(prior_room, room_id, direction)
		echo("[[connectExit: Set exit from prior room to here]]\n")
	end

	setExit(room_id, prior_room, opposite_direction)
	echo("[[connectExit: Set exit from here to prior room]]\n")
end

function linkSpecialExit(move_command, dir)

	-- Find the room in <dir> direction
	local x,y,z = getRelativeCoords(dir)
	echo("Relative:"..x..y..z.."\n")
	local t = getRoomsByPosition(getRoomArea(current_room), current_x+x, current_y+y, current_z+z)

	--display(t)
	-- 
	if table.size(t) == 0 then
		if not mapping then
			echo("linkSE: Mapper Off! No room found in that direction to link to]]\n")
			return
		else
			--send(move_command)
			--mapDirection(dir)
			--addSpecialExit(prior_room, current_room, move_command)
			--currentview(current_room)
			return
		end
	end

	-- Oops, the map is messy - too many rooms stacked
	if table.size(t) > 1 then
		echo("linkSE: Too many rooms in that location - please rearrange map]]\n")
		return
	end

	-- Ah ha, there is already a room there. Link to it!
	local room_to_link = t[0]
	addSpecialExit(room_to_link, current_room, move_command)
	setExit(room_to_link, -1, DIR_OPPOSITE[dir])
	setExit(current_room, -1, dir)
	setRoomChar(current_room, "_")
	echo("linkSE: Special exit added")

end

function checkDuplicateRoom(area_id, new_room)
	-- WARNING: getRoomsByPosition starts indexing at 0, so we can't check
	-- the array size with #t. Instead, we have to try pulling from it.
	local t = getRoomsByPosition(area_id, current_x, current_y, current_z)
	--display(t)
	--echo("Found # rooms at this spot: "..table.getn(t).."\n")
	if t[0] then
		-- Too many rooms overlapping?
		if t[1] then
			echo("[[checkDupes: Too many rooms overlapping - please adjust map]]\n")
			return true
		end

		-- Is it the same room?
		local room_to_check = t[0]
		if isSameRoom(new_room, room_to_check) then
			echo("[[checkDupes: Duplicate room found in that direction, moving there]]\n")
			connectExitToHere(room_to_check)
			centerview(room_to_check)
			current_x, current_y, current_z = getRoomCoordinates(room_to_check)
			current_room = room_to_check
		end

		return true
	end

	echo("[[checkDupes: No duplicate room found at location]]\n")
	return false
end

-- Compare two rooms by name and room description
function isSameRoom(source, destination)
	if getRoomName(source) == getRoomName(destination) and
		getRoomUserData(source, "description") == getRoomUserData(destination, "description") then
		return true
	end

	return false
end

function createFakeExits(room_id, seen_exits)
	local defined_exits = getRoomExits(room_id)
	local seen_exits = seen_exits

	--display(seen_exits)
	--display(defined_exits)

	-- Check all the seen exits for already linked directions, and eliminate those
	for id, dir in pairs(seen_exits) do
		if table.contains(defined_exits, dir) then
			table.remove(seen_exits, id)
		end
	end

	--display(seen_exits)

	-- With the exits that remain, create 'fake' exits so they show up on the map
	-- as 'unexplored'
	for id, dir in pairs(seen_exits) do
		if table.contains(DIR_LONG, dir) then
			local room_id = createRoomID()
			addRoom(room_id)
			setRoomName(room_id, tostring(room_id)..":"..current_area)
			setRoomArea(room_id, fake_area)
			setExit(current_room, room_id, DIR_NORMALIZE[dir])
			echo("[[fake: Created fake room "..room_id.." with exit from "..current_room.."]]\n")
		else
			setRoomChar(id, ">")
			echo("[[fake: Created fake room character]]\n")
		end
	end

end

function initFakeArea()
	local fake_area_id = addAreaName("fakeexitarea")
	if fake_area_id == -1 then
		local t = getAreaTable()
		fake_area_id = t["fakeexitarea"]
	end
	
	return fake_area_id
end

------------------------
--   Utility        --
------------------------

function normalizeDirection(direction)
	if table.contains(DIR_LONG, direction) then
		direction = DIR_NORMALIZE[direction]
	end

	return direction
end

function getOppositeDirection(direction)
	-- Make sure the direction is 'long form'
	local direction = normalizeDirection(direction)



	echo("[[getOpposite: orig direction = "..direction.."]]\n")

	return DIR_OPPOSITE[direction]
end

function followDirection(dir)
	if current_room == 0 then return end

	-- If it is a normal compass direction...
	if isCardinalDirection(dir) then
		local t = getRoomExits(current_room)
		local existing_room = t[DIR_NORMALIZE_SHORT[dir]]
		setMapToExistingRoom(existing_room)
	else
		local t = getSpecialExitsSwap(current_room)
		local existing_room = t[dir]
		display(t)
		if table.contains(t, dir) then
			echo("[[follow: Found known special exits]]\n")
			setMapToExistingRoom(existing_room)
		end
	end
end

function setMapToExistingRoom(room_id)
	if room_id and 
	 getRoomName(room_id) == roomname and
	 getRoomUserData(room_id, "description") == roomdesc then
		echo("[[setMapExisting: Moving to existing room "..room_id.."]]\n")
		setRoomById(room_id)
	end
end

function mapDirection(dir)
	echo("[[mapDir: Found command: "..dir .. "]]\n")
	if isCardinalDirection(dir) then
		echo("[[mapDir: Confirmed movement command]]\n")

		if current_room ~= 0 then
			-- If there is no room already in this direction, create a new room
			local t = getRoomExits(current_room)
			--display(t)
			local existing_room = t[DIR_NORMALIZE_SHORT[dir]]
			if existing_room and getRoomAreaName(getRoomArea(existing_room)) ~= "fakeexitarea" then

				echo("[[mapDir: Found an existing room at this exit: id: "..existing_room.."]]\n")
				setRoomById(existing_room)

			elseif existing_room and getRoomAreaName(getRoomArea(existing_room)) == "fakeexitarea" then
				deleteRoom(existing_room)
				createNewRoom(roomname, roomdesc, exittable)
			else
				createNewRoom(roomname, roomdesc, exittable)
			end
		else
			echo("[[mapDir: Creating first room of area]]\n")
			createNewRoom(roomname, roomdesc, exittable)
		end

	else
		echo("[[mapDir: Room seen, but not a cardinal direction.]]\n")
		local special_exit, newdir = string.match(dir,">(.*)>(%w+)")
		if newdir then
			command = newdir
			echo("[[specialExit: ".. special_exit.."]]\n")
			mapDirection(newdir)
			linkSpecialExit(special_exit, DIR_OPPOSITE[newdir])
		end
	end

	echo("[[mapDir: roomname = "..roomname.."]]\n")
end



-- For a given direction, give the relative coordinates from "here"
function getRelativeCoords(direction)
	echo("[[getRelative: direction = "..direction.."]]\n")
	if direction == "e" then 
		return 2, 0, 0
	elseif direction == "w" then
		return -2, 0, 0
	elseif direction == "n" then
		return 0, 2, 0
	elseif direction == "s" then
		return 0, -2, 0
	elseif direction == "ne" then
		return 2, 2, 0
	elseif direction == "nw" then
		return -2, 2, 0
	elseif direction == "se" then
		return 2, -2, 0
	elseif direction == "sw" then
		return -2, -2, 0
	elseif direction == "u" then
		return 0, 0, 2
	elseif direction == "d" then
		return 0, 0, -2
	end
end

function setLastCoordinates()
	last_x = current_x
	last_y = current_y
	last_z = current_z
end

function setNewCoordinates(direction)
		setLastCoordinates()

		local x,y,z = getRelativeCoords(direction)
		echo("[[newCoords: x, y, z: "..x..", "..y.." ,"..z.."]]\n")
		current_x = current_x + x
		current_y = current_y + y
		current_z = current_z + z
end

function isCardinalDirection(command)
	--display(exittable)

	--echo("[[isCardinal: given command: "..command.."]]\n")
	-- If it is a 'short' direction, spell it out (ie., s = south)
	command = normalizeDirection(command)

	echo("[[isCardinal: normalized command: "..command.."]]\n")
	if table.contains(DIR_SHORT,command) then
		setNewCoordinates(command)
		return true
	end

	return false

end


