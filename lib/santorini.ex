defmodule Santorini do
  defmodule Json do
    defstruct [:players, :spaces, :turn]
  end


  def encode_Map(map) do

    #json = Poison.encode!(map)
    {_, p_Value} = Map.fetch(map, :players)
    {_, s_Value} = Map.fetch(map, :spaces)
    {_, t_Value} = Map.fetch(map, :turn)
    json = [
      {"players", p_Value},
      {"spaces", s_Value},
      {"turn", t_Value}
    ]

    json = "{\"players\":#{p_Value},\"spaces\":#{s_Value},\"turn\":#{t_Value}}"
    IO.puts json

    # keys = [:players, :spaces, :turn]
    # IO.inspect keys
    # data = [
    #   "{",
    #   Enum.map(keys, fn k ->
    #     {_, v} = Map.fetch(map, k)
    #     [Poison.encode!(k) |> String.replace("\"", ""), ":", v]
    #   end) |> Enum.intersperse(","),
    #   "}"
    # ]
  end
  @doc """
  send json to play-random. and get result json back
  """
  def send(json) do
    path = System.find_executable("win/play-random.exe")
    port = Port.open({:spawn, path}, [:binary])
    Port.command(port, json)

    receive do
      {^port, {:data, result}} ->
        IO.inspect result
        result
    end
  end

  def update(json) do

    regex = Regex.replace(~r/([a-z0-9+]):/, json, "\"\\1\":")
    json = regex |> String.replace("'", "\"") |> Poison.decode!
    IO.inspect json

    st = %{:players => json, :spaces => [[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0]], :turn => 0}
    # st = Enum.reduce(json, %{}, fn({key, value}, acc) ->
    #   Map.merge(acc, %{ String.to_atom(key) => value})
    # end)
    struct(Json, st)

  end

  @doc """
  check if the move isn't out of bound
  if it's vaid move, update player
  else, keep find recursive
  TODO if move block already have building or players
  """
  def valid_move(cpRow, cpCol) do
    # calculate valid moves
    valid = [[cpRow, cpCol+1], [cpRow, cpCol-1], [cpRow+1, cpCol], [cpRow-1, cpCol], [cpRow+1, cpCol+1], [cpRow-1, cpCol-1], [cpRow+1, cpCol-1], [cpRow-1, cpCol+1]]
    # pick rand move
    # TODO pick random move
    randMove = Enum.random(valid)


    r = Enum.at(randMove, 0)
    c = Enum.at(randMove, 1)
    result = False
    if r <1 or r >5 or c <1 or c >5 do
      valid_move(cpRow, cpCol)
    else
      [r,c]
    end
  end

  def check_valid_neighbor(item) do
    cpRow = Enum.at(item, 0)
    cpCol = Enum.at(item, 1)
    if cpRow <1 or cpRow >5 or cpCol <1 or cpCol >5 do
      False
    else
      True
    end

  end


  def pick_rand_build(valid_neighbor, spaces) do
    # build random - default
    # TODO
    [r, c] = Enum.random(valid_neighbor)
    randLevel = Enum.at(Enum.at(spaces, r), c)
    if randLevel >=3 do
      pick_rand_build(valid_neighbor, spaces)
    else
      {[r,c], randLevel + 1}
    end
  end
  @doc """
  get all valid build position, try build valid

  """
  def valid_build(move, level, spaces) do
    cpRow = Enum.at(move, 0)
    cpCol = Enum.at(move, 1)
    valid = [[cpRow, cpCol+1], [cpRow, cpCol-1], [cpRow+1, cpCol], [cpRow-1, cpCol], [cpRow+1, cpCol+1], [cpRow-1, cpCol-1], [cpRow+1, cpCol-1], [cpRow-1, cpCol+1]]

    # get all valid neighbors
    valid_neighbor = []
    valid_neighbor = Enum.map(valid, fn item ->
      if check_valid_neighbor(item) do
        valid_neighbor ++ item
      end
    end)

    pick_rand_build(valid_neighbor, spaces)
    # update spaces



  end

  def calculate(map) do
    # pick player - default the first one
    # TODO pick better one
    {_, players} = Map.fetch(map, :players)
    [cpRow, cpCol] = Enum.at(Enum.at(players, 0), 0)

    # index need to -1
    cpRow = cpRow - 1
    cpCol = cpCol - 1

    # get valid random move
    [r, c] = valid_move(cpRow, cpCol)
    randMove = [r, c]

    # update players in map, opponent at front
    op = Enum.at(players, 1)
    update = [op, [randMove, Enum.at(Enum.at(players, 0), 1)]]

    # update map
    {_, map} = Map.get_and_update(map, :players, fn current ->
      {current, update}
    end)

    # build
    # build based on randMove

    # get current spaces
    {_, spaces} = Map.fetch(map, :spaces)
    # get building level on current cell. The position num is index+1
    currentLevel = Enum.at(Enum.at(spaces, r), c)
    # get a valid build option
    {[r,c], randLevel} = valid_build(randMove, currentLevel, spaces)
    # update spaces
    updateRow = Enum.at(spaces, r) |> List.replace_at(c, randLevel)
    spaces = List.replace_at(spaces, r, updateRow)

    {_, map} = Map.get_and_update(map, :spaces, fn current ->
      {current, spaces}
    end)

    # update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)

    map
  end

  def main() do
    # pick chess
    pos1 = [Enum.random(1..5), Enum.random(1..5)]
    pos2 = [Enum.random(1..5), Enum.random(1..5)]
    step = "[[[1,2], [2,3]]]"
    # prepare json and sent
    oppo = send(step)

    # receive, update moves, create struct
    map = update(oppo)
    # calculate next move
    result = calculate(map)

    # encode map to json
    json = encode_Map(result)
    # send again
    oppo2 = send(json)
    IO.inspect oppo2
    #calculate next stpe
    #calculate(map)
    #

  end

end

#Santorini.empty()
