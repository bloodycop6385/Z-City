Randomplayer = Randomplayer or {}

function Randomplayer.Iterator()
    local players = player.GetAll()

    for i = #players, 2, -1 do
        local j = math.random(i)
        players[i], players[j] = players[j], players[i]
    end

    local i = 0
    return function()
        i = i + 1
        local ply = players[i]
        if ply == nil then return nil end
        return i, ply
    end
end
