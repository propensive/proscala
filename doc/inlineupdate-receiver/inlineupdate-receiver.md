# Judge inline receiver proxies by their underlying capture set

FIXME: this feature is not documented yet.

The patch (`feature/3.9/inlineupdate-receiver`, tip commit "Judge inline
receiver proxies by their underlying capture set") builds on
[inlineupdate](../inlineupdate/inlineupdate.md) but has no `doc/features`
file. Per AGENTS.md it needs: a single-sentence description; context,
reproduction and solution sections; a minimal reproduction; and the key
compiler change.

Note also that the branch itself is a legacy aggregation-style branch (it
carries other patches besides its own change) and is due to be rebuilt as a
clean patch on top of `inlineupdate`.
