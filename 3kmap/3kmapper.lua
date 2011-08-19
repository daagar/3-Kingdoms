mudlet = mudlet or {}; mudlet.mapper_script = true

function daagmap:forceLook()
  setRoomName(daagmap.current_room, roomname)
  setRoomUserData(daagmap.current_room, "description", roomdesc)
  daagmap:createFakeExits(daagmap.current_room, exittable)
  daagmap.isForcedLook = false
end

function doSpeedWalk()

  if #speedWalkPath == 0 then
    echo("No path from here to there!\n")
    return
  end

  --display(speedWalkPath)
  daagmap.isMapping = false
  local exits = daagmap:getAllExits(daagmap.current_room)
  local path = {}
  --display(exits)
  for i, room_id in pairs(speedWalkPath) do
    for j, exit in pairs(exits) do
      if tonumber(room_id) == exit then
        table.insert(path,j) 
        break
      end
    end
    exits = daagmap:getAllExits(tonumber(room_id))
  end
  --display(path)

  daagmap.path = path
  if daagmap.path[1] then
    speedwalking = true
    enableTrigger("walking")
    disableTrigger("roomname")
    local dirToSend = daagmap.path[1]
    table.remove(daagmap.path, 1)
    send(dirToSend) 
  end
    
  --  followDirection(DIR_SHRINK[v])
  --speedwalking = false
  --tempTimer(3, [[send("look");expandAlias("mfind")]])

end

function daagmap:getAllExits(room_id)
   local exits = getRoomExits(room_id)
   local sexits = getSpecialExitsSwap(room_id)
   return daagmap:concatTables(exits,sexits)
end

function daagmap:concatTables(table1, table2)
	local output = {}
	for i,v in pairs(table1) do
		output[i] = v
	end
	for i,v in pairs(table2) do
		output[i] = v
	end
	return output
end

----------------------
--   Room Handling  --
----------------------

-- Clean up a room name of the form "Room Name (exit, exit, exit)      "
-- to just "Room Name"
function daagmap:parseRoomName(roomname)
  --display(roomname)
	local fixname = roomname
  fixname = fixname:gsub("^> ", "")   -- When speedwalking, the roomname gets a prompt added
	fixname = fixname:gsub("  %s+.?","")
	fixname = fixname:gsub("%([%a+,?]+%).?", "") -- Remove short exits
	fixname = fixname:trim()
	--echo("\n"..fixname)
	return fixname
end

-- Take a full exit line and break it down to a table of actual exits
function daagmap:parseExitLine(exitline)
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
function daagmap:setRoomById(room_id)
	centerview(room_id)
	daagmap.current_x, daagmap.current_y, daagmap.current_z = getRoomCoordinates(room_id)
	daagmap.current_room = room_id
	daagmap.prior_room = room_id
	daagmap.current_area = getRoomAreaName(getRoomArea(room_id))
end

-- Given a roomname and roomdesc, attempt to find that room and move the map to it
function daagmap:setRoomByLook(roomname, roomdesc)
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
			echo("[[setRoombyLook: Found a match by description, moving map there]]\n")
			daagmap:setRoomById(id)
			return
		end
	end

	echo("[[setRoomByLook: Unable to find exact room match]]\n")

end

function daagmap:mergeRooms(top_room, bottom_room)
  --assert(getRoomArea(top_room) == getRoomArea(bottom_room), "ERROR: Rooms must be located in the same area to merge")
  if getRoomArea(top_room) ~= getRoomArea(bottom_room) then
    echo("ERROR: Rooms must be located in the same area to merge\n")
    return
  end

  local top_exits = getRoomExits(top_room)
  local bottom_exits = getRoomExits(bottom_room)
  local top_special_exits = getSpecialExitsSwap(top_room)
  local bottom_special_exits = getSpecialExitsSwap(bottom_room)

  -- Remap all exits from the top room to the bottom room, excluding fake rooms
  for exit_dir, id in pairs(top_exits) do
    exit_dir = daagmap:normalizeDirToShort(exit_dir)
    if getRoomAreaName(getRoomArea(id)) == daagmap.current_area then
      local other_room_exits = getRoomExits(id)
      --display(other_room_exits)
      local opposite = daagmap:getOppositeDir(exit_dir)
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
  daagmap:setRoomById(daagmap.current_room)
end


