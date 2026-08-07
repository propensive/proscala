# ==============================================================================
# Maven Central publication
#
# Publishes the jars built into release/<branch>/lib to Maven Central (the
# Sonatype Central Portal), under the `dev.propensive` group, using the same
# artifact names as the mainline Scala releases so the fork can stand in for
# them — `scala3-compiler_3`, `scala-library`, `tasty-core_3` and so on — at
# version <upstream-base>-p<n>.
#
# This mirrors how `consequent` publishes (same group, same portal, same
# detached-GPG signing, same one-bundle-per-release model) but is written in
# plain make + curl rather than Mill, so the build keeps to the toolchain
# AGENTS.md advertises: GNU make, curl, javac, jar and a JDK.
#
# Included by the top-level Makefile after mk/<stream>.mk, so every per-stream
# version variable is already set and the dependency lists below are derived
# from the very same variables the compile classpaths use. That is deliberate:
# a version bump in mk/<stream>.mk moves the POMs with it, and there is no
# second copy of the dependency graph to drift.
#
#   make VERSION=<v> publish-bundle   # build, stage, sign, zip — no upload
#   make VERSION=<v> publish          # ... and upload to the Central Portal
#
# Credentials, all from the environment:
#   SONATYPE_USERNAME / SONATYPE_PASSWORD   a Central *user token*, not portal
#                                           login credentials
#   PROSCALA_GPG_PASSPHRASE                 optional; when set, gpg runs
#                                           non-interactively (CI). When unset,
#                                           gpg-agent stays in charge and may
#                                           prompt, as consequent's release.sh
#                                           does on a developer machine.
# ==============================================================================

PUB_GROUP  := dev.propensive
PUB_URL    := https://github.com/propensive/proscala
PUB_SCM    := scm:git:https://github.com/propensive/proscala.git
PUB_STAGE  := $(BUILD)/publish
PUB_REPO   := $(PUB_STAGE)/repo
PUB_BUNDLE := $(RELEASE)/proscala-$(VERSION)-bundle.zip
PUB_API    := https://central.sonatype.com/api/v1/publisher/upload
PUB_NAME   := $(PUB_GROUP)-proscala:$(VERSION)
PUB_DESC   := A module of Proscala, the Propensive fork of Scala 3

# md5sum/sha1sum on Linux; md5/shasum on macOS. Both forms print the digest
# first, so a single `cut -d' ' -f1` works for either.
MD5CMD  := $(shell command -v md5sum  >/dev/null 2>&1 && echo md5sum  || echo 'md5 -q')
SHA1CMD := $(shell command -v sha1sum >/dev/null 2>&1 && echo sha1sum || echo 'shasum -a 1')

# ---- Third-party dependency coordinates --------------------------------------
# group:artifact:version, built from the same variables that name the downloaded
# jars in MAVEN_PATHS. $(LZ4_GROUP) and $(SCALAJS_GROUP) are path-shaped there
# (at/yawk/lz4), so they are dotted here.
D_ASM      := org.scala-lang.modules:scala-asm:$(ASM_VERSION)
D_CIFACE   := org.scala-sbt:compiler-interface:$(COMPILER_IFACE_VER)
D_UIFACE   := org.scala-sbt:util-interface:$(UTIL_IFACE_VER)
D_JLINE    := org.jline:jline-reader:$(JLINE_VERSION) \
              org.jline:jline-terminal:$(JLINE_VERSION) \
              org.jline:jline-terminal-jni:$(JLINE_VERSION)
D_COURSIER := io.get-coursier:interface:$(COURSIER_IFACE_VER)
D_LZ4      := $(subst /,.,$(LZ4_GROUP)):lz4-java:$(LZ4_VERSION)
D_GUAVA    := com.google.guava:guava:$(GUAVA_VERSION) \
              com.google.guava:failureaccess:$(FAILUREACCESS_VER)
D_MTAGS    := org.scalameta:mtags-interfaces:$(MTAGS_VERSION)
D_LSP4J    := org.eclipse.lsp4j:org.eclipse.lsp4j:$(LSP4J_VERSION) \
              org.eclipse.lsp4j:org.eclipse.lsp4j.jsonrpc:$(LSP4J_VERSION) \
              com.google.code.gson:gson:$(GSON_VERSION)
D_SJSJAVA  := $(subst /,.,$(SCALAJS_GROUP)):scalajs-javalib:$(SCALAJS_VERSION)

