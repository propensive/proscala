# Per-stream build configuration for the 3.10 stream (tracks scala/scala3 `main`).
# Included by the top-level Makefile once STREAM is known. Only the settings that
# genuinely differ between streams live here; everything else is shared and
# tree-detected. $(JARS) is defined by the Makefile before this file is included.

VERSION            := 3.10.1-dev-propensive
# The branch of scala/scala3 that upstream/3.10 mirrors. Authoritative: the docs
# are checked against it, and `proscala-rebase-tree -u` fast-forwards to it.
UPSTREAM_REF       := main
REF_VERSION        := 3.10.0-RC1
BASE_SCALAJS_VERSION    := 1.22.0
COMPILER_IFACE_VER := 1.12.0
UTIL_IFACE_VER     := 1.11.5
JLINE_VERSION      := 4.0.14
COURSIER_IFACE_VER := 1.0.29-M4
LZ4_VERSION        := 1.8.1
LZ4_GROUP          := at/yawk/lz4
GUAVA_VERSION      := 33.6.0-jre
FAILUREACCESS_VER  := 1.0.3
# -Werror is enabled on warning-clean trees (main / 3.10.0-RC1).
WERROR_FLAGS       := -Werror

# This tree carries the scala3-directives-parser module and a leaner repl, so it
# needs no extra Maven artifacts beyond the common set.
EXTRA_MAVEN_PATHS  :=
REPL_EXTRA_JARS    :=
# The same jars as Maven coordinates, for the published scala3-repl_3 POM (see
# mk/publish.mk). Keep in step with REPL_EXTRA_JARS above.
REPL_EXTRA_COORDS  :=

# Upstream main's JVM backend imports org.objectweb.asm directly (unshaded)
# since the 9.10 switch, so this tree compiles and ships the org.ow2.asm jars;
# the shaded scala-asm remains only on the reference-compiler classpath.
TREE_ASM_VERSION := 9.10.1
TREE_ASM_NAMES := asm asm-tree asm-analysis asm-util asm-commons
TREE_ASM_MAVEN_PATHS := $(foreach n,$(TREE_ASM_NAMES),org/ow2/asm/$(n)/$(TREE_ASM_VERSION)/$(n)-$(TREE_ASM_VERSION).jar)
TREE_ASM_JARS := $(foreach n,$(TREE_ASM_NAMES),$(JARS)/$(n)-$(TREE_ASM_VERSION).jar)
TREE_ASM_COORDS := org.ow2.asm:asm-util:$(TREE_ASM_VERSION) org.ow2.asm:asm-commons:$(TREE_ASM_VERSION)
