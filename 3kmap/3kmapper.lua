----------------
--  Init --
--  ------------



function daagar.map:forceLook()
  setRoomName(daagar.map.current_room, roomname)
  setRoomUserData(daagar.map.current_room, "description", roomdesc)
  daagar.map:createFakeExits(daagar.map.current_room, exittable)
  daagar.map.isForcedLook = false
end

function doSpeedWalk()

  if #speedWalkPath == 0 then
    log:info("No path from here to there!")
    return
  end

  --display(speedWalkPath)
  daagar.map.isMapping = false
  local exits = daagar.map:getAllExits(daagar.map.current_room)
  local path = {}
  --display(exits)
  for i, room_id in pairs(speedWalkPath) do
    for j, exit in pairs(exits) do
      if tonumber(room_id) == exit then
        table.insert(path,j) 
        break
      end
    end
    exits = daagar.map:getAllExits(tonumber(room_id))
  end
  --display(path)

  daagar.map.path = path
  if daagar.map.path[1] then
    speedwalking = true
    enableTrigger("walking")
    disableTrigger("roomname")
    local dirToSend = daagar.map.path[1]
    table.remove(daagar.map.path, 1)
    send(dirToSend) 
  end
    
  --  followDirection(DIR_SHRINK[v])
  --speedwalking = false
  --tempTimer(3, [[send("look");expandAlias("mfind")]])

end

function daagar.map:getAllExits(room_id)
   local exits = getRoomExits(room_id)
   local sexits = getSpecialExitsSwap(room_id)
   return daagar.map:concatTables(exits,sexits)
end

function daagar.map:concatTables(table1, table2)
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
function daagar.map:parseRoomName(roomname)
  --display(roomname)
	local fixname = roomname
  fixname = fixname:gsub("^> ", "")   -- When speedwalking, the roomname gets a prompt added
	fixname = fixname:gsub("  %s+.?","")
	fixname = fixname:gsub("%([%a+,?]+%).?", "") -- Remove short exits
	fixname = fixname:trim()
	log:debug(fixname)
	return fixname
end

-- Take a full exit line and break it down to a table of actual exits
function daagar.map:parseExitLine(exitline)
	local t = {}
	exitline = exitline:trim()
	exitline = exitline:gsub("There %w+ %w+ obvious exit.?:","")
	exitline = exitline:gsub("No obvious exits.", "")

	t = exitline:split(",")
	for k, v in pairs(t) do
		t[k] = string.trim(v)
	end

	log:debug("Cleaned exit line:" .. exitline)
	--display(t)

	return t
end

-- Given a room id, set the map to that location
function daagar.map:setRoomById(room_id)
	centerview(room_id)
	daagar.map.current_x, daagar.map.current_y, daagar.map.current_z = getRoomCoordinates(room_id)
	daagar.map.current_room = room_id
	daagar.map.prior_room = room_id
	daagar.map.current_area = getRoomAreaName(getRoomArea(room_id))
end

-- Given a roomname and roomdesc, attempt to find that room and move the map to it
function daagar.map:setRoomByLook(roomname, roomdesc)
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
			log:info("Found a match by description, moving map there")
			daagar.map:setRoomById(id)
			return
		end
	end

	log:info("Unable to find exact room match")

end

function daagar.map:mergeRooms(top_room, bottom_room)
  --assert(getRoomArea(top_room) == getRoomArea(bottom_room), "ERROR: Rooms must be located in the same area to merge")
  if getRoomArea(top_room) ~= getRoomArea(bottom_room) then
    log:error("Rooms must be located in the same area to merge")
    return
  end

  local top_exits = getRoomExits(top_room)
  local bottom_exits = getRoomExits(bottom_room)
  local top_special_exits = getSpecialExitsSwap(top_room)
  local bottom_special_exits = getSpecialExitsSwap(bottom_room)

  -- Remap all exits from the top room to the bottom room, excluding fake rooms
  for exit_dir, id in pairs(top_exits) do
    exit_dir = daagar.map:normalizeDirToShort(exit_dir)
    if getRoomAreaName(getRoomArea(id)) == daagar.map.current_area then
      local other_room_exits = getRoomExits(id)
      --display(other_room_exits)
      local opposite = daagar.map:getOppositeDir(exit_dir)
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
  daagar.map:setRoomById(daagar.map.current_room)
end