# `scalajs-library_2.13` depends on `org.scala-js:scalajs-scalalib_2.13`, the
# Scala 2.13 Scala.js standard library. Upstream publishes *its* Scala 3 stdlib
# to that same coordinate at the Scala version, so ordinary version-conflict
# resolution evicts the 2.13 one — which is the whole reason a Scala 3 artifact
# carries a `_2.13` suffix (see `scala-library-sjs` in project/Build.scala).
# We publish under `dev.propensive`, a different coordinate, so nothing is
# evicted and a consumer would end up with both copies of the stdlib .sjsir,
# which the Scala.js linker rejects as duplicate definitions. Excluding it here
# — on the dependency that actually drags it in — restores the intended
# single-stdlib classpath.
#
# The exclusion follows $(SCALAJS_GROUP): a stock tree gets Scala.js proper
# (org.scala-js:scalajs-library_2.13 -> org.scala-js:scalajs-scalalib_2.13),
# while a WASM tree gets the scala-wasm fork, whose library depends on
# io.github.scala-wasm:scalajs-scalalib_2.13 instead. Hard-coding org.scala-js
# would silently fail to exclude anything on precisely the trees we ship.
SJS_SCALALIB_COORD := $(subst /,.,$(SCALAJS_GROUP)):scalajs-scalalib_2.13


# ---- Our own modules, at this build's version --------------------------------
P_SCALALIB   := $(PUB_GROUP):scala-library:$(VERSION)
P_SCALA3LIB  := $(PUB_GROUP):scala3-library_3:$(VERSION)
P_IFACES     := $(PUB_GROUP):scala3-interfaces:$(VERSION)
P_TASTY      := $(PUB_GROUP):tasty-core_3:$(VERSION)
P_COMPILER   := $(PUB_GROUP):scala3-compiler_3:$(VERSION)
P_DIRECTIVES := $(PUB_GROUP):scala3-directives-parser_3:$(VERSION)
P_REPL       := $(PUB_GROUP):scala3-repl_3:$(VERSION)
P_SJSSCALA   := $(PUB_GROUP):scalajs-scalalib_2.13:$(VERSION)

# Only when the tree carries the module — mirrors $(HAS_DIRECTIVES) in the
# Makefile, which is what decides whether the jar is built at all.
DIRECTIVES_DEP := $(if $(HAS_DIRECTIVES),$(P_DIRECTIVES))

# ---- The published set -------------------------------------------------------
# One record per artifact, four `|`-separated fields:
#
#   artifactId | jar basename in $(LIB) | source roots (comma) | deps (comma)
#
# No field may contain a space. A dependency is `group:artifact:version`, with
# an optional `^exclGroup:exclArtifact` suffix adding a POM <exclusion>. Source
# roots are searched first-wins (so `library-js/src` overrides `library/src`,
# as the scalajs-scalalib compile does); `-` means no sources, which yields an
# empty jar — correct for the two placeholder modules, whose jars are empty too.
#
# The dependency graph matches the one Soundness resolves the fork through (the
# `repo` task in its build.mill, validated by a full Soundness build), extended
# with the two modules Soundness does not use — scala3-directives-parser and
# scala3-presentation-compiler — whose dependencies are taken from $(REPL_CP)
# and $(PC_CP) above.
comma     := ,
join_deps  = $(subst $(space),$(comma),$(strip $1))

# ---- The Scala.js library: stock, or ours on a WASM tree ---------------------
# Defined here, below `join_deps` and the P_* coordinates, because these are
# simply-expanded (`:=`) and would otherwise silently expand to nothing.
#
# On a WASM tree the build does not merely *add* to the Scala.js library: the
# $(SJS_LIB_SHIP) recipe in the Makefile replaces its `scala/scalajs/wit/package*`
# with Proscala's (nine `wit*` intrinsics that the scala-wasm fork's one-member
# version lacks) and *deletes* all of `scala/scalajs/wasi/*`, so those facades
# reach the classpath only from the scalalib, with a single provenance — mixed
# provenance reorders WIT variant cases, which miscompiles silently.
#
# Neither half can be delivered by an extra jar alongside the stock one: the wit
# package would be a duplicate class rather than an addition (a hard error for
# the Scala.js linker, and resolution-order roulette at compile time), and
# nothing can remove entries from someone else's jar. So on a WASM tree the
# patched library is published as ours and consumers resolve that instead — the
# same substitution Soundness makes locally in its build.mill `repo` task.
#
# With library and scalalib both under $(PUB_GROUP), no stock Scala.js artifact
# enters our graph at all, so no <exclusion> is needed. A stock tree still points
# at Scala.js proper, and still needs the exclusion described above.
ifeq ($(strip $(WIT_SRC)),)
  SJS_LIB_DEP := $(subst /,.,$(SCALAJS_GROUP)):scalajs-library_2.13:$(SCALAJS_VERSION)^$(SJS_SCALALIB_COORD)
  PUB_SJSLIB  :=
