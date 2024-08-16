%%THIS IS SOLELY A LEARNING PROJECT AND NOTHING MORE 
%%I AM IN NO RESPONSIBLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, ATTACKS OR OTHER DAMAGES CAUSED BY THIS SOFTWARE


-module(xmlrpc_util).

-export([is_string/1, is_iso8601_date/1, is_base64/1]).

is_string([C|Rest]) when C >= 0, C =< 255 -> is_string(Rest);
is_string([]) -> yes;
is_string(_) -> no.

is_iso8601_date(_) -> yes. % FIXME

is_base64(_) -> yes. % FIXME
