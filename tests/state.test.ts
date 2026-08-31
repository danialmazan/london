import { describe, expect, it } from "vitest";
import { DEFAULT_STATE, parseHash, serializeState } from "../src/state";

describe("London atlas URL state", () => {
  it("uses the London camera and accepts LSOA21 identifiers", () => {
    expect(DEFAULT_STATE.camera.lat).toBeCloseTo(51.5072);
    const state = parseHash("#group=income&layer=income-bhc&section=E01000001&report=1");
    expect(state.selectedSection).toBe("E01000001");
    expect(state.reportOpen).toBe(true);
  });
  it("rejects non-LSOA identifiers", () => expect(parseHash("#section=2807911001&report=1").selectedSection).toBeNull());
  it("round-trips all four elections and TfL modes", () => {
    const state = { ...DEFAULT_STATE, group: "elections" as const, election: "mayor" as const, layer: "mayor-lead", transport: ["tube", "bus"], route: "24" };
    const parsed = parseHash(serializeState(state));
    expect(parsed.election).toBe("mayor"); expect(parsed.transport).toEqual(["tube", "bus"]); expect(parsed.route).toBe("24");
  });
});