else
  SJS_LIB_DEP := $(PUB_GROUP):scalajs-library_2.13:$(VERSION)
  # Mirrors the stock POM's dependencies with our scalalib substituted for
  # theirs. `scalajs-javalib-intf` is omitted: it is `provided` there, so it is
  # not propagated to consumers, and this generator has no scope support.
  PUB_SJSLIB  := scalajs-library_2.13|scalajs-library_2.13-$(SCALAJS_VERSION).jar|-|$(call join_deps,org.scala-lang:scala-library:$(SCALA2_VERSION) $(D_SJSJAVA) $(P_SJSSCALA))
endif

PUB_TABLE := \
  scala-library|scala-library.jar|library/src|- \
  scala3-library_3|scala3-library.jar|-|$(P_SCALALIB) \
  scala3-interfaces|scala3-interfaces.jar|interfaces/src|- \
  tasty-core_3|tasty-core.jar|tasty/src|$(P_SCALALIB) \
  scala3-compiler_3|scala3-compiler.jar|compiler/src,compiler/src-scalajs-ir|$(call join_deps,$(P_IFACES) $(P_TASTY) $(P_SCALA3LIB) $(D_ASM) $(D_CIFACE) $(D_UIFACE)) \
  $(if $(HAS_DIRECTIVES),scala3-directives-parser_3|scala3-directives-parser.jar|directives-parser/src/main/scala|$(P_SCALALIB)) \
  scala3-staging_3|scala3-staging.jar|staging/src|$(P_COMPILER) \
  scala3-tasty-inspector_3|scala3-tasty-inspector.jar|tasty-inspector/src|$(P_COMPILER) \
  scala3-repl_3|scala3-repl.jar|repl/src|$(call join_deps,$(P_COMPILER) $(DIRECTIVES_DEP) $(D_JLINE) $(D_COURSIER) $(REPL_EXTRA_COORDS)) \
  scala3-sbt-bridge|scala3-sbt-bridge.jar|sbt-bridge/src|$(call join_deps,$(P_COMPILER) $(P_REPL)) \
  scala3-presentation-compiler_3|scala3-presentation-compiler.jar|presentation-compiler/src|$(call join_deps,$(P_COMPILER) $(DIRECTIVES_DEP) $(D_LZ4) $(D_COURSIER) $(D_MTAGS) $(D_GUAVA) $(D_LSP4J)) \
  scalajs-scalalib_2.13|scalajs-scalalib_2.13.jar|library-js/src,library/src|$(D_SJSJAVA) \
  $(PUB_SJSLIB) \
  scala3-library_sjs1_3|scala3-library_sjs1.jar|-|$(call join_deps,$(P_SCALALIB) $(SJS_LIB_DEP) $(P_SJSSCALA))

# ==============================================================================
# Targets
# ==============================================================================

# Refuse to publish a development version. Plain `make` leaves VERSION at the
# stream's `<base>-propensive`; a real publication is always driven by the
# release workflow, which passes the computed `<base>-p<n>`.
.PHONY: publish-check-version
publish-check-version:
	@case '$(VERSION)' in \
	  *-propensive) \
	    echo "publish: refusing to publish development version '$(VERSION)'" >&2; \
	    echo "         pass a release version, e.g. make VERSION=3.10.0-dev-p1 publish" >&2; \
	    exit 1 ;; \
	esac
	@echo ">> publishing $(words $(PUB_TABLE)) $(PUB_GROUP) artefacts at version $(VERSION)"

