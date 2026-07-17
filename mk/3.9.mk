# Per-stream build configuration for the 3.9 stream (tracks scala/scala3
# `release-3.9.0`). Included by the top-level Makefile once STREAM is known.
# $(JARS) is defined by the Makefile before this file is included.

VERSION            := 3.9.0-RC1-propensive
REF_VERSION        := 3.8.4
SCALAJS_VERSION    := 1.22.0
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
