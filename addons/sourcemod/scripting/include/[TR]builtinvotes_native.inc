#if defined  _builtinvotes_native_included_
        #endinput
#endif
#define _builtinvotes_native_included_



native bool BuiltinVotes_StartVote(int client, char[] sArgument);


native bool BuiltinVotes_StartVoteAllTeam(int client, char[] sArgument);


forward void BuiltinVotes_VoteResult();


public SharedPlugin __pl_builtinvotes_native =
{
	name = "builtinvotes_native",
	file = "builtinvotes_native.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public void __pl_builtinvotes_native_SetNTVOptional()
{
	MarkNativeAsOptional("BuiltinVotes_StartVote");
	MarkNativeAsOptional("BuiltinVotes_StartVoteAllTeam");
}
