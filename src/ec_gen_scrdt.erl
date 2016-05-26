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

-module(ec_gen_scrdt).

-behavior(ec_gen_crdt).

-export([new_crdt/2,
	 delta_crdt/4,
	 reconcile_crdt/2,
	 update_fun_crdt/1,
	 merge_fun_crdt/1,
	 query_crdt/2,
	 reset_crdt/1,
	 causal_consistent_crdt/4]).
	 
-include("erlang_crdt.hrl").

-spec new_crdt(Type :: atom(), Args :: term()) -> #ec_dvv{}.
new_crdt(Type, Args) ->
    #ec_dvv{module=?MODULE, type=Type, option=Args, annonymus_list=[{sets:new(), sets:new(), sets:new()}]}. 

-spec delta_crdt(Ops :: term(), DL :: list(), State :: #ec_dvv{}, ServerId :: term()) -> #ec_dvv{}.
delta_crdt(Ops, DL, #ec_dvv{module=?MODULE}=State, ServerId) ->
    case new_value(Ops, State, ServerId) of
	{undefined, undefined, undefined} ->
	    ec_crdt_util:add_param(#ec_dvv{}, State);
	Value                             ->
	    ec_crdt_util:new_delta(Value, DL, State, ServerId)
    end.

-spec reconcile_crdt(State :: #ec_dvv{}, ServerId :: term()) -> #ec_dvv{}.
reconcile_crdt(#ec_dvv{module=?MODULE, type=Type, annonymus_list=AL}=State, ServerId) ->
    {AL8, AL9} = case {ec_crdt_util:find_dot(State, ServerId), AL} of
		     {false, [E1]}                  ->
			 {[E1], undefined};
		     {false, [E1, E2]}              ->
			 {[E1], [E2]};
		     {#ec_dot{values=[]}, [E1]}      ->
			 {[E1], undefined};
		     {#ec_dot{values=[]}, [E1, E2]} ->
			 {[E1], [E2]};
		     {#ec_dot{values=[E1]}, [E2]}   ->
			 {[E1], [E2]}
                 end,
		
    State1 = ec_crdt_util:reset(State, ?EC_RESET_VALUES_ONLY),

    NewAL = case {AL8, AL9} of
		{_, undefined}         ->
		    AL8;
		{_, _}                 ->
		    case Type of
			?EC_AWORSET ->
			    add_win(AL8, AL9);
			?EC_RWORSET ->
			    rmv_win(AL8, AL9)
		    end
	    end,
    State1#ec_dvv{annonymus_list=NewAL}.
			     
-spec update_fun_crdt(Args :: list()) -> fun().
update_fun_crdt([_Type]) -> 
    fun ec_dvv:merge_default/3.

-spec merge_fun_crdt(Args :: list()) -> fun().
merge_fun_crdt([_Type]) ->
    fun ec_dvv:merge_default/3.

-spec reset_crdt(State :: #ec_dvv{}) -> #ec_dvv{}.
reset_crdt(#ec_dvv{module=?MODULE}=State) ->
    ec_crdt_util:reset(State, ?EC_RESET_ALL).

-spec causal_consistent_crdt(Delta :: #ec_dvv{}, State :: #ec_dvv{}, Offset :: non_neg_integer(), ServerId :: term()) -> ?EC_CAUSALLY_CONSISTENT | 
															 ?EC_CAUSALLY_AHEAD |
															 ?EC_CAUSALLY_BEHIND.
causal_consistent_crdt(#ec_dvv{module=?MODULE, type=Type, option=Option}=Delta, 
		       #ec_dvv{module=?MODULE, type=Type, option=Option}=State,
		       Offset,
		       ServerId) ->
    ec_dvv:causal_consistent(Delta, State, Offset, ServerId).

-spec query_crdt(Criteria :: term(), State :: #ec_dvv{}) -> term().
query_crdt(_Criteria, #ec_dvv{module=?MODULE, annonymus_list=[{VSet, _RSet, _CSet}]}) ->
    get_elements(VSet).

% private function

-spec add_win(AL1 :: list(), AL2 :: list()) -> list().
add_win([{VSet1, _, CSet1}],
        [{VSet2, _, CSet2}]) ->    
    CSet = sets:union(CSet1, CSet2),
    VSet = sets:union(sets:intersection(VSet1, VSet2),
                      sets:union(get_add_element_set(VSet1, CSet2),
                                 get_add_element_set(VSet2, CSet1))),
    [{VSet, sets:new(), CSet}].

-spec rmv_win(AL1 :: list(), AL2 :: list()) -> list().
rmv_win([{VSet1, RSet1, CSet1}],
        [{VSet2, RSet2, CSet2}]) ->    
    VX2 = sets:subtract(VSet2, sets:intersection(get_cartesian_product(RSet1, CSet2), VSet2)),
    [{VSet, _, CSet}] = add_win([{VSet1, undefined, CSet1}], [{VX2, undefined, CSet2}]),
    RSet = sets:subtract(sets:union(RSet1, RSet2), get_elements(VSet)),
    [{VSet, RSet, CSet}].

-spec next_counter_value(State :: #ec_dvv{}, ServerId :: term()) -> non_neg_integer().
next_counter_value(#ec_dvv{module=?MODULE}=State, ServerId) ->
    case ec_crdt_util:find_dot(State, ServerId) of
	false                    ->
	    1;
	#ec_dot{counter_max=Max} ->
	    Max+1
    end.

-spec new_value(Ops :: term(), State :: #ec_dvv{}, ServerId :: term()) -> {sets:set() | undefined, sets:set() | undefined, sets:set() | undefined}.
new_value({add, Value}, #ec_dvv{module=?MODULE}=State, ServerId) ->
    C1 = next_counter_value(State, ServerId),
    VSet = sets:add_element({ServerId, C1, Value}, sets:new()),
    CSet = sets:add_element({ServerId, C1}, sets:new()),
    {VSet, sets:new(), CSet};
new_value({rmv, Value}, #ec_dvv{module=?MODULE, type=Type, annonymus_list=[{VSet, _RSet, _CSet}]}, _ServerId) ->
    CSet = sets:fold(fun(X, Set) -> get_element_set(Value, X, Set) end, sets:new(), VSet),
    case {sets:size(CSet) > 0, Type} of
        {true, ?EC_AWORSET} ->
	    {sets:new(), sets:new(), CSet};
	{true, ?EC_RWORSET} ->
	    {sets:new(), sets:from_list([Value]), CSet};
        {false, _} ->
	    {undefined, undefined, undefined}
    end.

-spec get_cartesian_product(Set1 :: sets:set(), Set2 :: sets:set()) -> sets:set().
get_cartesian_product(RSet, CSet) ->
    sets:fold(fun(X, SetX) -> get_value_set(X, CSet, SetX) end, sets:new(), RSet).

-spec get_value_set(R :: term(), CSet :: sets:set(), Set :: sets:set()) -> sets:set().
get_value_set(R, CSet, Set) ->
    sets:fold(fun({S, N}, SetX) -> sets:add_element({S, N, R}, SetX) end, Set, CSet).
		      
-spec get_elements(ElementSet :: sets:set()) -> sets:set().
get_elements(ElementSet) ->
    sets:fold(fun get_elements/2, sets:new(), ElementSet).
    
-spec get_elements(Element :: term(), Set :: sets:set()) -> sets:set().
get_elements({_, _, Element}, Set) ->
    sets:add_element(Element, Set).

-spec get_element_set(Element1 :: term(), {ServerId :: term(), Counter :: non_neg_integer(), Element :: term()}, Set :: sets:set()) -> sets:set().
get_element_set(Element, {ServerId, Counter, Element}, Set) ->
    sets:add_element({ServerId, Counter}, Set);
get_element_set(_Element, _SetElement, Set) ->
    Set.

-spec get_element(Element :: term(), Flag :: true | false, RefSet :: sets:set(), Set :: sets:set()) -> sets:set().
get_element({ServerId, Counter, _}=Element, Flag, RefSet, Set) ->
    case sets:is_element({ServerId, Counter}, RefSet) =:= Flag of
	false ->
	    Set;
	true  ->
	    sets:add_element(Element, Set)
    end.

-spec get_add_element_set(ElementSet :: sets:set(), RefElementSet :: sets:set()) -> sets:set().
get_add_element_set(ElementSet, RefElementSet) ->
    sets:fold(fun(X, SetX) -> get_element(X, false, RefElementSet, SetX) end, sets:new(), ElementSet).



