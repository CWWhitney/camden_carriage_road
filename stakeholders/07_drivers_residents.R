# Drivers and road residents
# Ontology: Hosmer Pond Road is a shared route. Fewer bikes in the lane means
# less delay and fewer tense overtakes; more bikes on shoulders means a little more.

stakeholder <- new_stakeholder(
  id = "drivers_residents",
  label = "Drivers and road residents",
  ontology = "Road as shared route for getting somewhere; counts delay and near-miss stress.",
  dag_parents = list(
    delay_saving_usd = c("road_bike_trips_change", "dr_passes_per_bike_trip", "dr_delay_sec_per_pass",
                         "dr_value_of_time_usd_hr", "dr_shoulder_delay_factor", "option_is_path",
                         "dr_discount_rate", "horizon_yrs"),
    near_miss_stress_pts = c("road_bike_trips_change", "dr_passes_per_bike_trip", "dr_stress_pts_per_pass",
                             "dr_shoulder_delay_factor", "option_is_path", "dr_discount_rate", "horizon_yrs"),
    winter_driving_cost_usd = c("shoulder_km", "dr_winter_narrowing_usd_per_km_yr",
                                "dr_discount_rate", "horizon_yrs"),
    speed_delay_cost_usd = c("baseline_car_trips_yr", "speed_delay_min", "dr_value_of_time_usd_hr",
                             "dr_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("dr_passes_per_bike_trip", 3, 10, "posnorm", "Vehicles passing a cyclist per route trip"),
    E("dr_delay_sec_per_pass", 10, 40, "posnorm", "Delay per pass (seconds)"),
    E("dr_value_of_time_usd_hr", 15, 35, "posnorm", "Value of driver time (USD/hr)"),
    E("dr_shoulder_delay_factor", 0.3, 0.7, "tnorm_0_1", "Delay/stress per on-road cyclist when shoulders exist (fraction)"),
    E("dr_stress_pts_per_pass", 0.0005, 0.005, "posnorm", "Wellbeing lost per pass of a cyclist (pts)"),
    E("dr_winter_narrowing_usd_per_km_yr", 0, 800, "unif", "Cost to residents of snowbank narrowing per km (USD/yr)"),
    E("dr_discount_rate", 0.03, 0.07, "tnorm_0_1", "Discount rate (drivers)")
  ),
  values = rbind(
    V("delay_saving_usd", "Delay time saved", "USD"),
    V("near_miss_stress_pts", "Near-miss stress relief", "wellbeing pts"),
    V("winter_driving_cost_usd", "Winter narrowing cost", "USD"),
    V("speed_delay_cost_usd", "Lower speed limit delay", "USD")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(dr_discount_rate, horizon_yrs)
    f <- option_is_path + (1 - option_is_path) * dr_shoulder_delay_factor
    c(
      delay_saving_usd = -road_bike_trips_change * dr_passes_per_bike_trip * f *
        dr_delay_sec_per_pass / 3600 * dr_value_of_time_usd_hr * af,
      near_miss_stress_pts = -road_bike_trips_change * dr_passes_per_bike_trip * f *
        dr_stress_pts_per_pass * af,
      winter_driving_cost_usd = -shoulder_km * dr_winter_narrowing_usd_per_km_yr * af,
      speed_delay_cost_usd = -baseline_car_trips_yr * speed_delay_min / 60 * dr_value_of_time_usd_hr * af
    )
  })
)
