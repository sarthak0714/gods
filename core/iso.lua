local Iso = {}

function Iso.project(x, y, tileW, tileH)
    local sx = (x - y) * tileW / 2
    local sy = (x + y) * tileH / 2
    return sx, sy
end

function Iso.screenToWorld(sx, sy, tileW, tileH)
    local x = (sx / (tileW / 2) + sy / (tileH / 2)) / 2
    local y = (sy / (tileH / 2) - sx / (tileW / 2)) / 2
    return x, y
end

return Iso
