%% @doc
%% Implementation module for the galactic battle simulator.
%% The following example shows the expected behavior of the simulator:
%%
%% Planets=[mercury,uranus,venus, earth]
%% Shields=[mercury,uranus]
%% Alliances=[{mercury, uranus}, {venus, earth}]
%% Actions=[{nuclear,mercury},{laser,venus}, {laser, uranus}]
%%
%% ExpectedSurvivors = [uranus]
%% In order to produce this expected results, the following calls will be tested:
%% * ok = setup_universe(Planets, Shields, Alliances)
%% * [uranus] = simulate_attack(Planets, Actions)
%% * ok = teardown_universe(Planets)
%%
%% All the 3 calls will be tested in order to check they produce the expected
%% side effects (setup_universe/3 creates a process per planet, etc)
%% @end

-module(galaxy_game).

-include_lib("eunit/include/eunit.hrl").

-type planet()::atom().
-type shield()::planet().
-type alliance()::{planet(), planet()}.
-type attack()::{laser | nuclear, planet()}.

-export([setup_universe/3, teardown_universe/1, simulate_attack/2]).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, {Planets, Shields, Alliances}) ->
  setup_universe(Planets, Shields, Alliances).

stop(Planets) ->
  teardown_universe(Planets).

%% @doc Set up a universe described by the input.
%% The input is assumed to be minimal and non redundant (i.e. if there is an
%% alliance {a, b} there won't be an alliance {b, a}).
%% Once this function returns, the universe is expected to be fully ready,
%% shields, alliances and all.
-spec setup_universe([planet()], [shield()], [alliance()]) -> ok.

%% @end
setup_universe(Planets, Shields, Alliances) ->
  io:format("setup_universe ~p~n", [Planets]),
  spawn_planets(Planets),
  setup_shields(Shields),
  link_planets(Alliances),
  io:format("setup_universe end ~p~n", [Planets]),
  ok.

spawn_planets([]) ->
  ok;
spawn_planets([Planet|Planets]) ->
  io:format("spawn ~p~n", [Planet]),
  register(Planet, spawn(fun() -> shield(Planet) end)),
  spawn_planets(Planets).

shield(Planet) ->
  receive
    {ping, From, FromPlanet} ->
      From ! {pong, FromPlanet},
      shield(Planet);
    {link, ToPlanet} ->
      io:format("~p and ~p are linked~n", [Planet, ToPlanet]),
      link(whereis(ToPlanet)),
      shield(Planet);
    shield ->
      io:format("~p has a shield~n", [Planet]),
      process_flag(trap_exit, true),
      shield(Planet);
    % Received only with the trap_exit
    {'EXIT', _From, laser} ->
      io:format("Laser was deflected from ~p~n", [Planet]),
      shield(Planet);
    {'EXIT', _From, Reason} ->
      io:format("~p was destroyed by ~p~n", [Planet, Reason]),
      exit(Reason)
  end.
link_planets([]) ->
  ok;
link_planets([{A, B}|Alliances]) ->
  A ! {link, B},
  link_planets(Alliances).

setup_shields([]) ->
  ok;
setup_shields([Shield|Shields]) ->
  Shield ! shield,
  setup_shields(Shields).

%% @doc Clean up a universe simulation.
%% This function will only be called after calling setup_universe/3 with the
%% same set of planets.
%% Once this function returns, all the processes spawned by the simulation
%% should be gone.
-spec teardown_universe([planet()]) -> ok.
%% @end
teardown_universe(Planets) ->
  io:format("teardown_universe ~p~n", [Planets]),
  terminate(Planets).

terminate([]) ->
  ok;
terminate([Planet|Planets]) ->
  io:format("terminate ~p~n", [Planet]),
  PPid = whereis(Planet),
  exit(PPid, shutdown),
  terminate(Planets).

%% @doc Simulate an attack.
%% This function will only be called after setting up a universe with the same
%% set of planets.
%% It returns the list of planets that have survived the attack
-spec simulate_attack([planet()], [attack()]) -> Survivors::[planet()].
%% @end
simulate_attack(Planets, []) ->
  timer:sleep(1),
  lists:filter(fun(Planet) ->
    Pid = whereis(Planet),
    (Pid /= undefined) andalso is_process_alive(Pid)
  end, Planets);
simulate_attack(Planets, [{Attack, Planet}|Attacks]) ->
  Pid = whereis(Planet),
  case Pid of
    undefined ->
      simulate_attack(Planets, Attacks);
    _ ->
      exit(whereis(Planet), Attack)
  end,
  simulate_attack(Planets, Attacks).
