# ==============================================================================
# Simplified non-bootstrapped release build for the Scala 3 compiler.
#
# Reproduces the essential parts of the sbt build (project/Build.scala) using a
# downloaded reference `scalac` invoked as a one-off `java` process, plus `javac`
# and `jar`. Produces the standard-distribution JARs into release/lib.
#
# Single non-bootstrapped stage: everything is compiled with the already-published
# reference compiler ($(REF_VERSION)). Portable to GNU Make 3.81 (macOS default):
# argfiles/manifests are written with shell `printf`, not the 4.0+ `$(file ...)`.
# ==============================================================================

# ---- Versions (per-tree config — the only block that differs across branches) -
VERSION            := 3.9.0-RC1-propensive
REF_VERSION        := 3.8.4
SCALA2_VERSION     := 2.13.18
SCALAJS_VERSION    := 1.20.2
ASM_VERSION        := 9.9.0-scala-1
COMPILER_IFACE_VER := 1.12.0
UTIL_IFACE_VER     := 1.11.5
JLINE_VERSION      := 4.0.14
COURSIER_IFACE_VER := 1.0.29-M4
LZ4_VERSION        := 1.8.1
LZ4_GROUP          := at/yawk/lz4
GUAVA_VERSION      := 33.6.0-jre
FAILUREACCESS_VER  := 1.0.3
MTAGS_VERSION      := 1.6.7
LSP4J_VERSION      := 1.0.0
GSON_VERSION       := 2.11.0
JAVA_TARGET        := 17
# -Werror is enabled on trees that are warning-clean (main, 3.9.0-RC1); the 3.8.4
# tree comments it out, so leave this empty there.
WERROR_FLAGS       := -Werror

# ---- Directories -------------------------------------------------------------
# Build artefacts and the release tree are laid out per git branch, so switching
# branches never clobbers another branch's output and each branch's build
# survives a checkout. The paths mirror the branch name — building
# feature/3.9/sambox writes release/feature/3.9/sambox/ and .build/feature/3.9/sambox/.
# Detached HEAD falls back to the short commit; override with `make BRANCH=<name>`.
# Downloaded Maven jars are shared (.build/jars): they are version-keyed and
# identical across branches, so there is no need to re-download them per branch.
ROOT     := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BRANCH   := $(shell git -C $(ROOT) symbolic-ref --quiet --short HEAD 2>/dev/null || git -C $(ROOT) rev-parse --short HEAD 2>/dev/null || echo detached)
JARS     := $(ROOT)/.build/jars
BUILD    := $(ROOT)/.build/$(BRANCH)
CLASSES  := $(BUILD)/classes
GEN      := $(BUILD)/gen
RELEASE  := $(ROOT)/release/$(BRANCH)
LIB      := $(RELEASE)/lib
BIN      := $(RELEASE)/bin

MC := https://repo1.maven.org/maven2

# Build-time constants
GITHASH := $(shell git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)
YEAR    := $(shell date +%Y)
JAVAC_FLAGS := -Xlint:unchecked -Xlint:deprecation --release $(JAVA_TARGET)

# ---- Make helpers ------------------------------------------------------------
empty :=
space := $(empty) $(empty)
cpjoin = $(subst $(space),:,$(strip $1))

.DEFAULT_GOAL := release

# Build modules in parallel by default. Module outputs are isolated (per-module
# class/arg/manifest dirs and distinct jar names), so this is race-free. Override
# on the command line with e.g. `make -j1` or `make -j12`. ~6 is a sweet spot:
# scalac is already multi-threaded, so higher just oversubscribes cores.
MAKEFLAGS += -j6

# ---- Per-tree extra dependencies (part of the per-tree config) ----------------
# Maven artifacts this tree needs beyond the common set, plus the repl's extra
# runtime jars. Empty on main (which uses the directives-parser module and a
# leaner repl); older release trees pull pprint/fansi/sourcecode and the
# using_directives parser from Maven instead.
EXTRA_MAVEN_PATHS := \
  com/lihaoyi/pprint_3/0.9.3/pprint_3-0.9.3.jar \
  com/lihaoyi/fansi_3/0.5.1/fansi_3-0.5.1.jar \
  com/lihaoyi/sourcecode_3/0.4.4/sourcecode_3-0.4.4.jar \
  org/virtuslab/using_directives/1.1.4/using_directives-1.1.4.jar
REPL_EXTRA_JARS := \
  $(JARS)/pprint_3-0.9.3.jar $(JARS)/fansi_3-0.5.1.jar \
  $(JARS)/sourcecode_3-0.4.4.jar $(JARS)/using_directives-1.1.4.jar

