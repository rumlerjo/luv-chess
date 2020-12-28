--avoiding en passant and castling to start out
-- this is for use in luaJIT, specifically luvit environment
-- there are foreseeable bottlenecks in lua with looping for available moves, although passes made aren't that intensive

local board = {
    a8 = {}, b8 = {}, c8 = {}, d8 = {}, e8 = {}, f8 = {}, g8 = {}, h8 = {},
    a7 = {}, b7 = {}, c7 = {}, d7 = {}, e7 = {}, f7 = {}, g7 = {}, h7 = {},
    a6 = {}, b6 = {}, c6 = {}, d6 = {}, e6 = {}, f6 = {}, g6 = {}, h6 = {},
    a5 = {}, b5 = {}, c5 = {}, d5 = {}, e5 = {}, f5 = {}, g5 = {}, h5 = {},
    a4 = {}, b4 = {}, c4 = {}, d4 = {}, e4 = {}, f4 = {}, g4 = {}, h4 = {},
    a3 = {}, b3 = {}, c3 = {}, d3 = {}, e3 = {}, f3 = {}, g3 = {}, h3 = {},
    a2 = {}, b2 = {}, c2 = {}, d2 = {}, e2 = {}, f2 = {}, g2 = {}, h2 = {},
    a1 = {}, b1 = {}, c1 = {}, d1 = {}, e1 = {}, f1 = {}, g1 = {}, h1 = {},
}

--[[
    for unicode representation
local function RepresentPiece(piece)
    local pieces = {
        white = {
            pawn =  "♟︎",
            rook = "♜",
            knight = "♞",
            bishop = "♟︎",
            queen = "♛",
            king = "♚"
        },
        black = {
            pawn = "♙",
            rook = "♖",
            knight = "♘",
            bishop = "♗",
            queen = "♕",
            king = "♔"
        }
    }
    if piece == "none" then
        return "   "
    else
        return pieces[piece.color][piece.type]
    end
end
]]

local function RepresentPiece(piece)
    -- for use with chessboardimage.com
    local pieces = {
        white = {
            pawn =  "P",
            rook = "R",
            knight = "N",
            bishop = "B",
            queen = "Q",
            king = "K"
        },
        black = {
            pawn = "p",
            rook = "r",
            knight = "n",
            bishop = "b",
            queen = "q",
            king = "k"
        }
    }
    return pieces[piece.color][piece.type]
end

local function in_table(table, thing)
    for i, x in pairs(table) do
        if x == thing then
            return true, i
        end
    end
    return false, nil
end

local function TranslateSpace(coordinates)
    local letters = {"a", "b", "c", "d", "e", "f", "g", "h"}
    if coordinates[2] > 8 or coordinates[2] < 1 then
        return "a9" -- what im returning as an error code essentially (a9 isnt  a space)
    end
    return letters[coordinates[2]]..coordinates[1]
end

local function TranslateCoords(pos)
    local letters = {"a", "b", "c", "d", "e", "f", "g", "h"}
    local letter = string.match(pos, "%a")
    local v = tonumber(string.match(pos, "%d"))
    local h = 0
    for i, p in pairs(letters) do
        if p == letter then
            h = i
        end
    end
    return {vertical= v, horizontal = h}
end

-- piece behaviors
function pawn(board, piece)
    -- this just isn't consistent with the rest of them huh
    local possibilities = {}
    local h = piece.coordinates.horizontal
    local v = piece.coordinates.vertical
    if piece.color == "white" then
        -- white possibilities
        local up = TranslateSpace({v + 1, h})
        local diagRight = TranslateSpace({v + 1, h + 1})
        local diagLeft = TranslateSpace({v + 1, h - 1})
        if board[up] and not board[up].piece then
            table.insert(possibilities, up)
        end
        if board[diagRight] and board[diagRight].piece and board[diagRight].piece.color ~= piece.color then
            table.insert(possibilities, diagRight)
        end
        if board[diagLeft] and board[diagLeft].piece and board[diagLeft].piece.color ~= piece.color then
            table.insert(possibilities, diagLeft)
        end
    elseif piece.color == "black" then
        -- black possibilities
        local down = TranslateSpace({v - 1, h})
        local diagRight = TranslateSpace({v - 1, h + 1})
        local diagLeft = TranslateSpace({v - 1, h - 1})
        if board[down] and not board[down].piece then
            table.insert(possibilities, down)
        end
        if board[diagRight] and board[diagRight].piece and board[diagRight].piece.color ~= piece.color then
            table.insert(possibilities, diagRight)
        end
        if board[diagLeft] and board[diagLeft].piece and board[diagLeft].piece.color ~= piece.color then
            table.insert(possibilities, diagLeft)
        end
    end
    return possibilities
