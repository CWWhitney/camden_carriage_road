# Trees (the forest as a stakeholder with standing)
# Ontology: individual standing organisms and the soil they live in. Value is
# measured in stems, stored carbon and intact ground; near-zero discounting.

stakeholder <- new_stakeholder(
  id = "trees",
  label = "Trees",
  ontology = "Standing organisms and soil; counted in stems, carbon and intact ground; almost no discounting.",
  dag_parents = list(
    stems_lost = c("clear_ha", "edge_ha", "tr_stems_per_ha", "tr_edge_mortality_share"),
    mature_trees_lost = c("stems_lost", "tr_mature_share"),
    carbon_lost_tco2e = c("clear_ha", "tr_carbon_tco2e_per_ha", "tr_regrowth_share",
                          "tr_recovery_years", "tr_discount_rate"),
    soil_sealed_ha = c("clear_ha", "tr_sealed_share", "option_is_path")
  ),
  inputs = rbind(
    E("tr_stems_per_ha", 800, 2500, "posnorm", "Stems per hectare"),
    E("tr_mature_share", 0.2, 0.5, "tnorm_0_1", "Share of stems that are mature"),
    E("tr_edge_mortality_share", 0.05, 0.2, "tnorm_0_1", "Share of edge-zone stems that die from exposure"),
    E("tr_carbon_tco2e_per_ha", 150, 450, "posnorm", "Carbon in biomass (tCO2e/ha)"),
    E("tr_regrowth_share", 0.1, 0.4, "tnorm_0_1", "Share of carbon eventually recovered by regrowth on verges"),
    E("tr_recovery_years", 20, 60, "posnorm", "Years until that recovery"),
    E("tr_sealed_share", 0.1, 0.4, "tnorm_0_1", "Share of cleared area permanently compacted or surfaced"),
    E("tr_discount_rate", 0, 0.02, "unif", "Discount rate (trees: near zero)")
  ),
  values = rbind(
    V("stems_lost", "Stems lost", "stems"),
    V("mature_trees_lost", "Mature trees lost", "trees"),
    V("carbon_lost_tco2e", "Carbon lost (net of recovery)", "tCO2e"),
    V("soil_sealed_ha", "Soil sealed or compacted", "ha")
  ),
  outcomes = function(p, d) with(c(p, d), {
    stems <- (clear_ha + edge_ha * tr_edge_mortality_share) * tr_stems_per_ha
    recov <- tr_regrowth_share * (1 + tr_discount_rate)^(-tr_recovery_years)
    c(
      stems_lost = -stems,
      mature_trees_lost = -stems * tr_mature_share,
      carbon_lost_tco2e = -clear_ha * tr_carbon_tco2e_per_ha * (1 - recov),
      soil_sealed_ha = -clear_ha * tr_sealed_share * option_is_path
    )
  })
)
