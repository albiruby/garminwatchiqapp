from garmin_packet.sources import EndpointStatus, SourceStatus


def test_source_status_marks_partial_on_error():
    status = SourceStatus("demo")
    status.add(EndpointStatus("a", "ok"))
    assert status.status == "ok"
    status.add(EndpointStatus("b", "error", error="boom"))
    assert status.status == "partial"
    payload = status.as_dict()
    assert payload["source"] == "demo"
    assert len(payload["endpoints"]) == 2
