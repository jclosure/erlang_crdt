%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                  
%% Copyright (c) 2016 Gyanendra Aggarwal.  All Rights Reserved.                                          
%%                                                                                                        
%% This file is provided to you under the Apache License,                                                 
%% Version 2.0 (the "License"); you may not use this file                                                 
%% except in compliance with the License.  You may obtain                                                
%% a copy of the License at                                                                              
%%                                                                                                       
%%   http://www.apache.org/licenses/LICENSE-2.0                                                          
%%                                                                                                       
%% Unless required by applicable law or agreed to in writing,                                        
%% software distributed under the License is distributed on an                                           
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY                                                
%% KIND, either express or implied.  See the License for the                                             
%% specific language governing permissions and limitations                                               
%% under the License.                                                                                    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                             

-module(ec_crdt_util).

-export([add_param/2, 
	 new_delta/4,
	 find_module/1,
	 is_dirty/1,
	 delta_state_pair/1,
	 causal_consistent/5,
	 reset/2]).

-include("erlang_crdt.hrl").

-spec add_param(DVV :: #ec_dvv{}, State :: #ec_dvv{}) -> #ec_dvv{}.
add_param(DVV, #ec_dvv{module=Mod, type=Type, name=Name}) ->
    DVV#ec_dvv{module=Mod, type=Type, name=Name}.

-spec new_delta(Value :: term(), DL :: list(), State :: #ec_dvv{}, ServerId :: term()) -> #ec_dvv{}.
new_delta(Value, DL, State, ServerId) ->
    NewDL = case ec_dvv:find_dot(DL, ServerId) of
                false ->        
                    [];
                Dot   ->
                    [Dot]
            end,
    NewDelta = ec_dvv:new(NewDL, Value),
    add_param(NewDelta#ec_dvv{status=?EC_DVV_DIRTY_DELTA}, State).

-spec reset(DVV :: #ec_dvv{}, Flag :: ?EC_RESET_NONE | ?EC_RESET_VALUES | ?EC_RESET_ANNONYMUS_LIST | ?EC_RESET_ALL | ?EC_RESET_VALUES_ONLY) -> #ec_dvv{}.
reset(#ec_dvv{}=DVV, ?EC_RESET_RETAIN_ALL) ->
    DVV;
reset(#ec_dvv{dot_list=DL}=DVV, ?EC_RESET_ANNONYMUS_LIST) ->
    DVV#ec_dvv{dot_list=reset_dot_list(DL, ?EC_RESET_NONE), annonymus_list=[]};
reset(#ec_dvv{dot_list=DL}=DVV, ?EC_RESET_ALL) ->
    DVV#ec_dvv{dot_list=reset_dot_list(DL, ?EC_RESET_VALUES), annonymus_list=[]};
reset(#ec_dvv{dot_list=DL}=DVV, Flag) ->
    DVV#ec_dvv{dot_list=reset_dot_list(DL, Flag)}.

-spec find_module(Type :: atom()) -> atom() | error.
find_module(Type) ->
    case maps:find(Type, ?EC_CRDT_MAP) of
	error     ->
	    error;
	{ok, Mod} ->
	    Mod
    end.

-spec is_dirty(DVV :: #ec_dvv{}) -> true | false.
is_dirty(#ec_dvv{status={?EC_DVV_DIRTY, _}}) ->
    true;
is_dirty(#ec_dvv{}) ->
    false.

-spec delta_state_pair({Delta :: #ec_dvv{}, State :: #ec_dvv{}}) -> {#ec_dvv{}, #ec_dvv{}}.
delta_state_pair({Delta, State}) ->
    case is_state(State) of
	true  ->
	    {Delta, State};
	false ->
	    {State, Delta}
    end.

-spec causal_consistent(Delta :: #ec_dvv{}, State :: #ec_dvv{}, Offset :: non_neg_integer(), ServerId :: term(), List :: list()) -> list().
causal_consistent(#ec_dvv{module=Mod, type=Type, name=Name}=Delta,
		  #ec_dvv{module=Mod, type=Type, name=Name}=State,
		  Offset,
		  ServerId,
		  List) ->
    case ec_dvv:causal_consistent(Delta, State, Offset, ServerId) of
        ?EC_CAUSALLY_CONSISTENT -> 
	    List;
	Reason                  ->                 
	    [Reason | List]
    end.

% private function

-spec reset_dot_list(DL :: list(), Flag :: ?EC_RESET_NONE | ?EC_RESET_VALUES | ?EC_RESET_VALUES_ONLY) -> list().
reset_dot_list(DL, ?EC_RESET_NONE) ->
    lists:foldl(fun(#ec_dot{counter_max=Max}=DotX, Acc) -> [DotX#ec_dot{counter_min=Max} | Acc] end, [], DL);
reset_dot_list(DL, ?EC_RESET_VALUES) ->
    lists:foldl(fun(#ec_dot{counter_max=Max}=DotX, Acc) -> [DotX#ec_dot{counter_min=Max, values=[]} | Acc] end, [], DL);
reset_dot_list(DL, ?EC_RESET_VALUES_ONLY) ->
    lists:foldl(fun(DotX, Acc) -> [DotX#ec_dot{values=[]} | Acc] end, [], DL).

-spec is_state(DVV :: #ec_dvv{}) -> true | false.
is_state(#ec_dvv{status={_, ?EC_DVV_STATE}}) ->	
    true;
is_state(#ec_dvv{}) ->
    false.




    

