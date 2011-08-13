mudlet = mudlet or {}; mudlet.mapper_script = true

function doSpeedWalk()

  if #speedWalkPath == 0 then
    echo("No path from here to there!\n")
    return
  end

  --display(speedWalkPath)
  mapping = false
  local exits = getAllExits(current_room)
  local path = {}
  --display(exits)
  for i, room_id in pairs(speedWalkPath) do
    for j, exit in pairs(exits) do
      if tonumber(room_id) == exit then
        table.insert(path,j) 
        break
      end
    end
    exits = getAllExits(tonumber(room_id))
  end
  --display(path)

  speedwalking = true
  for k, v in ipairs(path) do
    send(v)
    followDirection(DIR_SHRINK[v])
  end
  speedwalking = false
  --tempTimer(3, [[send("look");expandAlias("mfind")]])

end

function getAllExits(room_id)
   local exits = getRoomExits(room_id)
   local sexits = swapKeysValues(getSpecialExits(room_id))
   return concatTables(exits,sexits)
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

	--display(match_rooms)

	-- Try to narrow it down by using the room desc
	for id, name in pairs(match_rooms) do
		local desc = getRoomUserData(id, "description")
		if desc == roomdesc then
			--echo("[[setRoombyLook: Found a match by description, moving map there]]\n")
			setRoomById(id)
			return
		end
	end

	echo("[[setRoomByLook: Unable to find exact room match]]\n")

end

