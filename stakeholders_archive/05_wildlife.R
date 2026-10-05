# Wildlife (aggregated: squirrels, deer, amphibians near Hosmer Pond, birds...)
# Ontology: territories, litters and crossings. A path costs habitat and adds
# disturbance, but fewer car trips on the road can mean fewer deaths.

stakeholder <- new_stakeholder(
  id = "wildlife",
  label = "Forest wildlife (aggregated)",
  ontology = "Territories, litters and crossings; hurt by habitat loss and disturbance, helped by fewer vehicles.",
  dag_parents = list(
    habitat_loss_ha = c("clear_ha", "edge_ha", "wl_edge_disturbance_share"),
    squirrel_litters_lost = c("clear_ha", "edge_ha", "wl_edge_disturbance_share", "wl_squirrel_territories_per_ha",
                              "wl_litters_per_territory_yr", "wl_discount_rate", "horizon_yrs"),
    roadkill_change = c("car_trips_avoided", "wl_baseline_roadkill_per_km_yr", "route_km",
                        "baseline_car_trips_yr", "wl_discount_rate", "horizon_yrs"),
    disturbance_events = c("extra_bike_trips", "extra_walk_trips", "wl_disturbance_per_1000_users",
                           "option_is_path", "wl_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("wl_edge_disturbance_share", 0.1, 0.4, "tnorm_0_1", "Share of edge zone that is unusable habitat"),
    E("wl_squirrel_territories_per_ha", 0.3, 1.2, "posnorm", "Red squirrel territories per ha"),
    E("wl_litters_per_territory_yr", 0.8, 1.6, "posnorm", "Litters per territory per year"),
    E("wl_baseline_roadkill_per_km_yr", 5, 30, "posnorm", "Animals killed per km of road per year today"),
    E("wl_disturbance_per_1000_users", 0.5, 5, "posnorm", "Disturbance events (flushing, abandonment) per 1000 users"),
    E("wl_discount_rate", 0, 0.02, "unif", "Discount rate (wildlife: near zero)")
  ),
  values = rbind(
    V("habitat_loss_ha", "Habitat lost", "ha"),
    V("squirrel_litters_lost", "Squirrel litters lost", "litters"),
    V("roadkill_change", "Road deaths avoided", "animals"),
    V("disturbance_events", "Trail disturbance events", "events")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(wl_discount_rate, horizon_yrs)
    hab <- clear_ha + edge_ha * wl_edge_disturbance_share
    c(
      habitat_loss_ha = -hab,
      squirrel_litters_lost = -hab * wl_squirrel_territories_per_ha * wl_litters_per_territory_yr * af,
      roadkill_change = wl_baseline_roadkill_per_km_yr * route_km *
        (car_trips_avoided / baseline_car_trips_yr) * af,
      disturbance_events = -option_is_path * (extra_bike_trips + extra_walk_trips) / 1000 *
        wl_disturbance_per_1000_users * af
    )
  })
)
