import System.Random
import System.IO.Unsafe
import Data.Set (Set)
import qualified Data.Set as Set

-- Maze data structure
data Maze = Maze { cells :: [(Bool, Bool)]  -- [(rightWall, downWall)]
                 , width :: Int
                 , height :: Int
                 } deriving (Show)

rand :: Int -> Int
-- Returns a random integer from 0 to max-1
rand max = unsafePerformIO $ randomRIO (0, max-1)

shuffle :: [a] -> [a]
-- Randomly shuffles a list
shuffle = unsafePerformIO . shuffleM

shuffleM :: [a] -> IO [a]
-- DON'T BOTHER! Helper for shuffle
shuffleM [] = return []
shuffleM n = do {
                r <- fmap (flip mod $ length n) randomIO;
                n1 <- return $ n !! r;
                fmap ((:) n1) $ shuffleM $ (take r n) ++ (drop (r+1) n)
             }

-- makeMaze --

makeMaze :: Int -> Int -> Maze
makeMaze width height = Maze (fill_cell_list width height) width height

fill_cell_list :: Int -> Int -> [(Bool, Bool)]
fill_cell_list width height = if (height == 1) then (fill_row width) else (fill_row width) ++
    (fill_cell_list width (height - 1))

fill_row :: Int -> [(Bool, Bool)]
fill_row width = if (width == 1) then [(True, True)] else [(True, True)] ++ (fill_row (width - 1) )

-- kruskal --

-- Every cell is represented by an integer equal to its position in the list (only for the kruskal algorithm implementation)
kruskal :: Maze -> Maze
-- Function that executes the custom kruskal algorithm
kruskal maze = maze_from_path maze (make_path (init_sets (cells maze) 0) (shuffle (init_walls (width maze) (height maze) 0)))

init_sets :: [(Bool, Bool)] -> Int -> [Set Int]
-- Function that returns a list containing a set for each cell of the maze, with a representation of it
init_sets [] _ = []
init_sets (c : cells) curr = (Set.singleton curr : init_sets cells (curr + 1))

init_walls :: Int -> Int -> Int -> [(Int, Int)]
-- Function that returns a list with all the possible wall positions between two neighboring cells
init_walls width height curr
	| curr `div` width < height - 1 && curr `mod` width < width - 1 =
		((curr, curr + 1) : (curr, curr + width) : init_walls width height (curr + 1))
	| curr `div` width < height - 1 = ((curr, curr + width) : init_walls width height (curr + 1))
	| curr `mod` width < width - 1 = ((curr, curr + 1) : init_walls width height (curr + 1))
	| otherwise = []

join_sets :: [Set Int] -> Int -> Set Int -> [Set Int]
-- Function that replaces a set with a joined set where needed
join_sets [] _ _ = []
join_sets (x : xs) k joined_set = if Set.member k joined_set
	then (joined_set : join_sets xs (k + 1) joined_set)
	else (x : join_sets xs (k + 1) joined_set)

make_path :: [Set Int] -> [(Int, Int)] -> [(Int, Int)]
-- Function that executes the core kruskal algorithm part (returns corridor positions)
make_path sets [] = []
make_path sets ((ci, cj) : walls) = if Set.notMember ci (sets !! cj) && Set.notMember cj (sets !! ci)
	then ((ci, cj) : make_path (join_sets sets 0 (Set.union (sets !! ci) (sets !! cj))) walls)
	else make_path sets walls

alter_maze_cell :: Maze -> Int -> Int -> Bool -> Maze
-- Function that alters given maze's cell value (0 is rw, 1 is dw)
alter_maze_cell maze pos rw_or_dw new_value = Maze (alter_cell_list (cells maze) pos rw_or_dw new_value) (width maze) (height maze)

alter_cell_list :: [(Bool, Bool)] -> Int -> Int -> Bool -> [(Bool, Bool)]
-- Function that returns an altered maze cell list (alter_maze_cell helper)
alter_cell_list [] _ _ _ = []
alter_cell_list ((rw, dw) : cells) pos 0 new_value = if pos == 0
	then ((new_value, dw) : alter_cell_list cells (pos - 1) 0 new_value)
	else ((rw, dw) : alter_cell_list cells (pos - 1) 0 new_value)
alter_cell_list ((rw, dw) : cells) pos 1 new_value = if pos == 0
	then ((rw, new_value) : alter_cell_list cells (pos - 1) 0 new_value)
	else ((rw, dw) : alter_cell_list cells (pos - 1) 1 new_value)

maze_from_path :: Maze -> [(Int, Int)] -> Maze
-- Function that applies paths to maze
maze_from_path maze [] = maze
maze_from_path maze ((ci, cj) : corr) = if cj == ci + 1
	then maze_from_path (alter_maze_cell maze ci 0 False) corr
	else maze_from_path (alter_maze_cell maze ci 1 False) corr

-- solvePerfect --

