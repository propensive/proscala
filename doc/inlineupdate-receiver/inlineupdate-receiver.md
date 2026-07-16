# Judge inline receiver proxies by their underlying capture set

FIXME: this feature is not documented yet.

The patch (`feature/3.9/inlineupdate-receiver`, commit "Judge inline receiver
proxies by their underlying capture set") builds on
[inlineupdate](../inlineupdate/inlineupdate.md) and has never been documented.
Per AGENTS.md it needs: a single-sentence description; context, reproduction
and solution sections; a minimal reproduction; and the key compiler change.
The commit message is a useful starting point: capture checking runs on
inlined trees, so an update call made through an inline forwarder sees the
inliner's receiver proxy, whose own capability is never exclusive; the patch
judges an `InlineProxy` `TermRef` by the capture set of its underlying type —
the receiver expression it binds.
