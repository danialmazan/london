export type LayerGroup = "population" | "education-work" | "buildings" | "elections" | "income" | "transport";
export type BasemapTheme = "light" | "dark";
export type LayerKind = "choropleth" | "dot-density" | "point" | "fill" | "fill-extrusion" | "transport-line" | "transport-stop";
export type ValueFormat = "integer" | "decimal" | "percent" | "pp" | "currency" | "year" | "text";
export type ElectionKey = "general" | "local" | "mayor" | "assembly";
export type TransportMode = "tube" | "dlr" | "tram" | "overground" | "elizabeth-line" | "bus" | "santander";
export interface SourceDefinition { id: string; url: string; sourceLayer: string; attribution: string; minzoom?: number; maxzoom?: number; }
export interface TooltipField { property: string; label: string; format: ValueFormat; suffix?: string; percentileProperty?: string; }
export interface ElectionResultField { property: string; label: string; color: string; }
export interface LayerControl { election?: ElectionKey; party?: string; transportMode?: TransportMode; routeProperty?: string; routes?: Array<{ value: string; label: string }>; results?: ElectionResultField[]; }
export interface LayerScale { type: "continuous-diverging"; center: number; clamp: boolean; }
export interface LayerDefinition {
  id: string; group: LayerGroup; kind: LayerKind; label: string; shortLabel?: string; description: string;
  methodology?: string; unit: string; referenceDate: string; geography: string; sourceIds: string[];
  property: string; palette: string[]; breaks: number[]; format: ValueFormat; minzoom?: number; maxzoom?: number;
  opacity?: number; lineColor?: string; lineWidth?: number; tooltip: TooltipField[]; control?: LayerControl;
  scale?: LayerScale; dataStatus?: string; dotValue?: number; dotColors?: Partial<Record<BasemapTheme, string>>;
  dotRadiusStops?: Array<[number, number]>; dotOpacityStops?: Array<[number, number]>;
}
export interface SourceReference { title: string; organisation: string; url: string; licence: string; retrieved: string; }
export interface LayerManifest { generatedAt: string; version: string; defaultLayer: string; sources: SourceDefinition[]; layers: LayerDefinition[]; references: SourceReference[]; notes: string[]; }
export interface Place { id: string; name: string; kind: "district" | "neighbourhood"; district?: string; bbox: [number, number, number, number]; }
export type AddressRecord = [id: string, name: string, district: string, longitude: number, latitude: number];
export interface AddressIndex { referenceDate: string; records: AddressRecord[]; }
export interface CameraState { lng: number; lat: number; zoom: number; bearing: number; pitch: number; }
export interface AtlasState { group: LayerGroup; layer: string; dataLayerVisible: boolean; election: ElectionKey; party: string; transport: string[]; route: string; country: string; basemap: BasemapTheme; camera: CameraState; is3d: boolean; selectedSection: string | null; reportOpen: boolean; }
export interface ReportDistribution { label: string; format: ValueFormat; unit: string; breaks: number[]; counts: number[]; observationCount: number; min: number | null; max: number | null; percentileValues: number[]; percentileRanks: number[]; }
export interface ReportMetricValue { value: number | null; percentile: number | null; label: string; format: ValueFormat; unit: string; geography: string; referenceDate: string; note?: string; }
export interface ReportElection { leader: string | null; leadVotes: number | null; leadPercent: number | null; leadLabel: string | null; turnoutPct: number | null; validVotes: number | null; geography: string; areaId: string | null; areaName: string | null; shares: Record<string, number | null>; shareLabels: Record<string, string>; shareColours: Record<string, string>; }
export interface SectionReport { id: string; name: string; district: string; geographies: Record<string, { id: string | null; name: string | null; vintage: string }>; metrics: Record<string, ReportMetricValue>; elections: Record<ElectionKey, ReportElection>; building: null; }
export interface SectionReportIndex { generatedAt: string; version: string; canonicalVintage: "2021"; methodologyUrl: string; distributions: Record<string, ReportDistribution>; references: SourceReference[]; sections: Record<string, SectionReport>; }
