local discordia = require("discordia")
local client = discordia.Client()
local emitter = discordia.Emitter()
local chess = require("./chess")
local in_table = chess.in_table
local fs = require("fs")
local json = require("json")

-- note to self, look into emitter and waitfor stuff, not sure what for yet, but seems useful

local file = {
    --find a directory
    find_dir = function(dir)
        fs.mkdirSync(dir)
        return true
    end,
    find_file = function(path)
        -- find or create the file
        local bool, err = fs.existsSync(path)
        if not bool then
            p("creating "..path)
            local f = fs.openSync(path, "a+")
            fs.closeSync(f)
        end
        return true
    end,
    check_for_file = function(path)
        -- ONLY checks for the file, does not create
        local file_exists = false
        local bool, err = fs.existsSync(path)
        if bool then
            file_exists = true
        end
        return file_exists
    end,
    --read file from path (json to lua)
    read_to_table = function(path)
        local f = fs.openSync(path, "r")
        local data = fs.readSync(f)
        fs.closeSync(f)
        if data and data ~= "" then
            return json.decode(data)
        end
        return nil
    end,
    --write lua table to json file
    write_to_JSON = function(table, path)
        if table ~= nil and table ~= {} then
            local jToWrite = json.encode(table)
            local f = fs.openSync(path, "w")
            fs.writeSync(f, 0, jToWrite)
            fs.closeSync(f)
            return true
        end
        return false
    end,
    -- save the board to a file
    save_board = function(board, path)
        local to_encode = {}
        local letters = {"a", "b", "c", "d", "e", "f", "g", "h"}
        for v = 8, 1, -1 do
            for h = 1, 8 do
                to_encode[letters[h]..v] = board[letters[h]..v]
            end
        end
        local f = fs.openSync(path, "w")
        fs.writeSync(f, 0, json.encode(to_encode))
        fs.closeSync(f)
    end,
    -- retrieve the board from a file
    load_board = function(path)
        local f = fs.openSync(path, "r")
        local data = fs.readSync(f)
        fs.close(f)
        local temp_tab = json.decode(data)
        return chess.board:new(temp_tab)
    end,
    delete = function(path)
        fs.unlinkSync(path)
    end,
}

