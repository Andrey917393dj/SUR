"""Targeted test: Lair Farm must target ONLY the boss, never ordinary NPCs.

Regression guard for the bug where findLairBoss() fell back to "any live
Humanoid that is not a player", which made the farm chew through every NPC
in Workspace.Living.

Usage: python tools/boss_target.py SUR_Message.lua
"""

import os
import sys

import lupa

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    if len(sys.argv) < 2:
        print("usage: boss_target.py <script.lua>")
        return 1

    lua = lupa.LuaRuntime()
    with open(os.path.join(HERE, "mock_roblox.lua"), encoding="utf-8") as f:
        mock = lua.execute(f.read())

    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        src = f.read()

    # click_all=False: we do not want the farm starting during the test
    ok, err, errors = mock.run(src, False)
    if not ok:
        print(f"FATAL: {err}")
        return 1

    err_list = list(errors.values()) if hasattr(errors, "values") else list(errors)
    for e in err_list:
        print(f"spawned error: {e}")

    # Build NPCs inside Workspace.Living through the mock's own constructor.
    setup = lua.eval("""
        function(mock, names)
            local living = mock.workspace:FindFirstChild("Living")
            local made = {}
            for _, spec in ipairs(names) do
                local m = mock.newInstance("Model", spec.name)
                local h = mock.newInstance("Humanoid", "Humanoid")
                h.Health = spec.hp
                h.MaxHealth = spec.hp
                h.Parent = m
                local r = mock.newInstance("Part", "HumanoidRootPart")
                r.Parent = m
                m.Parent = living
                made[#made + 1] = m
            end
            return #made
        end
    """)

    def boss_alive():
        env = mock.env
        if env is None:
            return "__NO_ENV__"
        sur = env.getgenv().SUR
        if sur is None:
            return "__NO_SUR__"
        return sur.state().bossAlive

    failures = []

    # --- case 1: only ordinary NPCs, no boss -------------------------------
    lua_table = lua.table()
    for i, spec in enumerate([
        {"name": "Dio", "hp": 100},
        {"name": "Jotaro", "hp": 100},
        {"name": "Kira", "hp": 100},
    ]):
        row = lua.table()
        row["name"] = spec["name"]
        row["hp"] = spec["hp"]
        lua_table[i + 1] = row

    made = setup(mock, lua_table)
    print(f"spawned {made} ordinary NPCs in Living")

    got = boss_alive()
    if got is not None:
        failures.append(f"case 1: ordinary NPC '{got}' was treated as the boss")
        print(f"  FAIL  bossAlive = {got!r}  (expected nil)")
    else:
        print("  OK    bossAlive = nil")

    # --- case 2: real boss appears ----------------------------------------
    boss_spec = lua.table()
    boss_row = lua.table()
    boss_row["name"] = "Boss"
    boss_row["hp"] = 5000
    boss_spec[1] = boss_row

    setup(mock, boss_spec)

    got = boss_alive()
    if got != "Boss":
        failures.append(f"case 2: expected 'Boss', got {got!r}")
        print(f"  FAIL  bossAlive = {got!r}  (expected 'Boss')")
    else:
        print("  OK    bossAlive = 'Boss'")

    # --- case 3: a world boss with a non-canonical name must NOT be picked --
    # Living also holds world bosses (Jotaro Over Heaven, JohnnyJoestar, ...).
    # The farm must ignore them completely — otherwise it leaves the lair and
    # teleports into the open world to chew on whatever it finds.
    lua.eval("""
        function(mock)
            local living = mock.workspace:FindFirstChild("Living")
            local b = living:FindFirstChild("Boss")
            if b then b.Parent = nil end
        end
    """)(mock)

    lua_table2 = lua.table()
    row = lua.table()
    row["name"] = "Jotaro Over Heaven"
    row["hp"] = 5000
    lua_table2[1] = row
    setup(mock, lua_table2)

    got = boss_alive()
    if got is not None:
        failures.append(f"case 3: world boss '{got}' was treated as the lair boss")
        print(f"  FAIL  bossAlive = {got!r}  (expected nil)")
    else:
        print("  OK    bossAlive = nil  (world boss ignored)")

    print()
    if failures:
        for f in failures:
            print(f"FAIL {f}")
        return 1
    print("ALL BOSS-TARGETING CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