# ==============================================================================
# Dependencies (downloaded from Maven Central, cached under .build/jars)
# ==============================================================================
MAVEN_PATHS := $(EXTRA_MAVEN_PATHS) \
  org/scala-lang/scala3-compiler_3/$(REF_VERSION)/scala3-compiler_3-$(REF_VERSION).jar \
  org/scala-lang/scala3-library_3/$(REF_VERSION)/scala3-library_3-$(REF_VERSION).jar \
  org/scala-lang/scala-library/$(REF_VERSION)/scala-library-$(REF_VERSION).jar \
  org/scala-lang/tasty-core_3/$(REF_VERSION)/tasty-core_3-$(REF_VERSION).jar \
  org/scala-lang/scala3-interfaces/$(REF_VERSION)/scala3-interfaces-$(REF_VERSION).jar \
  org/scala-lang/modules/scala-asm/$(ASM_VERSION)/scala-asm-$(ASM_VERSION).jar \
  org/scala-sbt/compiler-interface/$(COMPILER_IFACE_VER)/compiler-interface-$(COMPILER_IFACE_VER).jar \
  org/scala-sbt/util-interface/$(UTIL_IFACE_VER)/util-interface-$(UTIL_IFACE_VER).jar \
  org/jline/jline-reader/$(JLINE_VERSION)/jline-reader-$(JLINE_VERSION).jar \
  org/jline/jline-terminal/$(JLINE_VERSION)/jline-terminal-$(JLINE_VERSION).jar \
  org/jline/jline-terminal-jni/$(JLINE_VERSION)/jline-terminal-jni-$(JLINE_VERSION).jar \
  io/get-coursier/interface/$(COURSIER_IFACE_VER)/interface-$(COURSIER_IFACE_VER).jar \
  $(LZ4_GROUP)/lz4-java/$(LZ4_VERSION)/lz4-java-$(LZ4_VERSION).jar \
  com/google/guava/guava/$(GUAVA_VERSION)/guava-$(GUAVA_VERSION).jar \
  com/google/guava/failureaccess/$(FAILUREACCESS_VER)/failureaccess-$(FAILUREACCESS_VER).jar \
  org/scalameta/mtags-interfaces/$(MTAGS_VERSION)/mtags-interfaces-$(MTAGS_VERSION).jar \
  org/scalameta/mtags-shared_$(SCALA2_VERSION)/$(MTAGS_VERSION)/mtags-shared_$(SCALA2_VERSION)-$(MTAGS_VERSION)-sources.jar \
  org/eclipse/lsp4j/org.eclipse.lsp4j/$(LSP4J_VERSION)/org.eclipse.lsp4j-$(LSP4J_VERSION).jar \
  org/eclipse/lsp4j/org.eclipse.lsp4j.jsonrpc/$(LSP4J_VERSION)/org.eclipse.lsp4j.jsonrpc-$(LSP4J_VERSION).jar \
  com/google/code/gson/gson/$(GSON_VERSION)/gson-$(GSON_VERSION).jar \
  org/scala-js/scalajs-library_2.13/$(SCALAJS_VERSION)/scalajs-library_2.13-$(SCALAJS_VERSION).jar \
  org/scala-js/scalajs-javalib/$(SCALAJS_VERSION)/scalajs-javalib-$(SCALAJS_VERSION).jar

DEPS_STAMP := $(JARS)/.stamp

# Depends on the Makefile so a version bump re-runs the download step (only the
# newly-named, missing jars are actually fetched).
$(DEPS_STAMP): Makefile
	@mkdir -p $(JARS)
	@for p in $(MAVEN_PATHS); do \
	  f=$(JARS)/$$(basename $$p); \
	  if [ ! -f "$$f" ]; then \
	    echo "  download $$(basename $$p)"; \
	    curl -fsSL "$(MC)/$$p" -o "$$f" || { echo "FAILED: $(MC)/$$p" >&2; exit 1; }; \
	  fi; \
	done
	@touch $@

.PHONY: deps
deps: $(DEPS_STAMP)

# Every third-party jar is actually produced by the $(DEPS_STAMP) recipe above,
# but modules list individual jars as prerequisites. Give those jars an explicit
# rule with an order-only dependency on the stamp (the empty recipe leaves the
# downloaded file in place) so a parallel build (`-j`) blocks on the download
# step instead of racing it and failing with "No rule to make target ...jar".
$(JARS)/%.jar: | $(DEPS_STAMP)
	@:

