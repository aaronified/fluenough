"""pytest hooks for the tools' tests (CI only; the tests are plain unittest).

CI runs these in parallel jobs ("Decks: tools' tests (part N/2)"). Setting
TOOLS_TESTS_PART=N/M keeps every Mth test, by its position in the sorted list
of test ids, starting at N: the parts are disjoint, together they are every
test, and each worker collects the same list, so `pytest -n auto` inside a
part agrees with itself. Unset, nothing is filtered, as on a contributor's
machine.
"""

import os

import pytest


def _part() -> tuple[int, int] | None:
    raw = os.environ.get("TOOLS_TESTS_PART")
    if not raw:
        return None
    n, _, m = raw.partition("/")
    part, total = int(n), int(m)
    if not 1 <= part <= total:
        raise SystemExit(f"TOOLS_TESTS_PART={raw!r}: want N/M with 1 <= N <= M")
    return part, total


@pytest.hookimpl(trylast=True)
def pytest_collection_modifyitems(config, items):
    part = _part()
    if part is None:
        return
    n, total = part
    # The `-k` / `--deselect` filters have already run: split what is left.
    ordered = sorted(items, key=lambda item: item.nodeid)
    mine = {item.nodeid for i, item in enumerate(ordered) if i % total == n - 1}
    skipped = [item for item in items if item.nodeid not in mine]
    config.hook.pytest_deselected(items=skipped)
    items[:] = [item for item in items if item.nodeid in mine]