end

function knight(board, piece)
    -- Ls up 1 right 2, up 1 left 2, up 2 right 1, up 2 left 1 and backwards as well
    local h = piece.coordinates.horizontal
    local v = piece.coordinates.vertical
    local coord_possibilities = {{v + 1, h + 2}, {v + 1, h - 2}, {v + 2, h + 1}, {v + 2, h - 1}, {v - 1, h + 2}, {v - 1, h - 2}, {v - 2, h + 1}, {v - 2, h - 1}}
    local possibilities = {}
    for i, pos in pairs(coord_possibilities) do
        local space = TranslateSpace(pos)
        if board[space] then
            if board[space].piece and board[space].piece.color ~= piece.color then
                table.insert(possibilities, space)
            end
            table.insert(possibilities, space)
        end
    end
    return possibilities
end

function rook(board, piece)
    -- all the way horizontally and vertically
    local v = piece.coordinates.vertical
    local h = piece.coordinates.horizontal
    local possibilities = {}
    -- up
    for i = v, 8 do
        local space = TranslateSpace({v + i, h})
        if board[space] then
            if board[space].piece then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
                break
            else
                table.insert(possibilities, space)
            end
        end
    end
    --down
    for i = v, 1, -1 do
        local space = TranslateSpace({v + i, h})
        if board[space] then
            if board[space].piece then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
                break
            else
                table.insert(possibilities, space)
            end
        end
    end
    -- right
    for i = h, 8 do
        local space = TranslateSpace({v, h + i})
        if board[space] then
            if board[space].piece then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
                break
            else
                table.insert(possibilities, space)
            end
        end
    end
    -- left
    for i = h, 1, -1 do
        local space = TranslateSpace({v, h + i})
        if board[space] then
            if board[space].piece then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
                break
            else
                table.insert(possibilities, space)
            end
        end
    end
    return possibilities
end

function bishop(board, piece)
    -- diags
    local v = piece.coordinates.vertical
    local h = piece.coordinates.horizontal
    local possibilities = {}
    local count = 1
    -- up right
    for i = v, 8 do
        if (h + count) > 0 and (h + count) < 9 then
            local space = TranslateSpace({i, h + count})
            if board[space].piece ~= nil then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
                break
            else
                table.insert(possibilities, space)
            end
        end
    end
    -- up left
    count = 1
    for i = v, 8 do
        if (h - count) > 0 and (h - count) < 9 then
            local space = TranslateSpace({i, h - count})
            if board[space].piece ~= nil then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
                break
            else
                table.insert(possibilities, space)
            end
        end
    end
    -- down right
    count = 1
    for i = 8, v, -1 do
        if (h + count) > 0 and (h + count) < 9 then
            local space = TranslateSpace({i, h + count})
            if board[space].piece ~= nil then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
                break
            else
                table.insert(possibilities, space)
            end
        end
    end
    -- down left
    count = 1
    for i = 8, v, -1 do
        if (h - count) > 0 and (h - count) < 9 then
            local space = TranslateSpace({i, h - count})
            if board[space].piece ~= nil then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
                break
            else
                table.insert(possibilities, space)
            end
        end
    end
    return possibilities
end

function queen(board, piece)
    -- just run rook and bishop lul
    local possibilities = {}
    for i, pos in pairs(rook(board, piece)) do
        table.insert(pos, possibilities)
    end
    for i, pos in pairs(bishop(board, piece)) do
        table.insert(pos, possibilities)
    end
    return possibilities
end

