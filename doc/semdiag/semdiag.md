# Semantic diagnostics: XML error output with TASTy-encoded types

Adds `-Xsemantic-diagnostics`, which replaces the console error output with a
stream of XML elements in which the fragments of each message that were
interpolated from compiler entities — types, symbols, names, trees — are marked
up as such, and every type additionally carries its TASTy serialization,
Base64-encoded, so that a consumer can reconstruct it as a `TypeRepr`. Without
the flag, output is byte-for-byte unchanged.

## Context

Compiler error messages are assembled by the `i`/`em` string interpolators
(`Decorators.i`, `Formatting.StringFormatter`). Each interpolated argument — a
`Type`, `Symbol`, `Name`, a tree — is flattened to a `String` independently, at
`Showable.show`, *before* the surrounding message exists. By the time a
reporter sees a `Message`, it is plain text: a tool that wants to know "which
span of this message is a type, and which type?" has nothing to work with.

## The design

Three cooperating pieces, all inactive without the flag:

1. **In-band markup at the interpolation seam.** When a `Message` is forced
   with the flag set (`Message.inMessageContext` puts a
   `DiagnosticMarkup.Active` property on the message context),
   `StringFormatter.showArg` wraps the shown form of each argument in markers
   from the Unicode private use area (`U+E000`–`U+E003`), recording the
   argument's kind and attributes (`reporting/DiagnosticMarkup.scala`). Only
   message forcing is affected; `i""` used for logging never sees the property.
   Every consumer other than the XML reporter — the console renderer, the
   zinc/interface `Diagnostic.message()` accessor — strips the markers via
   `DiagnosticMarkup.plain`.

2. **Types pickled to standalone TASTy.** For a `Type` argument, the marker
   carries a `tasty` attribute: the type, wrapped in a `TypeTree`, pickled with
   `TastyPickler`/`TreePickler` (the same recipe as quote pickling) and
   Base64-encoded (`reporting/DiagnosticTypePickler.scala`). Because diagnostic
   types routinely mention things no consumer can resolve — symbols defined in
   the (failing) sources being compiled, error types, uninstantiated type
   variables, skolems — a sanitizing `TypeMap` first replaces each *maximal*
   subtree headed by such a part with a string literal type
   `"⟨scala-diag:<n>⟩"`. Whole subtrees are replaced, not just the offending
   reference, because a literal type cannot stand in a type-constructor or
   prefix position. Each replacement is described out-of-band by a placeholder
   record (kind, name, arity, definition position, printed form). A genuine
   string literal type starting with the reserved prefix is escaped as
   `"⟨scala-diag:esc:…⟩"`. Pickling failures are absorbed: the marker then
   simply has no `tasty` attribute — a diagnostic must never become a crash.

3. **An XML reporter.** `Driver.setup` installs
   `reporting/XmlReporter.scala` when the flag is set (unless `-Yreporter`
   names a custom reporter). It parses the markers back into structure and
   emits one top-level `<diagnostic>` element per diagnostic — a *stream of
   fragments*, not a single document.

`TypeMismatch.msg` is additionally changed to interpolate the found/required
types directly when markup is active, instead of pre-rendering them through
`Formatting.typeDiff` (whose colored string diff is useless to a structured
consumer and would defeat the markup).

## Output format

```xml
<diagnostic severity="error" kind="TypeMismatch" errorId="TypeMismatchID"
    errorNumber="7" compilerVersion="3.9.0-RC1-propensive" tastyVersion="28.9-1"
    file="local.scala" line="6" column="22" endLine="6" endColumn="24"
    start="126" end="128">
  <message>Found:    <type tasty="XKGrH5…">(Test.b2 : Box[String])<placeholder
      id="0" kind="local-term" name="b2" definedAt="local.scala:5"
      printed="(Test.b2 : Box[String])"/></type>
Required: <type tasty="XKGrH5…">Box[Int]<placeholder id="0" kind="local-type"
      name="Box" arity="1" definedAt="local.scala:1"
      printed="Box[Int]"/></type></message>
  <explanation>…</explanation>
</diagnostic>
```

- `<message>` (and `<explanation>`, present when the message can explain) hold
  mixed content: plain text interleaved with `<type>`, `<sym name=".."
  full="..">`, `<name isType="..">`, `<code>` and `<span>` elements whose text
  is the rendered form. Elements may nest (a marked composite phrase contains
  its marked constituents). An entity rendered in a non-default style — a
  declaration (`showDcl`), a location (`showLocated`), a full name — carries a
  `style` attribute (`dcl`, `located`, `full`) on its element. The elements of
  rendered sequences (e.g. lists of alternatives or type arguments) are marked
  individually. Line/column attributes are 1-based; `start`/`end` are
  character offsets.
- `<type tasty="…">` holds the Base64 TASTy of the sanitized type.
  `tastyVersion` gives the TASTy format version (`major.minor-experimental`);
  TASTy is version-locked, so a consumer must unpickle with a matching
  compiler.
- `<placeholder>` describes each `"⟨scala-diag:<id>⟩"` literal inside that
  type: `kind` is `local-type`, `local-term`, `error`, `typevar` or `skolem`;
  `definedAt` points at the source definition when there is one; `printed` is
  the display form of the replaced subtree, for rendering fallback.

A consumer that just wants clean text can concatenate the text content; a
consumer with a compiler on its classpath can unpickle each `tasty` attribute
(the payload is a single `TypeTree`) into a `TypeRepr`, substituting its
placeholder table wherever it finds a `ConstantType` string starting with
`⟨scala-diag:`.

## Limitations

- The composite-phrase helpers in `typer/ErrorReporting.scala` (`refStr`,
  `infoString`, `expectedTypeStr`, …) still pre-render their entities; the
  marker format supports converting them (markers nest, and `Styled` can
  carry any value), so coverage improves helper-by-helper without any format
  change. A caution for those conversions: `Styled` text is evaluated eagerly
  at the argument position on purpose — the `Seen` disambiguation machinery
  (superscripts, `where:` clauses) is sensitive to symbol recording order, and
  deferring a show reorders it after eagerly-evaluated sibling arguments.
  Messages that build synthetic example code or suggested identifiers from
  shown fragments are intentionally left as plain text.
- The REPL and sbt use their own reporters, so the flag currently only changes
  batch `scalac` output; under other reporters the markers are stripped and
  output is plain.
- `-explain` content, code actions and related-information are not yet
  structured beyond the message/explanation markup.

## Files

New: `reporting/DiagnosticMarkup.scala`, `reporting/DiagnosticTypePickler.scala`,
`reporting/XmlReporter.scala`. Modified: `config/ScalaSettings.scala` (flag),
`printing/Formatting.scala` (marking), `reporting/Message.scala` (activation),
`reporting/Diagnostic.scala` and `reporting/MessageRendering.scala` (stripping),
`reporting/messages.scala` (`TypeMismatch`), `Driver.scala` (reporter wiring).
