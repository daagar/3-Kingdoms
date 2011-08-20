--------------------
-- Area Handling --
--------------------

-- Set the active area
-- Returns the areaname on success, "" otherwise
function daagar.map:setArea(areaname)
	local t = getAreaTable()
	--display(t)
	if table.contains(t, areaname) then
		log:info("Setting active area to '" .. areaname .. "'")
		return areaname
	else
		log:error("No such area as '"..areaname.."'. Please 'createarea' first")
	end

	return ""
end

-- Return an id for the given area name, nil if area doesn't exist
function daagar.map:getAreaId(areaname)
	local t = getAreaTable()
	local id = t[areaname]

	if id then
		--echo("[[getAreaId: Found area id of "..id.." for area name '"..areaname.."']]\n")
		return id
	else
		--echo("[[getAreaId: No id found for that area!]]\n")
	end

	return nil
end

-- Remove all rooms in the given area
function daagar.map:resetArea(areaname)
	local area_id = daagar.map:getAreaId(areaname)
--display(areaname)
--display(area_id)

	if area_id then
		local t = getAreaRooms(area_id)
		for k,v in pairs(t) do
			deleteRoom(v)
		end

		daagar.map.prior_room = 0
		daagar.map.current_room = 0
		log:info("All rooms removed")
	else
		log:error("Invalid area - no rooms removed")
	end
end

function daagar.map:createArea(areaname)
  local area_id = addAreaName(areaname)

  if area_id == -1 then
    log:error("Area name already exists!")
  else
    log:info("New area created with id "..area_id)
  end
end

function daagar.map:initFakeArea()
  local room_id = -1
	local fake_area_id = addAreaName("fakeexitarea")
	if fake_area_id == -1 then
		local t = getAreaTable()
		fake_area_id = t["fakeexitarea"]
  end

  room_id = getAreaRooms(fake_area_id)[0] 
  if room_id then
    log:debug("Fake room already created: "..room_id)
  else
    log:debug("Creating initial room in 'fakeexitarea'")
    room_id = createRoomID()
	  addRoom(room_id)
	  setRoomName(room_id, "Fake Room for exit mapping")
	  setRoomUserData(room_id, "description", "Fake room for purposes of keeping track of unexplored exits")
  	setRoomCoordinates(room_id, 0, 0, 0)
    setRoomArea(room_id, fake_area_id)
  end

  daagar.map.fake_room_id = room_id
	
	return fake_area_id
end