function king(board, piece)
    local h = piece.coordinates.horizontal
    local v = piece.coordinates.vertical
    local possibilities = {}
    local coord_possibilities = {{v + 1, h}, {v + 1, h + 1}, {v + 1, h - 1}, {v, h + 1}, {v, h - 1}, {v - 1, h}, {v - 1, h - 1}, {v - 1, h + 1}}
    for i, pos in pairs(coord_possibilities) do
        local space = TranslateSpace(pos)
        if board[space] ~= nil then
            if board[space].piece ~= nil then
                if board[space].piece.color ~= piece.color then
                    table.insert(possibilities, space)
                end
            else
                table.insert(possibilities, space)
            end
        end
    end
    return possibilities
end


--[[ was gonna set pieces up as a metatable but then didnt
local pieces = {
    pawn = {type = "pawn", color = "", coordinates = {vertical = 0, horizontal = 0}, behavior = behaviors.pawn},
    knight = {type = "knight", color = "", coordinates = {vertical = 0, horizontal = 0}, behavior = behaviors.knight},
    rook = {type = "rook", color = "", coordinates = {vertical = 0, horizontal = 0}, behavior = behaviors.rook},
    bishop = {type = "bishop", color = "", coordinates = {vertical = 0, horizontal = 0}, behavior = behaviors.bishop},
    queen = {type = "queen", color = "", coordinates = {vertical = 0, horizontal = 0}, behavior = behaviors.queen},
    king = {type = "king", color = "", coordinates = {vertical = 0, horizontal = 0},  behavior = behabiors.king},
}
]]

function board:new()
    -- create the board object
    local b = {}
    setmetatable(b, self)
    self.__index = self
    return b
end

--[[
    for displaying the unicode version
function board:display()
    -- gets a unicode representation of each piece and returns the board as a string
    local outString = "8 "
    local bottomString = "\n   A B C D E F G H"
    for v = 8, 1, -1 do
        for h = 1, 8 do
            local space = TranslateSpace({v, h})
            local piece
            if self[space].piece then
                piece = self[space].piece
            else
                piece = "none"
            end
            outString = outString..RepresentPiece(piece)
        end
        if v > 1 then
            outString = outString.."\n"..(v - 1).." "
        end
    end
    outString = outString..bottomString
    return outString
end
]]

local function find_king(board, color)
    for v = 8, 1, -1 do
        for h = 1, 8 do
            local space = TranslateSpace({v, h})
            if board[space] and board[space].piece and board[space].piece.type == "king" and board[space].piece.color == color then
                return space
            end
        end
    end
end

function board:display()
    -- uses chessboardimage.com to genereate a board image
    local urlString = "https://chessboardimage.com/"
    for v = 8, 1, -1 do
        local toAdd = ""
        local numSincePiece = 0
        for h = 1, 8 do
            local space = TranslateSpace({v, h})
            if self[space].piece then
                if numSincePiece > 0 then
                    urlString = urlString..numSincePiece
                    numSincePiece = 0
                end
                urlString = urlString..RepresentPiece(self[space].piece)
            else
                numSincePiece = numSincePiece + 1
            end
        end
        if numSincePiece > 0 then
            urlString = urlString..numSincePiece
        end
        urlString = urlString.."/"
    end
    urlString = urlString..".png"
    return urlString
end

function board:get_moves(position)
    local piece = self[position].piece
    return piece.behavior(self, piece)
end

function board:get_checks(king)
    -- king is passed as a space since find_king returns a space
    local possibilities = {}
    local kingPiece = self[king].piece
    for v = 1, 8 do
        for h = 1, 8 do
            local space = TranslateSpace({v, h})
            if self[space].piece and self[space].piece.color ~= kingPiece.color then
                for i, pos in pairs(self[space].piece.behavior(self, self[space].piece)) do
                    table.insert(possibilities, pos)
                end
            end
        end
    end
    if in_table(possibilities, king) then
        return true
    else
        return false
    end
end