# Stage a Maven repository layout — jar, POM, sources jar and javadoc jar per
# artifact — then sign and checksum every file in it. Done in a single shell
# pass: re-entering make per artifact would re-parse the Makefile (and re-run
# its parse-time `find`s over compiler/src) dozens of times.
#
# `release` is built through a sub-make rather than named as a prerequisite so
# the version guard runs *before* the build, not concurrently with it. In CI
# the tarball step has already built everything, so this is a no-op.
.PHONY: publish-stage
publish-stage: publish-check-version
	@$(MAKE) release
	@rm -rf '$(PUB_STAGE)' && mkdir -p '$(PUB_REPO)'
	@set -eu; \
	 group_path=$$(printf '%s' '$(PUB_GROUP)' | tr . /); \
	 emit_pom() { \
	   id="$$1"; deps="$$2"; out="$$3"; \
	   case "$$id" in \
	     scalajs-library_2.13) \
	       desc='The Scala.js standard library from the scala-wasm fork (io.github.scala-wasm:scalajs-library_2.13), redistributed with Proscala&apos;s scala.scalajs.wit API spliced in and the scala/scalajs/wasi facades removed (they ship in scalajs-scalalib_2.13 instead, so that they have a single provenance). Original work by the Scala.js authors and the scala-wasm project, under the Apache License 2.0.' ;; \
	     *) desc="$(PUB_DESC) ($$id)." ;; \
	   esac; \
	   { printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
	       '<project xmlns="http://maven.apache.org/POM/4.0.0"' \
	       '         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' \
	       '         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">' \
	       '  <modelVersion>4.0.0</modelVersion>'; \
	     printf '  <groupId>%s</groupId>\n'       '$(PUB_GROUP)'; \
	     printf '  <artifactId>%s</artifactId>\n' "$$id"; \
	     printf '  <version>%s</version>\n'       '$(VERSION)'; \
	     printf '  <packaging>jar</packaging>\n'; \
	     printf '  <name>%s</name>\n'             "$$id"; \
	     printf '  <description>%s</description>\n' "$$desc"; \
	     printf '  <url>%s</url>\n'               '$(PUB_URL)'; \
	     printf '%s\n' '  <licenses><license>' \
	       '    <name>Apache-2.0</name>' \
	       '    <url>https://www.apache.org/licenses/LICENSE-2.0</url>' \
	       '    <distribution>repo</distribution>' \
	       '  </license></licenses>' \
	       '  <scm>' \
	       '    <url>$(PUB_URL)</url>' \
	       '    <connection>$(PUB_SCM)</connection>' \
	       '  </scm>' \
	       '  <developers><developer>' \
	       '    <id>propensive</id>' \
	       '    <name>Jon Pretty</name>' \
	       '    <url>https://github.com/propensive</url>' \
	       '  </developer></developers>' \
	       '  <dependencies>'; \
	     if [ "$$deps" != '-' ] && [ -n "$$deps" ]; then \
	       printf '%s\n' "$$deps" | tr ',' '\n' | while read -r dep; do \
	         [ -n "$$dep" ] || continue; \
	         spec=$${dep%%^*}; excl=''; \
	         case "$$dep" in *^*) excl=$${dep#*^} ;; esac; \
	         printf '    <dependency>\n'; \
	         printf '      <groupId>%s</groupId>\n'       "$$(printf '%s' "$$spec" | cut -d: -f1)"; \
	         printf '      <artifactId>%s</artifactId>\n' "$$(printf '%s' "$$spec" | cut -d: -f2)"; \
	         printf '      <version>%s</version>\n'       "$$(printf '%s' "$$spec" | cut -d: -f3)"; \
	         if [ -n "$$excl" ]; then \
	           printf '      <exclusions><exclusion>\n'; \
	           printf '        <groupId>%s</groupId>\n'       "$$(printf '%s' "$$excl" | cut -d: -f1)"; \
	           printf '        <artifactId>%s</artifactId>\n' "$$(printf '%s' "$$excl" | cut -d: -f2)"; \
	           printf '      </exclusion></exclusions>\n'; \
	         fi; \
	         printf '    </dependency>\n'; \
	       done; \
	     fi; \
	     printf '  </dependencies>\n</project>\n'; \
	   } > "$$out"; \
	 }; \
	 emit_srcjar() { \
	   roots="$$1"; out="$$2"; stage='$(PUB_STAGE)/src'; \
	   rm -rf "$$stage"; mkdir -p "$$stage"; \
	   if [ "$$roots" != '-' ]; then \
	     printf '%s\n' "$$roots" | tr ',' '\n' | while read -r root; do \
	       [ -n "$$root" ] && [ -d "$$root" ] || continue; \
	       cp -Rn "$$root/." "$$stage/" 2>/dev/null || true; \
	     done; \
	   fi; \
	   ( cd "$$stage" && jar cf "$$out" . ); \
	 }; \
	 emit_docjar() { \
	   out="$$1"; stage='$(PUB_STAGE)/doc'; \
	   rm -rf "$$stage"; mkdir -p "$$stage"; \
	   printf 'This artefact carries no API documentation.\n' > "$$stage/README"; \
	   ( cd "$$stage" && jar cf "$$out" . ); \
	 }; \
	 for record in $(foreach r,$(PUB_TABLE),'$(r)'); do \
	   id=$$(printf  '%s' "$$record" | cut -d'|' -f1); \
	   jar=$$(printf '%s' "$$record" | cut -d'|' -f2); \
	   src=$$(printf '%s' "$$record" | cut -d'|' -f3); \
	   dep=$$(printf '%s' "$$record" | cut -d'|' -f4); \
	   dir="$(PUB_REPO)/$$group_path/$$id/$(VERSION)"; \
	   base="$$dir/$$id-$(VERSION)"; \
	   mkdir -p "$$dir"; \
	   [ -f '$(LIB)'/"$$jar" ] || { echo "publish: missing $(LIB)/$$jar" >&2; exit 1; }; \
	   cp '$(LIB)'/"$$jar" "$$base.jar"; \
	   emit_pom    "$$id" "$$dep" "$$base.pom"; \
	   emit_srcjar "$$src"        "$$base-sources.jar"; \
	   emit_docjar                "$$base-javadoc.jar"; \
	   echo "   staged $$id"; \
	 done; \
	 rm -rf '$(PUB_STAGE)/src' '$(PUB_STAGE)/doc'
	@$(MAKE) --no-print-directory publish-sign

