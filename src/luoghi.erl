-module(luoghi).
-export([start/0, luogo/0, init_luogo/1, visit_place/2]).
-import(utils, [sleep/1, set_subtract/2, make_probability/1, check_service/1, flush/0]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI INIZIALIZZAZIONE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
init_luogo(Prob) ->
  PidServer = check_service(server),
  PidServer ! {ciao, da, luogo, self()},
  link(PidServer),
  process_flag(trap_exit, true),
  PidServer ! {new_place, self()},
  visit_place([], Prob).

get_probs() ->
  Probs = #{contact_tracing => make_probability(25), check_for_closing => make_probability(10)},
  fun(X) ->
    maps:get(X, Probs)
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI VISITA DEI LUOGHI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
visit_place(L, Probs) ->
  receive
    {begin_visit, PID, Ref} ->
      check_for_closing(Probs(check_for_closing)),
      contact_tracing(PID, [PidOldUser || {PidOldUser, _} <- L], Probs(contact_tracing)),
      visit_place([{PID, Ref} | L], Probs);
    {end_visit, PID, Ref} ->
      visit_place(set_subtract(L, [{PID, Ref}]), Probs)
  end.

%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI RILEVAMENTO DEI CONTATTI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
contact_tracing(_, [], _) -> ok;
contact_tracing(NewUser, [PidOldUser | T], Prob) ->
  case Prob() of
    1 ->
      NewUser ! {contact, PidOldUser},
      io:format("~p Contact from ~p to ~p~n", [self(), NewUser, PidOldUser]);
    _ -> ok
  end,
  contact_tracing(NewUser, T, Prob).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CICLO DI VITA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
check_for_closing(Prob) ->
  case Prob() of
    1 -> exit(normal);
    _ -> ok
  end.

start() ->
  [spawn(fun luogo/0) || _ <- lists:seq(1, 1000)].

luogo() ->
  io:format("Io sono il luogo ~p~n", [self()]),
  init_luogo(get_probs()).