client:on("messageCreate", function(msg)
    local content = string.lower(msg.content)
    local cmd, args = string.match(content, "(.-) (.+)")
    local called = false
    local guild = msg.guild
    local guild_id = guild.id
    local channel = msg.channel
    local channel_id = channel.id
    local bot_id = client.user.id
    local user = msg.author
    if user.bot then return end
    local user_id = user.id
    if string.sub(content, 1, 2) == "c!" then
        called = true
        if cmd then
            cmd = string.sub(cmd, 3, -1)
        else
            cmd = string.sub(content, 3, -1)
        end
    end
    local type = "guild"
    if msg.channel.type == 1 or msg.channel.type == 3 then
        type = "dm"
    end
    local mentions = msg.mentionedUsers:toArray(function(e) return e end)
    local mentioned_channels = msg.mentionedChannels
    local server_directory = "./server_"..guild_id
    local server_info_directory = server_directory.."/info.json"
    local games_directory = server_directory.."/games"
    -- naming these differently so that they don't interfere with the ones in the challenge cmd
    local game_board_dir = games_directory.."/board_for_"..channel_id..".json"
    local game_info_dir = games_directory.."/info_for_"..channel_id..".json"
    -- handle commands and file storage
    if called and type == "guild" then
        local can_set_channel = false
        local is_admin = false
        local default_server_info = {owner = guild.ownerId, challenges_channel = nil}
        local server_info
        file.find_dir(server_directory)
        if file.find_file(server_info_directory) then -- this should always find it.
            server_info = file.read_to_table(server_info_directory)
            if not server_info then
                server_info = default_server_info
            end
        end
        file.find_dir(games_directory)
        -- get a list of roles that have administrator designations
        if type == "guild" then
            guild:getMember(user_id).roles:forEach(function(obj)
                local permissions = obj:getPermissions()
                -- check for administrator (0x00000008), manage guild (0x00000020), or manage channels (0x00000010) to be able to set challenge chan
                if permissions:has(0x00000008) then
                    is_admin = true
                end
                if permissions:has(0x00000008) or permissions:has(0x00000020) or permissions:has(0x00000010) then
                    can_set_channel = true
                end
            end)
        end
        -- command lookup table
        local commands = {
            ["set-channel"] = function(args)
                -- doesn't need args, changes challenge channel to channel mentioned in message
                if can_set_channel and #mentioned_channels[1] > 0 then
                    server_info.challenges_channel = mentioned_channels[1][1]
                    channel:send {
                        embed = {
                            title = "New challenges channel set",
                            description = "Challenges channel now set to <#"..server_info.challenges_channel..">. Challenges for chess games may only be made there.",
                            footer = {
                                text = "Requested by "..user.tag,
                                icon_url = user.avatarURL,                  
                            },
                            color = "32060",
                        }
                    }
                end
            end,
            ["create-channel"] = function(args)
                if not server_info.challenges_channel and is_admin then
                    local challenges = guild:createTextChannel("Chess-challenges")
                    local category = channel.category
                    if category then
                        challenges:setCategory(category.id)
                    end
                    server_info.challenges_channel = challenges.id
                    channel:send {
                        embed = {
                            title = "Challenges channel created!",
                            description = "Challenges channel can be located at <#"..challenges.id..">",
                            footer = {
                                text = "Requested by "..user.tag,
                                icon_url = user.avatarURL,
                            },
                            color = "32060",
                        }
                    }
                end
            end,
            ["challenge"] = function(args)
                -- must be requested in form "c!challenge @user"
                -- can not challenge bot
                if channel_id == server_info.challenges_channel then
                    if #mentions > 0 and not mentions[1].bot then
                        local wait_for_acceptance = coroutine.create(function()
                            channel:send {
                                embed = {
                                    title = user.name.." challenged "..mentions[1].name.." to a game of chess",
                                    description = "<@!"..mentions[1].id.."> has 30 seconds to accept. Form is 'c!accept @"..user.tag.."'.",
                                    footer = {
                                        text = "Requested by "..user.tag,
                                        icon_url = user.avatarURL,                  
                                    },
                                    color = "12751116",
                                }
                            }
                            local caught = emitter:waitFor("challenge_accept_from_"..user_id.."_to_"..mentions[1].id, 30000)
                            if caught then
                                -- create the channel and game files after acceptance
                                local user_nick = guild:getMember(user_id).name
                                local mentioned_nick = guild:getMember(mentions[1].id).name
                                local new_channel = guild:createTextChannel("Chess: "..user_nick.." vs. "..mentioned_nick)
                                local category = guild:getChannel(server_info.challenges_channel).category
                                if category then
                                    new_channel:setCategory(category.id)
                                end
                                -- set channel perms
                                local everyone_role = guild:getRole(guild_id)
                                local member_1 = guild:getMember(user_id)
                                local member_2 = guild:getMember(mentions[1].id)
                                local everyone_role_perms = new_channel:getPermissionOverwriteFor(everyone_role)
                                local member_1_perms = new_channel:getPermissionOverwriteFor(member_1)
                                everyone_role_perms:denyAllPermissions()
                                member_1_perms:allowPermissions(0x00000400, 0x00000800, 0x00010000)
                                if member_1 ~= member_2 then
                                    local member_2_perms = new_channel:getPermissionOverwriteFor(member_2)
                                    member_2_perms:allowPermissions(0x00000400, 0x00000800, 0x00010000)
                                end
                                -- send acceptance message
                                channel:send {
                                    embed = {
                                        title = "Challenge accepted from "..user.tag,
                                        description = "Creating channel <#"..new_channel.id.."> for a match.",
                                        footer = {
                                            text = "Requested by "..mentions[1].tag,
                                            icon_url = mentions[1].avatarURL,
                                        },
                                        color = "32060",
                                    }
                                }
                                -- create files
                                local game_board_directory = games_directory.."/board_for_"..new_channel.id..".json"
                                local game_info_directory = games_directory.."/info_for_"..new_channel.id..".json"
                                local default_game_info = {white = user.id, black = mentions[1].id, turn = "white", move_log = {}}
                                file.find_file(game_board_directory)
                                file.find_file(game_info_directory)
                                local board = chess.board:new()
                                board:setup()
                                file.save_board(board, game_board_directory)
                                file.write_to_JSON(default_game_info, game_info_directory)
                                new_channel:send("If you would like to allow spectators, use c!allow-spec at any time."..
                                                "\nIf you would like to stop the game before its conclusion, use c!close-game."..
                                                "\nIf you would like to view a log of previous moves, use c!show-log.")
                                -- set up the listener for spectators
                                emitter:on("allow_spec_in_"..new_channel.id, function()
                                    everyone_role_perms:allowPermissions(0x00000400, 0x00010000)
                                    new_channel:send("Spectating is now allowed.")
                                end)
                                -- start the game!
                                new_channel:send {
                                    embed = {
                                        title = "Starting game!",
                                        description = "<@!"..user_id.."> is white. <@!"..mentions[1].id.."> is black. White to play.",
                                        color = "32060",
                                    }
                                }
                                new_channel:send {
                                    embed = {
                                        title = "White's turn.",
                                        image = {
                                            url = board:display(),
                                        },
                                        footer = {
                                            text = "White's turn."
                                        },
                                        color = "12751116",
                                    }
                                }
                            else
                                -- send error msg
                                channel:send {
                                    embed = {
                                        title = "Challenge timed out",
                                        description = "<@!"..mentions[1].id.."> failed to accept within 30 seconds. Challenge was cancelled.",
                                        footer = {
                                            text = "Requested by "..user.tag,
                                            icon_url = user.avatarURL,                  
                                        },
                                        color = "15414342",
                                    }
                                }
                            end
                        end)
                        coroutine.resume(wait_for_acceptance)
                    else
                        channel:send {
                            embed = {
                                title = "Invalid command syntax for 'c!challenge'",
                                description = "Incorrect arguments provided or user attempted to challenge a bot. Proper command form is 'c!challenge @user'",
                                footer = {
                                    text = "Requested by "..user.tag,
                                    icon_url = user.avatarURL,                  
                                },
                                color = "15414342",
                            },
                        }
                    end
                end
            end,
            ["accept"] = function(args)
                -- accept challenge, just emits an event related to the player 'accepting'
                if #mentions > 0 and channel_id == server_info.challenges_channel then
                    emitter:emit("challenge_accept_from_"..mentions[1].id.."_to_"..user_id)
                end
            end,
            ["close-game"] = function(args)
                -- close the game channel and delete the info files
                if file.check_for_file(game_board_dir) and file.check_for_file(game_info_dir) then
                    file.delete(game_board_dir)
                    file.delete(game_info_dir)
                    channel:delete()
                else
                    channel:send {
                        embed = {
                            title = "Invalid usage of 'c!close-game'",
                            description = "Incorrect usage of command. Command must be used in a channel where a game is being played.",
                            footer = {
                                text = "Requested by "..user.tag,
                                icon_url = user.avatarURL,                  
                            },
                            color = "15414342",
                        }
                    }
                end
            end,
            ["allow-spec"] = function(args)
                if file.check_for_file(game_board_dir) and file.check_for_file(game_info_dir) then
                    emitter:emit("allow_spec_in_"..channel_id)
                else
                    channel:send {
                        embed = {
                            title = "Invalid usage of 'c!allow-spec'",
                            description = "Incorrect usage of command. Command must be used in a channel where a game is being played.",
                            footer = {
                                text = "Requested by "..user.tag,
                                icon_url = user.avatarURL,                  
                            },
                            color = "15414342",
                        }
                    }
                end
            end,
            ["show-log"] = function(args)
                if file.check_for_file(game_board_dir) and file.check_for_file(game_info_dir) then
                    local info = file.read_to_table(game_info_dir)
                    local logs = info.move_log
                    local move_str = ""
                    for i, l in pairs(logs) do
                        move_str = move_str..l.."\n"
                    end
                    if not (#logs > 0) then
                        move_str = "No moves played yet."
                    end
                    channel:send {
                        embed = {
                            title = "Move log",
                            description = move_str,
                            footer = {
                                text = "Requested by "..user.tag,
                                icon_url = user.avatarURL,                  
                            },
                        }
                    }
                end
            end,
            ["move"] = function(args)
                if file.check_for_file(game_board_dir) and file.check_for_file(game_info_dir) then
                    local start_pos, end_pos = string.match(args, "(.-) (.+)")
                    local game_info = file.read_to_table(game_info_dir)
                    local board = file.load_board(game_board_dir)
                    if game_info.turn ~= "game over" and user_id == game_info[game_info.turn] then
                        local piece
                        if board[start_pos] then
                            piece = board[start_pos].piece
                        end
                        if piece and piece.color == game_info.turn then
                            local moved, removed = board:validate_and_move(piece, end_pos)
                            if moved then
                                file.save_board(board, game_board_dir)
                                local log_move
                                if removed then
                                    log_move = chess.RepresentPiece(piece).."x"..end_pos
                                else
                                    log_move = chess.RepresentPiece(piece)..end_pos
                                end
                                table.insert(game_info.move_log, log_move)
                                if game_info.turn == "white" then
                                    game_info.turn = "black"
                                else
                                    game_info.turn = "white"
                                end
                                local check = board:get_checks(board:find_king(game_info.turn))
                                local checkmate
                                if check then
                                    checkmate = board:checkmate(board:find_king(game_info.turn))
                                end
                                local title
                                local footer
                                local color
                                if game_info.turn == "white" then
                                    color = "4672070"
                                else
                                    color = "15448109"
                                end
                                if checkmate then
                                    if game_info.turn == "white" then
                                        title = log_move..", checkmate. Black wins!"
                                    else
                                        title = log_move..", checkmate. White wins!"
                                    end
                                elseif check then
                                    title = log_move..", "..game_info.turn.." in check."
                                    footer = game_info.turn.." ("..guild:getMember(game_info[game_info.turn]).name..") to play."
                                else
                                    title = log_move
                                    footer = game_info.turn.." ("..guild:getMember(game_info[game_info.turn]).name..") to play."
                                end
                                channel:send {
                                    embed = {
                                        title = title,
                                        image = {
                                            url = board:display(),
                                        },
                                        color = color,
                                        footer = {
                                            text = footer,
                                        },
                                    }
                                }
                                if checkmate then
                                    game_info.turn = "game over"
                                    channel:send {
                                        embed = {
                                            title = "Game over",
                                            description = "Channel will automatically close in 20 seconds.",
                                            color = "15414342",
                                        }
                                    }
                                    local close_routine = coroutine.create(function()
                                        local close = emitter:waitFor("close", 20000) -- close will never fire.
                                        if not close then
                                            channel:delete()
                                        end
                                    end)
                                    coroutine.resume(close_routine)
                                end
                                file.write_to_JSON(game_info, game_info_dir)
                            else
                                channel:send {
                                    embed = {
                                        title = "Invalid move!",
                                        description = "Move can not be made with the current board. Try a different move with format 'c!move space1 space2'.",
                                        color = "15414342",
                                        footer = {
                                            text = "Requested by "..user.tag,
                                            icon_url = user.avatarURL,                  
                                        },
                                    }
                                }
                            end
                        end
                    end
                end
            end,
            ["help"] = function(args)
                local subsections = {
                    ["commands"] = function()
                        channel:send {
                            embed = {
                                title = "General/admin commands",
                                fields = {
                                    {name = "c!create-channel", value = "Creates a challenges channel in the same category command was requested from. Admin only.", inline = false},
                                    {name = "c!set-channel", value = "Requires user to mention a channel. Sets challenges channel to provided channel. Admin only.", inline = false},
                                    {name = "c!challenge", value = "Requires user to mention another user. Challenges user to a game.", inline = false},
                                    {name = "c!accept", value = "Requires user to mention another user. Accepts open challenge and creates a channel under the "..
                                    "same category as the challenges channel. By default only the users in the game and admins can see the channel.", inline = false}
                                },
                                footer = {
                                    text = "Requested by "..user.tag,
                                    icon_url = user.avatarURL,                  
                                },
                                color = "32060",
                            }
                        }
                    end,
                    ["gameplay"] = function()
                        channel:send {
                            embed = {
                                title = "Gameplay help and commands",
                                fields = {
                                    {name = "Where to start", value = "If you are new to chess read this guide https://www.chess.com/learn-how-to-play-chess", inline = false},
                                    {name = "Missing game components", value = "In its early state, this bot is missing en passant and draw conditions such as stalemate."..
                                    " These aspects of the game are a work in progress.", inline = false},
                                    {name = "c!allow-spec", value = "Allows everyone in the server access to viewing a match. Spectators can not send messages in the channel.", inline = false},
                                    {name = "c!close-game", value = "Stops the game and deletes game data before the game has ended.", inline = false},
                                    {name = "c!show-log", value = "Shows a log of every move made up to the current turn.", inline = false},
                                    {name = "c!move", value = "User must provide a start space and an end space. Example: 'c!move a2 a4' moves white pawn at a2 to a4."..
                                    " In the special case of castling, user would provide kc or qc, for kingside or queenside. Example: 'c!move kc' performs kingside castling.",
                                    inline = false},
                                },
                                footer = {
                                    text = "Requested by "..user.tag,
                                    icon_url = user.avatarURL,                  
                                },
                                color = "32060",
                            }
                        }
                    end,
                }
                if args and subsections[args] then
                    subsections[args]()
                else
                    channel:send {
                        embed = {
                            title = "Help subsections",
                            fields = {
                                {name = "commands", value = "A list of general bot commands.", inline = false},
                                {name = "gameplay", value = "A list of game commands.", inline = false}
                            },
                            footer = {
                                text = "Requested by "..user.tag,
                                icon_url = user.avatarURL,                  
                            },
                            color = "32060",
                        }
                    }
                end
            end,
        }
        if commands[cmd] then
            commands[cmd](args)
        end
        -- write to files
        if not file.write_to_JSON(server_info, server_info_directory) then
            p("failed to write to "..server_info_directory..". likely caused by nothing returned from read.")
        end
    end
end)

client:on("guildCreate", function(guild)
    guild.systemChannel:send("Thank you for using shaft-chess! In order to play, a challenges channel must be set. Use c!help for more info.")
end)

function getkey() f = io.open("./chesskey.txt") return f:read(), f:close() end
local key = getkey()
client:run("Bot "..key)