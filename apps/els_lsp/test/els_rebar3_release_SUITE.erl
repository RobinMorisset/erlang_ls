%%==============================================================================
%% Unit Tests for interacting with rebar3 releases
%%==============================================================================
-module(els_rebar3_release_SUITE).

%% CT Callbacks
-export([
    all/0,
    init_per_suite/1,
    end_per_suite/1,
    init_per_testcase/2,
    end_per_testcase/2,
    suite/0
]).

%% Test cases
-export([code_navigation/1]).

%%==============================================================================
%% Includes
%%==============================================================================
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").
-include("els_lsp.hrl").

%%==============================================================================
%% Macro Definitions
%%==============================================================================
-define(TEST_APP, rebar3_release).

%%==============================================================================
%% Types
%%==============================================================================
-type config() :: [{atom(), any()}].

%%==============================================================================
%% CT Callbacks
%%==============================================================================
-spec all() -> [atom()].
all() ->
    els_test_utils:all(?MODULE).

-spec init_per_suite(config()) -> config().
init_per_suite(Config) ->
    RootPath = root_path(),
    AppPath = src_path(RootPath, "rebar3_release_app.erl"),
    SupPath = src_path(RootPath, "rebar3_release_sup.erl"),
    application:load(els_lsp),
    [
        {root_uri, els_uri:uri(RootPath)},
        {app_uri, els_uri:uri(AppPath)},
        {sup_uri, els_uri:uri(SupPath)}
        | Config
    ].

-spec end_per_suite(config()) -> ok.
end_per_suite(Config) ->
    els_test_utils:end_per_suite(Config).

-spec init_per_testcase(atom(), config()) -> config().
init_per_testcase(_TestCase, Config) ->
    meck:new(els_distribution_server, [no_link, passthrough]),
    meck:expect(els_distribution_server, connect, 0, ok),
    Started = els_test_utils:start(),
    RootUri = ?config(root_uri, Config),
    AppUri = ?config(app_uri, Config),
    els_client:initialize(RootUri),
    {ok, AppText} = file:read_file(els_uri:path(AppUri)),
    els_client:did_open(AppUri, erlang, 1, AppText),
    els_indexing:find_and_deeply_index_file("rebar3_release_app.erl"),
    els_indexing:find_and_deeply_index_file("rebar3_release_sup.erl"),
    [{started, Started} | Config].

-spec end_per_testcase(atom(), config()) -> ok.
end_per_testcase(TestCase, Config) ->
    els_test_utils:end_per_testcase(TestCase, Config).

-spec suite() -> [tuple()].
suite() ->
    [{timetrap, {seconds, 30}}].

%%==============================================================================
%% Testcases
%%==============================================================================
-spec code_navigation(config()) -> ok.
code_navigation(Config) ->
    AppUri = ?config(app_uri, Config),
    SupUri = ?config(sup_uri, Config),
    #{result := Result} = els_client:definition(AppUri, 13, 12),
    #{range := DefRange, uri := SupUri} = Result,
    ?assertEqual(
        els_protocol:range(#{from => {16, 1}, to => {16, 11}}),
        DefRange
    ),
    ok.

%%==============================================================================
%% Internal Functions
%%==============================================================================

-spec root_path() -> binary().
root_path() ->
    RootPath = filename:join([code:priv_dir(els_lsp), ?TEST_APP]),
    els_utils:to_binary(RootPath).

-spec src_path(binary(), [any()]) -> binary().
src_path(RootPath, FileName) ->
    filename:join([RootPath, apps, ?TEST_APP, src, FileName]).
