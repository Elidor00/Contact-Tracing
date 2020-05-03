-module(server).
-export([main/0, init_server/1, luogo/0, luogo2/0, sleep/1]).

sleep(T) ->
  receive after T -> ok end.

init_server(L) ->
  io:format("[Server] Actual places list: ~p ~n", [L]),
  receive
    {new_place, PID} ->
      io:format("[Server] Received new_place from ~p ~n", [PID]),
      case lists:member(PID, L) of
        true -> init_server(L);
        false -> 
          monitor(process, PID),
          init_server([ PID | L ])
      end;
    {_, _, process, Pid, Reason} ->
      io:format("Process ~p died with reason ~p ~n", [Pid, Reason]),
      init_server(lists:delete(Pid, L));
      % can we use -- instead delete?
    {get_places, PID} ->
      PID ! {places, L},
      init_server(L)
  end.

% test
luogo() ->
  global:send(server, {new_place, self()}) ,
  sleep(rand:uniform(5000)),
  exit (ciccio).

luogo2() ->
  global:send(server, {new_place, self()}) ,
  global:send(server, {new_place, self()}) ,
  sleep(rand:uniform(5000)),
  exit (ciccio).

main() ->
  Init = spawn(?MODULE, init, [[]]),
  global:register_name(server, Init).
  %spawn(?MODULE, luogo, []),
  %L2 = spawn(?MODULE, luogo2, []),
  %L3 = spawn(?MODULE, luogo, []),
  %spawn(?MODULE, luogo2, []),
  %spawn(?MODULE, luogo, []),
  %sleep(1000),
  %exit(L2,kill),
  %exit(L3, kill).

