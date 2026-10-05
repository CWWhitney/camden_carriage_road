# Camden Snow Bowl
# Ontology: the road is a customer funnel and a staff commute. A safe bike
# route widens the summer and shoulder-season audience but adds liability.

stakeholder <- new_stakeholder(
  id = "snowbowl",
  label = "Camden Snow Bowl",
  ontology = "Destination to fill; counts visitors, margin, staff access and liability.",
  dag_parents = list(
    operating_margin_usd = c("extra_bike_trips", "sb_destination_share", "sb_spend_per_visitor",
                             "sb_margin", "sb_discount_rate", "horizon_yrs"),
    staff_commute_usd = c("sb_staff_bike_commuters", "sb_commute_saving_usd_yr", "option_is_path",
                          "sb_discount_rate", "horizon_yrs"),
    liability_usd = c("sb_liability_usd_yr", "option_is_path", "sb_discount_rate", "horizon_yrs"),
    brand_pts = c("sb_brand_pts_per_km", "trail_km_new", "sb_discount_rate", "horizon_yrs"),
    capital_contribution_usd = c("public_capital_cost", "annual_maint", "town_cost_share", "capshare_snowbowl",
                                 "sb_discount_rate", "horizon_yrs"),
    payment_contribution_usd = c("payment_oneoff", "payment_annual", "share_snowbowl",
                                  "sb_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("sb_destination_share", 0.1, 0.4, "tnorm_0_1", "Share of added bike trips that end at the Snow Bowl"),
    E("sb_spend_per_visitor", 8, 30, "posnorm", "Spend per visitor (USD)"),
    E("sb_margin", 0.2, 0.5, "tnorm_0_1", "Operating margin on spend"),
    E("sb_staff_bike_commuters", 5, 25, "posnorm", "Staff who would commute by bike"),
    E("sb_commute_saving_usd_yr", 200, 800, "posnorm", "Saving per bike-commuting staff member (USD/yr)"),
    E("sb_liability_usd_yr", 500, 4000, "posnorm", "Extra liability/insurance cost (USD/yr)"),
    E("sb_brand_pts_per_km", 0.2, 2, "posnorm", "Brand value of being bike-accessible (pts per km of path per yr)"),
    E("sb_discount_rate", 0.05, 0.12, "tnorm_0_1", "Discount rate (Snow Bowl)")
  ),
  values = rbind(
    V("operating_margin_usd", "Added operating margin", "USD"),
    V("staff_commute_usd", "Staff commute savings", "USD"),
    V("liability_usd", "Liability and insurance", "USD"),
    V("brand_pts", "Bike-accessible brand", "brand pts"),
    V("payment_contribution_usd", "Share of landowner payments", "USD"),
    V("capital_contribution_usd", "Share of path capital and upkeep (binding agreement)", "USD")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(sb_discount_rate, horizon_yrs)
    c(
      operating_margin_usd = extra_bike_trips * sb_destination_share * sb_spend_per_visitor * sb_margin * af,
      staff_commute_usd = option_is_path * sb_staff_bike_commuters * sb_commute_saving_usd_yr * af,
      liability_usd = -option_is_path * sb_liability_usd_yr * af,
      brand_pts = trail_km_new * sb_brand_pts_per_km * af,
      capital_contribution_usd = -(public_capital_cost + annual_maint * af) * town_cost_share * capshare_snowbowl,
      payment_contribution_usd = -(payment_oneoff + payment_annual * af) * share_snowbowl
    )
  })
)
