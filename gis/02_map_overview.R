# First overview map of the Camden to Snow Bowl area. Data (c) OpenStreetMap contributors (ODbL).
suppressPackageStartupMessages({ library(sf); library(ggplot2) })
g <- "gis/data/osm_camden.gpkg"
rd <- st_read(g, "roads_paths", quiet = TRUE); wa <- st_read(g, "water", quiet = TRUE)
pk <- st_read(g, "parks", quiet = TRUE); tb <- st_read(g, "town_boundary", quiet = TRUE)
an <- st_read(g, "anchors", quiet = TRUE)
tb <- tb[tb$name == "Camden", ]
trail <- rd[rd$highway %in% c("path", "track", "footway", "bridleway", "cycleway"), ]
road  <- rd[rd$highway %in% c("primary", "secondary", "tertiary", "residential", "unclassified", "service"), ]
p <- ggplot() +
  geom_sf(data = pk, fill = "#d8e8c8", colour = NA) + geom_sf(data = wa, fill = "#bcd7ee", colour = NA) +
  geom_sf(data = tb, fill = NA, colour = "grey40", linetype = "dashed") +
  geom_sf(data = road, colour = "grey55", linewidth = 0.3) +
  geom_sf(data = trail, colour = "#b5651d", linewidth = 0.25) +
  geom_sf(data = an, colour = "red", size = 2.5) +
  ggrepel::geom_text_repel(data = an, aes(label = ifelse(osm_id == "snowbowl", "Camden Snow Bowl", "Downtown Camden"),
                                         geometry = geom), stat = "sf_coordinates", size = 3.8, fontface = "bold",
                           nudge_y = 0.012, min.segment.length = 0, bg.color = "white") +
  coord_sf(xlim = c(-69.20, -69.00), ylim = c(44.16, 44.28), expand = FALSE) + theme_void(base_size = 12) +
  labs(title = "Camden to the Snow Bowl: roads (grey), trails (brown), parks (green)",
       subtitle = "Dashed line: Camden town boundary",
       caption = "(c) OpenStreetMap contributors")
ggsave("outputs/map_overview.png", p, width = 9, height = 6, dpi = 150, bg = "white")