function daagmap:createNewRoom(roomname, roomdesc, roomexits)

	if daagmap.current_area == "" then
		echo("[[createNewRoom: No area set! Use 'setarea <name>' first.]]\n")
		return
	end

	local area_id = daagmap:getAreaId(daagmap.current_area)
	if area_id == nil then
		echo("[[createNewRoom: Failed to find area id, room creation aborted]]\n")
		return
	end

	daagmap.prior_room = daagmap.current_room

	-- Start creating a new room
	local room_id = createRoomID()
	addRoom(room_id)
	setRoomName(room_id, roomname)
	setRoomUserData(room_id, "description", roomdesc)
	setRoomCoordinates(room_id, daagmap.current_x, daagmap.current_y, daagmap.current_z)

  local overlapping_room = daagmap:isRoomOverlapping(area_id, room_id)

  if overlapping_room then
    echo("Found overlapping room\n")
    -- When mapping special exits, we remove the newly created room as unneccessary
    if daagmap:isSameRoom(room_id, overlapping_room) and daagmap.isSpecialMapping then
      deleteRoom(room_id)
			daagmap.current_x, daagmap.current_y, daagmap.current_z = getRoomCoordinates(overlapping_room)
			daagmap.current_room = overlapping_room
      centerview(overlapping_room)
      return overlapping_room 
    elseif daagmap:isSameRoom(room_id, overlapping_room) then

			echo(".. it is a duplicate room\n")
			daagmap:connectExitToHere(overlapping_room)
			centerview(overlapping_room)
			daagmap.current_x, daagmap.current_y, daagmap.current_z = getRoomCoordinates(overlapping_room)
			daagmap.current_room = overlapping_room
      return overlapping_room
    else
      echo("Moving other rooms out of the way")
      daagmap:moveCollidingRooms(area_id)
		end
  end

 	daagmap:connectExitToHere(room_id)

  -- Otherwise, add it to the current area
  daagmap.current_room = room_id
  setRoomArea(room_id, area_id)

  daagmap:createFakeExits(room_id, roomexits)

  --echo("[[createNewRoom: Created new room with id: "..room_id.."]]\n")
  centerview(room_id)
  return room_id 
 end

