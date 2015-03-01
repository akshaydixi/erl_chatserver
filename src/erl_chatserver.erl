-module(erl_chatserver).
-export([start/1]).
-record(client, {name, sock}).

start(Port) ->
  inets:start(),
  register(server, spawn(fun() -> server([]) end)),
  {ok, Sock} = gen_tcp:listen(Port, [{packet, 0}, {active, false}]),
  accept(Sock).

server(Clients) ->
  receive
    {join, Client} ->
      self() ! {broadcast, Client, "HAS JOINED\n"},
      server([Client|Clients]);
    {leave, Client} ->
      self() ! {broadcast, Client#client.sock, io_lib:format("~s lost connection~n",[Client#client.name])},
      server(lists:delete(Client, Clients));
    {broadcast, Client, Message} ->
      case Message of
        [$\\ |Pokemon] -> 
          try getPokemon(Pokemon) of
            Pkmn -> message(Pkmn, Clients)
          catch
            _:_ -> ErrMsg = io_lib:format("ERROR: ~s is not an acceptable Pokemon name! Please enter a valid Pokemon name all in small letters!!~n",[clean(Pokemon)]),
                   message(ErrMsg,[Client])
          end;
        _ -> BtrMessage = io_lib:format("[~s]:~s",[Client#client.name, Message]),
             message(BtrMessage, lists:delete(Client,Clients))
      end
  end,
  server(Clients).

message(Message, Clients) ->
  lists:foreach(fun(#client{sock = Sock}) -> gen_tcp:send(Sock, Message) end, Clients).


getPokemon(Pokemon) ->
  {ok, RequestId} = httpc:request(get, {io_lib:format("http://pokeapi.co/api/v1/pokemon/~s",[clean(Pokemon)]), []}, [], [{sync, false}]),
  receive {http, {RequestId, Response}} -> 
    {_,_,Json} = Response,
    DecodedJson = jsx:decode(Json),
    io_lib:format("~s ~n ~s ~n",[extractName(DecodedJson),extractDescription(DecodedJson)])
  after 30000 -> io_lib:format("~s : error~n",[Pokemon])
  end.
  
extractName(Json) ->
  BinName = list_to_binary("name"),
  binary_to_list(element(2,hd(lists:filter(fun(X) -> element(1, X) =:= BinName end, Json)))).

extractDescription(Json) ->
  BinDescriptions = list_to_binary("descriptions"),
  [_,Resource|_] = hd(element(2,hd(lists:filter(fun(X) -> element(1, X) =:= BinDescriptions end, Json)))),
  Url = string:concat("http://pokeapi.co",binary_to_list(element(2,Resource))),
  {ok, RequestId} = httpc:request(get, {Url, []}, [], [{sync, false}]),
  receive {http, {RequestId, Response1}} -> 
    {_, _, Json1} = Response1,
    DecodedJson1 = jsx:decode(Json1),
   Description = hd(lists:filter(fun(X) -> element(1, X) =:= list_to_binary("description") end, DecodedJson1)),
   binary_to_list(element(2,Description))
  after 30000 -> "error"
  end.
  
accept(Socket) ->
  {ok, Sock} = gen_tcp:accept(Socket),
  spawn(fun() -> connecting(Sock) end),
  accept(Socket).

connecting(Sock) ->
  gen_tcp:send(Sock, "Enter your nickname: "),
  case listen(Sock) of
    {ok, RawName} ->
                  Name = clean(RawName),
                  Client = #client{name = Name, sock = Sock},
                  server ! {join, #client{name = Name, sock = Sock}},
                  client(Client);
    _ -> ok
  end.

client(Client= #client{sock = Sock}) ->
  case listen(Sock) of
    {ok, Data} -> server ! {broadcast, Client, Data},
                  client(Client);
    _ -> server ! {leave, Client}
  end.

listen(Sock) ->
  case gen_tcp:recv(Sock, 0) of
    Response -> Response
  end.

clean(String) ->
  re:replace(String, "(^\\s+)|(\\s+$)", "", [global,{return,list}]).
