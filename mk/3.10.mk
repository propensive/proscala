# Per-stream build configuration for the 3.10 stream (tracks scala/scala3 `main`).
# Included by the top-level Makefile once STREAM is known. Only the settings that
# genuinely differ between streams live here; everything else is shared and
# tree-detected. $(JARS) is defined by the Makefile before this file is included.

VERSION            := 3.10.1-dev-propensive
# The scala/scala3 commit this stream is built on (patches/3.10/series applies
# onto it), and the scala/scala3 branch it is taken from. Authoritative: the
# docs are checked against both. An upstream bump changes UPSTREAM_SHA.
UPSTREAM_REF       := main
UPSTREAM_SHA       := 403f2f663af8ad947e36a8f80f9680a9b71f7cf2
REF_VERSION        := 3.10.0-RC3
BASE_SCALAJS_VERSION    := 1.22.0
# The Scala version whose stock Scala Native artifacts (nscplugin, scala3lib) the
# Native variants of tasty-core and proscala-library are built with. None here:
# this stream's compiler comes from scala/scala3 `main`, whose internals have moved
# on from 3.10.0 (nscplugin_3.10.0 fails with a NoSuchMethodError in
# NirPrimitivesBase), and no plugin exists for an unreleased version. The
# variants are built for release targets, where mk/target.mk sets this.
SN_SCALA_VERSION   :=
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
# The 3.10.0-RC3 reference compiler depends on the same unshaded jars (see its
# POM), not on scala-asm, so they go on the reference classpath as well.
REF_ASM_JARS := $(foreach n,$(TREE_ASM_NAMES),$(n)-$(TREE_ASM_VERSION).jar)
