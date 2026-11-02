"""Reading a deck's YAML faster, with the same result.

PyYAML's pure-Python reader is slow, and libyaml's, which `yaml.CSafeLoader`
uses, is quick at the first half of the job only: turning the text into
nodes. Building the data from them stays in Python and takes most of the
time. [fast_load] does that for the plain case, a document of mappings,
lists and scalars, which every deck is, and gives up on anything else.

It never has an opinion of its own. A text it will not read, for any reason,
raises [Fallback], and the caller reads it with the loader it always used, so
that every error message is that loader's. What it does read it reads to the
same data, scalar for scalar, key order included; tools/test_fast_yaml.py
holds it to that.
"""

from __future__ import annotations

import yaml

__all__ = ["Fallback", "fast_load"]


class Fallback(Exception):
    """Not read here; read it with the loader of record."""


_TAG = "tag:yaml.org,2002:"
_KEY_TAGS = frozenset(_TAG + t for t in ("str", "int", "float", "bool", "null"))


def fast_load(text: str, loader_class: type) -> object:
    """`yaml.load(text, Loader=L)`, where [loader_class] is the libyaml-backed
    twin of L (one that builds nodes with `yaml.CParser`). Raises [Fallback]
    for anything but mappings, lists and scalars, for a duplicate key, for a
    `<<` key and for every error."""
    loader = loader_class(text)
    try:
        node = loader.get_single_node()
        if node is None:
            return None
        made: dict[int, object] = {}
        scalar, mapping, sequence = (yaml.ScalarNode, yaml.MappingNode,
                                     yaml.SequenceNode)
        construct = loader.construct_object
        str_tag, seq_tag, map_tag = _TAG + "str", _TAG + "seq", _TAG + "map"

        def build(node: yaml.Node) -> object:
            t = type(node)
            if t is scalar:
                if node.tag == str_tag:
                    return node.value
                return construct(node, deep=True)
            done = made.get(id(node), made)
            if done is not made:
                return done
            if t is sequence and node.tag == seq_tag:
                items: list = []
                made[id(node)] = items
                items.extend([build(n) for n in node.value])
                return items
            if t is mapping and node.tag == map_tag:
                result: dict = {}
                made[id(node)] = result
                for key_node, value_node in node.value:
                    if type(key_node) is not scalar \
                            or key_node.tag not in _KEY_TAGS \
                            or key_node.value == "<<":
                        raise Fallback
                    key = build(key_node)
                    if key in result:
                        raise Fallback
                    result[key] = build(value_node)
                return result
            raise Fallback

        return build(node)
    except Fallback:
        raise
    except Exception as exc:  # noqa: BLE001 - re-read, for its message
        raise Fallback from exc
    finally:
        loader.dispose()