# ---- Reference compiler classpath & launcher --------------------------------
REF_JARS := \
  scala3-compiler_3-$(REF_VERSION).jar \
  scala3-library_3-$(REF_VERSION).jar \
  scala-library-$(REF_VERSION).jar \
  tasty-core_3-$(REF_VERSION).jar \
  scala3-interfaces-$(REF_VERSION).jar \
  scala-asm-$(ASM_VERSION).jar \
  compiler-interface-$(COMPILER_IFACE_VER).jar \
  util-interface-$(UTIL_IFACE_VER).jar

REF_CP := $(call cpjoin,$(addprefix $(JARS)/,$(REF_JARS)))
REFC   := java -cp "$(REF_CP)" dotty.tools.dotc.Main

# ---- Third-party jar paths (reused across modules) ---------------------------
ASM_JAR            := $(JARS)/scala-asm-$(ASM_VERSION).jar
COMPILER_IFACE_JAR := $(JARS)/compiler-interface-$(COMPILER_IFACE_VER).jar
UTIL_IFACE_JAR     := $(JARS)/util-interface-$(UTIL_IFACE_VER).jar
COURSIER_IFACE_JAR := $(JARS)/interface-$(COURSIER_IFACE_VER).jar
JLINE_JARS         := $(JARS)/jline-reader-$(JLINE_VERSION).jar \
                      $(JARS)/jline-terminal-$(JLINE_VERSION).jar \
                      $(JARS)/jline-terminal-jni-$(JLINE_VERSION).jar
LZ4_JAR            := $(JARS)/lz4-java-$(LZ4_VERSION).jar
GUAVA_JARS         := $(JARS)/guava-$(GUAVA_VERSION).jar $(JARS)/failureaccess-$(FAILUREACCESS_VER).jar
MTAGS_IFACE_JAR    := $(JARS)/mtags-interfaces-$(MTAGS_VERSION).jar
MTAGS_SHARED_SRC   := $(JARS)/mtags-shared_$(SCALA2_VERSION)-$(MTAGS_VERSION)-sources.jar
LSP4J_JARS         := $(JARS)/org.eclipse.lsp4j-$(LSP4J_VERSION).jar \
                      $(JARS)/org.eclipse.lsp4j.jsonrpc-$(LSP4J_VERSION).jar \
                      $(JARS)/gson-$(GSON_VERSION).jar
SJS_LIBRARY_JAR    := $(JARS)/scalajs-library_2.13-$(SCALAJS_VERSION).jar
SJS_JAVALIB_JAR    := $(JARS)/scalajs-javalib-$(SCALAJS_VERSION).jar

.PHONY: check-ref
check-ref: deps
	$(REFC) -version

# ==============================================================================
# Shared scalac argfile (common options, written once via portable printf).
# Space-containing -Wconf flags are wrapped in double quotes so the compiler's
# @argfile tokenizer keeps them as single arguments.
# ==============================================================================
COMMON_ARGS := $(GEN)/common.args

$(COMMON_ARGS): Makefile
	@mkdir -p $(GEN)
	@printf '%s\n' \
	  -feature -deprecation -unchecked $(WERROR_FLAGS) \
	  -encoding UTF8 \
	  -language:implicitConversions \
	  --java-output-version:$(JAVA_TARGET) \
	  -Yexplicit-nulls -Wsafe-init \
	  '"-Wconf:msg=package scala contains object and package with same name:i"' \
	  '"-Wconf:src=scaladoc-testcases/.*:s"' \
	  '"-Wconf:msg=The RHS of reassignment must be transitively initialized:i"' \
	  '"-Wconf:msg=Could not verify that the method argument is transitively initialized:i"' \
	  '"-Wconf:msg=may cause initialization errors:i"' \
	  '"-Wconf:cat=deprecation&origin=scala\.collection\.Iterable\.stringPrefix:s"' \
	  > $@

# Canned recipe: compile a Scala module with a given compiler launcher.
#   $(1) = compiler launch command (e.g. $(REFC) or $(STAGEC))
#   $(2) = module key (subdir under $(CLASSES))
#   $(3) = -classpath value (may be empty)
#   $(4) = source roots to scan for *.scala / *.java
# Sources are sorted (LC_ALL=C) for a deterministic order — the non-bootstrapped
# stdlib self-compile is sensitive to source order.
define scalac_with
	@rm -rf $(CLASSES)/$(2) && mkdir -p $(CLASSES)/$(2)
	@cp $(COMMON_ARGS) $(CLASSES)/$(2).args
	$(if $(strip $(3)),@printf '%s\n' -classpath '$(3)' >> $(CLASSES)/$(2).args)
	@printf '%s\n' -d $(CLASSES)/$(2) >> $(CLASSES)/$(2).args
	@find $(4) \( -name '*.scala' -o -name '*.java' \) -type f | LC_ALL=C sort >> $(CLASSES)/$(2).args
	$(1) @$(CLASSES)/$(2).args
