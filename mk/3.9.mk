# Per-stream build configuration for the 3.9 stream (tracks scala/scala3
# `lts-3.9`). Included by the top-level Makefile once STREAM is known.
# $(JARS) is defined by the Makefile before this file is included.

VERSION            := 3.9.1-dev-propensive
# The scala/scala3 commit this stream is built on (patches/3.9/series applies
# onto it), and the scala/scala3 branch it is taken from. Authoritative: the
# docs are checked against both. An upstream bump changes UPSTREAM_SHA.
UPSTREAM_REF       := lts-3.9
UPSTREAM_SHA       := 0bc121c5fd74a0340dc56e0739ebab40de3333a2
REF_VERSION        := 3.8.4
BASE_SCALAJS_VERSION    := 1.22.0
# The Scala version whose stock Scala Native artifacts (nscplugin, scala3lib) the
# Native variants of tasty-core and proscala-library are built with: the 3.9.0
# release, whose plugin this stream's lts-3.9 compiler still runs (tested at
# UPSTREAM_SHA). Empty disables the variants, as mk/3.10.mk does.
SN_SCALA_VERSION   := 3.9.0
COMPILER_IFACE_VER := 1.12.0
UTIL_IFACE_VER     := 1.11.5
JLINE_VERSION      := 4.0.14
COURSIER_IFACE_VER := 1.0.29-M4
LZ4_VERSION        := 1.8.1
LZ4_GROUP          := at/yawk/lz4
GUAVA_VERSION      := 33.6.0-jre
FAILUREACCESS_VER  := 1.0.3
WERROR_FLAGS       := -Werror

# This tree has no scala3-directives-parser module, so the repl pulls pprint /
# fansi / sourcecode and the using_directives parser from Maven instead.
EXTRA_MAVEN_PATHS := \
  com/lihaoyi/pprint_3/0.9.3/pprint_3-0.9.3.jar \
  com/lihaoyi/fansi_3/0.5.1/fansi_3-0.5.1.jar \
  com/lihaoyi/sourcecode_3/0.4.4/sourcecode_3-0.4.4.jar \
  org/virtuslab/using_directives/1.1.4/using_directives-1.1.4.jar
REPL_EXTRA_JARS := \
  $(JARS)/pprint_3-0.9.3.jar $(JARS)/fansi_3-0.5.1.jar \
  $(JARS)/sourcecode_3-0.4.4.jar $(JARS)/using_directives-1.1.4.jar
# The same jars as Maven coordinates, for the published scala3-repl_3 POM (see
# mk/publish.mk). Keep in step with REPL_EXTRA_JARS above.
REPL_EXTRA_COORDS := \
  com.lihaoyi:pprint_3:0.9.3 com.lihaoyi:fansi_3:0.5.1 \
  com.lihaoyi:sourcecode_3:0.4.4 org.virtuslab:using_directives:1.1.4
