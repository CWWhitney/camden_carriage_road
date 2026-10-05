# Parcels and grades along the candidate routes ------------------------------------------------
# Downloads (public data, approved by Cory 2026-10-05; run from the project root):
#  * Maine GeoLibrary "Maine Parcels Organized Towns" feature service (parcel polygons within 150 m of
#    the routes only). Tax-parcel data are submitted by towns on an unscheduled basis and can be old.
#    Parcel ownership: only OWNER1 of parcels whose owner looks public or conservation (town, state,
#    land trust, conservation) is fetched; street addresses are not kept either, to classify public vs private land. No private owner names
#    are downloaded or saved.
#  * USGS 3DEP elevation (National Map Elevation Point Query Service), sampled every 50 m along the routes.
# Outputs: gis/data/parcels_corridor.gpkg, gis/outputs/parcel_summary.csv, elevation_profiles.csv,
#          grade_summary.csv. Maps and profile plots are drawn in the vignette.
suppressPackageStartupMessages({ library(sf); library(jsonlite) })
crs_m <- 26919
routes <- st_read("gis/data/routes.gpkg", quiet = TRUE)
dir.create("gis/data", showWarnings = FALSE); dir.create("gis/outputs", showWarnings = FALSE)
svc <- "https://services1.arcgis.com/RbMX0mRVOFNTdLzd/arcgis/rest/services/Maine_Parcels_Organized_Towns/FeatureServer"

# 1. Parcels near the routes ---------------------------------------------------------------------
par_file <- "gis/data/parcels_corridor.gpkg"
if (!file.exists(par_file)) {
  env <- st_bbox(st_buffer(st_union(routes), 150))
  q <- function(url) {
    for (i in 1:3) { r <- try(readLines(url, warn = FALSE), silent = TRUE); if (!inherits(r, "try-error")) return(paste(r, collapse = "")); Sys.sleep(2) }
    stop("request failed: ", url)
  }
  url <- paste0(svc, "/10/query?f=geojson&where=1%3D1&outSR=4326&inSR=26919&spatialRel=esriSpatialRelIntersects",
                "&geometryType=esriGeometryEnvelope&geometry=", paste(env[c("xmin", "ymin", "xmax", "ymax")], collapse = ","),
                "&outFields=TOWN,GEOCODE,MAP_BK_LOT,FMUPDAT&resultRecordCount=2000")
  parcels <- st_read(q(url), quiet = TRUE)
  geos <- unique(parcels$GEOCODE)
  where <- paste0("GEOCODE IN (", paste0("'", geos, "'", collapse = ","), ") AND (",
                  paste0("UPPER(OWNER1) LIKE '%", c("TOWN OF", "CITY OF", "STATE OF", "LAND TRUST", "CONSERVATION", "STATE OF MAINE", "COUNTY OF"), "%'", collapse = " OR "), ")")
  url2 <- paste0(svc, "/9/query?f=json&outFields=GEOCODE,MAP_BK_LOT,OWNER1&returnGeometry=false&where=", URLencode(where, reserved = TRUE))
  own <- fromJSON(q(url2))$features$attributes
  parcels$public_owner <- paste(parcels$GEOCODE, parcels$MAP_BK_LOT) %in% paste(own$GEOCODE, own$MAP_BK_LOT)
  parcels <- st_transform(parcels, crs_m)
  st_write(parcels, par_file, quiet = TRUE)
}
parcels <- st_read(par_file, quiet = TRUE)

# 2. Parcels each route touches (15 m either side) -----------------------------------------------
buf_m <- 15
summ <- do.call(rbind, lapply(seq_len(nrow(routes)), function(i) {
  ln <- st_line_merge(st_geometry(routes)[i])
  corr <- st_buffer(ln, buf_m)
  hit <- parcels[lengths(st_intersects(parcels, corr)) > 0, ]
  pts <- st_line_sample(st_cast(ln, "LINESTRING"), density = 1 / 10)
  pts <- st_cast(pts, "POINT")
  near_priv <- lengths(st_is_within_distance(pts, parcels[!parcels$public_owner, ], dist = buf_m)) > 0
  near_pub  <- lengths(st_is_within_distance(pts, parcels[parcels$public_owner, ], dist = buf_m)) > 0
  data.frame(route = routes$route[i], length_km = round(as.numeric(st_length(ln)) / 1000, 2),
             parcels_touched = nrow(hit), private_parcels_touched = sum(!hit$public_owner),
             public_parcels_touched = sum(hit$public_owner),
             pct_route_next_to_private = round(100 * mean(near_priv)),
             pct_route_next_to_public = round(100 * mean(near_pub)))
}))
print(summ, row.names = FALSE)
write.csv(summ, "gis/outputs/parcel_summary.csv", row.names = FALSE)

# 3. Elevation profiles, every 50 m ---------------------------------------------------------------
prof_file <- "gis/outputs/elevation_profiles.csv"
if (!file.exists(prof_file)) {
  one <- function(x, y) {
    for (i in 1:4) {
      r <- try(fromJSON(sprintf("https://epqs.nationalmap.gov/v1/json?x=%.6f&y=%.6f&wkid=4326&units=Meters&includeDate=false", x, y)), silent = TRUE)
      if (!inherits(r, "try-error") && !is.null(r$value)) return(as.numeric(r$value))
      Sys.sleep(1.5)
    }
    NA_real_
  }
  prof <- do.call(rbind, lapply(seq_len(nrow(routes)), function(i) {
    ln <- st_line_merge(st_geometry(routes)[i])
    len <- as.numeric(st_length(ln))
    d <- seq(0, len, by = 50)
    pts <- st_transform(st_cast(st_line_sample(ln, sample = pmin(d / len, 1)), "POINT"), 4326)
    xy <- st_coordinates(pts)
    data.frame(route = routes$route[i], dist_m = d, elev_m = mapply(one, xy[, 1], xy[, 2]))
  }))
  write.csv(prof, prof_file, row.names = FALSE)
}
prof <- read.csv(prof_file)
# Orient every profile from downtown Camden (low) up to the Snow Bowl road (high)
prof <- do.call(rbind, lapply(split(prof, prof$route), function(d) {
  d <- d[order(d$dist_m), ]
  if (d$elev_m[1] > tail(d$elev_m, 1)) { d$elev_m <- rev(d$elev_m) }
  d
}))
write.csv(prof, prof_file, row.names = FALSE)
grades <- do.call(rbind, lapply(split(prof, prof$route), function(d) {
  d <- d[order(d$dist_m), ]
  de <- diff(d$elev_m); dd <- diff(d$dist_m)
  k <- 2                                               # 100 m windows
  win <- (d$elev_m[-seq_len(k)] - d$elev_m[seq_len(nrow(d) - k)]) / (d$dist_m[-seq_len(k)] - d$dist_m[seq_len(nrow(d) - k)])
  data.frame(route = d$route[1], start_elev_m = d$elev_m[1], end_elev_m = tail(d$elev_m, 1),
             net_climb_m = round(tail(d$elev_m, 1) - d$elev_m[1]), total_ascent_m = round(sum(pmax(de, 0), na.rm = TRUE)),
             mean_grade_pct = round(100 * (tail(d$elev_m, 1) - d$elev_m[1]) / max(d$dist_m), 1),
             max_100m_grade_pct = round(100 * max(abs(win), na.rm = TRUE), 1),
             pct_over_8 = round(100 * mean(abs(win) > 0.08, na.rm = TRUE)))
}))
print(grades, row.names = FALSE)
write.csv(grades, "gis/outputs/grade_summary.csv", row.names = FALSE)
