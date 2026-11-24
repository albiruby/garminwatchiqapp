"""WorkoutMCP — MCP server khusus workout Garmin (stdio)."""
import sys

from mcp.server.fastmcp import FastMCP

from workout_mcp import auth, workouts, builders


def main():
    if sys.platform == "win32":
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, newline="\n")

    client = auth.init_api()
    if client is None:
        print("FATAL: login Garmin gagal.", file=sys.stderr)
        sys.exit(1)

    workouts.configure(client)
    builders.configure(client)

    app = FastMCP("WorkoutMCP v1.0")
    app = workouts.register_tools(app)
    app = builders.register_tools(app)

    print("WorkoutMCP siap (stdio).", file=sys.stderr)
    app.run(transport="stdio")


if __name__ == "__main__":
    main()
