-module(utenti).
-export([main/0, list_handler/2, check_list/2, visit_place/2, trace_contact/1, actorDispatcher/0, get_places_update/2, require_test/2, utente/0, start/0]).
-import(utils, [sleep/1, set_subtract/2, take_random/2, check_service/1, make_probability/1, flush/0]).


%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI MANTENIMENTO DELLA TOPOLOGIA (a) %%%%%%%%%%%%%%%%%%%%
main() ->
  PidServer = check_service(server),
  PidServer ! {ciao, da, utente, self()},
  link(PidServer),
  actorDispatcher().

actorDispatcher() ->
  process_flag(trap_exit, true),
  ActorListHandler = spawn_link(?MODULE, list_handler, [self(), []]),
  io:format("[ActorDispatcher] User ~p ActorListHandler ~p ~n", [self(), ActorListHandler]),
  CheckList = spawn_link(?MODULE, check_list, [ActorListHandler, self()]),
  io:format("[ActorDispatcher] User ~p CheckList ~p ~n", [self(), CheckList]),
  ActorVisitPlace = spawn_link(?MODULE, visit_place, [ActorListHandler, self()]),
  io:format("[ActorDispatcher] User ~p ActorVisitPlace ~p ~n", [self(), ActorVisitPlace]),
  ActorTraceContact = spawn_link(?MODULE, trace_contact, [self()]),
  io:format("[ActorDispatcher] User ~p ActorTraceContact ~p ~n", [self(), ActorTraceContact]),
  ActorRequireTest = spawn_link(?MODULE, require_test, [self(), make_probability(25)]),
  io:format("[ActorDispatcher] User ~p ActorRequireTest ~p ~n", [self(), ActorRequireTest]),
  ActorGetPlacesUpdate = spawn_link(?MODULE, get_places_update, [self(), ActorListHandler]),
  io:format("[ActorDispatcher] User ~p ActorGetPlacesUpdate ~p ~n", [self(), ActorGetPlacesUpdate]),
  dispatcher_loop(ActorTraceContact, ActorRequireTest, ActorGetPlacesUpdate, ActorVisitPlace).

dispatcher_loop(ContactTrace, RequiredTest, MergList, VisitPlace) ->
  receive
    {places, PIDLIST} ->
      MergList ! {places, PIDLIST};
    {contact, PID} -> ContactTrace ! {contact, PID};
    positive -> RequiredTest ! positive;
    negative -> RequiredTest ! negative;
    end_visit -> VisitPlace ! end_visit;
    {'EXIT', Sender, R} ->
      io:format("[Dispatcher] ~p received exit from ~p with: ~p~n", [self(), Sender, R]),
      exit(R);
    Msg ->
      % Check unexpected message from other actors
      io:format("[Dispatcher] ~p  ~p~n", [self(), Msg])
  end,
  dispatcher_loop(ContactTrace, RequiredTest, MergList, VisitPlace).

%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI MANTENIMENTO DELLA TOPOLOGIA (b) %%%%%%%%%%%%%%%%%%%%
list_handler(PidDispatcher, L) ->
  receive
    {get_list, Pid} ->
      Pid ! L,
      list_handler(PidDispatcher, L);
    {update_list, L1} ->
      % monitor all places in L1
      [monitor(process, X) || X <- L1],
      list_handler(PidDispatcher, L1 ++ L);
  % messages from a dead place (DOWN)
    {_, _, process, Pid, _} ->
      global:send(server, {get_places, PidDispatcher}),
      list_handler(PidDispatcher, set_subtract(L,[Pid]));
    Msg ->
      % Check unexpected message from other actors
      io:format("[User] ~p Messaggio non gestito ~p~n", [self(), Msg]),
      list_handler(PidDispatcher, L)
  end.

get_places_update(PidDispatcher, ActorList) ->
  receive
    {places, PIDLIST} ->
      ActorList ! {get_list, self()},
      receive
        L ->
          R = set_subtract(PIDLIST, L),
          case length(L) of
            0 -> ActorList ! {update_list, take_random(R, 3)};
            1 -> ActorList ! {update_list, take_random(R, 2)};
            2 -> ActorList ! {update_list, take_random(R, 1)};
            _ -> ok
          end
      end
  end,
  get_places_update(PidDispatcher, ActorList).

%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI MANTENIMENTO DELLA TOPOLOGIA (c, d) %%%%%%%%%%%%%%%%%%%%
check_list(ActorList, PidDispatcher) ->
  ActorList ! {get_list, self()},
  receive
    L ->
      io:format("Places in ~p check_list: ~p~n", [PidDispatcher, L]),
      case length(L) >= 3 of
        true -> ok;
        false ->
          global:send(server, {get_places, PidDispatcher})
      end
  end,
  sleep(10000),
  check_list(ActorList, PidDispatcher).

%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI VISITA DEI LUOGHI %%%%%%%%%%%%%%%%%%%%
visit_place(ActorList, PidDispatcher) ->
  ActorList ! {get_list, self()},
  receive
    L ->
      case length(L) >= 1 of
        true ->
          REF = make_ref(),
          [LUOGO|_] = take_random(L, 1),
          flush(),
          LUOGO ! {begin_visit, PidDispatcher, REF},

          receive end_visit ->
            io:format("Received end_visit"),
            LUOGO ! {end_visit, PidDispatcher, REF}
          after 5000 + rand:uniform(5000) -> ok end,

          LUOGO ! {end_visit, PidDispatcher, REF};
        false -> ok
      end,
      sleep(3000 + rand:uniform(2000)),
      visit_place(ActorList, PidDispatcher)
  end.

%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI RILEVAMENTO DEI CONTATTI (a,b) %%%%%%%%%%%%%%%%%%%%
trace_contact(PidDispatcher) ->
  process_flag(trap_exit, true),
  trace_contact_loop(PidDispatcher).
trace_contact_loop(PidDispatcher) ->
  receive
    {contact, PID} ->
      %let it fail
      %try
      link(PID),
      io:format("[User] ~p linked to ~p~n", [PidDispatcher, PID]),
      %catch X ->
      %  io:format("[User] ~p unable to link to ~p error ~p~n", [PidDispatcher, PID, X])
      %end,
      trace_contact_loop(PidDispatcher);
    {'EXIT', _, R} ->
      case R of
        quarantine ->
          io:format("[User] ~p entro in quaratena ~n", [PidDispatcher]),
          exit(quarantine);
        positive ->
          io:format("[User] ~p entro in quaratena ~n", [PidDispatcher]),
          exit(quarantine)
      end;
    Msg ->
      % Check unexpected message from other actors
      io:format("[User] ~p Messaggio non gestito ~p~n", [self(), Msg])
  end.

%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI TEST (a,b) %%%%%%%%%%%%%%%%%%%%
require_test(PidDispatcher, Probability) ->
  sleep(30000),
  case Probability() of
    1 ->
      PidOspedale = check_service(ospedale),
      PidOspedale ! {test_me, PidDispatcher},
      receive
        positive ->
          io:format("[User] ~p sono positivo ~n", [PidDispatcher]),
          PidDispatcher ! end_visit,
          exit(positive);
        negative -> io:format("[User] ~p Sono negativo ~n", [PidDispatcher])
      end;
    _ -> ok
  end,
  require_test(PidDispatcher, Probability).

utente() ->
  io:format("Io sono l'utente ~p~n", [self()]),
  main().

start() ->
  [spawn(fun utente/0) || _ <- lists:seq(1, 10)].