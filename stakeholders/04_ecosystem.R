# Ecosystem (trees and wildlife together)
# Ontology: the forest as living systems with standing. Trees are counted in stems,
# carbon and intact soil; wildlife in territories, litters and crossings. Near-zero
# discounting. (Earlier separate trees and wildlife files are in stakeholders_archive/.)

stakeholder <- new_stakeholder(
  id = "ecosystem",
  label = "Ecosystem (trees and wildlife)",
  ontology = "Living forest systems with standing; counted in stems, carbon, territories and crossings; almost no discounting.",
  dag_parents = list(
    stems_lost = c("clear_ha", "edge_ha", "tr_stems_per_ha", "tr_edge_mortality_share"),
    mature_trees_lost = c("stems_lost", "tr_mature_share"),
    carbon_lost_tco2e = c("clear_ha", "tr_carbon_tco2e_per_ha", "tr_regrowth_share",
                          "tr_recovery_years", "ec_discount_rate"),
    soil_sealed_ha = c("clear_ha", "tr_sealed_share", "option_is_path"),
    habitat_loss_ha = c("clear_ha", "edge_ha", "wl_edge_disturbance_share"),
    squirrel_litters_lost = c("clear_ha", "edge_ha", "wl_edge_disturbance_share", "wl_squirrel_territories_per_ha",
                              "wl_litters_per_territory_yr", "ec_discount_rate", "horizon_yrs"),
    roadkill_change = c("car_trips_avoided", "wl_baseline_roadkill_per_km_yr", "route_km",
                        "baseline_car_trips_yr", "ec_discount_rate", "horizon_yrs"),
    disturbance_events = c("extra_bike_trips", "extra_walk_trips", "wl_disturbance_per_1000_users",
                           "option_is_path", "ec_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("tr_stems_per_ha", 800, 2500, "posnorm", "Stems per hectare"),
    E("tr_mature_share", 0.2, 0.5, "tnorm_0_1", "Share of stems that are mature"),
    E("tr_edge_mortality_share", 0.05, 0.2, "tnorm_0_1", "Share of edge-zone stems that die from exposure"),
    E("tr_carbon_tco2e_per_ha", 150, 450, "posnorm", "Carbon in biomass (tCO2e/ha)"),
    E("tr_regrowth_share", 0.1, 0.4, "tnorm_0_1", "Share of carbon eventually recovered by regrowth on verges"),
    E("tr_recovery_years", 20, 60, "posnorm", "Years until that recovery"),
    E("tr_sealed_share", 0.1, 0.4, "tnorm_0_1", "Share of cleared area permanently compacted or surfaced"),
    E("wl_edge_disturbance_share", 0.1, 0.4, "tnorm_0_1", "Share of edge zone that is unusable habitat"),
    E("wl_squirrel_territories_per_ha", 0.3, 1.2, "posnorm", "Red squirrel territories per ha"),
    E("wl_litters_per_territory_yr", 0.8, 1.6, "posnorm", "Litters per territory per year"),
    E("wl_baseline_roadkill_per_km_yr", 5, 30, "posnorm", "Animals killed per km of road per year today"),
    E("wl_disturbance_per_1000_users", 0.5, 5, "posnorm", "Disturbance events (flushing, abandonment) per 1000 users"),
    E("ec_discount_rate", 0, 0.02, "unif", "Discount rate (ecosystem: near zero)")
  ),
  values = rbind(
    V("stems_lost", "Stems lost", "stems"),
    V("mature_trees_lost", "Mature trees lost", "trees"),
    V("carbon_lost_tco2e", "Carbon lost (net of recovery)", "tCO2e"),
    V("soil_sealed_ha", "Soil sealed or compacted", "ha"),
    V("habitat_loss_ha", "Habitat lost", "ha"),
    V("squirrel_litters_lost", "Squirrel litters lost", "litters"),
    V("roadkill_change", "Road deaths avoided", "animals"),
    V("disturbance_events", "Trail disturbance events", "events")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(ec_discount_rate, horizon_yrs)
    stems <- (clear_ha + edge_ha * tr_edge_mortality_share) * tr_stems_per_ha
    recov <- tr_regrowth_share * (1 + ec_discount_rate)^(-tr_recovery_years)
    hab <- clear_ha + edge_ha * wl_edge_disturbance_share
    c(
      stems_lost = -stems,
      mature_trees_lost = -stems * tr_mature_share,
      carbon_lost_tco2e = -clear_ha * tr_carbon_tco2e_per_ha * (1 - recov),
      soil_sealed_ha = -clear_ha * tr_sealed_share * option_is_path,
      habitat_loss_ha = -hab,
      squirrel_litters_lost = -hab * wl_squirrel_territories_per_ha * wl_litters_per_territory_yr * af,
      roadkill_change = wl_baseline_roadkill_per_km_yr * route_km *
        (car_trips_avoided / baseline_car_trips_yr) * af,
      disturbance_events = -option_is_path * (extra_bike_trips + extra_walk_trips) / 1000 *
        wl_disturbance_per_1000_users * af
    )
  })
)
