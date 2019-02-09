--
-- Minetest chat channels
--
-- Allows you to send all messages as PMs.
--

local main_channel = '#main'
local channel = main_channel
local storage = minetest.get_mod_storage()
local channels = {}
local connected_players = {}
local messages_sent = 0
local status_sent = 0
local buffer = ''
local localplayer = '[you]'
local show_main_channel = true
local initial_status = true
local strip_colours
if storage:get_string('strip_colours') == 'yes' then
    strip_colours = true
else
    strip_colours = false
end
chat_channels = {}

if storage:get_string('channels') then
    channels = loadstring(storage:get_string('channels'))()
end

if not channels then channels = {} end



-- Support older versions of MT.
local function depluralify_register(n)
    n = 'register_on_' .. n
    if not minetest[n] then
        minetest[n] = minetest[n .. 's']
    end
end

depluralify_register('sending_chat_message')
depluralify_register('receiving_chat_message')

depluralify_register = nil

-- Get the localplayer
minetest.register_on_connect(function()
    localplayer = minetest.localplayer:get_name()
    if localplayer == 'singleplayer' then
        connected_players[localplayer] = true
    end
end)

chat_channels.player_in_channel = function(v, c)
    local in_channel = false
    if not c then c = channel end
    if channels[c] then
        for p = 1, #channels[c] do
            if channels[c][p] == v then
                in_channel = p
                break
            end
        end
    end
    return in_channel
end

local save = function()
    storage:set_string('channels', minetest.serialize(channels))
end

chat_channels.get_channel_users = function(c)
    if not c then c = channel end
    if c == main_channel then return false end
    local prefix = c:sub(1, 1)
    local name = c:sub(2)
    if prefix == '#' then
        local u = channels[name]
        if u and #u > 0 then
            local i = chat_channels.player_in_channel(localplayer, name)
            if i then
                table.remove(channels[name], i)
                save()
            end
            return channels[name]
        else
            if u then
                channels[name] = false
            end
            show_main_channel = true
            channel = main_channel
            return false
        end
    elseif prefix == '@' then
        if not connected_players[name] then
            local empty           = true
            local visible_players = minetest.get_player_names()
            for _, player in ipairs(visible_players) do
                if player == name then
                    empty = false
                    break
                end
            end
            if empty then return {} end
        end
        return {name}
    else
        show_main_channel = true
        channel = main_channel
        return false
    end
end

chat_channels.send_message = function(msg, c)
    if not c or c == '' then c = channel end
    prefix = c:sub(1, 1)
    if prefix ~= '#' and prefix ~= '@' then
        return false, 'Channels must start in either # or @.'
    elseif c == '@' then
        minetest.display_chat_message('-!- <' .. localplayer .. '> ' .. msg)
        return true, 'Message sent!'
    elseif c == main_channel then
        show_main_channel = true
        minetest.send_chat_message(msg)
        return true, 'Message sent!'
    elseif c == '@[off]' then
        show_main_channel = true
        minetest.send_chat_message('[off] ' .. msg)
        return true, 'Message sent!'
    elseif c:sub(1, 2) == '@/' then
        minetest.run_server_chatcommand(c:sub(3):gsub('%.', ' '), msg)
        if c == '@/s' then
            minetest.display_chat_message('-' .. main_channel .. '- <' ..
                localplayer .. '> (s) ' .. msg)
        end
        return true, 'Message sent!'
    elseif prefix == '#' and not channels[c:sub(2)] then
        if c == channel then channel = '@' end
        return false, 'The channel ' .. c .. ' does not exist!'
    end
    local players = chat_channels.get_channel_users(c)
    if not players then return end
    for p = 1, #players do
        if connected_players[players[p]] then
            messages_sent = messages_sent + 1
            minetest.run_server_chatcommand('msg', players[p] .. ' -' .. c ..
                '- ' .. msg)
        end
    end

    if messages_sent > 0 then
        if #buffer > 0 then buffer = buffer .. '\n' end
        buffer = buffer .. '-' .. c .. '- <' .. localplayer .. '> ' .. msg
    else
        if channel == c then channel = '@' end
        return false, 'The channel ' .. c .. ' is empty.'
    end
    return true, 'Message sent!'
end

