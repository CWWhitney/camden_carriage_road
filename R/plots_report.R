# Plots for the vignette and the Town blog. They read the files written by run_all.R and gis/*.R,
# so documents can be rebuilt without rerunning the Monte Carlo.
# Map data: (c) OpenStreetMap contributors (ODbL); parcels: Maine GeoLibrary.

theme_report <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"),
                   plot.title.position = "plot", legend.position = "bottom",
                   panel.grid.minor = ggplot2::element_blank())
}

# Route map: roads, trails, parks, water, parcels next to the routes, routes A and D ----------------
plot_routes_map <- function(gpkg = "gis/data/osm_camden.gpkg", routes_gpkg = "gis/data/routes.gpkg",
                            parcels_gpkg = "gis/data/parcels_corridor.gpkg", crs_m = 26919) {
  rd <- sf::st_transform(sf::st_read(gpkg, "roads_paths", quiet = TRUE), crs_m)
  wt <- sf::st_transform(sf::st_read(gpkg, "water", quiet = TRUE), crs_m)
  pk <- sf::st_make_valid(sf::st_transform(sf::st_read(gpkg, "parks", quiet = TRUE), crs_m))
  an <- sf::st_transform(sf::st_read(gpkg, "anchors", quiet = TRUE), crs_m)
  rt <- sf::st_read(routes_gpkg, quiet = TRUE)
  pc <- if (file.exists(parcels_gpkg)) sf::st_read(parcels_gpkg, quiet = TRUE) else NULL
  rt <- rt[c(1, 4), ]
  rt$short <- c("A: Hosmer Pond Road corridor", "B: loop avoiding Hosmer Pond Road")
  bb <- sf::st_bbox(sf::st_buffer(sf::st_union(rt), 1300))
  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = pk, fill = "#e3f0da", color = NA) +
    ggplot2::geom_sf(data = wt, fill = "#cfe2f3", color = NA)
  if (!is.null(pc))
    p <- p + ggplot2::geom_sf(data = pc, ggplot2::aes(fill = ifelse(public_owner, "Public or conservation owner", "Private owner")),
                              color = "white", linewidth = 0.1, alpha = 0.9) +
      ggplot2::scale_fill_manual(values = c("Private owner" = "#f3d9a8", "Public or conservation owner" = "#7fb069"), name = "Parcels beside the routes")
  p <- p +
    ggplot2::geom_sf(data = rd[!rd$highway %in% c("footway", "path", "track", "cycleway", "bridleway"), ], color = "gray60", linewidth = 0.3) +
    ggplot2::geom_sf(data = rd[rd$highway %in% c("footway", "path", "track", "cycleway", "bridleway"), ], color = "gray55", linewidth = 0.25, linetype = "dotted") +
    ggplot2::geom_sf(data = rt, ggplot2::aes(color = short, linetype = short), linewidth = 1.3) +
    ggplot2::scale_color_manual(values = c("#B2182B", "#2166AC"), name = "Route") +
    ggplot2::scale_linetype_manual(values = c("solid", "longdash"), name = "Route") +
    ggplot2::geom_sf(data = an, size = 3) +
    ggplot2::geom_sf_text(data = an, ggplot2::aes(label = ifelse(osm_id == "snowbowl", "Camden Snow Bowl", "Downtown Camden")),
                          nudge_y = 330, size = 3.8, fontface = "bold") +
    ggplot2::annotate("segment", x = bb["xmin"] + 300, xend = bb["xmin"] + 1300, y = bb["ymin"] + 250, yend = bb["ymin"] + 250, linewidth = 1) +
    ggplot2::annotate("text", x = bb["xmin"] + 800, y = bb["ymin"] + 420, label = "1 km", size = 3.5) +
    ggplot2::coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], expand = FALSE) +
    ggplot2::labs(title = "Two ways to connect downtown Camden to the Snow Bowl",
                  subtitle = "Cheapest paths on OpenStreetMap roads and trails, with the tax parcels they pass. Approximate.",
                  caption = "Roads, trails, parks: (c) OpenStreetMap contributors. Parcels: Maine GeoLibrary (town-submitted, some data are old).") +
    ggplot2::guides(color = ggplot2::guide_legend(nrow = 2, order = 1), linetype = ggplot2::guide_legend(nrow = 2, order = 1),
                    fill = ggplot2::guide_legend(nrow = 2, order = 2)) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(legend.position = "bottom", plot.title = ggplot2::element_text(face = "bold"),
                   plot.margin = ggplot2::margin(8, 8, 8, 8))
  p
}

plot_elevation <- function(file = "gis/outputs/elevation_profiles.csv") {
  d <- read.csv(file)
  d$short <- ifelse(grepl("^A", d$route), "A: Hosmer Pond Road corridor",
             ifelse(grepl("^D", d$route), "B: loop avoiding Hosmer Pond Road", NA))
  d <- d[!is.na(d$short), ]
  ggplot2::ggplot(d, ggplot2::aes(dist_m / 1000, elev_m, color = short, linetype = short)) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::scale_color_manual(values = c("#B2182B", "#2166AC"), name = NULL) +
    ggplot2::scale_linetype_manual(values = c("solid", "longdash"), name = NULL) +
    ggplot2::labs(x = "Distance from downtown Camden (km)", y = "Elevation (m)",
                  title = "The climb from downtown to the Snow Bowl road",
                  subtitle = "USGS 3DEP elevation sampled every 50 m along each route") +
    theme_report()
}

# Where could the money come from? The Snow Bowl's added margin against what the Town pays -------------
# Uses medians of each value from value_summary.csv (a sum of medians is only a rough guide).
plot_budget_pockets <- function(summ_file = "outputs/liability_protected/value_summary.csv",
                                options = c("carriage_path", "path_annual", "path_donated", "path_cost_sharing")) {
  s <- read.csv(summ_file)
  s <- s[s$stakeholder == "town" & s$option %in% options, ]
  pos <- s[s$value == "snowbowl_margin_usd", c("option", "median")]
  pos$part <- "Snow Bowl added margin (Snow Bowl fund)"
  cost_vals <- c("net_capital_maint_cost_usd", "payment_contribution_usd", "winter_maintenance_cost_usd")
  cost_lab <- c(net_capital_maint_cost_usd = "Capital and upkeep (General Fund)",
                payment_contribution_usd = "Payments to landowners (Town)",
                winter_maintenance_cost_usd = "Winter maintenance (Town)")
  neg <- s[s$value %in% cost_vals, c("option", "median", "value")]
  neg$part <- cost_lab[neg$value]; neg$value <- NULL
  d <- rbind(pos, neg)
  d$option <- factor(setNames(options_tbl$label, options_tbl$option)[d$option],
                     levels = setNames(options_tbl$label, options_tbl$option)[options])
  d$part <- factor(d$part, levels = c(unname(cost_lab), "Snow Bowl added margin (Snow Bowl fund)"))
  ggplot2::ggplot(d, ggplot2::aes(option, median / 1e6, fill = part)) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::geom_hline(yintercept = 0, color = "gray30") +
    ggplot2::scale_fill_manual(values = c("#B2182B", "#E08214", "#8C510A", "#2166AC"), name = NULL) +
    ggplot2::scale_x_discrete(labels = function(x) stringr_wrap(x, 20)) +
    ggplot2::labs(x = NULL, y = "Present value (million USD)",
                  title = "Could the Snow Bowl's added margin cover the Town's cost of the path?",
                  subtitle = "Median of each line; both pockets belong to the Town. PLACEHOLDER INPUTS.") +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2)) +
    theme_report()
}
