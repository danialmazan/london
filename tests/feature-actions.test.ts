import { describe, expect, it } from "vitest";
import { renderFeatureActions } from "../src/feature-actions";
describe("London atlas feature actions", () => {
  it("offers an LSOA report for thematic areas", () => expect(renderFeatureActions("population", true)).toContain("See full report"));
  it("adds an election overview return", () => expect(renderFeatureActions("elections", true)).toContain("Back to election overview"));
  it("does not link to the Madrid housing article", () => expect(renderFeatureActions("buildings", false)).toBe(""));
});
