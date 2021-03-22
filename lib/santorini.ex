defmodule Santorini.CLI do

  # json struct
  defmodule Json do
    defstruct [:players, :spaces, :turn]
  end


  def encode_Map(map) do

    #json = Poison.encode!(map)
    {_, p_Value} = Map.fetch(map, :players)
    {_, s_Value} = Map.fetch(map, :spaces)
    {_, t_Value} = Map.fetch(map, :turn)

    p_Value = Poison.encode!(p_Value)
    s_Value = Poison.encode!(s_Value)
    t_Value = Poison.encode!(t_Value)

    json = "{\"players\":#{p_Value},\"spaces\":#{s_Value},\"turn\":#{t_Value}}\n"
    json
  end

  def show_board(json) do
    path = System.find_executable("win/gui.exe")
    port = Port.open({:spawn, path}, [:binary])
    Port.command(port, json)

    receive do
      {^port, {:data, result}} ->
        result
    end
  end

  def update(json) do
    if String.first(json) == "[" do
      lists = [[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0]]
      {_, dec} = Poison.decode(json)
      st = %{turn: 1, spaces: lists, players: dec}
      struct(Json, st)
    else
      regex = Regex.replace(~r/([a-z0-9+]):/, json, "\"\\1\":")
      json = regex |> String.replace("'", "\"") |> Poison.decode!

      st = Enum.reduce(json, %{}, fn({key, value}, acc) ->
        Map.merge(acc, %{ String.to_atom(key) => value})
      end)
      struct(Json, st)
    end


  end

  @doc """
  check if the move isn't out of bound, or if it's too high/low to jump
  if it's vaid move, update player
  else, keep find recursive
  TODO if move block already have building or players
  """
  def valid_move(cpRow, cpCol, spaces, players, currentLevel) do
    # calculate valid moves
    valid = [[cpRow, cpCol+1], [cpRow, cpCol-1], [cpRow+1, cpCol], [cpRow-1, cpCol], [cpRow+1, cpCol+1], [cpRow-1, cpCol-1], [cpRow+1, cpCol-1], [cpRow-1, cpCol+1]]
    # pick rand move

    valid_move_recur(valid, spaces, players, currentLevel)
  end

  def valid_move_recur(valid, spaces, players, currentLevel) do
    if length(valid) == 0 do
      [-1, -1]
    else
      randMove = Enum.random(valid)
      r = Enum.at(randMove, 0)
      c = Enum.at(randMove, 1)
      build = Enum.at(Enum.at(spaces, r-1), c-1)

      # invalid case:
      # cell out of bound,
      # cell duplicate with other players
      # the level difference between current cell and target cell is more than one, player can't jump

      if r <1 or r >5 or c <1 or c >5 or abs(build-currentLevel)>1 or ([r,c] in players) do
        valid = valid -- [randMove]
        valid_move_recur(valid, spaces, players, currentLevel)
      else
        [r,c]
      end
    end
  end

  @doc """
  check if the item is valid
  if it's out of bound
  or if the current cell already contain other build
  """
  def check_valid_neighbor(item, players) do
    cpRow = Enum.at(item, 0)
    cpCol = Enum.at(item, 1)

    if cpRow <1 or cpRow >5 or cpCol <1 or cpCol >5 or ([cpRow, cpCol] in players)do
      False
    else
      True
    end

  end


  def pick_rand_build(valid_neighbor, spaces) do
    # build random - default
    [r, c] = Enum.random(valid_neighbor)
    randLevel = Enum.at(Enum.at(spaces, r), c)

    # cannot build on a building level > 3
    if randLevel >=3 do
      valid_neighbor = valid_neighbor -- [r, c]
      pick_rand_build(valid_neighbor, spaces)
    else
      {[r,c], randLevel + 1}
    end
  end
  @doc """
  get all valid build position, try build valid

  """
  def valid_build(move, spaces, players) do
    cpRow = Enum.at(move, 0)
    cpCol = Enum.at(move, 1)
    valid = [[cpRow, cpCol+1], [cpRow, cpCol-1], [cpRow+1, cpCol], [cpRow-1, cpCol], [cpRow+1, cpCol+1], [cpRow-1, cpCol-1], [cpRow+1, cpCol-1], [cpRow-1, cpCol+1]]

    # get all valid neighbors
    valid_neighbor = []
    valid_neighbor = Enum.map(valid, fn item ->
      if check_valid_neighbor(item, players) do
        valid_neighbor ++ item
      end
    end)

    pick_rand_build(valid_neighbor, spaces)
    # update spaces

  end

  def calculate(map) do

    """
    FIRST pick and update player
    check whether next_player is duplicate with current one
    check whether next_player contain un reachable build
    default pick first player
    """

    # pick player - default the first one
    {_, players} = Map.fetch(map, :players)
    [cpRow, cpCol] = Enum.at(Enum.at(players, 0), 0)

    # get current spaces
    {_, spaces} = Map.fetch(map, :spaces)
    # get building level on current cell. The position num is index+1
    currentLevel = Enum.at(Enum.at(spaces, cpRow-1), cpCol-1)

    # get valid random move
    [r, c] = valid_move(cpRow, cpCol, spaces, players, currentLevel)

    # if no valid move for current player
    if [r,c] == [-1, -1] do
      # pick second player
      [cpRow, cpCol] = Enum.at(Enum.at(players, 0), 1)
      {_, spaces} = Map.fetch(map, :spaces)
      currentLevel = Enum.at(Enum.at(spaces, cpRow-1), cpCol-1)
      [r, c] = valid_move(cpRow, cpCol, spaces, players, currentLevel)
    end
    # when update to Map, need +1
    randMove = [r, c]

    # update players in map, opponent at front
    op = Enum.at(players, 1)
    update = [op, [randMove, Enum.at(Enum.at(players, 0), 1)]]

    # update map
    {_, map} = Map.get_and_update(map, :players, fn current ->
      {current, update}
    end)

    '''
    SECOND, build based on chosed player
    '''
    # build
    {[r,c], randLevel} = valid_build(randMove, spaces, players)

    # update spaces
    updateRow = Enum.at(spaces, r) |> List.replace_at(c, randLevel)
    spaces = List.replace_at(spaces, r, updateRow)
    {_, map} = Map.get_and_update(map, :spaces, fn current ->
      {current, spaces}
    end)

    '''
    LAST, update turn
    '''
    # update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)

    map
  end

  def check_win(map) do
    {_, players} = Map.fetch(map, :players)
    {_, spaces} = Map.fetch(map, :spaces)

    # if player stand on a building with 3 level, win
    # [[[3,3],[2,3]],[[1,4],[4,3]]]
    [p1row, p1col] = Enum.at(Enum.at(players, 0), 0)
    level1 = Enum.at(Enum.at(spaces, p1row-1), p1col-1)

    [p2row, p2col] = Enum.at(Enum.at(players, 0), 1)
    level2 = Enum.at(Enum.at(spaces, p2row-1), p2col-1)
    if level1 == 3 or level2 == 3 do
      IO.puts "I'm win\n"
      true
    end

    [p3row, p3col] = Enum.at(Enum.at(players, 1), 0)
    level3 = Enum.at(Enum.at(spaces, p3row-1), p3col-1)

    [p4row, p4col] = Enum.at(Enum.at(players, 1), 1)
    level4 = Enum.at(Enum.at(spaces, p4row-1), p4col-1)
    if level3 == 3 or level4 == 3 do
      IO.puts "You're win\n"
      true
    end

    false

  end

  def main(_args \\ []) do

    oppo = IO.gets "Your turn: \n"
    if oppo == "\n" do
      oppo = "[[[1,2], [2,3]]]"
      # json = encode_Map(oppo)
      IO.puts oppo
      main()
    else
      # receive, update moves, create struct
      map = update(oppo)
      # IO.puts "update result: "
      # IO.inspect map

      # calculate next move
      result = calculate(map)
      json = encode_Map(result)
      IO.puts json
      # check win
      if not check_win(map) do
        # keep playing
        main()
      end

    end

  end

end



#Santorini.empty()
