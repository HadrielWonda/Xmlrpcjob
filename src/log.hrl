%%THIS IS SOLELY A LEARNING PROJECT AND NOTHING MORE 
%%I AM IN NO RESPONSIBLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, ATTACKS OR OTHER DAMAGES CAUSED BY THIS SOFTWARE


-define(INFO_LOG(Reason),
	error_logger:info_report({?MODULE, ?LINE, Reason})).

-define(ERROR_LOG(Reason),
	error_logger:error_report({?MODULE, ?LINE, Reason})).

-ifdef(DEBUG).
-define(DEBUG_LOG(Reason),
	error_logger:info_report({debug, ?MODULE, ?LINE, Reason})).
-else.
-define(DEBUG_LOG(Reason), ok).
-endif.
