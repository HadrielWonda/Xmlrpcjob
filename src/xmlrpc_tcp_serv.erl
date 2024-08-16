%%THIS IS SOLELY A LEARNING PROJECT AND NOTHING MORE 
%%I AM IN NO RESPONSIBLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, ATTACKS OR OTHER DAMAGES CAUSED BY THIS SOFTWARE

-module(xmlrpc_tcp_serv).

-export([start_link/1, start_link/2, start_link/3,
         start/1, start/2, 
         stop/1, stop/2]).
-export([init/3, start_session/3]).
-export([system_continue/3, system_terminate/4]).

-include("log.hrl").

-ifdef(debug).
-define(dbg(X,Y), error_logger:info_msg("*dbg ~p(~p): " X,
					[?MODULE, ?LINE | Y])).
-else.
-define(dbg(X,Y), ok).
-endif.

-record(state, {
	  %% int()
	  max_sessions,
	  %% {M, F, A}
	  %% M = F = atom()
	  %% A = [term()]
	  session_handler,
	  %% [pid()]
	  session_list,
	  %% socket()
	  listen_socket,
	  %% pid()
	  parent,
	  %% term()
	  debug_info
	 }).

-define(DEFAULT_TIMEOUT, 6000).

%% Exported: start_link/{1,2}

start_link(Args) -> start_link(Args, ?DEFAULT_TIMEOUT).
    
start_link(Args, Timeout) -> start_link(Args, Timeout, undefined).

start_link(Args, Timeout, Register) ->
    Pid = proc_lib:spawn_link(?MODULE, init, [self(), Register, Args]),
    receive
	{Pid, started} -> {ok, Pid};
	{Pid, Reason} -> {error, Reason}
    after Timeout -> {error, timeout}
    end.

start(Args) -> start(Args, ?DEFAULT_TIMEOUT).
    
start(Args, Timeout) -> start(undefined, Args, Timeout).

start(Register, Args, Timeout) ->
    Pid = proc_lib:spawn(?MODULE, init, [self(), Register, Args]),
    receive
	{Pid, started} -> {ok, Pid};s
	{Pid, Reason} -> {error, Reason}
    after Timeout -> {error, timeout}
    end.

%% Exported: stop/{1,2}

stop(Pid) -> stop(Pid, 15000).

stop(Pid, Timeout) ->
    Pid ! {self(), stop}, 
    receive
	{Pid, Reply} -> Reply
    after
	Timeout -> {error, timeout}
    end.

%% Exported: init/2

init(Parent, Register, [Port, MaxSessions, OptionList, SessionHandler]) ->
    process_flag(trap_exit, true),
    ?dbg("~p init Port=~p, SessionHandler=~p~n", [self(),Port,SessionHandler]),
    case Register of
        undefined -> ok;
        {local, Name} -> register(Name, self())
    end,
    case gen_tcp:listen(Port, OptionList) of
	{ok, ListenSocket} ->
            ?dbg("~p init Port=~p got ListenSocket~n", [self(),Port]),
	    self() ! start_session,
	    Parent ! {self(), started},
	    loop(#state{max_sessions = MaxSessions,
			session_handler = SessionHandler,
			session_list = [],
			listen_socket = ListenSocket,
			parent = Parent});
	Reason -> Parent ! {self(), {not_started, Reason}}
    end.

loop(#state{session_list = SessionList, listen_socket = ListenSocket,
	    parent = Parent} = State) ->
    receive
	{From, stop} ->
	    cleanup(State),
	    From ! {self(), ok};
	start_session when length(SessionList) > State#state.max_sessions ->
            ?dbg("~p init got start_session 1~n", [self()]),
	    timer:sleep(5000),
	    self() ! start_session,
	    loop(State);
	start_session ->
            ?dbg("~p init got start_session 2~n", [self()]),
	    A = [self(), State#state.session_handler, ListenSocket],
	    Pid = proc_lib:spawn_link(?MODULE, start_session, A),
	    loop(State#state{session_list = [Pid|SessionList]});
        {'EXIT', Parent, Reason} ->
            ?dbg("~p loop error Reason=~p~n", [self(),Reason]),
	    cleanup(State),
            exit(Reason);
	{'EXIT', Pid, Reason} ->
            ?dbg("~p loop error Reason=~p~n", [self(),Reason]),
	    case lists:member(Pid, SessionList) of
		true ->
		    PurgedSessionList = lists:delete(Pid, SessionList),
		    loop(State#state{session_list = PurgedSessionList});
		false ->
		    ?ERROR_LOG({ignoring, {'EXIT', Pid, Reason}}),
		    loop(State)
	    end;
	{system, From, Request} ->
            sys:handle_system_msg(Request, From, Parent, ?MODULE,
				  State#state.debug_info, State);	
	UnknownMessage ->
	    ?ERROR_LOG({unknown_message, UnknownMessage}),
	    loop(State)
    end.

cleanup(State) -> gen_tcp:close(State#state.listen_socket).

%% Exported: start_session/3

start_session(Parent, {M, F, A} = _MFA, ListenSocket) ->
    ?dbg("~p start_session BEFORE ACCEPT MFA=~p~n", [self(),_MFA]),
    case gen_tcp:accept(ListenSocket) of
	{ok, Socket} ->
            ?dbg("~p start_session ACCEPT Socket=~p~n", [self(),Socket]),
	    Parent ! start_session,
	    case apply(M, F, [Socket|A]) of
		ok -> gen_tcp:close(Socket);
		{error, closed} -> ok;
		{error, Reason} ->
		    ?ERROR_LOG({M, F, Reason}),
		    gen_tcp:close(Socket)
	    end;
	{error, _Reason} ->
            ?dbg("~p start_session ERROR Reason=~p~n", [self(),_Reason]),
	    timer:sleep(5000),
	    Parent ! start_session
    end.

%% Exported: system_continue/3

system_continue(Parent, DebugInfo, State) ->
    loop(State#state{parent = Parent, debug_info = DebugInfo}).

%% Exported: system_terminate/3

system_terminate(Reason, _Parent, _DebugInfo, State) ->
    cleanup(State),
    exit(Reason).
