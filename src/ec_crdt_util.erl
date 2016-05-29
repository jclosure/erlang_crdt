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
	 find_dot/2,
	 reset/2]).

-include("erlang_crdt.hrl").

-spec add_param(DVV :: #ec_dvv{}, State :: #ec_dvv{}) -> #ec_dvv{}.
add_param(DVV, #ec_dvv{module=Mod, type=Type, option=Option}) ->
    DVV#ec_dvv{module=Mod, type=Type, option=Option}.

-spec new_delta(Value :: term(), DL :: list(), State :: #ec_dvv{}, ServerId :: term()) -> #ec_dvv{}.
new_delta(Value, DL, State, ServerId) ->
    NewDL = case find_dot(DL, ServerId) of
                false ->        
                    [];
                Dot   ->
                    [Dot]
            end,
    add_param(ec_dvv:new(NewDL, Value), State).

-spec find_dot(DX :: list() | #ec_dvv{}, ServerId :: term()) -> false | #ec_dot{}.
find_dot(DL, ServerId) when is_list(DL) ->
    lists:keyfind(ServerId, #ec_dot.replica_id, DL);
find_dot(#ec_dvv{dot_list=DL}, ServerId) ->
    find_dot(DL, ServerId).

-spec reset(DVV :: #ec_dvv{}, Flag :: ?EC_RESET_NONE | ?EC_RESET_VALUES | ?EC_RESET_ANNONYMUS_LIST | ?EC_RESET_ALL | ?EC_RESET_VALUES_ONLY) -> #ec_dvv{}.
reset(#ec_dvv{}=DVV, ?EC_RESET_RETAIN_ALL) ->
    DVV;
reset(#ec_dvv{dot_list=DL}=DVV, ?EC_RESET_ANNONYMUS_LIST) ->
    DVV#ec_dvv{dot_list=reset_dot_list(DL, ?EC_RESET_NONE), annonymus_list=[]};
reset(#ec_dvv{dot_list=DL}=DVV, ?EC_RESET_ALL) ->
    DVV#ec_dvv{dot_list=reset_dot_list(DL, ?EC_RESET_VALUES), annonymus_list=[]};
reset(#ec_dvv{dot_list=DL}=DVV, Flag) ->
    DVV#ec_dvv{dot_list=reset_dot_list(DL, Flag)}.

% private function

-spec reset_dot_list(DL :: list(), Flag :: ?EC_RESET_NONE | ?EC_RESET_VALUES | ?EC_RESET_VALUES_ONLY) -> list().
reset_dot_list(DL, ?EC_RESET_NONE) ->
    lists:foldl(fun(#ec_dot{counter_max=Max}=DotX, Acc) -> [DotX#ec_dot{counter_min=Max} | Acc] end, [], DL);
reset_dot_list(DL, ?EC_RESET_VALUES) ->
    lists:foldl(fun(#ec_dot{counter_max=Max}=DotX, Acc) -> [DotX#ec_dot{counter_min=Max, values=[]} | Acc] end, [], DL);
reset_dot_list(DL, ?EC_RESET_VALUES_ONLY) ->
    lists:foldl(fun(DotX, Acc) -> [DotX#ec_dot{values=[]} | Acc] end, [], DL).
			


    
