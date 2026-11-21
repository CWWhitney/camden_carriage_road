# Routes that are roadless where possible, on public land, and short -------------------------------
# From downtown Camden to the Snow Bowl base (Ragged Mountain). Run from the project root:
#   Rscript gis/05_public_land_routes.R
#
# DATA AND PRIVACY
#  * OpenStreetMap roads, trails, parks (gis/01_fetch_osm.R).
#  * Maine GeoLibrary tax parcels for the routing area (public service). Owner NAMES are used only in
#    memory and only for parcels whose owner looks public or conserved (town, state, county, land trust,
#    conservation, water district), to assign a class. Only the class is saved. No private owner names
#    are requested, saved or committed. Parcel-level lists of what a route crosses go to gis/private/,
#    which git ignores.
#
# HOW ROUTES ARE FOUND (rules chosen by us, so read them as assumptions)
#  * Network = existing roads and trails, plus possible NEW trail on a 50 m grid: cheap on public parcels and
#    park polygons, expensive across private parcels (it would need the owner's agreement; the parcels are
#    counted), never across water or the water district.
#  * Edge cost = length x multiplier. Busy roads (primary to tertiary) cost A, small roads
#    (residential, unclassified) cost S, existing trails 1, new trail on public land N, new trail on private
#    land N x Pn, and existing roads or trails on private parcels are multiplied by B. A family of routes comes
#    from varying A, S, B, N and Pn.
#  * "Shortest" is the cheapest route on the existing network with every multiplier at 1.
#  Parcels may be years old, OSM park polygons can include private inholdings, and nothing here knows
#  slopes (see gis/06_route_grades.R), wetlands, easements or what landowners will allow.

suppressPackageStartupMessages({ library(sf); library(igraph); library(ggplot2); library(jsonlite); library(ggrepel) })
sf_use_s2(FALSE)
crs_m <- 26919
gpkg <- "gis/data/osm_camden.gpkg"
dir.create("gis/outputs", showWarnings = FALSE, recursive = TRUE); dir.create("gis/private", showWarnings = FALSE)
area_ll <- c(xmin = -69.17, ymin = 44.18, xmax = -69.04, ymax = 44.26)       # routing area, lon/lat
area_poly <- st_transform(st_as_sfc(st_bbox(area_ll, crs = 4326)), crs_m)

# 1. Parcels with a land class ------------------------------------------------------------------
svc <- "https://services1.arcgis.com/RbMX0mRVOFNTdLzd/arcgis/rest/services/Maine_Parcels_Organized_Towns/FeatureServer"
read_url <- function(url) {
  for (i in 1:4) { r <- try(readLines(url, warn = FALSE), silent = TRUE); if (!inherits(r, "try-error")) return(paste(r, collapse = "")); Sys.sleep(3) }
  stop("request failed: ", substr(url, 1, 120))
}
par_file <- "gis/data/parcels_study.gpkg"
if (!file.exists(par_file)) {
  message("Downloading parcels for the routing area ...")
  pieces <- list(); off <- 0
  repeat {
    url <- paste0(svc, "/10/query?f=geojson&where=1%3D1&outSR=4326&inSR=4326&spatialRel=esriSpatialRelIntersects",
                  "&geometryType=esriGeometryEnvelope&geometry=", paste(area_ll, collapse = ","),
                  "&outFields=TOWN,GEOCODE,MAP_BK_LOT,FMUPDAT&resultOffset=", off, "&resultRecordCount=2000")
    x <- st_read(read_url(url), quiet = TRUE)
    if (!nrow(x)) break
    pieces[[length(pieces) + 1]] <- x; off <- off + nrow(x)
  }
  parcels <- do.call(rbind, pieces)
  geos <- unique(parcels$GEOCODE)
  pats <- c("TOWN OF", "CITY OF", "STATE OF", "COUNTY OF", "UNITED STATES", "INHABITANTS OF",
            "LAND TRUST", "CONSERVATION", "PRESERVE", "WATER DISTRICT")
  where <- paste0("GEOCODE IN (", paste0("'", geos, "'", collapse = ","), ") AND (",
                  paste0("UPPER(OWNER1) LIKE '%", pats, "%'", collapse = " OR "), ")")
  own <- list(); off <- 0
  repeat {                                              # owner names of PUBLIC-looking parcels only
    r <- fromJSON(read_url(paste0(svc, "/9/query?f=json&outFields=GEOCODE,MAP_BK_LOT,OWNER1&returnGeometry=false",
                                  "&resultOffset=", off, "&resultRecordCount=2000&where=", URLencode(where, reserved = TRUE))))
    if (!length(r$features)) break
    own[[length(own) + 1]] <- r$features$attributes; off <- off + nrow(r$features$attributes)
  }
  own <- do.call(rbind, own); up <- toupper(own$OWNER1)
  own$land_class <- ifelse(grepl("WATER DISTRICT", up), "restricted",
                    ifelse(grepl("LAND TRUST|CONSERVATION|PRESERVE", up), "conserved", "public"))
  own <- own[, c("GEOCODE", "MAP_BK_LOT", "land_class")]                # names are dropped here
  k <- paste(parcels$GEOCODE, parcels$MAP_BK_LOT)
  parcels$land_class <- own$land_class[match(k, paste(own$GEOCODE, own$MAP_BK_LOT))]
  parcels$land_class[is.na(parcels$land_class)] <- "private"
  parcels <- st_transform(parcels, crs_m)
  st_write(parcels, par_file, quiet = TRUE)
}
parcels <- st_make_valid(st_read(par_file, quiet = TRUE))
message("Parcels: ", nrow(parcels), " (", paste(names(table(parcels$land_class)), table(parcels$land_class), collapse = ", "), ")")