solvePerfect :: Maze -> (Int, Int) -> (Int, Int) -> [(Int, Int)]
-- Function that solves a perfect maze
solvePerfect maze (sx, sy) (gx, gy) = perfect_dfs maze (get_actions maze (sx, sy)) (-1, -1) (sx, sy) (gx, gy)

get_actions :: Maze -> (Int, Int) -> [(Int, Int)]
-- Function that returns possible actions from a maze cell
get_actions maze pos = up_action maze pos

up_action :: Maze -> (Int, Int) -> [(Int, Int)]
-- Function that returns the position of the cell up if there is no wall separating them (and calls left_action)
up_action maze (x, y) = if x == 0 then left_action maze (x, y) else
	if snd ((cells maze) !! (width maze * (x - 1) + y)) == False
	then ((x - 1, y) : left_action maze (x, y))
	else left_action maze (x, y)

left_action :: Maze -> (Int, Int) -> [(Int, Int)]
-- Function that returns the position of the cell left if there is no wall separating them (and calls right_action)
left_action maze (x, y) = if y == 0 then right_action maze (x, y) else
	if fst ((cells maze) !! (width maze * x + y - 1)) == False
	then ((x, y - 1) : right_action maze (x, y))
	else right_action maze (x, y)

right_action :: Maze -> (Int, Int) -> [(Int, Int)]
-- Function that returns the position of the cell right if there is no wall separating them (and calls down_action)
right_action maze (x, y) = if fst ((cells maze) !! (width maze * x + y)) == False
	then ((x, y + 1) : down_action maze (x, y))
	else down_action maze (x, y)

down_action :: Maze -> (Int, Int) -> [(Int, Int)]
-- Function that returns the position of the cell down if there is no wall separating them
down_action maze (x, y) = if snd ((cells maze) !! (width maze * x + y)) == False
	then ((x + 1, y) : [])
	else []

perfect_dfs :: Maze -> [(Int, Int)] -> (Int, Int) -> (Int, Int) -> (Int, Int) -> [(Int, Int)]
-- Function that performs the core dfs algorithm (the second argument list are the actions remaining for the current cell)
perfect_dfs _ [] _ _ _ = []
perfect_dfs maze (curr_action : rest_actions) prev_pos curr_pos goal_pos
	| curr_pos == goal_pos = (curr_pos : [])
	| curr_action == prev_pos = perfect_dfs maze rest_actions prev_pos curr_pos goal_pos
	| perfect_dfs maze (get_actions maze curr_action) curr_pos curr_action goal_pos == [] =
		perfect_dfs maze rest_actions prev_pos curr_pos goal_pos
	| otherwise = (curr_pos : perfect_dfs maze (get_actions maze curr_action) curr_pos curr_action goal_pos)

-- braid --

braid :: Maze -> Maze
-- Function that takes a kruskal maze and returns a braid one
braid maze = braidify maze (0, 0)

braidify :: Maze -> (Int, Int) -> Maze
-- Function that executes the core braid algorithm
braidify maze (-1, -1) = maze
braidify maze (x, y) = if length (get_actions maze (x, y)) == 1
	then braidify (open_path maze (x, y)) (next_cell maze (x, y))
	else braidify maze (next_cell maze (x, y))

next_cell :: Maze -> (Int, Int) -> (Int, Int)
-- Function that returns the next cell of the maze (left to right, up to down) (returns (-1, -1) if there is no next cell)
next_cell maze (x, y)
	| x == height maze - 1 && y == width maze - 1 = (-1, -1)
	| y == width maze -1 = (x + 1, 0)
	| otherwise = (x, y + 1)

open_path :: Maze -> (Int, Int) -> Maze
-- Function that opens a path to a neighboring cell for braid maze (same structure as get_actions different order)
open_path maze pos = right_path maze pos

right_path :: Maze -> (Int, Int) -> Maze
-- Function that opens a path to the cell right if there is a wall separating them
right_path maze (x, y) = if y == width maze - 1 then down_path maze (x, y) else
	if fst ((cells maze) !! (width maze * x + y)) == True
	then alter_maze_cell maze (width maze * x + y) 0 False
	else down_path maze (x, y)

down_path :: Maze -> (Int, Int) -> Maze
-- Function that opens a path to the cell down if there is a wall separating them
down_path maze (x, y) = if x == height maze - 1 then up_path maze (x, y) else
	if snd ((cells maze) !! (width maze * x + y)) == True
	then alter_maze_cell maze (width maze * x + y) 1 False
	else up_path maze (x, y)

up_path :: Maze -> (Int, Int) -> Maze
-- Function that opens a path to the cell up if there is a wall separating them
up_path maze (x, y) = if x == 0 then left_path maze (x, y) else
	if snd ((cells maze) !! (width maze * (x - 1) + y)) == True
	then alter_maze_cell maze (width maze * (x - 1) + y) 1 False
	else left_path maze (x, y)

