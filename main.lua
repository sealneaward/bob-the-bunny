local levels = {
  {
    start_position = {track = 1, row = 1},
    end_position = {track = 2, row = 8},
    modifiers = {
      {type = 'down', track = 1, row = 2},
      {type = 'right', track = 2, row = 2},
      {type = 'down', track = 2, row = 5}
    },
    carrots = {}
  },
  {
    start_position = {track = 1, row = 1},
    end_position = {track = 3, row = 8},
    modifiers = {
      {type = 'down', track = 1, row = 2},
      {type = 'right', track = 2, row = 2},
      {type = 'right', track = 2, row = 6},
      {type = 'left', track = 3, row = 1}
    },
    carrots = {
      {track = 2, row = 4}
    }
  }
}

local current_level = 0 -- 0 is title screen, otherwise level ID
local map

local ROWS = 8
local TRACKS = 3
local SCALE = 2

local bunny
local modifiers
local house
local carrots

local game_timer = 1.0
local animation_frame = 1 -- or 2

local paused = false

local images = {}
local songs = {}

local grabbed_modifier

function setLevel(level)
  current_level = level

  if level == 0 then
    love.audio.stop()
    love.audio.rewind(songs.title)
    love.audio.play(songs.title)
    return
  elseif level == 1 then
    love.audio.stop()
    love.audio.rewind(songs.level)
    love.audio.play(songs.level)
  elseif level > #levels then
    return
  end

  bunny = levels[level].start_position
  house = levels[level].end_position
  modifiers = levels[level].modifiers
  carrots = levels[level].carrots

  -- If there's two portals, link them
  local first_portal
  for i, modifier in ipairs(modifiers) do
    if modifier.type == 'portal' then
      if not first_portal then
        first_portal = modifier
      else
        modifier.other_end = first_portal
        first_portal.other_end = modifier
        break
      end
    end
  end
end

function trackToX(track)
  return 32*SCALE + (track - 1) * 3 * 32*SCALE
end

function rowToY(row)
  return 32*SCALE + (row - 1) * 32*SCALE
end

function xToTrack(x)
  if x < 32 * SCALE then
    return nil
  end

  local q = math.floor((x - 32 * SCALE) / (3 * 32 * SCALE))
  local r = math.mod(x - 32 * SCALE, 3 * 32 * SCALE)

  if r > 32 * SCALE then
    return nil
  end

  return q + 1
end

function yToRow(y)
  local row = math.floor(y / (32 * SCALE))
  if row > 0 then
    return row
  end
  return nil
end

function love.load()
  love.window.setMode(576, 640)
  love.window.setTitle('Bob the Bunny Teaches Programming')

  -- Load images
  images.bunny_1 = love.graphics.newImage('Assets/bunny_1.png')
  images.bunny_2 = love.graphics.newImage('Assets/bunny_2.png')
  images.house = love.graphics.newImage('Assets/house.png')
  images.background = love.graphics.newImage('Assets/background.png')
  images.title = love.graphics.newImage('Assets/title.png')
  images.enter_prompt = love.graphics.newImage('Assets/Press-Enter.png')
  images.win_screen = love.graphics.newImage('Assets/YOU-WIN.png')
  images.carrot_pickup = love.graphics.newImage('Assets/carrot_pickup.png')
  images.carrot_icon = love.graphics.newImage('Assets/carrot_icon.png')

  images.bunny_1:setFilter('nearest')
  images.bunny_2:setFilter('nearest')
  images.house:setFilter('nearest')
  images.background:setFilter('nearest')

  images.modifiers = {}
  images.modifiers.down = love.graphics.newImage('Assets/down.png')
  images.modifiers.left = love.graphics.newImage('Assets/left.png')
  images.modifiers.right = love.graphics.newImage('Assets/right.png')
  images.modifiers.restart = love.graphics.newImage('Assets/restart.png')
  images.modifiers.portal = love.graphics.newImage('Assets/portal.png')

  for k, image in pairs(images.modifiers) do
    image:setFilter('nearest')
  end

  -- Load songs
  songs.title = love.audio.newSource('Assets/Jumpshot.mp3')
  songs.level = love.audio.newSource('Assets/Chibi Ninja.mp3')

  -- Play the title theme
  love.audio.play(songs.title)
end

function love.keypressed(key)
  if key == 'return' and current_level == 0 then
    setLevel(1)
  end
end

function love.mousepressed(x, y, button)
  if current_level == 0 or current_level > #levels or button ~= 'l' then
    return
  end

  local row = yToRow(y)
  local track = xToTrack(x)

  if not row or not track then
    return
  end

  -- Figure out which modifier is grabbed (if any)
  for i, modifier in ipairs(modifiers) do
    if modifier.row == row and modifier.track == track then
      grabbed_modifier = {
        type = modifier.type,
        x = trackToX(modifier.track),
        y = rowToY(modifier.row),
        original = modifier
      }
      love.audio.pause()
      break
    end
  end