function daagar.map:createNewRoom(roomname, roomdesc, roomexits)

	if daagar.map.current_area == "" then
		log:error("No area set! Use 'setarea <name>' first.")
		return
	end

	local area_id = daagar.map:getAreaId(daagar.map.current_area)
	if area_id == nil then
		log:error("Failed to find area id, room creation aborted")
		return
	end

	daagar.map.prior_room = daagar.map.current_room

	-- Start creating a new room
	local room_id = createRoomID()
	addRoom(room_id)
	setRoomName(room_id, roomname)
	setRoomUserData(room_id, "description", roomdesc)
	setRoomCoordinates(room_id, daagar.map.current_x, daagar.map.current_y, daagar.map.current_z)

  local overlapping_room = daagar.map:isRoomOverlapping(area_id, room_id)

  if overlapping_room then
    log:debug("Found overlapping room")
    -- When mapping special exits, we remove the newly created room as unneccessary
    if daagar.map:isSameRoom(room_id, overlapping_room) and daagar.map.isSpecialMapping then
      deleteRoom(room_id)
			daagar.map.current_x, daagar.map.current_y, daagar.map.current_z = getRoomCoordinates(overlapping_room)
			daagar.map.current_room = overlapping_room
      centerview(overlapping_room)
      return overlapping_room 
    elseif daagar.map:isSameRoom(room_id, overlapping_room) then

			log:debug(".. it is a duplicate room")
			daagar.map:connectExitToHere(overlapping_room)
			centerview(overlapping_room)
			daagar.map.current_x, daagar.map.current_y, daagar.map.current_z = getRoomCoordinates(overlapping_room)
			daagar.map.current_room = overlapping_room
      return overlapping_room
    else
      log:debug("Moving other rooms out of the way")
      daagar.map:moveCollidingRooms(area_id)
		end
  end

 	daagar.map:connectExitToHere(room_id)

  -- Otherwise, add it to the current area
  daagar.map.current_room = room_id
  setRoomArea(room_id, area_id)

  daagar.map:createFakeExits(room_id, roomexits)

  --echo("[[createNewRoom: Created new room with id: "..room_id.."]]\n")
  centerview(room_id)
  return room_id 
 end

function daagar.map:moveCollidingRooms(area_id)
    -- Move all rooms along the axis of movement away to make room for the new room. 
    local x_axis_pos = {"e"}
    local x_axis_neg = {"w"}
    local y_axis_pos = {"n", "nw", "ne" }
    local y_axis_neg = {"s", "sw", "se" } 
    local z_axis_pos = {"u"}
    local z_axis_neg = {"d"}

    local rooms = getAreaRooms(area_id)

    if table.contains(y_axis_pos, daagar.map.dir) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if y >= daagar.map.current_y then
          setRoomCoordinates(id, x, y+2, z)
        end
      end
    elseif table.contains(y_axis_neg, daagar.map.dir) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if y <= daagar.map.current_y then
          setRoomCoordinates(id, x, y-2, z)
        end
      end
    elseif table.contains(x_axis_pos, daagar.map.dir) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if x >= daagar.map.current_x then
          setRoomCoordinates(id, x+2, y, z)
        end
      end
    elseif table.contains(x_axis_neg, daagar.map.dir) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if x <= daagar.map.current_x then
          setRoomCoordinates(id, x-2, y, z)
        end
      end
    elseif table.contains(z_axis_pos, daagar.map.dir) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if z >= daagar.map.current_z then
          setRoomCoordinates(id, x, y, z+2)
        end
      end
    elseif table.contains(z_axis_neg, daagar.map.dir) then
      for name, id in pairs(rooms) do
        local x,y,z = getRoomCoordinates(id)
        if z <= daagar.map.current_z then
          setRoomCoordinates(id, x, y, z-2)
        end
      end
    end

end

function daagar.map:connectExitToHere(room_id)
	local direction = daagar.map.dir
	-- Make the bad assumption that exits will always be two way when
	-- they are cardinal directions. 
	local opposite_direction = daagar.map:getOppositeDir(direction)
	--echo("[[connectExit: Orig. direction: "..direction.." Opposite: "..opposite_direction.."]]\n")

	-- If we don't know what our prior room was, bail
	if(daagar.map.prior_room == 0) then
		log:debug("No prior room defined, no exit creation.")
		return
	end

	-- Is there already an exit connected?
	log:debug("Prior room id: "..daagar.map.prior_room)
	local t = getRoomExits(daagar.map.prior_room)
	if t[direction] == room_id then
		log:debug("Room exit already found to here. No action for connecting exits.")
	else
		setExit(daagar.map.prior_room, room_id, direction)
		log:debug("Set exit from prior room to here")
	end

	setExit(room_id, daagar.map.prior_room, opposite_direction)
	log:debug("Set exit from here to prior room")
