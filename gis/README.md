# GIS: candidate routes from downtown Camden to the Snow Bowl

Maps and route comparison that will replace placeholder geography (route length, land taken,
clearing, host parcels) in the decision model. All data are from OpenStreetMap; see limits below.

## Run it (from the project root)

```bash
Rscript gis/01_fetch_osm.R   # downloads OSM layers to gis/data/osm_camden.gpkg (skips layers already saved)
Rscript gis/02_routes.R      # builds the road/trail network, finds routes, writes maps and a summary
Rscript gis/03_parcels_elevation.R  # parcels beside the routes (Maine GeoLibrary) and elevation (USGS 3DEP)
```

Needs R packages `sf`, `igraph`, `ggplot2`, `osmdata`. The Overpass servers are often busy
(HTTP 504); the fetch script retries a second server and can be rerun, and it skips layers already
saved.

## Outputs

| File | What |
|---|---|
| `gis/data/osm_camden.gpkg` | roads and trails, water, parks and protected areas, town boundaries, two anchor points |
| `gis/data/routes.gpkg` | the candidate routes as lines |
| `gis/outputs/route_summary.csv` | length, share on trail, share in parks, share on Hosmer Pond Road, main roads used |
| `gis/outputs/routes_map.png` | the comparison map |
| `gis/data/parcels_corridor.gpkg` | tax parcels within 150 m of the routes, with a public/private flag (private owner names are not downloaded) |
| `gis/outputs/parcel_summary.csv` | parcels within 15 m of each route (private and public) |
| `gis/outputs/elevation_profiles.csv`, `grade_summary.csv` | elevation every 50 m, oriented from downtown up; climb and steepest 100 m |

The polished route map and elevation plot used in the vignette and blog are drawn by `plot_routes_map()` and
`plot_elevation()` in `R/plots_report.R`.

Map data: (c) OpenStreetMap contributors, ODbL. Credit that on any map made from these files.

## What the first run shows (2026-10-05, approximate)

Routes use the same two endpoints: the road junction nearest downtown Camden and the one nearest
the Snow Bowl.

| Route (rule) | Length | Notes |
|---|---|---|
| A road corridor: roads only | 6.91 km | 46% on Hosmer Pond Road, rest Mechanic Street, Barnestown Road and connectors |
| B existing trails where possible | 6.92 km | only 7% on trail |
| C park land where possible | 6.91 km | no park land helps, so it equals A |
| D avoiding Hosmer Pond Road | 7.87 km | loops north (Melvin Heights Road, Molyneaux Road), about 14% longer |

Straight-line distance between the endpoints is 5.98 km. So on this map there is one dominant
corridor, and the short Hosmer Pond Road route is also the best simple connection. Existing trails
and park land do not offer a more direct way into the road base of the Snow Bowl.

## Limits (read before using these numbers)

- OSM is volunteer-mapped; road classes and connections can be wrong or missing. Ways are split
  wherever lines cross, so a bridge or overpass counts as a junction.
- The routes are cheapest paths under made-up cost rules, not designs. Costs penalize primary roads
  and prefer trails or park land where the rule says so.
- Nothing here knows land ownership, grades, snow, wetlands, traffic or bike legality on a segment.
- The Snow Bowl anchor is the polygon's center on the mountain; for comparison every route ends at
  the nearest road junction instead. The downtown anchor is OSM's "Camden" place point.
- "Expanding existing trails" cannot be judged from existing connectivity alone: it needs the
  missing links (gaps between trails and roads that new trail would close).

## Next steps

1. Missing-link analysis: find gaps up to a few hundred meters between the trail network and the
   road network, and cost the new construction for a trail-based route.
2. (Done 2026-10-05) Parcels and grades: about 206 parcels touched by the main corridor (197 private),
   127 m net climb. Parcel data are town-submitted and may be old; the public/private flag only uses owner
   names containing Town of, State of, Land Trust or Conservation.
4. Feed measured length, land taken and host parcels into `R/shared_decision.R` in place of the
   placeholders, and add the route alternatives as options so Stage 1 and the game see the
   geography.

## Routes through public land (added 2026-11-07)

```bash
Rscript gis/05_public_land_routes.R
```

Finds routes from downtown Camden to the Snow Bowl that avoid busy roads and prefer public land, with new
trail allowed on a 50 m grid: cheap on public or conserved land, costly across private parcels (which are
counted, since each needs an owner's agreement). One option is forced to run south of Hosmer Pond Road.
Parcels for the routing area are downloaded once (Maine GeoLibrary); owner names are used in memory only to
mark public, conserved and water-district land and are never saved.

| File | What |
|---|---|
| `gis/outputs/public_land_routes.csv` | the four options: length, share on busy roads, small roads, new trail, private land, parcels crossed |
| `gis/outputs/public_land_route_family.csv` | all routes found under different weightings, with the ones not beaten on length, busy road and parcels crossed |
| `gis/outputs/public_land_tradeoff.png` | trade-off chart |
| `gis/private/` (not committed) | the route map, route geometry and the parcel IDs each route crosses |

Privacy: maps of hypothetical routes over parcel lines are effectively parcel-level crossing lists, so the
map, the route geometry and the parcel IDs stay in `gis/private/` (ignored by git) until owners are approached.

Limits: routes follow a 50 m grid, so new-trail stretches are corridors, not trail designs. Public land is
classified from owner-name patterns (town, state, county, land trust, conservation) plus OSM park polygons,
and parcel data can be years old. OSM tags Fox Trail and Miller Farm as private lanes and some are not
connected to the main network; gaps under 100 m are bridged and costed. No slopes, wetlands or ledge yet.