endef

# Canned recipe: write a MANIFEST with an Automatic-Module-Name and jar it up.
#   $(1) = module key   $(2) = output jar   $(3) = automatic module name
define jar_module
	@printf 'Automatic-Module-Name: %s\n' '$(3)' > $(CLASSES)/$(1).mf
	jar cfm $(2) $(CLASSES)/$(1).mf -C $(CLASSES)/$(1) .
endef

# ==============================================================================
# Module JARs (release/lib)
# ==============================================================================
INTERFACES_JAR := $(LIB)/scala3-interfaces.jar
SCALA_LIB_JAR  := $(LIB)/scala-library.jar
SCALA3_LIB_JAR := $(LIB)/scala3-library.jar
TASTY_JAR      := $(LIB)/tasty-core.jar
COMPILER_JAR   := $(LIB)/scala3-compiler.jar

# scala3-directives-parser is a standalone module only in newer trees (main).
# Older release trees (3.8.4, 3.9.0-RC1) don't have it — build it only if present.
HAS_DIRECTIVES := $(wildcard directives-parser/src/main/scala)
ifneq ($(HAS_DIRECTIVES),)
DIRECTIVES_JAR := $(LIB)/scala3-directives-parser.jar
endif

# ---- 1. scala3-interfaces (pure Java) ----------------------------------------
$(INTERFACES_JAR): $(DEPS_STAMP) $(shell find interfaces/src -name '*.java')
	@echo ">> scala3-interfaces"
	@rm -rf $(CLASSES)/interfaces && mkdir -p $(CLASSES)/interfaces $(LIB)
	javac $(JAVAC_FLAGS) -d $(CLASSES)/interfaces $(shell find interfaces/src -name '*.java')
	$(call jar_module,interfaces,$@,org.scala.lang.scala3.interfaces)

# ---- 2. scala-library (Scala 3 stdlib: scalac + javac) -----------------------
LIBRARY_SRC := $(shell find library/src \( -name '*.scala' -o -name '*.java' \) -type f)
$(SCALA_LIB_JAR): $(COMMON_ARGS) $(DEPS_STAMP) $(LIBRARY_SRC) library/resources/rootdoc.txt
	@echo ">> scala-library ($(words $(LIBRARY_SRC)) sources)"
	@rm -rf $(CLASSES)/scala-library && mkdir -p $(CLASSES)/scala-library $(LIB)
	@cp $(COMMON_ARGS) $(CLASSES)/scala-library.args
	@printf '%s\n' -sourcepath library/src -d $(CLASSES)/scala-library >> $(CLASSES)/scala-library.args
	@find library/src \( -name '*.scala' -o -name '*.java' \) -type f | LC_ALL=C sort >> $(CLASSES)/scala-library.args
	$(REFC) @$(CLASSES)/scala-library.args
	javac $(JAVAC_FLAGS) -cp $(CLASSES)/scala-library -d $(CLASSES)/scala-library \
	  $(shell find library/src -name '*.java')
	cp library/resources/rootdoc.txt $(CLASSES)/scala-library/rootdoc.txt
	@printf '%s\n' \
	  'version.number=$(VERSION)' \
	  'maven.version.number=$(VERSION)' \
	  'copyright.string=Copyright 2002-$(YEAR), LAMP/EPFL' \
	  'shell.banner=%n      ________ ___   / /  ___%n    / __/ __// _ | / /  / _ |%n  __\ \/ /__/ __ |/ /__/ __ |%n /____/\___/_/ |_/____/_/ | |%n                          |/  %s' \
	  > $(CLASSES)/scala-library/library.properties
	@# Overlay the Scala 2.13-derived specialized classes (public tuple/function
	@# fields, $$sp variants) from the reference stdlib, matching the set the sbt
	@# build splices (project/ScalaLibraryFilesToCopy.scala).
	@rm -rf $(BUILD)/refstd && mkdir -p $(BUILD)/refstd
	@cd $(BUILD)/refstd && jar xf $(JARS)/scala-library-$(REF_VERSION).jar
	@# The reference stdlib ships matching .class + .tasty pairs; replace BOTH so
	@# the overlaid classfile stays in sync with its TASTy (avoids -Werror warning).
	@# Skips gracefully on trees without this file (grep -> empty list).
	@for E in $$(grep -oE '"[^"]+"' project/ScalaLibraryFilesToCopy.scala 2>/dev/null | tr -d '"'); do \
	   d=$$(dirname "$$E"); b=$$(basename "$$E"); \
	   [ -d "$(BUILD)/refstd/$$d" ] || continue; \
	   mkdir -p "$(CLASSES)/scala-library/$$d"; \
	   find "$(CLASSES)/scala-library/$$d" -maxdepth 1 -type f \
	     \( -name "$$b.class" -o -name "$$b\$$*.class" -o -name "$$b.tasty" -o -name "$$b\$$*.tasty" \) \
	     -delete 2>/dev/null || true; \
	   find "$(BUILD)/refstd/$$d" -maxdepth 1 -type f \
	     \( -name "$$b.class" -o -name "$$b\$$*.class" -o -name "$$b.tasty" -o -name "$$b\$$*.tasty" \) \
	     -exec cp {} "$(CLASSES)/scala-library/$$d/" \; ; \
	 done
	$(call jar_module,scala-library,$@,scala.library)