end

function daagar.map:linkSpecialExit(move_command, dir)

	-- Find the room in <dir> direction
	local x,y,z = daagar.map:getRelativeCoords(dir)
	--echo("Relative:"..x..y..z.."\n")
	local t = getRoomsByPosition(getRoomArea(daagar.map.current_room), daagar.map.current_x+x, daagar.map.current_y+y, daagar.map.current_z+z)

  -- A room should have already been created before calling this function
  --assert(table.size(t) ~= 0, "(mapper): ERROR - Got an empty table in linkSpecialExit()\n")
  if table.size(t) == 0 then
    log:debug("Got an empty table in linkSpecialExit()")
    return
  end

	--display(t)

	-- Oops, the map is messy - too many rooms stacked
	if table.size(t) > 1 then
		log:error("Too many rooms in that location - please rearrange map")
		return
	end

	-- Link to the new room just created
	local room_to_link = t[0]
	addSpecialExit(room_to_link, daagar.map.current_room, move_command)
  --local t = getRoomExits(room_to_link)
  --if getRoomArea(t[daagar.map.DIR_OPPOSITE[dir]]) == daagar.map.current_area then
	setExit(room_to_link, -1, daagar.map.DIR_OPPOSITE[dir])
  --end
	setExit(daagar.map.current_room, -1, dir)
	setRoomChar(daagar.map.current_room, "_")
	log:debug("Special exit added")
end

function daagar.map:isRoomOverlapping(area_id, new_room)
  local t = getRoomsByPosition(area_id, daagar.map.current_x, daagar.map.current_y, daagar.map.current_z)
  if t then return t[0] else return false end -- t is nil on first room of area
end

function daagar.map:checkDuplicateRoom(area_id, new_room)
	-- WARNING: getRoomsByPosition starts indexing at 0, so we can't check
	-- the array size with #t. Instead, we have to try pulling from it.
	local t = getRoomsByPosition(area_id, daagar.map.current_x, daagar.map.current_y, daagar.map.current_z)
	--display(t)
	--echo("Found # rooms at this spot: "..table.getn(t).."\n")
	if t[0] then
		-- Too many rooms overlapping?
		if t[1] then
			log:error("Too many rooms overlapping - please adjust map")
			return true
		end

		-- Is it the same room?
		local room_to_check = t[0]
		if daagar.map:isSameRoom(new_room, room_to_check) then
			--echo("[[checkDupes: Duplicate room found in that direction, moving there]]\n")
			daagar.map:connectExitToHere(room_to_check)
			centerview(room_to_check)
			daagar.map.current_x, daagar.map.current_y, daagar.map.current_z = getRoomCoordinates(room_to_check)
			daagar.map.current_room = room_to_check
		end

		return true
	end

	log:debug("No duplicate room found at location")
	return false
end

-- Compare two rooms by name and room description
function daagar.map:isSameRoom(source, destination)
	if getRoomName(source) == getRoomName(destination) and
		getRoomUserData(source, "description") == getRoomUserData(destination, "description") then
		return true
	end

	return false
end
-- By creating rooms in a 'bogus' area, we can get exit arrows on rooms
-- to show unexplored exits. 
function daagar.map:createFakeExits(room_id, seen_exits)
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
		if table.contains(daagar.map.DIR_LONG, dir) then
			local room_id = createRoomID()
			addRoom(room_id)
			setRoomName(room_id, tostring(room_id)..":"..daagar.map.current_area)
			setRoomArea(room_id, daagar.map.fake_area)
			setExit(daagar.map.current_room, room_id, daagar.map:normalizeDirToShort(dir))
			--echo("[[fake: Created fake room "..room_id.." with exit from "..current_room.."]]\n")
		else
			setRoomChar(id, ">")
			--echo("[[fake: Created fake room character]]\n")
		end
	end

end

function daagar.map:moveCurrentRoomToArea(area_name)
  --assert(daagar.map.current_room ~= 0, "ERROR: Don't know what room you are in!")
  daagar.map:moveRoomToArea(daagar.map.current_room, area_name)
end

function daagar.map:moveRoomToArea(room_id, area_name)
 local areas = getAreaTable()
 if not table.contains(areas, area_name) then
   log:error("(mapper) No such area!")
 end

 local area_id = areas[area_name]
 setRoomArea(room_id, area_id)
 expandAlias("mfind",false)

end


------------------------
--   Utility        --
------------------------


