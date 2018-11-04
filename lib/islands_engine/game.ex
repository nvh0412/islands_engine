defmodule IslandsEngine.Game do
  alias IslandsEngine.{Board, Coordinate, Guesses, Island, Rules}

  use GenServer

  @players [:player1, :player2]

  def init(name) do
    player1 = %{name: name, board: Board.new(), guesses: Guesses.new()}
    player2 = %{name: nil, board: Board.new(), guesses: Guesses.new()}
    { :ok, %{player1: player1, player2: player2, rules: %Rules{}} }
  end

  def start_link(name) when is_binary(name), do:
    GenServer.start_link(__MODULE__, name, [])

  def add_player(game, name) when is_binary(name), do:
    GenServer.call(game, { :add_player, name })

  def position_islands(game, player, key, row, col) when player in @players, do:
    GenServer.call(game, { :position_islands, player, key, row, col })

  def set_islands(game, player) when player in @players, do:
    GenServer.call(game, { :set_islands, player })

  def handle_call({:add_player, name}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :add_player) do
      state_data
      |> update_player2_name(name)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> { :reply, :error, state_data }
    end
  end

  def handle_call({:position_islands, player, key, row, col}, _from, state_data) do
    board = player_board(state_data, player)
    with {:ok, rules} <- Rules.check(state_data.rules, {:position_islands, player}),
         {:ok, coordinate} <- Coordinate.new(row, col),
         {:ok, island} <- Island.new(key, coordinate),
         %{} = board <- Board.position_island(board, key, island)
    do
      state_data
      |> update_board(player, board)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state_data}
      { :error, :invalid_coordiate } -> {:reply, {:error, :invalid_coordiate}, state_data}
      { :error, :invalid_island_type } -> {:reply, {:error, :invalid_island_type}, state_data}
      { :error, :overlapping_island } -> {:reply, {:error, :overlapping_island}, state_data}
    end
  end

  def handle_call({:set_islands, player}, _from, state_data) do
    board = player_board(state_data, player)
    with {:ok, rules} <- Rules.check(state_data.rules, {:set_islands, player}),
         true <- Board.all_island_positioned?(board)
    do
      state_data
      |> update_rules(rules)
      |> reply_success({ :ok, board })
    else
      :error -> {:reply, :error, state_data}
      false -> {:reply, {:error, :not_all_island_positioned}, state_data}
    end
  end

  defp update_board(state, player, board) do
    Map.update!(state, player, fn player -> %{player | board: board} end)
  end

  defp player_board(state, player) do
    Map.get(state, player).board
  end

  defp update_player2_name(state, name) do
    put_in(state.player2.name, name)
  end

  defp update_rules(state, rules) do
    %{ state | rules: rules }
  end

  defp reply_success(state_data, reply), do: { :reply, reply, state_data }
end