function board:move(piece, position)
    local piecePos = TranslateSpace({piece.coordinates.vertical, piece.coordinates.horizontal})
    if in_table(piece.behavior(self, piece), position) then
        local new_coords
        local removedPiece
        if self[position].piece then
            new_coords = self[position].piece.coordinates
            removedPiece = self[position].piece
        else
            new_coords = TranslateCoords(position)
        end
        self[position].piece = self[piecePos].piece
        self[piecePos].piece.coordinates = new_coords
        self[piecePos].piece = nil
        return true, removedPiece -- true, nil if no piece was removed
    end
    return false, nil
end

function board:checkmate(king)
    local kingPiece = self[king].piece
    local move_out = {}
    if self:get_checks(kingPiece) then
        local moves = king.behavior(self, kingPiece)
        for i, m in pairs(moves) do
            local tryMove, rem = self:move(kingPiece, m)
            if tryMove then
                if not self:get_checks(king) then
                    table.insert(move_out, m)
                end
                if rem then
                    self:move(self[position].piece, piecePos)
                    self[position] = rem
                else
                    self:move(self[position].piece, piecePos)
                end
            end
        end
    end
    if #move_out > 0 then
        return false
    end
    return true
end

function board:validate_and_move(piece, position)
    local piecePos = TranslateSpace({piece.coordinates.vertical, piece.coordinates.horizontal})
    local tryMove, rem = self:move(self[piecePos].piece, position)
    if tryMove then
        if not self:get_checks(find_king(self, piece.color)) then
            return true
        end
        if rem then
            self:move(self[position].piece, piecePos)
            self[position] = rem
        else
            self:move(self[position].piece, piecePos)
        end
        return false
    end
    return false
end

function board:setup()
    -- generate default values for board positions. reset if board already has spaces filled.
    -- pawns
    for i = 1, 8 do
        local whiteSpace = TranslateSpace({2, i})
        local blackSpace = TranslateSpace({7, i})
        self[whiteSpace].piece = {type = "pawn", color = "white", coordinates = {vertical = 2, horizontal = i}, behavior = pawn}
        self[blackSpace].piece = {type = "pawn", color = "black", coordinates = {vertical = 7, horizontal = i}, behavior = pawn}
    end
    -- rooks
    self.a1.piece = {type = "rook", color = "white", coordinates = {vertical = 1, horizontal = 1}, behavior = rook}
    self.h1.piece = {type = "rook", color = "white", coordinates = {vertical = 1, horizontal = 8}, behavior = rook}
    self.a8.piece = {type = "rook", color = "black", coordinates = {vertical = 8, horizontal = 1}, behavior = rook}
    self.h8.piece = {type = "rook", color = "black", coordinates = {vertical = 8, horizontal = 8}, behavior = rook}
    -- knights
    self.b1.piece = {type = "knight", color = "white", coordinates = {vertical = 1, horizontal = 2}, behavior = knight}
    self.g1.piece = {type = "knight", color = "white", coordinates = {vertical = 1, horizontal = 7}, behavior = knight}
    self.b8.piece = {type = "knight", color = "black", coordinates = {vertical = 8, horizontal = 2}, behavior = knight}
    self.g8.piece = {type = "knight", color = "black", coordinates = {vertical = 8, horizontal = 7}, behavior = knight}
    -- bishops
    self.c1.piece = {type = "bishop", color = "white", coordinates = {vertical = 1, horizontal = 3}, behavior = bishop}
    self.f1.piece = {type = "bishop", color = "white", coordinates = {vertical = 1, horizontal = 6}, behavior = bishop}
    self.c8.piece = {type = "bishop", color = "black", coordinates = {vertical = 8, horizontal = 3}, behavior = bishop}
    self.f8.piece = {type = "bishop", color = "black", coordinates = {vertical = 8, horizontal = 6}, behavior = bishop}
    --queens
    self.d1.piece = {type = "queen", color = "white", coordinates = {vertical = 1, horizontal = 4}, behavior = queen}
    self.d8.piece = {type = "queen", color = "black", coordinates = {vertical = 8, horizontal = 4}, behavior = queen}
    --kings
    self.e1.piece = {type = "king", color = "white", coordinates = {vertical = 1, horizontal = 5},  behavior = king}
    self.e8.piece = {type = "king", color = "black", coordinates = {vertical = 8, horizontal = 5},  behavior = king}
end

return {
    board = board;
}