# 2. OSM layers ---------------------------------------------------------------------------------------
rd <- function(l) st_make_valid(st_transform(st_read(gpkg, l, quiet = TRUE), crs_m))
roads <- rd("roads_paths"); water <- rd("water"); parks <- rd("parks"); anch <- rd("anchors")
ww <- if ("waterways" %in% st_layers(gpkg)$name) rd("waterways") else NULL
busy_cls <- c("primary", "trunk", "secondary", "tertiary"); small_cls <- c("unclassified", "residential", "living_street")
trail_cls <- c("footway", "path", "track", "cycleway", "bridleway")
roads <- roads[roads$highway %in% c(busy_cls, small_cls, trail_cls), ]
roads <- suppressWarnings(st_intersection(roads, area_poly))
roads <- roads[st_geometry_type(roads) %in% c("LINESTRING", "MULTILINESTRING"), ]
roads <- st_cast(roads, "LINESTRING", warn = FALSE)
parks_ok <- parks[!grepl("Easement|Water Supply", parks$name, ignore.case = TRUE), ]

# 3. Node the network and classify each segment ----------------------------------------------------
segs <- st_sf(geometry = st_cast(st_union(st_geometry(roads)), "LINESTRING"))
pt <- st_point_on_surface(st_geometry(segs))
nr <- st_nearest_feature(st_sf(geometry = pt), roads)
segs$name <- roads$name[nr]; segs$highway <- roads$highway[nr]
segs$type <- ifelse(segs$highway %in% busy_cls, "busy_road", ifelse(segs$highway %in% small_cls, "small_road", "trail"))
segs$length_m <- as.numeric(st_length(segs))
pc <- vapply(st_intersects(pt, parcels), function(i) if (length(i)) i[1] else NA_integer_, 1L)
pcl <- parcels$land_class[pc]; pcl[is.na(pcl)] <- "none"      # "none" = no parcel, i.e. road right-of-way
in_park <- lengths(st_intersects(pt, parks_ok)) > 0
segs$land <- ifelse(pcl %in% c("public", "conserved"), pcl,
             ifelse(pcl == "restricted", "restricted",
             ifelse(in_park, "public_park",
             ifelse(pcl == "private", "private", "row"))))
segs$parcel_id <- ifelse(is.na(pc), NA_character_, parcels$MAP_BK_LOT[pc])
xy <- st_coordinates(segs); fst <- !duplicated(xy[, "L1"]); lst <- !duplicated(xy[, "L1"], fromLast = TRUE)
key <- function(m) paste(round(m[, "X"], 1), round(m[, "Y"], 1))
segs$from <- key(xy[fst, ]); segs$to <- key(xy[lst, ])
nodes <- unique(data.frame(key = c(segs$from, segs$to), x = c(xy[fst, "X"], xy[lst, "X"]), y = c(xy[fst, "Y"], xy[lst, "Y"])))
net_edges <- data.frame(from = segs$from, to = segs$to, length_m = pmax(segs$length_m, 0.1), type = segs$type, land = segs$land,
                        name = segs$name, pf = ifelse(segs$land == "private", segs$parcel_id, NA_character_), pt = NA_character_,
                        src = "network", seg = seq_len(nrow(segs)), stringsAsFactors = FALSE)

