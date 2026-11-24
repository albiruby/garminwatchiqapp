import pytest

from garmin_packet.sources import ReadOnlyGarminClient


class DummyClient:
    def get_gear(self):
        return [{"gearId": "g1"}]

    def delete_workout(self, workout_id):
        return {"deleted": workout_id}

    def post(self, *args, **kwargs):
        return "posted"


def test_read_only_wrapper_allows_get_methods():
    wrapped = ReadOnlyGarminClient(DummyClient())
    assert wrapped.get_gear() == [{"gearId": "g1"}]


def test_read_only_wrapper_blocks_writes_and_raw_client():
    wrapped = ReadOnlyGarminClient(DummyClient())
    with pytest.raises(PermissionError):
        wrapped.delete_workout(1)
    with pytest.raises(PermissionError):
        wrapped.post("x")
    with pytest.raises(PermissionError):
        wrapped._client
    with pytest.raises(PermissionError):
        wrapped.client
    # Introspection only exposes the allowlisted read methods.
    methods = object.__getattribute__(wrapped, "_methods")
    assert "get_gear" in methods
    assert "delete_workout" not in methods