# ---- 3. scala3-library (empty placeholder jar) -------------------------------
$(SCALA3_LIB_JAR): $(DEPS_STAMP)
	@echo ">> scala3-library (empty)"
	@rm -rf $(CLASSES)/scala3-library && mkdir -p $(CLASSES)/scala3-library $(LIB)
	$(call jar_module,scala3-library,$@,org.scala.lang.scala3.library)

# ---- 4. tasty-core ------------------------------------------------------------
$(TASTY_JAR): $(COMMON_ARGS) $(SCALA_LIB_JAR) $(shell find tasty/src -name '*.scala')
	@echo ">> tasty-core"
	$(call scalac_with,$(REFC),tasty-core,$(SCALA_LIB_JAR),tasty/src)
	$(call jar_module,tasty-core,$@,org.scala.lang.tasty.core)

# ---- 5. scala3-directives-parser (only when the module exists) ---------------
ifneq ($(HAS_DIRECTIVES),)
$(DIRECTIVES_JAR): $(COMMON_ARGS) $(SCALA_LIB_JAR) $(shell find directives-parser/src/main/scala -name '*.scala')
	@echo ">> scala3-directives-parser"
	$(call scalac_with,$(REFC),directives,$(SCALA_LIB_JAR),directives-parser/src/main/scala)
	$(call jar_module,directives,$@,org.scala.lang.scala3.directives.parser)
endif

# ---- 6. scala3-compiler (compiler/src + vendored scalajs-ir + javac) ---------
COMPILER_SRC := $(shell find compiler/src compiler/src-scalajs-ir \( -name '*.scala' -o -name '*.java' \) -type f)
COMPILER_CP  := $(call cpjoin,$(SCALA_LIB_JAR) $(INTERFACES_JAR) $(TASTY_JAR) \
  $(JARS)/scala-asm-$(ASM_VERSION).jar $(JARS)/compiler-interface-$(COMPILER_IFACE_VER).jar \
  $(JARS)/util-interface-$(UTIL_IFACE_VER).jar)

$(COMPILER_JAR): $(COMMON_ARGS) $(SCALA_LIB_JAR) $(INTERFACES_JAR) $(TASTY_JAR) $(COMPILER_SRC)
	@echo ">> scala3-compiler ($(words $(COMPILER_SRC)) sources)"
	@rm -rf $(CLASSES)/compiler && mkdir -p $(CLASSES)/compiler $(LIB)
	@cp $(COMMON_ARGS) $(CLASSES)/compiler.args
	@printf '%s\n' \
	  '"-Wconf:src=.*src-scalajs-ir/.*&msg=Implicit parameters should be provided with a `using` clause:s"' \
	  '"-Wconf:src=.*src-scalajs-ir/.*&msg=uninitialized` instead:s"' \
	  '"-Wconf:src=.*src-scalajs-ir/.*&msg=object AnyRefMap in package scala\.collection\.mutable is deprecated:s"' \
	  >> $(CLASSES)/compiler.args
	@printf '%s\n' -classpath '$(COMPILER_CP)' -d $(CLASSES)/compiler >> $(CLASSES)/compiler.args
	@find compiler/src compiler/src-scalajs-ir \( -name '*.scala' -o -name '*.java' \) -type f | LC_ALL=C sort >> $(CLASSES)/compiler.args
	$(REFC) @$(CLASSES)/compiler.args
	javac $(JAVAC_FLAGS) -cp "$(COMPILER_CP):$(CLASSES)/compiler" -d $(CLASSES)/compiler \
	  $(shell find compiler/src -name '*.java')
	@printf '%s\n' \
	  'version.number=$(VERSION)' \
	  'maven.version.number=$(VERSION)' \
	  'git.hash=$(GITHASH)' \
	  'copyright.string=Copyright 2002-$(YEAR), LAMP/EPFL' \
	  > $(CLASSES)/compiler/compiler.properties
	@printf 'Automatic-Module-Name: %s\nGit-Hash: %s\n' 'org.scala.lang.scala3.compiler' '$(GITHASH)' \
	  > $(CLASSES)/compiler.mf
	jar cfm $@ $(CLASSES)/compiler.mf -C $(CLASSES)/compiler .

