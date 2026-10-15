defmodule Aiur.Experiments.PreregistrationTest do
  use ExUnit.Case, async: true
  alias Aiur.Experiments.Preregistration
  @fixture Path.expand("../../fixtures/experiments/preregistration.valid.json", __DIR__)

  test "server timestamps prevent backdating and author cannot hide post-hoc registration" do
    attrs = @fixture |> File.read!() |> Jason.decode!()
    now = ~U[2026-10-15 18:00:00Z]
    assert {:ok, record} = Preregistration.prepare(attrs, nil, "2026-10-14T18:00:00Z", now)
    assert record["post_hoc"] == true
    assert record["registered_at"] == "2026-10-15T18:00:00Z"
    assert {:ok, timely} = Preregistration.prepare(Map.put(attrs, "post_hoc", true), nil, nil, now)
    assert timely["post_hoc"] == false
    assert timely["amendments"] == []
  end

  test "amendments preserve the original, require a reason, and flag results already read" do
    attrs = @fixture |> File.read!() |> Jason.decode!()
    assert {:ok, first} = Preregistration.prepare(attrs, nil, nil, ~U[2026-10-09 18:00:00Z])
    changed = Map.put(attrs, "hypothesis", "Amended hypothesis")
    assert {:error, [%{path: "reason"}]} = Preregistration.prepare(changed, first, nil, ~U[2026-10-10 18:00:00Z])
    assert {:error, [%{path: "reason"}]} = Preregistration.prepare(Map.put(changed, "reason", "  "), first, nil, ~U[2026-10-10 18:00:00Z])
    assert {:ok, amended} = Preregistration.prepare(Map.put(changed, "reason", "Correct measurement unit"), first, "2026-10-10T00:00:00Z", ~U[2026-10-10 18:00:00Z])
    assert Map.delete(amended, "amendments") == Map.delete(first, "amendments")
    assert [%{"reason" => "Correct measurement unit", "post_hoc" => true, "at" => "2026-10-10T18:00:00Z", "record" => amendment}] = amended["amendments"]
    assert amendment["hypothesis"] == "Amended hypothesis"
  end

  test "rejects malformed and incomplete registrations" do
    assert {:error, [%{path: "preregistration"}]} = Preregistration.prepare([], nil, nil, DateTime.utc_now())
    assert {:error, errors} = Preregistration.prepare(%{}, nil, nil, DateTime.utc_now())
    assert Enum.any?(errors, &(&1.path == "preregistration.planned_n_per_cohort"))
  end
end