# 4. Possible new trail on a 50 m grid: public land cheap, private land costly and counted ---------------------
cell <- 50
pub <- st_make_valid(st_union(c(st_geometry(parcels[parcels$land_class %in% c("public", "conserved"), ]), st_geometry(parks_ok))))
water_u <- st_make_valid(st_union(st_geometry(water)))
restr_u <- if (any(parcels$land_class == "restricted")) st_union(st_geometry(parcels[parcels$land_class == "restricted", ])) else NULL
gp <- st_make_grid(area_poly, cellsize = cell, what = "centers")
in_water <- lengths(st_intersects(gp, water_u)) > 0
in_restr <- if (is.null(restr_u)) rep(FALSE, length(gp)) else lengths(st_intersects(gp, restr_u)) > 0
in_pub <- lengths(st_intersects(gp, pub)) > 0
pidx <- vapply(st_intersects(gp, parcels), function(i) if (length(i)) i[1] else NA_integer_, 1L)
gcls <- ifelse(in_water | in_restr, "no", ifelse(in_pub, "public", ifelse(!is.na(pidx) & parcels$land_class[pidx] == "private", "private", "no")))
keep <- gcls != "no"; gp <- gp[keep]; gcls <- gcls[keep]
gpid <- ifelse(gcls == "private", parcels$MAP_BK_LOT[pidx[keep]], NA_character_)
gxy <- st_coordinates(gp); ix <- round((gxy[, 1] - min(gxy[, 1])) / cell); iy <- round((gxy[, 2] - min(gxy[, 2])) / cell)
gkey <- paste0("g", ix, "_", iy); look <- setNames(seq_along(gkey), gkey)
grid_edges <- do.call(rbind, lapply(list(c(1, 0), c(0, 1), c(1, 1), c(1, -1)), function(d) {
  nb <- look[paste0("g", ix + d[1], "_", iy + d[2])]; ok <- !is.na(nb); a <- which(ok); b <- nb[ok]
  data.frame(from = gkey[a], to = gkey[b], length_m = cell * sqrt(sum(d^2)), type = "new_trail",
             land = ifelse(gcls[a] == "public" & gcls[b] == "public", "public_new", "private_new"),
             name = NA_character_, pf = gpid[a], pt = gpid[b], src = "grid", seg = NA_integer_, stringsAsFactors = FALSE)
}))
# short links from existing network vertices onto the grid (trailheads)
vp <- st_as_sf(nodes, coords = c("x", "y"), crs = crs_m)
nn <- st_nearest_feature(vp, gp); dd <- as.numeric(st_distance(vp, gp[nn], by_element = TRUE))
lk <- dd <= 60
link_edges <- data.frame(from = nodes$key[lk], to = gkey[nn[lk]], length_m = pmax(dd[lk], 1), type = "new_trail",
                         land = ifelse(gcls[nn[lk]] == "public", "public_new", "private_new"), name = NA_character_,
                         pf = NA_character_, pt = gpid[nn[lk]], src = "link", seg = NA_integer_, stringsAsFactors = FALSE)
# OSM islands: link small disconnected pieces to the main network when within 100 m (assumed to be missing
# junctions, e.g. a lane that really meets the road). Treated as private land and penalized; reported.
gr0 <- graph_from_data_frame(net_edges[, c("from", "to")], directed = FALSE)
cmp <- components(gr0); main_comp <- which.max(cmp$csize)
main_keys <- names(cmp$membership)[cmp$membership == main_comp]
isl <- nodes[!nodes$key %in% main_keys, ]; mn <- nodes[nodes$key %in% main_keys, ]
gap_edges <- NULL
if (nrow(isl)) {
  nnm <- st_nearest_feature(st_as_sf(isl, coords = c("x", "y"), crs = crs_m), st_as_sf(mn, coords = c("x", "y"), crs = crs_m))
  dg <- sqrt((isl$x - mn$x[nnm])^2 + (isl$y - mn$y[nnm])^2); ok <- dg <= 100
  gap_edges <- data.frame(from = isl$key[ok], to = mn$key[nnm[ok]], length_m = pmax(dg[ok], 1), type = "gap", land = "private",
                          name = NA_character_, pf = NA_character_, pt = NA_character_, src = "gap", seg = NA_integer_, stringsAsFactors = FALSE)
}
edges <- rbind(net_edges, grid_edges, link_edges, gap_edges)
nodes_all <- rbind(nodes, data.frame(key = gkey, x = gxy[, 1], y = gxy[, 2]))
g <- graph_from_data_frame(edges[, c("from", "to")], directed = FALSE, vertices = data.frame(name = nodes_all$key))
message("Network: ", nrow(net_edges), " existing segments, ", nrow(grid_edges) + nrow(link_edges), " possible new-trail links (",
        sum(gcls == "public"), " public and ", sum(gcls == "private"), " private grid cells)")