function daagmap:moveCollidingRooms(area_id)
    -- Move all rooms along the axis of movement away to make room for the new room. 
    local x_axis_pos = {"e"}
    local x_axis_neg = {"w"}
    local y_axis_pos = {"n", "nw", "ne" }
    local y_axis_neg = {"s", "sw", "se" } 
    local z_axis_pos = {"u"}
    local z_axis_neg = {"d"}

    local rooms = getAreaRooms(area_id)

    if table.contains(y_axis_pos, daagmap.command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if y >= daagmap.current_y then
          setRoomCoordinates(id, x, y+2, z)
        end
      end
    elseif table.contains(y_axis_neg, daagmap.command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if y <= daagmap.current_y then
          setRoomCoordinates(id, x, y-2, z)
        end
      end
    elseif table.contains(x_axis_pos, daagmap.command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if x >= daagmap.current_x then
          setRoomCoordinates(id, x+2, y, z)
        end
      end
    elseif table.contains(x_axis_neg, daagmap.command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if x <= daagmap.current_x then
          setRoomCoordinates(id, x-2, y, z)
        end
      end
    elseif table.contains(z_axis_pos, daagmap.command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if z >= daagmap.current_z then
          setRoomCoordinates(id, x, y, z+2)
        end
      end
    elseif table.contains(z_axis_neg, daagmap.command) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if z <= daagmap.current_z then
          setRoomCoordinates(id, x, y, z-2)
        end
      end
    end

end

function daagmap:connectExitToHere(room_id)
	local direction = daagmap.command

	-- Make the bad assumption that exits will always be two way when
	-- they are cardinal directions. 
	local opposite_direction = daagmap:getOppositeDir(direction)
	--echo("[[connectExit: Orig. direction: "..direction.." Opposite: "..opposite_direction.."]]\n")

	-- If we don't know what our prior room was, bail
	if(daagmap.prior_room == 0) then
		echo("[[connectExit: No prior room defined, no exit creation.]]\n")
		return
	end

	-- Is there already an exit connected?
	--echo("[[connectExit:Prior room id: "..prior_room.."]]\n")
	local t = getRoomExits(daagmap.prior_room)
	if t[direction] == room_id then
		--echo("[[connectExit: Room exit already found to here. No action.\n")
	else
		setExit(daagmap.prior_room, room_id, direction)
		--echo("[[connectExit: Set exit from prior room to here]]\n")
	end

	setExit(room_id, daagmap.prior_room, opposite_direction)
	--echo("[[connectExit: Set exit from here to prior room]]\n")
end

function daagmap:linkSpecialExit(move_command, dir)

	-- Find the room in <dir> direction
	local x,y,z = daagmap:getRelativeCoords(dir)
	--echo("Relative:"..x..y..z.."\n")
	local t = getRoomsByPosition(getRoomArea(daagmap.current_room), daagmap.current_x+x, daagmap.current_y+y, daagmap.current_z+z)

  -- A room should have already been created before calling this function
  --assert(table.size(t) ~= 0, "(mapper): ERROR - Got an empty table in linkSpecialExit()\n")
  if table.size(t) == 0 then
    echo("(mapper): ERROR - Got an empty table in linkSpecialExit()\n")
    return
  end

	--display(t)

	-- Oops, the map is messy - too many rooms stacked
	if table.size(t) > 1 then
		echo("linkSE: Too many rooms in that location - please rearrange map]]\n")
		return
	end

	-- Link to the new room just created
	local room_to_link = t[0]
	addSpecialExit(room_to_link, daagmap.current_room, move_command)
  --local t = getRoomExits(room_to_link)
  --if getRoomArea(t[daagmap.DIR_OPPOSITE[dir]]) == daagmap.current_area then
	setExit(room_to_link, -1, daagmap.DIR_OPPOSITE[dir])
  --end
	setExit(daagmap.current_room, -1, dir)
	setRoomChar(daagmap.current_room, "_")
	--echo("linkSE: Special exit added")
end

function daagmap:isRoomOverlapping(area_id, new_room)
  local t = getRoomsByPosition(area_id, daagmap.current_x, daagmap.current_y, daagmap.current_z)
  if t then return t[0] else return false end -- t is nil on first room of area
end

function daagmap:checkDuplicateRoom(area_id, new_room)
	-- WARNING: getRoomsByPosition starts indexing at 0, so we can't check
	-- the array size with #t. Instead, we have to try pulling from it.
	local t = getRoomsByPosition(area_id, daagmap.current_x, daagmap.current_y, daagmap.current_z)
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
		if daagmap:isSameRoom(new_room, room_to_check) then
			--echo("[[checkDupes: Duplicate room found in that direction, moving there]]\n")
			daagmap:connectExitToHere(room_to_check)
			centerview(room_to_check)
			daagmap.current_x, daagmap.current_y, daagmap.current_z = getRoomCoordinates(room_to_check)
			daagmap.current_room = room_to_check
		end

		return true
	end

	--echo("[[checkDupes: No duplicate room found at location]]\n")
	return false
end

-- Compare two rooms by name and room description
function daagmap:isSameRoom(source, destination)
	if getRoomName(source) == getRoomName(destination) and
		getRoomUserData(source, "description") == getRoomUserData(destination, "description") then
		return true
	end

	return false
end
-- By creating rooms in a 'bogus' area, we can get exit arrows on rooms
-- to show unexplored exits. 
function daagmap:createFakeExits(room_id, seen_exits)
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
		if table.contains(daagmap.DIR_LONG, dir) then
			local room_id = createRoomID()
			addRoom(room_id)
			setRoomName(room_id, tostring(room_id)..":"..daagmap.current_area)
			setRoomArea(room_id, daagmap.fake_area)
			setExit(daagmap.current_room, room_id, daagmap:normalizeDirToShort(dir))
			--echo("[[fake: Created fake room "..room_id.." with exit from "..current_room.."]]\n")
		else
			setRoomChar(id, ">")
			--echo("[[fake: Created fake room character]]\n")
		end
	end

end

function daagmap:moveCurrentRoomToArea(area_name)
  --assert(daagmap.current_room ~= 0, "ERROR: Don't know what room you are in!")
  daagmap:moveRoomToArea(daagmap.current_room, area_name)
end

function daagmap:moveRoomToArea(room_id, area_name)
 local areas = getAreaTable()
 if not table.contains(areas, area_name) then
   echo("[[mapper: ERROR - No such area!]]\n")
 end

 local area_id = areas[area_name]
 setRoomArea(room_id, area_id)
 expandAlias("mfind")

end


------------------------
--   Utility        --
------------------------


function daagmap:followDirection(dir)
	if daagmap.current_room == 0 then return end

	-- If it is a normal compass direction...
	if daagmap:isCardinalDirection(dir) then
    daagmap:setNewCoordinates(dir)
		local t = getRoomExits(daagmap.current_room)
		local existing_room = t[daagmap:normalizeDirToLong(dir)]
		daagmap:setMapToExistingRoom(existing_room)
	else
		local t = getSpecialExitsSwap(daagmap.current_room)
		local existing_room = t[dir]
		--display(t)
		if t and table.contains(t, dir) then
			--echo("[[follow: Found known special exits]]\n")
			daagmap:setMapToExistingRoom(existing_room)
		end
	end

end

function daagmap:setMapToExistingRoom(room_id)
  if speedwalking then
    --display(roomname)
    --display(getRoomName(room_id))
    if getRoomName(room_id) == roomname then
      daagmap:setRoomById(room_id)
    else
      echo("[[Speedwalk Aborted! Expected room not seen]]\n")
      speedwalk = false
      disableTrigger("walking")
      enableTrigger("roomname")
      daagmap.path = {}
    end
  elseif room_id and 
	  getRoomName(room_id) == roomname and
	  getRoomUserData(room_id, "description") == roomdesc then
		--echo("[[setMapExisting: Moving to existing room "..room_id.."]]\n")
  	daagmap:setRoomById(room_id)
	end
end

-- Attempt to map a special exit. Returns true if a new room is created as a result, otherwise false
function daagmap:mapSpecialExit(dir)
  local mapped_special = false
 	local special_exit, newdir = string.match(dir,">(.*)>(%w+)")
  --display("dir passed in:" ..dir)

  if not daagmap:isCardinalDirection(dir) and newdir then
    echo("[[mapSpecial: Mapping "..special_exit.." to direction "..newdir.."]]\n")
    daagmap.command = newdir
    daagmap:mapDirection(newdir)
    daagmap:linkSpecialExit(special_exit, daagmap.DIR_OPPOSITE[newdir])
    mapped_special = true
  end
  daagmap.isSpecialMapping = false
  return mapped_special
end

function daagmap:mapDirection(dir)
	--echo("[[mapDir: Found command: "..dir .. "]]\n")

  -- If it is a special exit command, map it
  --if daagmap:mapSpecialExit(dir) then return end

  if daagmap.current_room == 0 then
		echo("[[mapDir: Creating first room of area]]\n")
		daagmap:createNewRoom(roomname, roomdesc, exittable)
    return
	end

  if not daagmap:isCardinalDirection(dir) then
    daagmap:followDirection(dir)
    return
  end

  daagmap:setNewCoordinates(dir)
	local t = getRoomExits(daagmap.current_room)
  --display(t)
	local existing_room = t[daagmap.DIR_EXPAND[dir]]
  --display(existing_room)
  if existing_room and getRoomAreaName(getRoomArea(existing_room)) ~= "fakeexitarea" then
    --echo("[[mapDir: Found an existing room at this exit: id: "..existing_room.."]]\n")
	  daagmap:setRoomById(existing_room)
  elseif existing_room and getRoomAreaName(getRoomArea(existing_room)) == "fakeexitarea" then
	  deleteRoom(existing_room)
	  daagmap:createNewRoom(roomname, roomdesc, exittable)
  else
    daagmap:createNewRoom(roomname, roomdesc, exittable)
  end

  local t = getSpecialExitsSwap(daagmap.current_room)
	local existing_room = t[dir]
	--display(t)
	if table.contains(t, dir) then
		--echo("[[follow: Found known special exits]]\n")
		daagmap:setMapToExistingRoom(existing_room)
	end
end



-- For a given direction, give the relative coordinates from "here"
function daagmap:getRelativeCoords(direction)
  --assert(isCardinalDirection(direction), "getRelativeCoords: Invalid direction "..direction.." provided\n")
  
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

function daagmap:setLastCoordinates()
	daagmap.last_x = daagmap.current_x
	daagmap.last_y = daagmap.current_y
	daagmap.last_z = daagmap.current_z
end

function daagmap:setNewCoordinates(direction)
  --display(direction)
    local direction = daagmap:normalizeDirToShort(direction)
		daagmap:setLastCoordinates()

		local x,y,z = daagmap:getRelativeCoords(direction)
		--echo("[[newCoords: x, y, z: "..x..", "..y.." ,"..z.."]]\n")
		daagmap.current_x = daagmap.current_x + x
		daagmap.current_y = daagmap.current_y + y
		daagmap.current_z = daagmap.current_z + z
end





