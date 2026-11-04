#!/usr/bin/env python3
"""Write the crux-layout ivy.xml for a Proscala POM.

Usage: pom-to-ivy.py <pom> <out>

Proscala publishes its modules under `dev.propensive`, but every Scala build asks for the Scala
toolchain as `org.scala-lang` (Mill 1.x ignores `scalaOrganization` altogether), and a release
serves a module under whichever organisation is asked for. So that one coordinate names each jar,
the descriptor names the fork's own modules `org.scala-lang` — and its Scala.js ones
`org.scala-js`, as the Soundness build does — in both its info and its dependencies.
"""
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import quoteattr

NS = {"m": "http://maven.apache.org/POM/4.0.0"}


def organisation(group, artifact):
    if group != "dev.propensive":
        return group
    return "org.scala-js" if artifact.startswith("scalajs-") else "org.scala-lang"


def text(node, name):
    found = node.find(f"m:{name}", NS)
    return found.text.strip() if found is not None and found.text else None


def main(pom, out):
    root = ET.parse(pom).getroot()
    group, artifact, version = (text(root, n) for n in ("groupId", "artifactId", "version"))
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<ivy-module version="2.0" xmlns:e="http://ant.apache.org/ivy/extra">',
        f'    <info organisation={quoteattr(organisation(group, artifact))} module={quoteattr(artifact)} revision={quoteattr(version)} status="release"/>',
        "    <configurations>",
        '        <conf name="pom" visibility="public" description=""/>',
        '        <conf extends="runtime" name="test" visibility="public" description=""/>',
        '        <conf name="provided" visibility="public" description=""/>',
        '        <conf name="optional" visibility="public" description=""/>',
        '        <conf name="compile" visibility="public" description=""/>',
        '        <conf extends="compile" name="runtime" visibility="public" description=""/>',
        # Ivy's conventional `default`, which sbt asks a Scala 3 compiler bridge for
        # (`ZincTool->default,optional(default)`) and Mill's own descriptors lack.
        '        <conf extends="runtime" name="default" visibility="public" description=""/>',
        "    </configurations>",
        "    <publications>",
        f'        <artifact name={quoteattr(artifact)} type="pom" ext="pom" conf="pom"/>',
        f'        <artifact name={quoteattr(artifact)} type="jar" ext="jar" conf="compile"/>',
        "    </publications>",
        "    <dependencies>",
    ]
    for dep in root.findall("m:dependencies/m:dependency", NS):
        g, a, v = (text(dep, n) for n in ("groupId", "artifactId", "version"))
        scope = text(dep, "scope") or "compile"
        conf = {"compile": "compile->default(compile)", "runtime": "runtime->default(compile)",
                "provided": "provided->default(compile)", "test": "test->default(compile)"}[scope]
        exclusions = dep.findall("m:exclusions/m:exclusion", NS)
        head = f'        <dependency org={quoteattr(organisation(g, a))} name={quoteattr(a)} rev={quoteattr(v)} conf={quoteattr(conf)}'
        if not exclusions:
            lines.append(head + "/>")
        else:
            lines.append(head + ">")
            for ex in exclusions:
                eg, ea = text(ex, "groupId"), text(ex, "artifactId")
                lines.append(f'            <exclude org={quoteattr(organisation(eg, ea))} module={quoteattr(ea)}/>')
            lines.append("        </dependency>")
    lines += ["    </dependencies>", "</ivy-module>"]
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
