
-----------
-- Init --
-----------

--fake_area = initFakeArea()

--------------------
-- Area Handling --
--------------------

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

function createArea(areaname)
  local area_id = addAreaName(areaname)

  if area_id == -1 then
    echo("[[createArea: Area name already exists!]]\n")
  else
    echo("[[createArea: New area created with id "..area_id.."]]\n")
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
