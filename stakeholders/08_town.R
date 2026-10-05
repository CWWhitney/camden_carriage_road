# Town of Camden, including the Snow Bowl
# Ontology: the Town is ONE entity with two budget pockets. The General Fund (taxes) pays for
# roads, EMS and most of the path. The Snow Bowl is a Town-owned special revenue fund (run by
# Parks and Recreation, outside the Budget Committee's general-fund review) that earns the
# added margin from more visitors but also carries the liability and the staff-commute effects.
# Source for the structure: Camden FY2026 municipal budget message (manager's letter), which
# lists the Snow Bowl among "the Town's special revenue funds" apart from the General Fund and
# says it "remains difficult for the Snow Bowl to turn a profit":
# https://cms8.revize.com/revize/camdenmaine/FY%202026%20Municipal%20Budget%20janice%20copy.pdf
# Because both pockets belong to one entity, there is no Snow Bowl "payer" separate from the
# Town: what the path costs the Town is paid out of the two pockets, and the vignette shows
# how much of it the Snow Bowl's own added margin could cover (an earmark). One discount rate
# (the Town's) is used for both pockets.

stakeholder <- new_stakeholder(
  id = "town",
  label = "Town of Camden (incl. the Snow Bowl)",
  ontology = "Budget, tax base and a town-owned ski area; counts net public cost, tax gain, EMS savings and Snow Bowl margin, staff access and liability.",
  dag_parents = list(
    net_capital_maint_cost_usd = c("public_capital_cost", "town_cost_share", "capshare_business", "annual_maint",
                                   "tw_discount_rate", "horizon_yrs"),
    tax_revenue_gain_usd = c("trail_km_new", "tw_assessed_uplift_per_km", "tw_tax_rate",
                             "tw_discount_rate", "horizon_yrs"),
    ems_savings_usd = c("injuries_avoided", "tw_ems_cost_per_injury", "tw_discount_rate", "horizon_yrs"),
    winter_maintenance_cost_usd = c("trail_km_new", "tw_winter_maint_per_km_yr",
                                    "tw_discount_rate", "horizon_yrs"),
    payment_contribution_usd = c("payment_oneoff", "payment_annual", "share_business",
                                 "tw_discount_rate", "horizon_yrs"),
    snowbowl_margin_usd = c("extra_bike_trips", "sb_destination_share", "sb_spend_per_visitor",
                            "sb_margin", "tw_discount_rate", "horizon_yrs"),
    snowbowl_staff_commute_usd = c("sb_staff_bike_commuters", "sb_commute_saving_usd_yr", "option_is_path",
                                   "tw_discount_rate", "horizon_yrs"),
    snowbowl_liability_usd = c("sb_liability_usd_yr", "option_is_path", "tw_discount_rate", "horizon_yrs"),
    snowbowl_brand_pts = c("sb_brand_pts_per_km", "trail_km_new", "tw_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("tw_assessed_uplift_per_km", 2e4, 1.5e5, "posnorm", "Added assessed value per km of path (USD/km)"),
    E("tw_tax_rate", 0.01, 0.02, "tnorm_0_1", "Effective property tax rate"),
    E("tw_ems_cost_per_injury", 1500, 6000, "posnorm", "Public EMS cost per injury crash (USD)"),
    E("tw_winter_maint_per_km_yr", 500, 3000, "posnorm", "Winter maintenance of path per km (USD/yr)"),
    E("tw_discount_rate", 0.02, 0.05, "tnorm_0_1", "Discount rate (Town, both budget pockets)"),
    E("sb_destination_share", 0.1, 0.4, "tnorm_0_1", "Share of added bike trips that end at the Snow Bowl (growth of mountain biking and bikepacking is the upside case)"),
    E("sb_spend_per_visitor", 8, 30, "posnorm", "Snow Bowl spend per visitor (USD)"),
    E("sb_margin", 0.2, 0.5, "tnorm_0_1", "Snow Bowl operating margin on spend"),
    E("sb_staff_bike_commuters", 5, 25, "posnorm", "Snow Bowl staff who would commute by bike"),
    E("sb_commute_saving_usd_yr", 200, 800, "posnorm", "Saving per bike-commuting staff member (USD/yr)"),
    E("sb_liability_usd_yr", 500, 4000, "posnorm", "Extra Snow Bowl liability/insurance cost (USD/yr)"),
    E("sb_brand_pts_per_km", 0.2, 2, "posnorm", "Brand value of being bike-accessible (pts per km of path per yr)")
  ),
  values = rbind(
    V("net_capital_maint_cost_usd", "Capital and upkeep cost to Town", "USD"),
    V("tax_revenue_gain_usd", "Added tax revenue", "USD"),
    V("ems_savings_usd", "Emergency-response savings", "USD"),
    V("winter_maintenance_cost_usd", "Winter maintenance", "USD"),
    V("payment_contribution_usd", "Landowner payments paid by Town", "USD"),
    V("snowbowl_margin_usd", "Snow Bowl added operating margin", "USD"),
    V("snowbowl_staff_commute_usd", "Snow Bowl staff commute savings", "USD"),
    V("snowbowl_liability_usd", "Snow Bowl liability and insurance", "USD"),
    V("snowbowl_brand_pts", "Snow Bowl bike-accessible brand", "brand pts")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(tw_discount_rate, horizon_yrs)
    c(
      net_capital_maint_cost_usd = -(public_capital_cost + annual_maint * af) * town_cost_share *
        (1 - capshare_business),
      tax_revenue_gain_usd = trail_km_new * tw_assessed_uplift_per_km * tw_tax_rate * af,
      ems_savings_usd = injuries_avoided * tw_ems_cost_per_injury * af,
      winter_maintenance_cost_usd = -trail_km_new * tw_winter_maint_per_km_yr * af,
      payment_contribution_usd = -(payment_oneoff + payment_annual * af) * (1 - share_business),
      snowbowl_margin_usd = extra_bike_trips * sb_destination_share * sb_spend_per_visitor * sb_margin * af,
      snowbowl_staff_commute_usd = option_is_path * sb_staff_bike_commuters * sb_commute_saving_usd_yr * af,
      snowbowl_liability_usd = -option_is_path * sb_liability_usd_yr * af,
      snowbowl_brand_pts = trail_km_new * sb_brand_pts_per_km * af
    )
  })
)
