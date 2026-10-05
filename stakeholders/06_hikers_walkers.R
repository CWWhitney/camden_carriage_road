# Hikers and walkers
# Ontology: the forest is a quiet, wild place. A path opens safe access to
# trailheads but adds bikes, a developed corridor and the chance of conflict.

stakeholder <- new_stakeholder(
  id = "hikers_walkers",
  label = "Hikers and walkers",
  ontology = "Forest as quiet wild place; values access and solitude; dislikes developed corridors and bike conflict.",
  dag_parents = list(
    access_gain_pts = c("extra_walk_trips", "hk_wellbeing_pts_per_trip", "hk_discount_rate", "horizon_yrs"),
    solitude_loss_pts = c("extra_bike_trips", "hk_regular_hikers", "hk_solitude_pts_per_1000_bike_trips",
                          "option_is_path", "hk_discount_rate", "horizon_yrs"),
    conflict_incidents = c("extra_bike_trips", "hk_regular_hikers", "hk_conflicts_per_1000_bike_trips_per_hiker_group",
                           "option_is_path", "hk_discount_rate", "horizon_yrs"),
    wild_character_loss_pts = c("clear_ha", "hk_wild_pts_per_ha")
  ),
  inputs = rbind(
    E("hk_regular_hikers", 150, 600, "posnorm", "Regular hikers using the corridor"),
    E("hk_wellbeing_pts_per_trip", 0.05, 0.25, "posnorm", "Wellbeing per added walk trip (pts)"),
    E("hk_solitude_pts_per_1000_bike_trips", 0.02, 0.15, "posnorm", "Solitude lost per regular hiker per 1000 added bike trips (pts)"),
    E("hk_conflicts_per_1000_bike_trips_per_hiker_group", 0.01, 0.1, "posnorm", "Conflict incidents per 1000 added bike trips (per 100 hikers)"),
    E("hk_wild_pts_per_ha", 0.5, 5, "posnorm", "Wild-character loss per hectare cleared (pts)"),
    E("hk_discount_rate", 0.02, 0.06, "tnorm_0_1", "Discount rate (hikers)")
  ),
  values = rbind(
    V("access_gain_pts", "Safer access to trailheads", "wellbeing pts"),
    V("solitude_loss_pts", "Loss of solitude", "wellbeing pts"),
    V("conflict_incidents", "Bike-hiker conflict incidents", "incidents"),
    V("wild_character_loss_pts", "Loss of wild character", "wellbeing pts")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(hk_discount_rate, horizon_yrs)
    c(
      access_gain_pts = extra_walk_trips * hk_wellbeing_pts_per_trip * af,
      solitude_loss_pts = -option_is_path * hk_regular_hikers * extra_bike_trips / 1000 *
        hk_solitude_pts_per_1000_bike_trips * af,
      conflict_incidents = -option_is_path * extra_bike_trips / 1000 * (hk_regular_hikers / 100) *
        hk_conflicts_per_1000_bike_trips_per_hiker_group * af,
      wild_character_loss_pts = -clear_ha * hk_wild_pts_per_ha
    )
  })
)
