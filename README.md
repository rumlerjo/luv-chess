# shaft-chess: a pretty scuffed chess module in lua
THIS REPOSITORY IS NO LONGER BEING UPDATED AND IS VERY BUGGY
### Usage:
```lua
local chess = require("file path here")
```
#### Board Functions
```lua
--create a board
local board = chess.board:new()
--initialize board positions
board:setup()
--get a representation of the board using https://chessboardimage.com
board:display()
--make a move
--provide piece you want to move with and to where you would like to move it
 board:move(piece, position)
 --validate and move the piece, recommended over move
 board:validate_and_move(piece, position)
 --check for check on the board
 --provide the position of the king of the color you're checking for checks from
 --can get the king position using chess.find_king(color)
 board:get_checks(king)
 --check for checkmate
 --requires king position like get_checks
 board:checkmate()
 ```
