import { describe, expect, it } from "vitest";
import { isAreaSelectionLayer, resolveMapClickTarget, shouldQueryAreaHitLayer } from "../src/map-selection";
import type { LayerGroup } from "../src/types";

describe("map selection priority", () => {
  it("selects the containing area when a dot-density tap misses every visible dot", () => {
    expect(resolveMapClickTarget({ group: "population" }, "E01000918", undefined)).toEqual({
      kind: "area",
      areaId: "E01000918",
    });
  });

  it("prioritises the containing area over a visible thematic feature", () => {
    const dot = { id: "resident-dot" };
    expect(resolveMapClickTarget({ group: "population" }, "E01000918", dot)).toEqual({
      kind: "area",
      areaId: "E01000918",
    });
  });

  it("keeps building and transport features independent of the area hit layer", () => {
    const building = { id: "building" };
    expect(resolveMapClickTarget({ group: "buildings" }, "E01000918", building)).toEqual({
      kind: "feature",
      feature: building,
    });
    expect(resolveMapClickTarget({ group: "transport" }, "E01000918", undefined)).toEqual({
      kind: "empty",
    });
    expect(shouldQueryAreaHitLayer("transport", { group: "population" }, true)).toBe(false);
    expect(shouldQueryAreaHitLayer("population", { group: "population" }, false)).toBe(false);
  });

  it("enables area-first selection for every report-backed layer group", () => {
    const groups: LayerGroup[] = ["population", "education-work", "income", "elections"];
    expect(groups.every((group) =>
      isAreaSelectionLayer({ group }),
    )).toBe(true);
  });
});