minetest.register_on_sending_chat_message(function(msg)
    local cmdprefix = msg:sub(1, 1)
    local c = channel
    if cmdprefix == '/' or cmdprefix == '.' then
        return
    elseif cmdprefix == '#' or cmdprefix == '@' then
        local s, e = msg:find(' ')
        if s then
            c = msg:sub(1, s - 1)
            msg = msg:sub(s + 1)
        else
            if cmdprefix ~= '#' or channels[msg:sub(2)] or msg == main_channel
              then
                local players = chat_channels.get_channel_users(msg)
                if players and msg ~= '@' and msg:sub(1, 2) ~= '@/' then
                    local empty           = true
                    local visible_players = minetest.get_player_names()
                    for p = 1, #players do
                        if connected_players[players[p]]
                          or visible_players[players[p]] then
                            empty = false
                            break
                        end
                    end
                    if empty then
                        minetest.display_chat_message('The channel ' .. msg ..
                            ' is empty.')
                        return true
                    end
                end
                channel = msg
                if channel == main_channel then
                    show_main_channel = true
                end
                minetest.display_chat_message('You have changed chat channels to '
                    .. channel)
                return true
            end
            c = msg
            msg = ''
        end
        if c == main_channel then
            if connected_players[localplayer] then
                show_main_channel = true
                minetest.send_chat_message(msg)
                return true
            end
        elseif cmdprefix == '#' and not channels[c:sub(2)] then
            minetest.display_chat_message('The channel ' .. c ..
                ' was not found.')
            return true
        end
    end
    if c == main_channel and connected_players[localplayer] then
        return
    end
    local s, n = chat_channels.send_message(msg, c)
    if not s then
        minetest.display_chat_message(n)
    end
    return true
end)

chat_channels.display_without_colours = function(msg)
    if strip_colours then
        minetest.display_chat_message(msg)
        return true
    end
end

local strip_newlines = function(msg)
    local msg, c = msg:gsub('\n', '\n --- ')
    return msg
end


