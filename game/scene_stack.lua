local M = {}

function M.new(initial)
    assert(initial, "initial scene is required")
    return { current = initial }
end

function M.switch(stack, nextScene, ...)
    assert(nextScene, "next scene is required")
    if stack.current.leave then stack.current:leave() end
    stack.current = nextScene
    if stack.current.enter then stack.current:enter(...) end
end

function M.update(stack, dt)
    if stack.current.update then stack.current:update(dt) end
end

function M.draw(stack)
    if stack.current.draw then stack.current:draw() end
end

function M.keypressed(stack, key)
    if stack.current.keypressed then stack.current:keypressed(key) end
end

function M.touchpressed(stack, id, x, y)
    if stack.current.touchpressed then stack.current:touchpressed(id, x, y) end
end

function M.touchmoved(stack, id, x, y)
    if stack.current.touchmoved then stack.current:touchmoved(id, x, y) end
end

function M.touchreleased(stack, id, x, y)
    if stack.current.touchreleased then stack.current:touchreleased(id, x, y) end
end

return M