# ==============================================================================
# Downstream modules, compiled with the freshly-built compiler (STAGEC)
# ==============================================================================
STAGE_JARS := $(SCALA_LIB_JAR) $(COMPILER_JAR) $(TASTY_JAR) $(INTERFACES_JAR) \
              $(ASM_JAR) $(COMPILER_IFACE_JAR) $(UTIL_IFACE_JAR)
STAGE_CP   := $(call cpjoin,$(STAGE_JARS))
STAGEC     := java -cp "$(STAGE_CP)" dotty.tools.dotc.Main

STAGING_JAR         := $(LIB)/scala3-staging.jar
TASTY_INSPECTOR_JAR := $(LIB)/scala3-tasty-inspector.jar
REPL_JAR            := $(LIB)/scala3-repl.jar
SBT_BRIDGE_JAR      := $(LIB)/scala3-sbt-bridge.jar

# ---- 7. scala3-staging --------------------------------------------------------
$(STAGING_JAR): $(COMMON_ARGS) $(STAGE_JARS) $(shell find staging/src -name '*.scala')
	@echo ">> scala3-staging"
	$(call scalac_with,$(STAGEC),staging,$(STAGE_CP),staging/src)
	$(call jar_module,staging,$@,org.scala.lang.scala3.staging)

# ---- 8. scala3-tasty-inspector ------------------------------------------------
$(TASTY_INSPECTOR_JAR): $(COMMON_ARGS) $(STAGE_JARS) $(shell find tasty-inspector/src -name '*.scala')
	@echo ">> scala3-tasty-inspector"
	$(call scalac_with,$(STAGEC),tasty-inspector,$(STAGE_CP),tasty-inspector/src)
	$(call jar_module,tasty-inspector,$@,org.scala.lang.scala3.tasty.inspector)

# ---- 9. scala3-repl -----------------------------------------------------------
REPL_CP := $(call cpjoin,$(STAGE_JARS) $(DIRECTIVES_JAR) $(JLINE_JARS) $(COURSIER_IFACE_JAR) $(REPL_EXTRA_JARS))
$(REPL_JAR): $(COMMON_ARGS) $(STAGE_JARS) $(DIRECTIVES_JAR) $(shell find repl/src -name '*.scala')
	@echo ">> scala3-repl"
	$(call scalac_with,$(STAGEC),repl,$(REPL_CP),repl/src)
	cp -R repl/resources/. $(CLASSES)/repl/
	$(call jar_module,repl,$@,org.scala.lang.scala3.repl)

# ---- 10. scala3-sbt-bridge (pure Java, needs the compiler on classpath) ------
$(SBT_BRIDGE_JAR): $(STAGE_JARS) $(shell find sbt-bridge/src -name '*.java')
	@echo ">> scala3-sbt-bridge"
	@rm -rf $(CLASSES)/sbt-bridge && mkdir -p $(CLASSES)/sbt-bridge $(LIB)
	javac $(JAVAC_FLAGS) -cp "$(STAGE_CP)" -d $(CLASSES)/sbt-bridge \
	  $(shell find sbt-bridge/src -name '*.java')
	cp -R sbt-bridge/resources/. $(CLASSES)/sbt-bridge/
	$(call jar_module,sbt-bridge,$@,org.scala.lang.scala3.sbt.bridge)

# ==============================================================================
# Extra modules: Scala.js libraries + presentation compiler
# ==============================================================================
SJS_SCALALIB_JAR := $(LIB)/scalajs-scalalib_2.13.jar
SJS3_LIB_JAR     := $(LIB)/scala3-library_sjs1.jar
PC_JAR           := $(LIB)/scala3-presentation-compiler.jar
SJS_CP := $(call cpjoin,$(SJS_LIBRARY_JAR) $(SJS_JAVALIB_JAR))

