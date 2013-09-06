-module(galaxy_game_eunit).

-include_lib("eunit/include/eunit.hrl").

galaxy_game_test_() ->
  Planets = [mercury, venus, earth, mars],
  Shields = [venus, earth],
  Alliances = [{mercury, venus}, {venus, earth}],
  Attacks = [{nuclear, venus}, {laser, earth}],
  Exp = [earth, mars],
  {setup,
    fun () -> galaxy_game:setup_universe(Planets, Shields, Alliances) end,
    fun (ok) -> galaxy_game:teardown_universe(Planets) end,
    fun (ok) ->
      [?_assert(valid_planets(Planets)),
       ?_assert(planets_shielded(Shields)),
       ?_assert(allied(Alliances)),
       ?_assertEqual(Exp, galaxy_game:simulate_attack(Planets, Attacks))]
    end
  }.

valid_planets(Planets) ->
  lists:all(fun (P) ->
    PPid = whereis(P),
    (PPid /= undefined) and is_process_alive(PPid)
  end, Planets).

planets_shielded(Shields) ->
  lists:all(fun (S) ->
    {trap_exit, true} == process_info(whereis(S), trap_exit)
  end, Shields).

allied(Alliances) ->
  lists:all(fun ({X, Y}) ->
    XPid = whereis(X),
    ?assert(XPid /= undefined),
    {links, Links} = erlang:process_info(XPid, links),
    YPid = whereis(Y),
    lists:member(YPid, Links)
  end, Alliances).

validity_printout(Validity) ->
  Printout = lists:zip(
    [valid_planets, planets_shielded, planets_allied],
    tuple_to_list(Validity)),
  ?debugFmt("Invalid Universe Setup:~n~p~n", [Printout]),
  false.