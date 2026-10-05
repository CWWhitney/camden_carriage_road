# Fetch OpenStreetMap layers for the Camden to Snow Bowl area ------------------------------
# Source: OpenStreetMap contributors (ODbL), via the Overpass API. Run from the project root:
#   Rscript gis/01_fetch_osm.R            (skips layers already in the file; delete the file to refetch)
# Output: gis/data/osm_camden.gpkg  (layers: roads_paths, water, parks, town_boundary, anchors)
# Attribution for any map made from this: (c) OpenStreetMap contributors.

suppressPackageStartupMessages({ library(osmdata); library(sf) })

out <- "gis/data/osm_camden.gpkg"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
bbox <- c(xmin = -69.20, ymin = 44.16, xmax = -69.00, ymax = 44.28)   # lon/lat, WGS84

overpass_urls <- c("https://overpass.private.coffee/api/interpreter",
                   "https://overpass-api.de/api/interpreter",
                   "https://overpass.kumi.systems/api/interpreter")

query <- function(build) {
  for (u in overpass_urls) {
    set_overpass_url(u)
    r <- try(osmdata_sf(build(opq(bbox = bbox, timeout = 180))), silent = TRUE)
    if (!inherits(r, "try-error")) return(r)
    message("  failed on ", u, ": ", substr(as.character(r), 1, 80))
    Sys.sleep(5)
  }
  stop("All Overpass servers failed; try again later.")
}

have <- if (file.exists(out)) st_layers(out)$name else character()
save_layer <- function(x, name) {
  x <- x[, c("osm_id", intersect(c("name", "highway", "surface", "bicycle", "foot", "access",
                                   "natural", "water", "leisure", "boundary", "protect_class",
                                   "admin_level", "place", "tracktype", "designation"), names(x))), drop = FALSE]
  st_write(x, out, layer = name, append = FALSE, quiet = TRUE)
  message("  saved ", name, ": ", nrow(x), " features")
}

if (!"roads_paths" %in% have) {
  message("Fetching roads, trails and paths ...")
  r <- query(function(q) add_osm_feature(q, key = "highway"))
  save_layer(r$osm_lines, "roads_paths"); Sys.sleep(5)
}
if (!"water" %in% have) {
  message("Fetching water bodies ...")
  r <- query(function(q) add_osm_feature(q, key = "natural", value = "water"))
  geoms <- Filter(function(x) !is.null(x) && nrow(x) > 0, list(r$osm_polygons, r$osm_multipolygons))
  keep <- lapply(geoms, function(x) { if (!"name" %in% names(x)) x$name <- NA_character_; x[, c("osm_id", "name")] })
  save_layer(do.call(rbind, keep), "water"); Sys.sleep(5)
}
if (!"parks" %in% have) {
  message("Fetching parks and protected areas ...")
  r <- query(function(q) add_osm_feature(q, key = "boundary", value = "protected_area"))
  r2 <- query(function(q) add_osm_feature(q, key = "leisure", value = c("park", "nature_reserve")))
  geoms <- list(r$osm_polygons, r$osm_multipolygons, r2$osm_polygons, r2$osm_multipolygons)
  geoms <- Filter(function(x) !is.null(x) && nrow(x) > 0, geoms)
  keep <- lapply(geoms, function(x) { if (!"name" %in% names(x)) x$name <- NA_character_; x[, c("osm_id", "name")] })
  save_layer(do.call(rbind, keep), "parks"); Sys.sleep(5)
}
if (!"town_boundary" %in% have) {                       # optional: heavy query, skip if servers are busy
  message("Fetching town boundaries (optional) ...")
  ok <- try({
    r <- query(function(q) add_osm_feature(add_osm_feature(q, key = "boundary", value = "administrative"),
                                           key = "admin_level", value = "8"))
    b <- r$osm_multipolygons
    b <- b[!is.na(b$name), c("osm_id", "name", "admin_level")]
    save_layer(b, "town_boundary")
  }, silent = TRUE)
  if (inherits(ok, "try-error")) message("  skipped town boundary (servers busy); rerun later if wanted")
  Sys.sleep(5)
}
if (!"anchors" %in% have) {
  message("Fetching the two anchors (downtown Camden, Camden Snow Bowl) ...")
  r1 <- query(function(q) add_osm_feature(q, key = "name", value = "Camden Snow Bowl"))
  sb <- r1$osm_polygons
  sb_pt <- st_sf(osm_id = "snowbowl", name = "Camden Snow Bowl",
                 geometry = st_centroid(st_union(st_geometry(sb))))
  r2 <- query(function(q) add_osm_feature(q, key = "place", value = c("town", "village")))
  dt <- r2$osm_points[which(r2$osm_points$name == "Camden"), ]
  anchors <- rbind(sb_pt, st_sf(osm_id = "downtown", name = "Downtown Camden (OSM place node)",
                                geometry = st_geometry(dt)[1]))
  save_layer(anchors, "anchors")
}
message("Done: ", out)
print(st_layers(out))