# ---- 11. scala-library-sjs (Scala.js stdlib; .sjsir-only artifact) -----------
# Source set mirrors Build.scala:1188-1211: library-js/src overrides win over
# library/src; BoxesRunTime/ScalaNumber come from the Scala.js deps, not here.
$(SJS_SCALALIB_JAR): $(COMMON_ARGS) $(STAGE_JARS) $(SJS_LIBRARY_JAR) $(SJS_JAVALIB_JAR) \
                     $(shell find library-js/src -type f) $(LIBRARY_SRC)
	@echo ">> scala-library-sjs (Scala.js stdlib)"
	@rm -rf $(CLASSES)/sjs-scalalib $(CLASSES)/sjs-scalalib-jar
	@mkdir -p $(CLASSES)/sjs-scalalib $(CLASSES)/sjs-scalalib-jar $(GEN) $(LIB)
	@(cd library-js/src && find . \( -name '*.scala' -o -name '*.java' \) -type f | sed 's|^\./||') | LC_ALL=C sort > $(GEN)/sjs-js-rel.txt
	@(cd library/src    && find . \( -name '*.scala' -o -name '*.java' \) -type f | sed 's|^\./||') | LC_ALL=C sort > $(GEN)/sjs-lib-rel.txt
	@cp $(COMMON_ARGS) $(CLASSES)/sjs-scalalib.args
	@printf '%s\n' -scalajs '"-Wconf:any:s"' -classpath '$(SJS_CP)' \
	  -sourcepath 'library-js/src:library/src' -d $(CLASSES)/sjs-scalalib >> $(CLASSES)/sjs-scalalib.args
	@grep -vE 'BoxesRunTime.scala|ScalaNumber.scala' $(GEN)/sjs-js-rel.txt | sed 's|^|library-js/src/|' >> $(CLASSES)/sjs-scalalib.args
	@comm -23 $(GEN)/sjs-lib-rel.txt $(GEN)/sjs-js-rel.txt | grep -vE 'BoxesRunTime|ScalaNumber' | sed 's|^|library/src/|' >> $(CLASSES)/sjs-scalalib.args
	$(STAGEC) @$(CLASSES)/sjs-scalalib.args
	@# Keep only .sjsir plus the UnitOps / AnonFunctionXXL class+tasty entries.
	cd $(CLASSES)/sjs-scalalib && jar cf $@ $$(find . \( -name '*.sjsir' \
	  -o -name 'UnitOps.tasty' -o -name 'UnitOps.class' -o -name 'UnitOps$$.class' \
	  -o -name 'AnonFunctionXXL.tasty' -o -name 'AnonFunctionXXL.class' \) -type f)

# ---- 12. scala3-library-sjs (empty placeholder jar) --------------------------
$(SJS3_LIB_JAR): $(DEPS_STAMP)
	@echo ">> scala3-library-sjs (empty)"
	@rm -rf $(CLASSES)/sjs3-library && mkdir -p $(CLASSES)/sjs3-library $(LIB)
	$(call jar_module,sjs3-library,$@,org.scala.lang.scala3.library.sjs1)

# ---- 13. scala3-presentation-compiler ----------------------------------------
# Generates dotty.tools.pc.buildinfo.BuildInfo and compiles the shaded
# mtags-shared sources (protobuf remap + unsafe-nulls, per project/Shading.scala)
# alongside presentation-compiler/src.
PC_CP := $(call cpjoin,$(STAGE_JARS) $(DIRECTIVES_JAR) $(LZ4_JAR) $(COURSIER_IFACE_JAR) \
  $(MTAGS_IFACE_JAR) $(GUAVA_JARS) $(LSP4J_JARS))