function mergeRooms(top_room, bottom_room)
  local top_exits = getRoomExits(top_room)
  local bottom_exits = getRoomExits(bottom_room)
  local top_special_exits = getSpecialExitsSwap(top_room)
  local bottom_special_exits = getSpecialExitsSwap(bottom_room)

  -- Remap all exits from the top room to the bottom room, excluding fake rooms
  for exit_dir, id in pairs(top_exits) do
    exit_dir = normalizeDirToShort(exit_dir)
    if getRoomAreaName(getRoomArea(id)) == current_area then
      local other_room_exits = getRoomExits(id)
      display(other_room_exits)
      local opposite = getOppositeDir(exit_dir)
      --echo("opposite)
      --echo("other id:"..other_room_exits[DIR_EXPAND[opposite]].."\n")
      setExit(id, bottom_room, opposite)
      setExit(bottom_room, id, exit_dir)
    else
      -- It is a fake room, remove it
      deleteRoom(id)
    end
  end

  -- Now fix up special exits
  for exit_dir_top, id_top in pairs(top_special_exits) do
    if not table.contains(bottom_special_exits, exit_dir_top) then
      
      addSpecialExit(id_top, bottom_room, exit_dir_top)

      local other_room_exits = getSpecialExitsSwap(id_top)
      -- Can't remove just one special exit, have to nuke all of them...
      clearSpecialExits(id_top)
      -- Find exits that lead back to the top room, and map them instead
      -- to the bottom room. If it is a special exit that leads somewhere else,
      -- keep that mapping the same.
      for exit_dir_other, id_other in pairs(other_room_exits) do
        if id_other == top_room then
          addSpecialExit(id_other, bottom_room, exit_dir_other)
        else
          addSpecialExit(id_other, id_top, exit_dir_other)
        end
      end

    end
  end

  deleteRoom(top_room)
  setRoomById(current_room)
end


function createNewRoom(roomname, roomdesc, roomexits)

	if current_area == "" then
		echo("[[createNewRoom: No area set! Use 'setarea <name>' first.]]\n")
		return
	end

	local area_id = getAreaId(current_area)
	if area_id == nil then
		echo("[[createNewRoom: Failed to find area id, room creation aborted]]\n")
		return
	end

	prior_room = current_room

	-- Start creating a new room
	local room_id = createRoomID()
	addRoom(room_id)
	setRoomName(room_id, roomname)
	setRoomUserData(room_id, "description", roomdesc)
	setRoomCoordinates(room_id, current_x, current_y, current_z)

  local overlapping_room = isRoomOverlapping(area_id, room_id)

  if overlapping_room then
    --echo("Found overlapping room\n")
   	if isSameRoom(room_id, overlapping_room) then

			--echo(".. it is a duplicate room\n")
			connectExitToHere(overlapping_room)
			centerview(overlapping_room)
			current_x, current_y, current_z = getRoomCoordinates(overlapping_room)
			current_room = overlapping_room
      return overlapping_room
    else
      --echo("Moving other rooms out of the way")
      moveCollidingRooms(area_id)
		end
  end

 	connectExitToHere(room_id)

  -- Otherwise, add it to the current area
  current_room = room_id
  setRoomArea(room_id, area_id)

  createFakeExits(room_id, roomexits)

  --echo("[[createNewRoom: Created new room with id: "..room_id.."]]\n")
  centerview(room_id)
  return room_id 
 end

function moveCollidingRooms(area_id)
    -- Move all rooms along the axis of movement away to make room for the new room. 
    local x_axis_pos = {"e"}
    local x_axis_neg = {"w"}
    local y_axis_pos = {"n", "nw", "ne" }
    local y_axis_neg = {"s", "sw", "se" } 
    local z_axis_pos = {"u"}
    local z_axis_neg = {"d"}


    local rooms = getAreaRooms(area_id)

    if table.contains(y_axis_pos, command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if y >= current_y then
          setRoomCoordinates(id, x, y+2, z)
        end
      end
    elseif table.contains(y_axis_neg, command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if y <= current_y then
          setRoomCoordinates(id, x, y-2, z)
        end
      end
    elseif table.contains(x_axis_pos, command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if x >= current_x then
          setRoomCoordinates(id, x+2, y, z)
        end
      end
    elseif table.contains(x_axis_neg, command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if x <= current_x then
          setRoomCoordinates(id, x-2, y, z)
        end
      end
    elseif table.contains(z_axis_pos, command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if z >= current_z then
          setRoomCoordinates(id, x, y, z+2)
        end
      end
    elseif table.contains(z_axis_neg, command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if z <= current_z then
          setRoomCoordinates(id, x, y, z-2)
        end
      end
    end

end

function connectExitToHere(room_id)
	local direction = command

	-- Make the bad assumption that exits will always be two way when
	-- they are cardinal directions. 
	local opposite_direction = getOppositeDir(direction)
	--echo("[[connectExit: Orig. direction: "..direction.." Opposite: "..opposite_direction.."]]\n")

	-- If we don't know what our prior room was, bail
	if(prior_room == 0) then
		echo("[[connectExit: No prior room defined, no exit creation.]]\n")
		return
	end

	-- Is there already an exit connected?
	--echo("[[connectExit:Prior room id: "..prior_room.."]]\n")
	local t = getRoomExits(prior_room)
	if t[direction] == room_id then
		--echo("[[connectExit: Room exit already found to here. No action.\n")
	else
		setExit(prior_room, room_id, direction)
		--echo("[[connectExit: Set exit from prior room to here]]\n")
	end

	setExit(room_id, prior_room, opposite_direction)
	--echo("[[connectExit: Set exit from here to prior room]]\n")
end

function linkSpecialExit(move_command, dir)

	-- Find the room in <dir> direction
	local x,y,z = getRelativeCoords(dir)
	--echo("Relative:"..x..y..z.."\n")
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
	--echo("linkSE: Special exit added")

end

function isRoomOverlapping(area_id, new_room)
  local t = getRoomsByPosition(area_id, current_x, current_y, current_z)
  if t then return t[0] else return false end -- t is nil on first room of area
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
			--echo("[[checkDupes: Duplicate room found in that direction, moving there]]\n")
			connectExitToHere(room_to_check)
			centerview(room_to_check)
			current_x, current_y, current_z = getRoomCoordinates(room_to_check)
			current_room = room_to_check
		end

		return true
	end

	--echo("[[checkDupes: No duplicate room found at location]]\n")
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

-- By creating rooms in a 'bogus' area, we can get exit arrows on rooms
-- to show unexplored exits. 
function createFakeExits(room_id, seen_exits)
	local defined_exits = getRoomExits(room_id)
	local seen_exits = seen_exits

	-- Check all the seen exits for already linked directions, and eliminate those
	for id, dir in pairs(seen_exits) do
		if table.contains(defined_exits, dir) then
			table.remove(seen_exits, id)
		end
	end

	-- With the exits that remain, create 'fake' exits so they show up on the map
	-- as 'unexplored'
	for id, dir in pairs(seen_exits) do
		if table.contains(DIR_LONG, dir) then
			local room_id = createRoomID()
			addRoom(room_id)
			setRoomName(room_id, tostring(room_id)..":"..current_area)
			setRoomArea(room_id, fake_area)
			setExit(current_room, room_id, normalizeDirToShort(dir))
			--echo("[[fake: Created fake room "..room_id.." with exit from "..current_room.."]]\n")
		else
			setRoomChar(id, ">")
			--echo("[[fake: Created fake room character]]\n")
		end
	end

end

------------------------
--   Utility        --
------------------------


function followDirection(dir)
	if current_room == 0 then return end

	-- If it is a normal compass direction...
	if isCardinalDirection(dir) then
    setNewCoordinates(dir)
		local t = getRoomExits(current_room)
		local existing_room = t[normalizeDirToLong(dir)]
		setMapToExistingRoom(existing_room)
	else
		local t = getSpecialExitsSwap(current_room)
		local existing_room = t[dir]
		--display(t)
		if table.contains(t, dir) then
			--echo("[[follow: Found known special exits]]\n")
			setMapToExistingRoom(existing_room)
		end
	end
end

function setMapToExistingRoom(room_id)
	if room_id and 
	 getRoomName(room_id) == roomname and
	 getRoomUserData(room_id, "description") == roomdesc then
		--echo("[[setMapExisting: Moving to existing room "..room_id.."]]\n")
		setRoomById(room_id)
	end
end

-- Attempt to map a special exit. Returns true if a new room is created as a result, otherwise false
function mapSpecialExit(dir)
  local mapped_special = false
 	local special_exit, newdir = string.match(dir,">(.*)>(%w+)")

  if not isCardinalDirection(dir) and newdir then
    --echo("[[mapSpecial: Mapping "..special_exit.." to direction "..newdir.."]]\n")
    command = newdir
    mapDirection(newdir)
    linkSpecialExit(special_exit, DIR_OPPOSITE[newdir])
    mapped_special = true
  end

  return mapped_special
end

function mapDirection(dir)
	--echo("[[mapDir: Found command: "..dir .. "]]\n")

  -- If it is a special exit command, map it
  if mapSpecialExit(dir) then return end

  if current_room == 0 then
		echo("[[mapDir: Creating first room of area]]\n")
		createNewRoom(roomname, roomdesc, exittable)
    return
	end

  if not isCardinalDirection(dir) then
    followDirection(dir)
  end

  setNewCoordinates(dir)
	local t = getRoomExits(current_room)
  --display(t)
	local existing_room = t[DIR_EXPAND[dir]]
  --display(existing_room)
  if existing_room and getRoomAreaName(getRoomArea(existing_room)) ~= "fakeexitarea" then
    --echo("[[mapDir: Found an existing room at this exit: id: "..existing_room.."]]\n")
	  setRoomById(existing_room)
  elseif existing_room and getRoomAreaName(getRoomArea(existing_room)) == "fakeexitarea" then
	  deleteRoom(existing_room)
	  createNewRoom(roomname, roomdesc, exittable)
  else
    createNewRoom(roomname, roomdesc, exittable)
  end

  local t = getSpecialExitsSwap(current_room)
	local existing_room = t[dir]
	--display(t)
	if table.contains(t, dir) then
		--echo("[[follow: Found known special exits]]\n")
		setMapToExistingRoom(existing_room)
	end
end



-- For a given direction, give the relative coordinates from "here"
function getRelativeCoords(direction)
  assert(isCardinalDirection(direction), "getRelativeCoords: Invalid direction provided\n")
  
	--echo("[[getRelative: direction = "..direction.."]]\n")
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
		--echo("[[newCoords: x, y, z: "..x..", "..y.." ,"..z.."]]\n")
		current_x = current_x + x
		current_y = current_y + y
		current_z = current_z + z
end





