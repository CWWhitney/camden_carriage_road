# Candidate routes from downtown Camden to the Camden Snow Bowl ------------------------------
# Builds a routable network from the OpenStreetMap roads and trails (gis/01_fetch_osm.R) and finds
# the cheapest route under different rules. APPROXIMATE: OSM connectivity and classes are
# volunteer-mapped, ways are noded wherever lines cross (so a bridge counts as a junction), and
# nothing here knows about land ownership, grades, snow or traffic. Use it to compare route
# concepts and to replace placeholder route lengths, not as a design.
#
#   A road corridor   roads only (Route 1 and other primary roads penalized): the Hosmer Pond Road idea
#   B existing trails prefers existing trails (footways, paths, tracks), roads as connectors
#   C through park    prefers anything inside the mapped park / protected-area polygons (needs the
#                     "parks" layer; skipped if missing)
# Run from the project root:  Rscript gis/02_routes.R

suppressPackageStartupMessages({ library(sf); library(igraph); library(ggplot2) })
gpkg <- "gis/data/osm_camden.gpkg"
crs_m <- 26919                                           # NAD83 / UTM 19N, metres
dir.create("gis/outputs", showWarnings = FALSE, recursive = TRUE)

roads <- st_transform(st_read(gpkg, "roads_paths", quiet = TRUE), crs_m)
road_cls  <- c("primary", "trunk", "secondary", "tertiary", "unclassified", "residential", "living_street")
trail_cls <- c("footway", "path", "track", "cycleway", "bridleway")
roads <- roads[roads$highway %in% c(road_cls, trail_cls), ]
water <- st_transform(st_read(gpkg, "water", quiet = TRUE), crs_m)
anch  <- st_transform(st_read(gpkg, "anchors", quiet = TRUE), crs_m)
parks <- if ("parks" %in% st_layers(gpkg)$name) st_make_valid(st_transform(st_read(gpkg, "parks", quiet = TRUE), crs_m)) else NULL

# 1. Node the network: split lines wherever they cross or touch ---------------------------
noded <- st_cast(st_union(st_geometry(roads)), "LINESTRING")
segs <- st_sf(geometry = noded)
mid <- st_line_sample(segs, sample = 0.5)
nearest <- st_nearest_feature(st_sf(geometry = mid), roads)
segs$name <- roads$name[nearest]
segs$highway <- roads$highway[nearest]
segs$length_m <- as.numeric(st_length(segs))
segs$kind <- ifelse(segs$highway %in% trail_cls, "trail", "road")
segs$busy <- segs$highway %in% c("primary", "trunk")
if (!is.null(parks)) {
  inpark <- lengths(st_intersects(st_sf(geometry = mid), st_union(parks))) > 0
  segs$in_park <- inpark
} else segs$in_park <- FALSE

xy <- st_coordinates(segs)
first <- !duplicated(xy[, "L1"]); last <- !duplicated(xy[, "L1"], fromLast = TRUE)
key <- function(m) paste(round(m[, "X"], 1), round(m[, "Y"], 1))
segs$from <- key(xy[first, ]); segs$to <- key(xy[last, ])

# Same endpoints for every route: the road junction nearest each anchor, so lengths are comparable
# (the Snow Bowl anchor is a point on the mountain; the road reaches the base area).
road_ends <- unique(data.frame(key = c(segs$from[segs$kind == "road"], segs$to[segs$kind == "road"]),
                               x = c(xy[first, "X"][segs$kind == "road"], xy[last, "X"][segs$kind == "road"]),
                               y = c(xy[first, "Y"][segs$kind == "road"], xy[last, "Y"][segs$kind == "road"])))
nearest_end <- function(pt) road_ends$key[which.min((road_ends$x - st_coordinates(pt)[1])^2 + (road_ends$y - st_coordinates(pt)[2])^2)]
start_key <- nearest_end(anch[anch$osm_id == "downtown", ]); end_key <- nearest_end(anch[anch$osm_id == "snowbowl", ])

# 2. Cheapest route under each rule -------------------------------------------------------
route <- function(allowed, mult, label) {
  e <- segs[allowed, ]
  e$cost <- e$length_m * mult[allowed]
  e$eid <- seq_len(nrow(e))
  g <- graph_from_data_frame(st_drop_geometry(e)[, c("from", "to", "length_m", "cost", "name", "highway", "kind", "in_park", "eid")],
                             directed = FALSE)
  a <- match(start_key, V(g)$name); b <- match(end_key, V(g)$name)
  sp <- shortest_paths(g, a, b, weights = E(g)$cost, output = "epath")$epath[[1]]
  if (!length(sp)) stop("No route found for ", label)
  used <- as_data_frame(g, "edges")[as.integer(sp), ]
  geom <- e$geometry[used$eid]
  list(label = label, edges = used, line = st_sf(route = label, geometry = st_sfc(st_union(st_sfc(geom, crs = crs_m)), crs = crs_m)))
}
busy_pen <- ifelse(segs$busy, 3, 1)
hosmer <- !is.na(segs$name) & segs$name == "Hosmer Pond Road"
A <- route(segs$kind == "road", busy_pen, "A road corridor (Hosmer Pond Road idea)")
B <- route(rep(TRUE, nrow(segs)), ifelse(segs$kind == "trail", 0.25, 1) * ifelse(segs$busy, 4, 1), "B existing trails where possible")
D <- route(rep(TRUE, nrow(segs)), ifelse(hosmer, 50, 1) * ifelse(segs$kind == "trail", 0.8, 1) * ifelse(segs$busy, 4, 1),
           "D avoiding Hosmer Pond Road")
