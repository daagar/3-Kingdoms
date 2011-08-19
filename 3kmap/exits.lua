daagmap.DIR_SHORT = {"n", "s", "e", "w", "ne", "nw", "se", "sw", "u", "d"}
daagmap.DIR_LONG = {"north", "south", "east", "west", "northeast", "northwest", "southeast", "southwest", "up", "down"}

daagmap.DIR_SHRINK = {
  ["north"]="n", 
  ["south"]="s", 
  ["east"] = "e", 
  ["west"]="w", 
  ["northeast"]="ne", 
  ["northwest"]="nw", 
  ["southeast"]="se", 
  ["southwest"]="sw", 
  ["up"]="u", 
  ["down"]="d"
}

daagmap.DIR_EXPAND = {
  ["n"]="north", 
  ["s"]="south", 
  ["e"]="east", 
  ["w"]="west", 
  ["ne"]="northeast", 
  ["nw"]="northwest", 
  ["se"]="southeast", 
  ["sw"]="southwest", 
  ["u"]="up", 
  ["d"]="down"
}

daagmap.DIR_OPPOSITE = {	
  ["n"]="s", 	
  ["s"]="n",	
  ["w"]="e",	
  ["e"]="w",	
  ["ne"]="sw",
  ["nw"]="se",	
  ["sw"]="ne",	
  ["se"]="nw",	
  ["u"]="d",	
  ["d"]="u"
}


function daagmap:isCardinalDirection(command)
  local is_cardinal = false

	-- If it is a 'short' direction, spell it out (ie., s = south)
	daagmap.command = daagmap:normalizeDirToShort(daagmap.command)
	--echo("[[isCardinal: normalized command: "..command.."]]\n")
	if table.contains(daagmap.DIR_SHORT,daagmap.command) then
	  is_cardinal = true	
	end

	return is_cardinal
end

-- Covert "long" directions to short (ie., north -> n)
function daagmap:normalizeDirToShort(direction)
	if table.contains(daagmap.DIR_LONG, direction) then
		direction = daagmap.DIR_SHRINK[direction]
	end

	return direction
end

-- Convert "short" directions to long form (ie., n -> north)
function daagmap:normalizeDirToLong(direction)
  if table.contains(daagmap.DIR_SHORT, direction) then
    direction = daagmap.DIR_EXPAND[direction]
  end

  return direction
end

-- Returns the short-form opposite to a given cardinal direction
function daagmap:getOppositeDir(direction)
  --assert(table.contains(daagmap.DIR_SHRINK, direction), "getOppositeDir: Invalid direction "..direction.."specified\n")
	return daagmap.DIR_OPPOSITE[daagmap:normalizeDirToShort(direction)]
end