$(PC_JAR): $(COMMON_ARGS) $(STAGE_JARS) $(DEPS_STAMP) $(shell find presentation-compiler/src -name '*.scala')
	@echo ">> scala3-presentation-compiler"
	@rm -rf $(CLASSES)/pc $(GEN)/pc-mtags $(GEN)/pc-buildinfo
	@mkdir -p $(CLASSES)/pc $(GEN)/pc-mtags $(GEN)/pc-buildinfo/dotty/tools/pc/buildinfo $(LIB)
	@printf '%s\n' 'package dotty.tools.pc.buildinfo' \
	  'object BuildInfo {' '  val scalaVersion: String = "$(VERSION)"' '}' \
	  > $(GEN)/pc-buildinfo/dotty/tools/pc/buildinfo/BuildInfo.scala
	@rm -rf $(BUILD)/mtags-shared && mkdir -p $(BUILD)/mtags-shared
	@cd $(BUILD)/mtags-shared && jar xf $(MTAGS_SHARED_SRC)
	@cd $(BUILD)/mtags-shared && find . -name '*.scala' -type f | while read f; do \
	   rel=$${f#./}; mkdir -p "$(GEN)/pc-mtags/$$(dirname "$$rel")"; \
	   sed -e 's|import com.google.protobuf.CodedInputStream|import dotty.tools.dotc.semanticdb.internal.SemanticdbInputStream as CodedInputStream|' \
	       -e 's|import com.google.protobuf.CodedOutputStream|import dotty.tools.dotc.semanticdb.internal.SemanticdbOutputStream as CodedOutputStream|' "$$f" \
	   | awk '{ if (found && !done && $$0 !~ /^[ \t]*$$/ && $$0 !~ /^package /) { print "import scala.language.unsafeNulls"; done=1 } print $$0; if (!found && $$0 ~ /^package /) found=1 }' \
	   > "$(GEN)/pc-mtags/$$rel"; \
	 done
	@cp $(COMMON_ARGS) $(CLASSES)/pc.args
	@printf '%s\n' '"-Wconf:src=.*/scala/meta/internal/.*:s"' -classpath '$(PC_CP)' -d $(CLASSES)/pc >> $(CLASSES)/pc.args
	@find presentation-compiler/src $(GEN)/pc-buildinfo $(GEN)/pc-mtags -name '*.scala' -type f | LC_ALL=C sort >> $(CLASSES)/pc.args
	$(STAGEC) @$(CLASSES)/pc.args
	$(call jar_module,pc,$@,org.scala.lang.scala3.presentation.compiler)

# ==============================================================================
# Aggregate targets
# ==============================================================================
STAGE1_JARS := $(INTERFACES_JAR) $(SCALA_LIB_JAR) $(SCALA3_LIB_JAR) $(TASTY_JAR) \
               $(DIRECTIVES_JAR) $(COMPILER_JAR)
STAGE2_JARS := $(STAGING_JAR) $(TASTY_INSPECTOR_JAR) $(REPL_JAR) $(SBT_BRIDGE_JAR)
EXTRA_JARS  := $(SJS_SCALALIB_JAR) $(SJS3_LIB_JAR) $(PC_JAR)

.PHONY: stage1
stage1: $(STAGE1_JARS)

.PHONY: stage2
stage2: $(STAGE2_JARS)

.PHONY: extra
extra: $(EXTRA_JARS)

# Third-party runtime jars shipped alongside the built modules on the classpath.
THIRDPARTY_JARS := $(ASM_JAR) $(COMPILER_IFACE_JAR) $(UTIL_IFACE_JAR) \
  $(JLINE_JARS) $(COURSIER_IFACE_JAR) $(LZ4_JAR) $(GUAVA_JARS) $(MTAGS_IFACE_JAR) \
  $(LSP4J_JARS) $(SJS_LIBRARY_JAR) $(SJS_JAVALIB_JAR) $(REPL_EXTRA_JARS)

# ---- Launcher scripts --------------------------------------------------------
SCALAC_LAUNCHER := $(BIN)/scalac
SCALA_LAUNCHER  := $(BIN)/scala

$(SCALAC_LAUNCHER): Makefile
	@mkdir -p $(BIN)
	@printf '%s\n' \
	  '#!/usr/bin/env bash' \
	  '# Simplified scalac launcher — runs the built compiler over release/lib.' \
	  'PROG_HOME="$$(cd "$$(dirname "$${BASH_SOURCE[0]}")/.." && pwd)"' \
	  'exec java -Dscala.usejavacp=true -cp "$$PROG_HOME/lib/*" dotty.tools.MainGenericCompiler "$$@"' \
	  > $@
	@chmod +x $@

$(SCALA_LAUNCHER): Makefile
	@mkdir -p $(BIN)
	@printf '%s\n' \
	  '#!/usr/bin/env bash' \
	  '# Simplified scala launcher — starts the REPL (dotty.tools.repl.Main).' \
	  '# Extra classpath entries can be added via SCALA_CP, e.g. SCALA_CP=out scala.' \
	  'PROG_HOME="$$(cd "$$(dirname "$${BASH_SOURCE[0]}")/.." && pwd)"' \
	  'CP="$$PROG_HOME/lib/*"; [ -n "$$SCALA_CP" ] && CP="$$CP:$$SCALA_CP"' \
	  'exec java -Dscala.usejavacp=true -cp "$$CP" dotty.tools.repl.Main "$$@"' \
	  > $@
	@chmod +x $@

.PHONY: launchers
launchers: $(SCALAC_LAUNCHER) $(SCALA_LAUNCHER)

.PHONY: clean
clean:
	rm -rf $(CLASSES) $(GEN) $(RELEASE)

.PHONY: distclean
distclean:
	rm -rf $(BUILD) $(RELEASE)

# Full release: all module jars + third-party runtime jars + launchers in release/.
.PHONY: release
release: stage1 stage2 extra launchers
	@cp $(THIRDPARTY_JARS) $(LIB)/
	@echo ""
	@echo "Release built in $(RELEASE)"
	@echo "  modules : $(words $(STAGE1_JARS) $(STAGE2_JARS) $(EXTRA_JARS)) jars"
	@echo "  deps    : $(words $(THIRDPARTY_JARS)) third-party jars"
	@echo "  launcher: $(BIN)/scalac  $(BIN)/scala"
