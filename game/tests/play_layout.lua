local layout = require("game.scenes.play_layout")

local M = {}

function M.run()
    print("  [R1] play_layout module tests...")

    local api = {}
    layout.install(api, { width = 720, height = 1280 })

    assert(api.returnControls.top == 244 and api.returnControls.bottom == 288,
        "R1: returning controls must retain their accessible touch band")
    assert(api.ascendControls.top == api.returnControls.top
            and api.ascendControls.bottom == api.returnControls.bottom,
        "R1: ascending and returning controls must retain matching bands")
    assert(api.settlementTouchRows[1].columns[1].key == "hull"
            and api.settlementTouchRows[5].key == "relaunch",
        "R1: settlement hit rows must retain their action routing")

    local shop = api.settlementShopLayout()
    assert(shop.slot.top == api.settlementTouchRows[4].top
            and shop.relaunch.bottom == api.settlementTouchRows[5].bottom,
        "R1: settlement shop layout must derive from installed touch rows")

    local pause = api.pauseMenuRects()
    assert(pause.restart.x == 210 and pause.restart.w == 300
            and pause.mainMenu.y == pause.restart.y + pause.restart.h + 20,
        "R1: pause actions must remain centered and vertically separated")

    local ax, ay, aw, ah = layout.adminButtonRect(2, 300)
    assert(ax == 640 and ay == 394 and aw == 72 and ah == 36,
        "R1: admin controls must retain their stacked layout")
    assert(api.settlementRowBackgroundColor(1) == api.settlementRowBackgroundColors[1]
            and api.settlementRowBackgroundColor(3) == api.settlementRowBackgroundColors[1],
        "R1: settlement row shading must retain alternating colors")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_layout"%)'),
        "R1: play.lua must delegate control and settlement layout")
    assert(not playSource:find("local settlementTouchRows%s*=%s*{"),
        "R1: settlement touch-row definitions must leave play.lua")
    assert(not playSource:find("local function adminButtonRect"),
        "R1: admin button layout must leave play.lua")

    print("  R1 play_layout module OK")
end

return M