end

function love.mousemoved(x, y, dx, dy)
  if grabbed_modifier then
    grabbed_modifier.x = grabbed_modifier.x + dx
    grabbed_modifier.y = grabbed_modifier.y + dy
  end
end

function love.mousereleased(x, y, button)
  if button ~= 'l' or not grabbed_modifier then
    return
  end

  local original = grabbed_modifier.original
  grabbed_modifier = nil
  love.audio.resume()

  local row = yToRow(y)
  local track = xToTrack(x)
  if not row or not track then
    return
  end

  -- Figure out which modifier is being dropped on (if any)
  for i, modifier in ipairs(modifiers) do
    if modifier.row == row and modifier.track == track then
      -- Check if it is being droped on itself
      if modifier == original then
        return
      end

      -- Swap the two modifiers
      local temp_row = modifier.row
      local temp_track = modifier.track
      modifier.row = original.row
      modifier.track = original.track
      original.row = temp_row
      original.track = temp_track
      break
    end
  end
end

function love.update(dt)
  if current_level == 0 or current_level > #levels then
    return
  end

  if grabbed_modifier then
    return
  end

  game_timer = game_timer - dt
  if game_timer < 0 then
    game_timer = 1
    -- Update the two-frame animation.
    if animation_frame == 1 then
      animation_frame = 2
    else
      animation_frame = 1
    end

    -- Check if Bob was on a modifier
    local on_modifier = false
    for i, modifier in ipairs(modifiers) do
      if modifier.row == bunny.row and modifier.track == bunny.track then
        on_modifier = true
        if modifier.type == 'down' then
          bunny.row = bunny.row + 1
          break
        elseif modifier.type == 'left' then
          if bunny.track > 1 then
            bunny.track = bunny.track - 1
          end
          break
        elseif modifier.type == 'right' then
          if bunny.track < TRACKS then
            bunny.track = bunny.track + 1
          end
          break
        elseif modifier.type == 'restart' then
          bunny.row = 1
          bunny.track = 1
          break
        elseif modifier.type == 'portal' then
          bunny.row = modifier.other_end.row + 1
          bunny.track = modifier.other_end.track
          break
        end
      end
    end

    if not on_modifier then
      bunny.row = bunny.row + 1
    end

    if bunny.row == house.row and bunny.track == house.track then
      setLevel(current_level + 1)
    end

    if bunny.row > ROWS then
      bunny.row = 1
      bunny.track = 1
    end
  end
end

function love.draw()
  -- Draw background
  love.graphics.draw(images.background, 0, 0, 0, 1, 1)

  if current_level == 0 then
    -- Title screen
    love.graphics.draw(images.title, 20, 140, 0, 0.75, 0.75)
    love.graphics.draw(images.enter_prompt, 160, 450, 0, 0.5, 0.5)
  elseif current_level <= #levels then
    -- Main game
    local x, y

    -- Draw house
    x = trackToX(house.track)
    y = rowToY(house.row)
    love.graphics.draw(images.house, x, y, 0, SCALE, SCALE)

    -- Draw modifiers
    for i, modifier in ipairs(modifiers) do
      x = trackToX(modifier.track)
      y = rowToY(modifier.row)
      love.graphics.draw(images.modifiers[modifier.type], x, y, 0, SCALE, SCALE)
    end

    -- Draw carrots
    for i, carrot in ipairs(carrots) do
      x = trackToX(carrot.track)
      y = rowToY(carrot.row)
      love.graphics.draw(images.carrot_pickup, x, y, 0, SCALE, SCALE)
    end

    -- Draw Bob
    x = trackToX(bunny.track)
    y = rowToY(bunny.row)
    if animation_frame == 1 then
      love.graphics.draw(images.bunny_1, x, y, 0, SCALE, SCALE)
    else
      love.graphics.draw(images.bunny_2, x, y, 0, SCALE, SCALE)
    end

    -- Draw grabbed modifier
    if grabbed_modifier then
      x = grabbed_modifier.x
      y = grabbed_modifier.y
      love.graphics.setColor(255, 255, 255, 128)
      love.graphics.draw(images.modifiers[grabbed_modifier.type], x, y, 0, SCALE, SCALE)
      love.graphics.setColor(255, 255, 255, 255)
    end
  else
    -- Player won the game.
    love.graphics.draw(images.win_screen, 90, 200, 0, 1, 1)
  end
end