function daagar.map:followDirection(dir)
	if daagar.map.current_room == 0 then return end

	-- If it is a normal compass direction...
	if daagar.map:isCardinalDirection(dir) then
    daagar.map:setNewCoordinates(dir)
		local t = getRoomExits(daagar.map.current_room)
		local existing_room = t[daagar.map:normalizeDirToLong(dir)]
		daagar.map:setMapToExistingRoom(existing_room)
	else
		local t = getSpecialExitsSwap(daagar.map.current_room)
		local existing_room = t[dir]

		--display(t)
		if t and table.contains(t, dir) then
			log:debug("Found known special exits")
			daagar.map:setMapToExistingRoom(existing_room)
		end
	end

end

function daagar.map:setMapToExistingRoom(room_id)
  if speedwalking then
    --display(roomname)
    --display(getRoomName(room_id))
    if getRoomName(room_id) == roomname then
      daagar.map:setRoomById(room_id)
    else
      log:error("Speedwalk Aborted! Expected room not seen")
      speedwalk = false
      disableTrigger("walking")
      enableTrigger("roomname")
      daagar.map.path = {}
    end
  elseif room_id and 
	  getRoomName(room_id) == roomname then 
	  --getRoomUserData(room_id, "description") == roomdesc then
		log:debug("Moving to existing room"..room_id)
  	daagar.map:setRoomById(room_id)
	end
end

-- Attempt to map a special exit. Returns true if a new room is created as a result, otherwise false
function daagar.map:mapSpecialExit(dir)
  local mapped_special = false
 	local special_exit, newdir = string.match(dir,">(.*)>(%w+)")
  --display("dir passed in:" ..dir)

  if not daagar.map:isCardinalDirection(dir) and newdir then
    log:debug("Mapping "..special_exit.." to direction "..newdir)
    daagar.map.dir = newdir
    daagar.map:mapDirection(newdir)
    daagar.map:linkSpecialExit(special_exit, daagar.map.DIR_OPPOSITE[newdir])
    mapped_special = true
  end
  daagar.map.isSpecialMapping = false
  return mapped_special
end

function daagar.map:mapDirection(dir)
	--echo("[[mapDir: Found command: "..dir .. "]]\n")

  -- If it is a special exit command, map it
  --if daagar.map:mapSpecialExit(dir) then return end
  
  if daagar.map.current_room == 0 then
		log:info("Creating first room of area")
		daagar.map:createNewRoom(roomname, roomdesc, exittable)
    return
	end

  if not daagar.map:isCardinalDirection(dir) then
    daagar.map:followDirection(dir)
    return
  end

  daagar.map:setNewCoordinates(dir)
	local t = getRoomExits(daagar.map.current_room)
  --display(t)
	local existing_room = t[daagar.map.DIR_EXPAND[dir]]
  --display(existing_room)
  if existing_room and getRoomAreaName(getRoomArea(existing_room)) ~= "fakeexitarea" then
    --echo("[[mapDir: Found an existing room at this exit: id: "..existing_room.."]]\n")
	  daagar.map:setRoomById(existing_room)
  elseif existing_room and getRoomAreaName(getRoomArea(existing_room)) == "fakeexitarea" then
	  deleteRoom(existing_room)
	  daagar.map:createNewRoom(roomname, roomdesc, exittable)
  else
    daagar.map:createNewRoom(roomname, roomdesc, exittable)
  end

  local t = getSpecialExitsSwap(daagar.map.current_room)
	local existing_room = t[dir]
	--display(t)
	if table.contains(t, dir) then
		--echo("[[follow: Found known special exits]]\n")
		daagar.map:setMapToExistingRoom(existing_room)
	end
end



-- For a given direction, give the relative coordinates from "here"
function daagar.map:getRelativeCoords(direction)
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

function daagar.map:setLastCoordinates()
	daagar.map.last_x = daagar.map.current_x
	daagar.map.last_y = daagar.map.current_y
	daagar.map.last_z = daagar.map.current_z
end

function daagar.map:setNewCoordinates(direction)
  --display(direction)
    local direction = daagar.map:normalizeDirToShort(direction)
		daagar.map:setLastCoordinates()

		local x,y,z = daagar.map:getRelativeCoords(direction)
		--echo("[[newCoords: x, y, z: "..x..", "..y.." ,"..z.."]]\n")
		daagar.map.current_x = daagar.map.current_x + x
		daagar.map.current_y = daagar.map.current_y + y
		daagar.map.current_z = daagar.map.current_z + z
end