left_path :: Maze -> (Int, Int) -> Maze
-- Function that opens a path to the cell left if there is a wall separating them
left_path maze (x, y) = if y == 0 then maze else
	if fst ((cells maze) !! (width maze * x + y - 1)) == True
	then alter_maze_cell maze (width maze * x + y - 1) 0 False
	else maze

-- solveBraid --

solveBraid :: Maze -> (Int, Int) -> (Int, Int) -> [(Int, Int)]
-- Function that solves a braid maze (instead of a previous node (Int, Int) there is an explored set (Set (Int, Int)))
solveBraid maze (sx, sy) (gx, gy) = braid_dfs maze (get_actions maze (sx, sy)) (Set.empty) (sx, sy) (gx, gy)

braid_dfs :: Maze -> [(Int, Int)] -> Set (Int, Int) -> (Int, Int) -> (Int, Int) -> [(Int, Int)]
-- Function that performs the core dfs algorithm for a graph (the second argument list are the actions remaining for the current cell)
braid_dfs _ [] _ _ _ = []
braid_dfs maze (curr_action : rest_actions) explored_set curr_pos goal_pos
	| curr_pos == goal_pos = (curr_pos : [])
	| Set.member curr_action explored_set = braid_dfs maze rest_actions explored_set curr_pos goal_pos
	| braid_dfs maze (get_actions maze curr_action) (Set.insert curr_pos explored_set) curr_action goal_pos == [] =
		braid_dfs maze rest_actions explored_set curr_pos goal_pos
	| otherwise = (curr_pos : braid_dfs maze (get_actions maze curr_action) (Set.insert curr_pos explored_set) curr_action goal_pos)

-- showMaze --

showMaze :: Maze -> [(Int,Int)] -> String
-- Function that prints the solution to a given maze
showMaze (Maze cells width height) solution = (first_line width)
	++ (fillboard width height 0 cells solution) ++ "\n"

fillboard :: Int -> Int -> Int -> [(Bool, Bool)] -> [(Int, Int)] -> String
-- The recursive function
fillboard width height y cells solution =
	if (y == height - 1) then (fst (fill_line width height 0 y cells solution)) ++ "\n"
		++ (snd (fill_line width height 0 y cells solution))
	else (fst (fill_line width height 0 y cells solution)) ++ "\n"
		++ (snd (fill_line width height 0 y cells solution)) ++ "\n" ++
		(fillboard width height (y+1) cells solution)

fill_line :: Int -> Int -> Int -> Int -> [(Bool, Bool)] -> [(Int, Int)] -> (String, String)
fill_line width height x y cells solution
	| x == 0 =  ("|" ++ (decide_star x y solution) ++
		(decide_right width height 0 y 0 0 cells)
		++ (fst (fill_line width height 1 y cells solution)),
		"+" ++ (decide_down width height 0 y 0 0 cells) ++ "+"
		++ (snd (fill_line width height 1 y cells solution)))
	| x == width = ("","")
	| otherwise = ((decide_star x y solution) ++ (decide_right width height x y 0 0 cells)
		++ (fst (fill_line width height (x + 1) y cells solution)),
		(decide_down width height x y 0 0 cells) ++ "+"
		++ (snd (fill_line width height (x + 1) y cells solution)))

decide_star :: Int -> Int -> [(Int, Int)] -> String
-- Function that decides if there is a star and returns the proper string
decide_star x y solution
	| solution == [] = "   " --3 spaces because roof is "---"
	| snd (head solution) == x && fst (head solution) == y = " * "
	| otherwise = decide_star x y (tail solution)

decide_right :: Int -> Int -> Int -> Int -> Int -> Int -> [(Bool, Bool)] -> String
-- Function that decides if there is a right wall and returns the proper string
decide_right width height x y curx cury cells =
	if (curx == x && cury == y) then fst (getwalls (head cells))
	else decide_right width height x y (fst (getnext width height curx cury))
		(snd (getnext width height curx cury)) (tail cells)

decide_down :: Int -> Int -> Int -> Int -> Int -> Int -> [(Bool, Bool)] -> String
-- Function that decides if there is a down wall and returns the proper string
decide_down width height x y curx cury cells =
	if (curx == x && cury == y) then snd (getwalls (head cells))
	else decide_down width height x y (fst (getnext width height curx cury))
		(snd (getnext width height curx cury)) (tail cells)

getwalls :: (Bool, Bool) -> (String, String)
-- Function that returns the permutations of walls' existence
getwalls walls
	| fst walls == True && snd walls == True = ("|", "---")
	| fst walls == True && snd walls == False = ("|", "   ")
	| fst walls == False && snd walls == False = (" ", "   ")
	| fst walls == False && snd walls == True = (" ", "---")

getnext :: Int -> Int -> Int -> Int -> (Int, Int)
-- Function that returns the next cell of the maze (different arguments that next_cell)
getnext width height x y = if (x + 1 >= width && y + 1 <= height - 1) then (0, y + 1) else (x + 1, y)

first_line :: Int -> String
first_line x = if (x == 0) then "+\n" else "+---" ++ (first_line (x - 1))
