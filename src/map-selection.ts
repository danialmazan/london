import type { LayerDefinition, LayerGroup } from "./types";

export type MapClickTarget<T> =
  | { kind: "area"; areaId: string }
  | { kind: "feature"; feature: T }
  | { kind: "empty" };

export function isAreaSelectionLayer(layer: Pick<LayerDefinition, "group">): boolean {
  return (
    layer.group === "population" ||
    layer.group === "education-work" ||
    layer.group === "income" ||
    layer.group === "elections"
  );
}

export function shouldQueryAreaHitLayer(
  activeGroup: LayerGroup,
  layer: Pick<LayerDefinition, "group">,
  dataLayerVisible: boolean,
): boolean {
  return activeGroup !== "transport" && dataLayerVisible && isAreaSelectionLayer(layer);
}

export function shouldDeferAreaSelection(
  areaHitEligible: boolean,
  canonicalAreaId: unknown,
  areaSourceLoaded: boolean,
): boolean {
  return areaHitEligible && canonicalAreaId === undefined && !areaSourceLoaded;
}

export function resolveMapClickTarget<T>(
  layer: Pick<LayerDefinition, "group">,
  canonicalAreaId: unknown,
  feature: T | undefined,
): MapClickTarget<T> {
  if (
    isAreaSelectionLayer(layer) &&
    typeof canonicalAreaId === "string" &&
    /^E010\d{5}$/.test(canonicalAreaId)
  ) {
    return { kind: "area", areaId: canonicalAreaId };
  }
  if (feature !== undefined) return { kind: "feature", feature };
  return { kind: "empty" };
}
