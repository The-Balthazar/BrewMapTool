function love.conf(t)
    t.version = "12.0"
    t.console = true
    t.externalstorage = true

    t.window = false

    t.modules.graphics = false
    t.modules.window = false
    t.modules.font = false

    t.modules.image = false
    t.modules.timer = false
    t.modules.audio = false
    t.modules.joystick = false
    t.modules.keyboard = false
    t.modules.physics = false
    t.modules.sound = false
    t.modules.touch = false
    t.modules.video = false
end