# 5. Costs, routes and metrics ---------------------------------------------------------------------------
mult <- function(A, S, B, N, Pn = 6, allow_new = TRUE) {
  m <- rep(1, nrow(edges))
  m[edges$type == "busy_road"] <- A; m[edges$type == "small_road"] <- S; m[edges$type == "new_trail"] <- N; m[edges$type == "gap"] <- 2
  priv <- edges$land == "private" & edges$type != "new_trail"
  m[priv] <- m[priv] * B
  m[edges$land == "private_new"] <- m[edges$land == "private_new"] * Pn
  m[edges$land == "restricted"] <- m[edges$land == "restricted"] * 50
  if (!allow_new) m[edges$type == "new_trail"] <- 1e5
  m
}
closest_key <- function(pt, types) {
  e <- net_edges[net_edges$type %in% types, ]; k <- intersect(unique(c(e$from, e$to)), main_keys); n <- nodes[match(k, nodes$key), ]
  k[which.min((n$x - st_coordinates(pt)[1])^2 + (n$y - st_coordinates(pt)[2])^2)]
}
start_key <- closest_key(anch[anch$osm_id == "downtown", ], c("busy_road", "small_road"))
end_key   <- closest_key(anch[anch$osm_id == "snowbowl", ], c("busy_road", "small_road"))
path_edges <- function(w, from, to) {
  sp <- shortest_paths(g, from, to, weights = w, output = "epath")$epath[[1]]
  as.integer(sp)
}
metrics <- function(eid) {
  e <- edges[eid, ]; L <- sum(e$length_m); s <- function(i) sum(e$length_m[i])
  priv <- e$land %in% c("private", "private_new")
  ids <- unique(na.omit(c(e$pf[priv], e$pt[priv & e$land == "private_new"])))
  data.frame(length_km = round(L / 1000, 2),
             busy_road_pct = round(100 * s(e$type == "busy_road") / L), small_road_pct = round(100 * s(e$type == "small_road") / L),
             trail_pct = round(100 * s(e$type == "trail") / L), new_trail_pct = round(100 * s(e$type == "new_trail") / L),
             private_pct = round(100 * s(priv) / L),
             public_pct = round(100 * s(e$land %in% c("public", "conserved", "public_park", "public_new")) / L),
             road_pct = round(100 * s(e$type %in% c("busy_road", "small_road")) / L),
             new_trail_km = round(s(e$type == "new_trail") / 1000, 2), private_new_km = round(s(e$land == "private_new") / 1000, 2),
             private_parcels = length(ids), gap_km = round(s(e$type == "gap") / 1000, 2))
}
signature <- function(eid) paste(sort(unique(eid)), collapse = ",")

base_eid <- path_edges(edges$length_m * mult(1, 1, 1, 1, allow_new = FALSE), start_key, end_key)
fam <- expand.grid(A = c(1, 4, 12), S = c(1, 2.5), B = c(1, 4), N = c(1.3, 2), Pn = c(2.5, 6, 15))
routes <- list(shortest = base_eid); fam_rows <- list()
for (i in seq_len(nrow(fam))) {
  eid <- path_edges(edges$length_m * with(fam[i, ], mult(A, S, B, N, Pn)), start_key, end_key)
  nm <- paste0("fam", i); routes[[nm]] <- eid
  fam_rows[[i]] <- cbind(route = nm, fam[i, ], metrics(eid), sig = signature(eid))
}
fam_df <- do.call(rbind, fam_rows); fam_df <- fam_df[!duplicated(fam_df$sig), ]
base_m <- metrics(base_eid); L0 <- base_m$length_km
dom <- function(a, b) all(a <= b) && any(a < b)
M <- as.matrix(fam_df[, c("length_km", "busy_road_pct", "private_parcels")])
fam_df$pareto <- vapply(seq_len(nrow(M)), function(i) !any(vapply(seq_len(nrow(M)), function(j) j != i && dom(M[j, ], M[i, ]), TRUE)), TRUE)
# B: shortest route with little busy road. C: most public land with little busy road, within 1.5x the shortest length.
pickB <- fam_df[fam_df$busy_road_pct <= 5, ]; if (!nrow(pickB)) pickB <- fam_df[order(fam_df$busy_road_pct)[1:3], ]
routeB <- pickB[order(pickB$length_km)[1], ]
pickC <- fam_df[fam_df$busy_road_pct <= 10 & fam_df$length_km <= 1.5 * L0, ]; if (!nrow(pickC)) pickC <- fam_df
routeC <- pickC[order(-pickC$public_pct, pickC$length_km)[1], ]
compromise <- routeB; most_roadless <- routeC