minetest.register_on_receiving_chat_message(function(msg)
    local m = minetest.strip_colors(msg)
    if strip_colours then msg = m end
    msg = strip_newlines(msg)
    if m == 'Message sent.' or m:match('^The player .* is not online.$')
      or m:match('^Your PM has been sent to') then
        if messages_sent > 0 then
          messages_sent = messages_sent - 1
          if messages_sent == 0 and #buffer > 0 then
              minetest.display_chat_message(buffer)
              buffer = ''
          end
          return true
        end
    elseif m:sub(1, 1) == '<' then
        if not show_main_channel then return true end
        local hijack = false
        if channel == main_channel then
            for _ in pairs(channels) do
                hijack = true
                break
            end
        else
            hijack = true
        end
        if hijack then
            if m:match('^<[^>]*> %[off%]') then
                local s, e   = m:find('[off]')
                local sender = m:sub(1, s - 2)
                local text   = m:sub(s + 5)
                minetest.display_chat_message('-[off]- ' .. sender .. text)
            else
                minetest.display_chat_message('-' .. main_channel .. '- '
                    .. msg)
            end
            return true
        end
    elseif m:match('^PM from [^\\- ]*: -[^ ]*- ') then
        local s, e = msg:find('-[^ ]*- ')
        if not s then return chat_channels.display_without_colours(msg) end
        local prefix = msg:sub(s + 1, s + 1)
        if prefix ~= '#' then
            return chat_channels.display_without_colours(msg)
        end
        local chan = msg:sub(s + 2, e - 2)
        local text = msg:sub(e + 1)
        local user = m:sub(9)
        local s, e = user:find(': ')
        local user = user:sub(1, s - 1)

        if chat_channels.player_in_channel(user, chan) then
            minetest.display_chat_message('-#' .. chan .. '- <' .. user ..
                '> ' .. text)
            return true
        end
    elseif m:match('^%*%*%* [^ ]* joined the game.$') then
        local s, e = m:find(' ')
        local victim = m:sub(s + 1)
        local s, e = victim:find(' ')
        local victim = victim:sub(1, s - 1)
        connected_players[victim] = true
    elseif m:match('^%*%*%* [^ ]* left the game') then
        local s, e = m:find(' ')
        local victim = m:sub(s + 1)
        local s, e = victim:find(' ')
        local victim = victim:sub(1, s - 1)
        connected_players[victim] = nil
    elseif m:match('^# Server: version=[^{]+, clients={[^}]*}') then
        local s, e = m:find('{')
        local list = m:sub(s + 1, #m)
        local s, e = list:find('}')
        local list = list:sub(1, s - 1)
        connected_players = {}
        for player in string.gmatch(list, "[^(, )]*") do
            if #player > 0 then
                connected_players[player] = true
            end
        end
        if initial_status and localplayer ~= '[you]' then
            initial_status = nil
            connected_players[localplayer] = true
        end
        if status_sent > 0 then
            status_sent = status_sent - 1
            return true
        end
    end

    return chat_channels.display_without_colours(m)
end)

minetest.register_chatcommand('add_to_channel', {
    params = "<victim> [channel]",
    description = "Add a player to a local chat channel.",
    func = function(param)
        local s, e = param:find(' ')
        local v
        local c
        if s then
            v = param:sub(1, s - 1)
            c = param:sub(s + 1)
        else
            v = param
            c = channel
            if v:find(' ') then v = '' end
        end
        if v == '' or c == '' or c:find(' ') or c:sub(1, 1) ~= '#' or c == '#'
          then
            return false, "Invalid syntax! Usage: .add_to_channel <victim> [channel]"
        elseif c == main_channel then
            return false, "You cannot add users to the main channel!"
        elseif v == localplayer then
            return false, "You cannot add yourself to a channel!"
        end
        c = c:sub(2)
        if channels[c] then
            if chat_channels.player_in_channel(v, c) then
                return true, "That player is already in the channel!"
            end
        else
            channels[c] = {}
        end
        table.insert(channels[c], v)
        save()
        return true, "Done!"
    end
})

minetest.register_chatcommand('remove_from_channel', {
    params = "<victim> [channel]",
    description = "Remove a player from a local chat channel.",
    func = function(param)
        local s, e = param:find(' ')
        local v
        local c
        if s then
            v = param:sub(1, s - 1)
            c = param:sub(s + 1)
        else
            v = param
            c = channel
            if v:find(' ') then v = '' end
        end
        if v == '' or c == '' or c:find(' ') or c:sub(1, 1) ~= '#' then
            return false, "Invalid syntax! Usage: .remove_from_channel <victim> [channel]"
        elseif c == main_channel then
            return false, "You cannot remove users to the main channel!"
        elseif v == localplayer then
            return false, "You cannot remove yourself from a channel!"
        end
        c = c:sub(2)
        local in_channel = chat_channels.player_in_channel(v, c)
        if in_channel then
            table.remove(channels[c], in_channel)
            if #channels[c] < 1 then channels[c] = nil end
            save()
            return true, "Done!"
        else
            return true, "The player is not in the channel!"
        end
    end
})

minetest.register_chatcommand('list_channels', {
    params = "",
    description = "Lists the channels.",
    func = function()
        local c = {}
        for i, _ in pairs(channels) do
            table.insert(c, i)
        end
        return true, "List of channels: " .. table.concat(c, ', ')
    end
})

minetest.register_chatcommand('delete_channel', {
    params = "<channel>",
    description = "Removes a channel.",
    func = function(c)
        if c:sub(1, 1) ~= '#' then
            return false, "The channel must start with a #."
        end
        c = c:sub(2)
        if not channels[c] then
            return false, "The channel does not exist!"
        end
        channels[c] = nil
        save()
        return true, "Channel #" .. c .. " is no longer."
    end
})

minetest.register_chatcommand('toggle_' .. main_channel:sub(2), {
    params = "",
    description = "Toggle between showing and hiding messages from "
        .. main_channel .. ".",
    func = function(c)
        if not show_main_channel then
            show_main_channel = true
            return true, "You will now start to receive messages from "
                .. main_channel .. "."
        elseif channel == main_channel or channel == '@[off]' or
          channel:sub(1, 2) == '@/' then
            return false, "You are currently in " .. main_channel
                .. "! Please change channels first."
        else
            show_main_channel = false
            return true, "You will no longer receive messages from "
                .. main_channel .. "."
        end
    end
})

minetest.register_chatcommand('who', {
    params = "[channel]",
    description = "List players in the current chat channel.",
    func = function(c)
        if c == '' then c = channel end
        if c:sub(1, 1) ~= '#' then
            return false, "The channel must start with a #."
        end
        c = c:sub(2)
        local players
        if c == main_channel:sub(2) then
            players = {localplayer}
            for player, _ in pairs(connected_players) do
                if player ~= localplayer and _ then
                    table.insert(players, player)
                end
            end
        elseif channels[c] then
            local u = table.unpack or unpack
            players = {localplayer,
                u(channels[c])}
        else
            players = {}
        end
        table.sort(players)
        players = table.concat(players, ', ')
        return true, "List of players in #" .. c .. ": " .. players
    end
})

minetest.register_chatcommand('coords', {
    params = "[channel]",
    description = "Send your co-ordinates to chat.",
    func = function(c)
        local pos = minetest.localplayer:get_pos()
        local x = math.floor(pos.x)
        local y = math.floor(pos.y)
        local z = math.floor(pos.z)
        local msg = "Current Position: " .. x .. ", " .. y .. ", " .. z .. "."
        return chat_channels.send_message(msg, c)
    end
})

-- Get unique namespace for strip_colours def.
if true then
    local def = {
        params = "",
        description = "Toggles the stripping of coloured chat.",
        func = function(c)
            if strip_colours then
                strip_colours = false
            else
                strip_colours = true
            end
            storage:set_string("strip_colours", strip_colours and "yes" or "")
            return true, "Done! Colours are " .. (strip_colours and "now" or
                "no longer") .. " being stripped from chat messages."
        end
    }

    minetest.register_chatcommand('strip_colours', def)

    minetest.register_chatcommand('strip_colors',  def)
end
