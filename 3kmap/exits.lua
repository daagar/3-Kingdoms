daagar.map.DIR_SHORT = {"n", "ne", "nw", "e", "w", "s", "se", "sw", "u", "d"}
daagar.map.DIR_LONG = {"north", "northeast", "northwest", "east", "west", "south", "southeast", "southwest", "up", "down"}


daagar.map.DIR_SHRINK = {
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

daagar.map.DIR_EXPAND = {
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

daagar.map.DIR_OPPOSITE = {	
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


function daagar.map:isCardinalDirection(command)
  local is_cardinal = false

	-- If it is a 'short' direction, spell it out (ie., s = south)
	daagar.map.command = daagar.map:normalizeDirToShort(daagar.map.command)
	--echo("[[isCardinal: normalized command: "..command.."]]\n")
	if table.contains(daagar.map.DIR_SHORT,daagar.map.command) then
	  is_cardinal = true	
	end

	return is_cardinal
end

-- Covert "long" directions to short (ie., north -> n)
function daagar.map:normalizeDirToShort(direction)
	if table.contains(daagar.map.DIR_LONG, direction) then
		direction = daagar.map.DIR_SHRINK[direction]
	end

	return direction
end

-- Convert "short" directions to long form (ie., n -> north)
function daagar.map:normalizeDirToLong(direction)
  if table.contains(daagar.map.DIR_SHORT, direction) then
    direction = daagar.map.DIR_EXPAND[direction]
  end

  return direction
end

-- Returns the short-form opposite to a given cardinal direction
function daagar.map:getOppositeDir(direction)
  --assert(table.contains(daagar.map.DIR_SHRINK, direction), "getOppositeDir: Invalid direction "..direction.."specified\n")
	return daagar.map.DIR_OPPOSITE[daagar.map:normalizeDirToShort(direction)]
end
