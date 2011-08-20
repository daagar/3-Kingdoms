
function daagar.log:debug(msg)
  if daagar.log.enableDebug then
    cecho("\n<dark_slate_grey>[[<dark_orchid>(DEBUG):<light_grey> "..msg.." <dark_slate_grey>]]\n")
  end
end

function daagar.log:info(msg)
  cecho("\n<dark_slate_grey>[[<light_slate_grey>(INFO):<light_grey> "..msg.." <dark_slate_grey>]]\n")
end

function daagar.log:error(msg)
  cecho("\n<dark_slate_grey>[[<firebrick_red>(ERROR):<light_grey> "..msg.." <dark_slate_grey>]]\n")
end
