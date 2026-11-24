"""Auth: token store + login + CLI pra-autentikasi (dengan MFA)."""
import argparse
import getpass
import os
import sys

TOKEN_ENV = "WORKOUT_MCP_TOKENS"
DEFAULT_DIR = "~/.workout-mcp-tokens"


def token_dir():
    d = os.path.expanduser(os.getenv(TOKEN_ENV) or DEFAULT_DIR)
    os.makedirs(d, exist_ok=True)
    return d


def init_api():
    """Login via token tersimpan; fallback email/password env. Return client/None."""
    from garminconnect import (Garmin, GarminConnectAuthenticationError,
                               GarminConnectConnectionError,
                               GarminConnectTooManyRequestsError)
    d = token_dir()
    try:
        g = Garmin()
        g.login(d)
        print(f"Login token OK ({d})", file=sys.stderr)
        return g
    except Exception as e:
        print(f"Token login gagal: {str(e).split(':')[0]}", file=sys.stderr)
    email = os.getenv("GARMIN_EMAIL")
    password = os.getenv("GARMIN_PASSWORD")
    if not (email and password):
        print("Set GARMIN_EMAIL + GARMIN_PASSWORD, atau jalankan workout-mcp-auth.",
              file=sys.stderr)
        return None
    try:
        g = Garmin(email=email, password=password, return_on_mfa=True)
        r1, r2 = g.client.login(email, password, return_on_mfa=True)
        if r1 == "needs_mfa":
            code = input("Kode MFA Garmin: ").strip()
            g.resume_login(r2, code)
        g.client.dump(d)
        os.chmod(d, 0o700)
        print(f"Token tersimpan di {d}", file=sys.stderr)
        g2 = Garmin()
        g2.login(d)
        return g2
    except (GarminConnectAuthenticationError, GarminConnectConnectionError,
            GarminConnectTooManyRequestsError) as e:
        print(f"Login gagal: {e}", file=sys.stderr)
        return None


def main():
    ap = argparse.ArgumentParser(description="Pra-autentikasi WorkoutMCP (1x, dukung MFA)")
    ap.add_argument("--force-reauth", action="store_true")
    args = ap.parse_args()
    from garminconnect import Garmin
    d = token_dir()
    if os.path.exists(os.path.join(d, "garmin_tokens.json")) and not args.force_reauth:
        try:
            Garmin().login(d)
            print("Token masih valid, tidak perlu login ulang.")
            return
        except Exception:
            pass
    email = os.getenv("GARMIN_EMAIL") or input("Email Garmin: ").strip()
    password = os.getenv("GARMIN_PASSWORD") or getpass.getpass("Password: ")
    g = Garmin(email=email, password=password, return_on_mfa=True)
    r1, r2 = g.client.login(email, password, return_on_mfa=True)
    if r1 == "needs_mfa":
        g.resume_login(r2, input("Kode MFA Garmin: ").strip())
    g.client.dump(d)
    os.chmod(d, 0o700)
    Garmin().login(d)
    print(f"OK, token tersimpan di {d} (±6 bulan).")


if __name__ == "__main__":
    main()
