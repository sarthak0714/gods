local Iso = {}

function Iso.project(x, y, tileW, tileH)
    return (x - y) * tileW / 2,
        (x + y) * tileH / 2
end

return Iso