res <- list(A, B, D)
if (!is.null(parks)) {
  C <- route(rep(TRUE, nrow(segs)), ifelse(segs$in_park, 0.25, 1) * ifelse(segs$busy, 4, 1), "C park land where possible")
  res <- c(res[1:2], list(C), res[3])
} else message("No parks layer yet: route C skipped.")

# 3. Summary ---------------------------------------------------------------------------------
summ <- do.call(rbind, lapply(res, function(r) {
  e <- r$edges; tot <- sum(e$length_m)
  by_name <- sort(tapply(e$length_m, ifelse(is.na(e$name), "(unnamed)", e$name), sum), decreasing = TRUE)
  data.frame(route = r$label, length_km = round(tot / 1000, 2),
             pct_trail = round(100 * sum(e$length_m[e$kind == "trail"]) / tot),
             pct_in_park = round(100 * sum(e$length_m[e$in_park]) / tot),
             pct_hosmer_pond_road = round(100 * sum(e$length_m[!is.na(e$name) & e$name == "Hosmer Pond Road"]) / tot),
             main_names = paste(head(names(by_name), 5), collapse = "; "))
}))
straight <- as.numeric(st_distance(anch[anch$osm_id == "downtown", ], anch[anch$osm_id == "snowbowl", ]))
summ$straight_line_km <- round(straight / 1000, 2)
print(summ, row.names = FALSE)
write.csv(summ, "gis/outputs/route_summary.csv", row.names = FALSE)
lines_out <- do.call(rbind, lapply(res, `[[`, "line"))
st_write(lines_out, "gis/data/routes.gpkg", layer = "routes", append = FALSE, quiet = TRUE)

# 4. Map ---------------------------------------------------------------------------------------
cols <- setNames(c("#B2182B", "#1B7837", "#2166AC", "#E08214")[seq_along(res)], vapply(res, `[[`, "", "label"))
bb <- st_bbox(st_buffer(st_union(lines_out, anch), 1500))
p <- ggplot() +
  geom_sf(data = water, fill = "#cfe2f3", color = NA) +
  geom_sf(data = if (!is.null(parks)) parks else water[0, ], fill = "#e5f2dc", color = "#9bc88a", linewidth = 0.2, alpha = 0.7) +
  geom_sf(data = roads[roads$highway %in% road_cls, ], color = "gray70", linewidth = 0.3) +
  geom_sf(data = roads[roads$highway %in% trail_cls, ], color = "gray60", linewidth = 0.25, linetype = "dotted") +
  geom_sf(data = lines_out[1, ], aes(color = route), linewidth = 4.8) +
  geom_sf(data = lines_out[2, ], aes(color = route), linewidth = 3.4) +
  geom_sf(data = lines_out[3, ], aes(color = route), linewidth = 2.2) +
  geom_sf(data = lines_out[4, ], aes(color = route), linewidth = 1.1) +
  geom_sf(data = anch, size = 3) +
  geom_sf_text(data = anch, aes(label = ifelse(osm_id == "snowbowl", "Camden Snow Bowl", "Downtown Camden")),
               nudge_y = 350, size = 3.5, fontface = "bold") +
  scale_color_manual(values = cols, name = NULL) +
  coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], expand = FALSE) +
  labs(title = "Candidate routes from downtown Camden to the Snow Bowl",
       subtitle = "Cheapest routes under different rules on OpenStreetMap roads and trails (shared stretches drawn as stacked lines).\nAPPROXIMATE; no land ownership or grades yet.",
       caption = "(c) OpenStreetMap contributors") +
  guides(color = guide_legend(nrow = 2)) +
  theme_void(base_size = 11) + theme(legend.position = "bottom", plot.margin = margin(8, 8, 8, 8),
                                      plot.title = element_text(face = "bold"))
ggsave("gis/outputs/routes_map.png", p, width = 10, height = 8, dpi = 150, bg = "white")
message("Wrote gis/outputs/route_summary.csv, routes_map.png and gis/data/routes.gpkg")
