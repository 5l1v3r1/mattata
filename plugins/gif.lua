--[[
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local gif = {}
local mattata = require('mattata')
local https = require('ssl.https')
local url = require('socket.url')
local json = require('dkjson')
local redis = require('libs.redis')

function gif:init()
    gif.commands = mattata.commands(self.info.username):command('gif'):command('giphy').table
    gif.help = '/gif <query> - Searches GIPHY for the given search query and returns a random, relevant result. Alias: /giphy.'
    gif.url = 'https://api.giphy.com/v1/gifs/search?api_key=dc6zaTOxFJmzC&q=' -- Includes the public test API key, because we don't have that many calls to it
end

function gif.on_inline_query(_, inline_query)
    local input = mattata.input(inline_query.query)
    if not input then
        return
    end
    local jstr = https.request(gif.url .. url.escape(input))
    local jdat = json.decode(jstr)
    local results = {}
    local id = 1
    for n in pairs(jdat.data) do
        local result = mattata.inline_result()
        :type('mpeg4_gif'):id(id)
        :mpeg4_url(jdat.data[n].images.original.mp4)
        :thumb_url(jdat.data[n].images.fixed_height.url)
        :mpeg4_width(jdat.data[n].images.original.width)
        :mpeg4_height(jdat.data[n].images.original.height)
        table.insert(results, result)
        id = id + 1
    end
    return mattata.answer_inline_query(inline_query.id, results)
end

function gif.on_message(_, message, _, language)
    local input = mattata.input(message.text)
    if not input then
        local success = mattata.send_force_reply(message, language['gif']['1'])
        if success then
            local action = string.format('action:%s:%s', message.chat.id, success.result.message_id)
            redis:set(action, '/gif')
        end
        return
    end
    local jstr, res = https.request(gif.url .. url.escape(input))
    if res ~= 200 then
        return mattata.send_reply(message, language.errors.connection)
    end
    local jdat = json.decode(jstr)
    if not jdat.data or not jdat.data[1] then
        return mattata.send_reply(message, language.errors.results)
    end
    mattata.send_chat_action(message.chat.id, 'upload_photo')
    return mattata.send_document(message.chat.id, jdat.data[math.random(#jdat.data)].images.original.mp4)
end

return gif