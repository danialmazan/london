import type { AtlasState, CameraState, LayerGroup } from "./types";
export const LONDON_CAMERA: CameraState = { lng: -0.1276, lat: 51.5072, zoom: 9.35, bearing: 0, pitch: 0 };
export const DEFAULT_STATE: AtlasState = { group: "population", layer: "population-density", dataLayerVisible: true, election: "general", party: "leading", transport: [], route: "all", country: "total", basemap: "light", camera: { ...LONDON_CAMERA }, is3d: false, selectedSection: null, reportOpen: false };
const groups: LayerGroup[] = ["population", "education-work", "buildings", "elections", "income", "transport"];
const elections = ["general", "local", "mayor", "assembly"] as const;
const finite = (value: string | null, fallback: number) => value === null || value.trim() === "" || !Number.isFinite(Number(value)) ? fallback : Number(value);
const bounded = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));
export function parseHash(hash: string): AtlasState {
  const p = new URLSearchParams(hash.replace(/^#/, "")); const g = p.get("group"); const e = p.get("election"); const s = p.get("section");
  const selectedSection = s && /^E010\d{5}$/.test(s) ? s : null;
  return { group: groups.includes(g as LayerGroup) ? g as LayerGroup : DEFAULT_STATE.group, layer: p.get("layer") || DEFAULT_STATE.layer, dataLayerVisible: p.get("data") !== "0", election: elections.includes(e as typeof elections[number]) ? e as typeof elections[number] : DEFAULT_STATE.election, party: p.get("party") || DEFAULT_STATE.party, transport: (p.get("transport") || "").split(",").map(x => x.trim()).filter(Boolean), route: p.get("route") || "all", country: "total", basemap: p.get("basemap") === "dark" ? "dark" : "light", camera: { lng: bounded(finite(p.get("lng"), LONDON_CAMERA.lng), -180, 180), lat: bounded(finite(p.get("lat"), LONDON_CAMERA.lat), -85, 85), zoom: bounded(finite(p.get("z"), LONDON_CAMERA.zoom), 0, 24), bearing: bounded(finite(p.get("bearing"), 0), -180, 180), pitch: bounded(finite(p.get("pitch"), 0), 0, 85) }, is3d: p.get("3d") === "1", selectedSection, reportOpen: selectedSection !== null && p.get("report") === "1" };
}
export function serializeState(state: AtlasState): string {
  const p = new URLSearchParams({ group: state.group, layer: state.layer }); if (!state.dataLayerVisible) p.set("data", "0");
  if (state.group === "elections") { p.set("election", state.election); p.set("party", state.party); }
  if (state.transport.length) p.set("transport", state.transport.join(",")); if (state.route !== "all") p.set("route", state.route); if (state.basemap === "dark") p.set("basemap", "dark");
  p.set("lng", state.camera.lng.toFixed(5)); p.set("lat", state.camera.lat.toFixed(5)); p.set("z", state.camera.zoom.toFixed(2)); if (Math.abs(state.camera.bearing) > .05) p.set("bearing", state.camera.bearing.toFixed(1)); if (state.camera.pitch > .05) p.set("pitch", state.camera.pitch.toFixed(1)); if (state.is3d) p.set("3d", "1"); if (state.selectedSection) { p.set("section", state.selectedSection); if (state.reportOpen) p.set("report", "1"); }
  return `#${p.toString()}`;
}