# 6. Option D: south of Hosmer Pond Road -------------------------------------------------------------------------
# Between a point 300 m from the Snow Bowl and the Emery Way end, everything on or north of Hosmer Pond Road is
# made 60x costlier, so the route must leave the road at or east of Emery Way and run south of the pond.
sbx <- st_coordinates(anch[anch$osm_id == "snowbowl", ])[1]
emx <- st_coordinates(st_centroid(st_union(st_geometry(roads[!is.na(roads$name) & roads$name == "Emery Way", ]))))[1]
x_min <- sbx + 300; x_max <- emx
hp_xy <- st_coordinates(st_union(st_geometry(roads[!is.na(roads$name) & roads$name == "Hosmer Pond Road", ])))[, 1:2]
hp_xy <- hp_xy[order(hp_xy[, 1]), ]; hp_xy <- hp_xy[hp_xy[, 1] >= x_min & hp_xy[, 1] <= x_max, , drop = FALSE]
zone <- st_sfc(st_polygon(list(rbind(cbind(hp_xy[, 1], hp_xy[, 2] - 40), c(x_max, max(hp_xy[, 2]) + 4000),
                                     c(x_min, max(hp_xy[, 2]) + 4000), c(hp_xy[1, 1], hp_xy[1, 2] - 40)))), crs = crs_m)
nx <- setNames(nodes_all$x, nodes_all$key); ny <- setNames(nodes_all$y, nodes_all$key)
mx <- (nx[edges$from] + nx[edges$to]) / 2; my <- (ny[edges$from] + ny[edges$to]) / 2
net_i <- which(edges$src == "network"); mp <- st_coordinates(pt)
mx[net_i] <- mp[edges$seg[net_i], 1]; my[net_i] <- mp[edges$seg[net_i], 2]
in_zone <- lengths(st_intersects(st_as_sf(data.frame(x = mx, y = my), coords = c("x", "y"), crs = crs_m), zone)) > 0
# Stay near the road: more than 700 m south of Hosmer Pond Road (near the pond stretch) costs 20x.
road_y <- approx(hp_xy[, 1], hp_xy[, 2], xout = mx, rule = 2)$y
far_south <- (my < road_y - 700) & (mx >= x_min - 500) & (mx <= x_max + 1500)
# The town stretch (downtown to the Emery Way end) is unavoidable road, so busy road is only mildly penalized (A = 1.5).
w_south <- edges$length_m * mult(A = 1.5, S = 1.2, B = 3, N = 1.5, Pn = 3) * ifelse(in_zone, 60, 1) * ifelse(far_south, 20, 1)
south_eid <- path_edges(w_south, start_key, end_key)

sel <- list(`A  Shortest on existing roads and trails` = base_eid,
            `B  Shortest with little busy road` = routes[[compromise$route]],
            `C  Most public land, little busy road` = routes[[most_roadless$route]],
            `D  South of Hosmer Pond Road` = south_eid)
sel_m <- do.call(rbind, lapply(names(sel), function(n) cbind(route = n, metrics(sel[[n]]))))
print(sel_m, row.names = FALSE)
write.csv(sel_m, "gis/outputs/public_land_routes.csv", row.names = FALSE)
write.csv(fam_df[, setdiff(names(fam_df), "sig")], "gis/outputs/public_land_route_family.csv", row.names = FALSE)
cat("\nVertices on the main network near start / end (m from anchors):",
    round(sqrt((nx[start_key] - st_coordinates(anch[anch$osm_id == "downtown", ])[1])^2 + (ny[start_key] - st_coordinates(anch[anch$osm_id == "downtown", ])[2])^2)), "/",
    round(sqrt((nx[end_key] - st_coordinates(anch[anch$osm_id == "snowbowl", ])[1])^2 + (ny[end_key] - st_coordinates(anch[anch$osm_id == "snowbowl", ])[2])^2)), "\n")

