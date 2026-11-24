"""Smoke test offline: builder + validasi + registrasi tools (tanpa login)."""
import asyncio
import sys

sys.path.insert(0, "src")

from workout_mcp import builders, workouts, validation


class StubClient:
    async def _noop(self, *a, **k):
        raise AssertionError("jangan panggil network saat smoke test")


async def main():
    # 1) builder interval 3x9' target pace
    d = builders.build_run_interval("Tes 3x9'", 3, 9, "time", 2, 10, 10,
                                    "pace", "4:38", None)
    validation.normalize_workout_steps(d)
    validation.validate_workout(d)
    steps = d["workoutSegments"][0]["workoutSteps"]
    assert steps[0]["stepType"]["stepTypeKey"] == "warmup", steps[0]
    grp = steps[1]
    assert grp["type"] == "RepeatGroupDTO", grp
    assert grp["numberOfIterations"] == 3, grp
    assert grp["endCondition"] == {"conditionTypeId": 7, "conditionTypeKey": "iterations"}
    assert [s["stepOrder"] for s in (steps[0], grp, grp["workoutSteps"][0],
                                     grp["workoutSteps"][1], steps[2])] == [1, 2, 3, 4, 5]
    tgt = grp["workoutSteps"][0]["targetType"]
    assert tgt == {"workoutTargetTypeId": 6, "workoutTargetTypeKey": "pace.zone"}, tgt

    # 2) builder 600m distance + HR zone
    d2 = builders.build_run_interval("Tes 8x600", 8, 600, "distance", 1, 10, 10,
                                     "hr", None, 4)
    validation.normalize_workout_steps(d2)
    validation.validate_workout(d2)
    rep0 = d2["workoutSegments"][0]["workoutSteps"][1]["workoutSteps"][0]
    assert rep0["endCondition"] == {"conditionTypeId": 3, "conditionTypeKey": "distance"}
    assert rep0["zoneNumber"] == 4, rep0

    # 3) builder walk/run
    d3 = builders.build_walk_run("Tes WR", 2, 2, 9, 10, 8, 2)
    validation.normalize_workout_steps(d3)
    validation.validate_workout(d3)

    # 4) validasi menolak pasangan salah
    bad = {"workoutSegments": [{"workoutSteps": [{
        "endCondition": {"conditionTypeId": 4, "conditionTypeKey": "heart.rate"}}]}]}
    try:
        validation.validate_workout(bad)
        raise SystemExit("FAIL: payload salah lolos validasi")
    except ValueError:
        pass

    # 5) registrasi tools (stub client, tanpa network)
    from mcp.server.fastmcp import FastMCP
    stub = StubClient()
    workouts.configure(stub)
    builders.configure(stub)
    app = FastMCP("smoke")
    n0 = len(await app.list_tools())
    app = workouts.register_tools(app)
    app = builders.register_tools(app)
    tools = sorted([t.name for t in await app.list_tools()])
    assert len(tools) == n0 + 12, tools
    for need in ("upload_workout", "delete_workout", "schedule_workout",
                 "unschedule_workout", "push_workout_to_device",
                 "create_run_interval_workout", "create_walk_run_workout",
                 "schedule_week", "list_workouts", "get_workout",
                 "get_scheduled_workouts", "get_devices"):
        assert need in tools, tools

    print(f"SMOKE OK: 12 tools terdaftar; builder 3x9'/8x600/walk-run valid.")


asyncio.run(main())