# Detached ASCII-armoured signature plus md5/sha1 for every staged file. With
# PROSCALA_GPG_PASSPHRASE set, gpg is fully non-interactive (loopback pinentry)
# for CI; without it gpg-agent stays in charge and may prompt, which is how a
# developer runs this locally.
.PHONY: publish-sign
publish-sign:
	@set -eu; \
	 find '$(PUB_REPO)' -type f ! -name '*.asc' ! -name '*.md5' ! -name '*.sha1' \
	 | while read -r f; do \
	     if [ -n "$${PROSCALA_GPG_PASSPHRASE:-}" ]; then \
	       printf '%s' "$$PROSCALA_GPG_PASSPHRASE" | gpg --batch --yes \
	         --pinentry-mode loopback --passphrase-fd 0 \
	         --armor --detach-sign --output "$$f.asc" "$$f"; \
	     else \
	       gpg --batch --yes --armor --detach-sign --output "$$f.asc" "$$f"; \
	     fi; \
	     $(MD5CMD)  "$$f" | cut -d' ' -f1 | tr -d '\n' > "$$f.md5"; \
	     $(SHA1CMD) "$$f" | cut -d' ' -f1 | tr -d '\n' > "$$f.sha1"; \
	   done; \
	 echo ">> signed $$(find '$(PUB_REPO)' -name '*.asc' | wc -l | tr -d ' ') files"

.PHONY: publish-bundle
publish-bundle: publish-stage
	@rm -f '$(PUB_BUNDLE)'
	@mkdir -p '$(RELEASE)'
	@cd '$(PUB_REPO)' && zip -qr '$(PUB_BUNDLE)' .
	@echo ">> bundle: $(PUB_BUNDLE)"

# publishingType=AUTOMATIC: the Portal validates the bundle and, if it passes,
# releases it to Maven Central with no further intervention — the same
# `--shouldRelease true` behaviour consequent's release.sh uses. Maven Central
# is append-only: a published version can never be replaced, only superseded by
# the next -p<n>.
.PHONY: publish
publish: publish-bundle
	@set -eu; \
	 : "$${SONATYPE_USERNAME:?publish: SONATYPE_USERNAME is not set}"; \
	 : "$${SONATYPE_PASSWORD:?publish: SONATYPE_PASSWORD is not set}"; \
	 token=$$(printf '%s:%s' "$$SONATYPE_USERNAME" "$$SONATYPE_PASSWORD" | base64 | tr -d '\n'); \
	 echo ">> uploading $(PUB_NAME) to the Central Portal"; \
	 id=$$(curl --fail-with-body --silent --show-error -X POST \
	        -H "Authorization: Bearer $$token" \
	        -F "bundle=@$(PUB_BUNDLE)" \
	        '$(PUB_API)?name=$(PUB_NAME)&publishingType=AUTOMATIC'); \
	 echo ">> deployment $$id submitted; Central will validate and release it"