# Private parcels each route touches: IDs stay in gis/private (not committed) -------------------------------
priv_tab <- do.call(rbind, lapply(names(sel), function(n) {
  e <- edges[sel[[n]], ]; e <- e[e$land %in% c("private", "private_new"), ]
  if (!nrow(e)) return(NULL)
  ids <- c(e$pf, e$pt); len <- c(e$length_m / ifelse(is.na(e$pt) | is.na(e$pf), 1, 2), e$length_m / 2 * !is.na(e$pt) * !is.na(e$pf))
  keep <- !is.na(ids); tt <- tapply(len[keep], ids[keep], sum)
  data.frame(route = n, parcel_id = names(tt), m_inside = round(as.numeric(tt)))
}))
write.csv(priv_tab, "gis/private/route_private_parcels.csv", row.names = FALSE)

# 7. Geometry for maps ---------------------------------------------------------------------------------------
edge_geom <- function(eid) {
  e <- edges[eid, ]
  geoms <- lapply(seq_len(nrow(e)), function(i) {
    if (e$src[i] == "network") st_geometry(segs)[[e$seg[i]]] else {
      a <- nodes_all[match(e$from[i], nodes_all$key), ]; b <- nodes_all[match(e$to[i], nodes_all$key), ]
      st_linestring(rbind(c(a$x, a$y), c(b$x, b$y))) }
  })
  st_sf(type = ifelse(e$land == "private_new", "new_private", e$type), land = e$land, geometry = st_sfc(geoms, crs = crs_m))
}
route_sf <- do.call(rbind, lapply(names(sel), function(n) cbind(route = n, edge_geom(sel[[n]]))))
st_write(route_sf, "gis/private/public_land_routes.gpkg", layer = "routes", append = FALSE, quiet = TRUE)

lab <- function(nm) { x <- segs[!is.na(segs$name) & segs$name %in% nm, ]; if (!nrow(x)) return(NULL); st_sf(label = nm[1], geometry = st_centroid(st_union(st_geometry(x)))) }
labs <- rbind(lab("Emery Way"), lab("Fox Trail"), lab("Miller Farm"), lab("Wiley Road"))
pond <- water[!is.na(water$name) & water$name == "Hosmer Pond", ]
labs <- rbind(labs, st_sf(label = "Hosmer Pond", geometry = st_centroid(st_union(st_geometry(pond)))))
rm_pk <- parks[!is.na(parks$name) & parks$name == "Ragged Mountain Preserve", ]
if (nrow(rm_pk)) labs <- rbind(labs, st_sf(label = "Ragged Mountain Preserve", geometry = st_centroid(st_union(st_geometry(rm_pk)))))
goose <- if (!is.null(ww)) ww[!is.na(ww$name) & grepl("Goose River", ww$name), ] else NULL
if (!is.null(goose) && nrow(goose)) labs <- rbind(labs, st_sf(label = "Goose River", geometry = st_centroid(st_union(st_geometry(goose)))))

cols <- setNames(c("gray35", "#1F78B4", "#6A3D9A", "#E31A1C"), names(sel))
bb <- st_bbox(st_buffer(st_union(c(st_geometry(route_sf), st_geometry(anch))), 700))
pub_parcels <- parcels[parcels$land_class %in% c("public", "conserved"), ]
p <- ggplot() +
  geom_sf(data = parcels[parcels$land_class == "private", ], fill = NA, color = "gray85", linewidth = 0.12) +
  geom_sf(data = parks_ok, fill = "#d9efc9", color = NA, alpha = 0.7) +
  geom_sf(data = pub_parcels, aes(fill = land_class), color = "#5b9b4a", linewidth = 0.2, alpha = 0.75) +
  geom_sf(data = parcels[parcels$land_class == "restricted", ], fill = "#f6d6a8", color = "#d9a05a", linewidth = 0.2) +
  geom_sf(data = water, fill = "#bcd8ee", color = NA) +
  { if (!is.null(ww)) geom_sf(data = ww, color = "#7fb0d8", linewidth = 0.3) } +
  { if (!is.null(goose) && nrow(goose)) geom_sf(data = goose, color = "#1f78b4", linewidth = 0.9) } +
  geom_sf(data = roads[roads$highway %in% c(busy_cls, small_cls), ], color = "gray55", linewidth = 0.25) +
  geom_sf(data = route_sf[route_sf$route == names(cols)[1], ], aes(color = route, linetype = type), linewidth = 3.4) +
  geom_sf(data = route_sf[route_sf$route == names(cols)[2], ], aes(color = route, linetype = type), linewidth = 2.4) +
  geom_sf(data = route_sf[route_sf$route == names(cols)[3], ], aes(color = route, linetype = type), linewidth = 1.7) +
  geom_sf(data = route_sf[route_sf$route == names(cols)[4], ], aes(color = route, linetype = type), linewidth = 1.1) +
  geom_sf(data = anch, size = 2.6) +
  geom_text_repel(data = cbind(labs, st_coordinates(labs)), aes(X, Y, label = label), size = 3, fontface = "italic", bg.color = "white", bg.r = 0.12,
                  min.segment.length = 0.2) +
  geom_text_repel(data = cbind(anch, st_coordinates(anch)), aes(X, Y, label = ifelse(osm_id == "snowbowl", "Snow Bowl", "Downtown Camden")),
                  size = 3.6, fontface = "bold", bg.color = "white", bg.r = 0.12) +
  scale_color_manual(values = cols, name = NULL) +
  scale_fill_manual(values = c(public = "#8fcf7a", conserved = "#6bbf8f"), labels = c(public = "Town, state or county land", conserved = "Conserved (land trust)"), name = NULL) +
  scale_linetype_manual(values = c(busy_road = "solid", small_road = "solid", trail = "solid", new_trail = "22", new_private = "dotted", gap = "11"), labels = c(busy_road = "busy road", small_road = "small road", trail = "existing trail", new_trail = "possible new trail, public land", new_private = "possible new trail, private land", gap = "assumed missing link"), name = NULL) +
  guides(color = guide_legend(order = 1, nrow = 2), linetype = guide_legend(order = 2), fill = guide_legend(order = 3)) +
  coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], expand = FALSE) +
  labs(title = "Routes from downtown Camden to the Snow Bowl: roadless, public land, short",
       subtitle = "Green = public or conserved land. Dashed = new trail on public land; dotted = new trail across private parcels (owner agreement needed). APPROXIMATE: old parcels, no slopes yet.",
       caption = "Parcels: Maine GeoLibrary. Roads, trails, parks: (c) OpenStreetMap contributors") +
  theme_void(base_size = 10) + theme(legend.position = "bottom", legend.box = "vertical", plot.title = element_text(face = "bold"),
                                       plot.margin = margin(6, 6, 6, 6))
ggsave("gis/private/public_land_routes_map.png", p, width = 13, height = 9, dpi = 150, bg = "white")

# Trade-off picture -------------------------------------------------------------------------------------------------------------
fam_plot <- rbind(fam_df[, c("length_km", "busy_road_pct", "private_parcels", "pareto")], data.frame(base_m[, c("length_km", "busy_road_pct", "private_parcels")], pareto = TRUE))
fam_plot$kind <- c(rep("Family of routes", nrow(fam_df)), "Shortest")
tp <- ggplot(fam_plot, aes(length_km, busy_road_pct, color = private_parcels, shape = kind, size = pareto)) +
  geom_point(alpha = 0.85) +
  scale_color_gradient(low = "#2b8cbe", high = "#e34a33", name = "Private parcels\ncrossed") +
  scale_size_manual(values = c(`TRUE` = 3.6, `FALSE` = 2), guide = "none") +
  scale_shape_manual(values = c("Family of routes" = 16, Shortest = 17), name = NULL) +
  labs(x = "Route length (km)", y = "% of route on busy roads", title = "Trade-off: length, busy road and number of private parcels crossed",
       subtitle = "Each dot is the cheapest route under a different weighting.\nLarger dots are not beaten on length, busy-road share and parcels crossed together.") +
  theme_minimal(base_size = 10)
ggsave("gis/outputs/public_land_tradeoff.png", tp, width = 8, height = 5, dpi = 150, bg = "white")
message("Wrote gis/private/public_land_routes_map.png (private), gis/outputs/public_land_tradeoff.png, public_land_routes.csv")
