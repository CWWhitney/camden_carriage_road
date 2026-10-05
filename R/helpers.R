# Helpers shared by every stakeholder file ------------------------------------
# E()  one row of a decisionSupport estimate table
# V()  one row describing an outcome value (name, label, unit)
# annuity()  present-value factor for a constant annual flow
# make_dag() build a dagitty string from "value = c(parents)" lists, pulling in
#            the shared physical layer automatically
# new_stakeholder() bundle DAG + inputs + values + outcome function

E <- function(variable, lower, upper, distribution = "posnorm",
              label = variable,
              Description = "PLACEHOLDER range - to be elicited from this stakeholder group") {
  data.frame(variable = variable, lower = lower, upper = upper,
             distribution = distribution, label = label,
             Description = Description, stringsAsFactors = FALSE)
}

V <- function(value, label, unit) {
  stopifnot(!grepl("__", value, fixed = TRUE))  # "__" is the output-name separator
  data.frame(value = value, label = label, unit = unit, stringsAsFactors = FALSE)
}

# Present value of 1 unit/yr over T years at discount rate r
annuity <- function(r, T) ifelse(r == 0, T, (1 - (1 + r)^(-T)) / r)

# Which shared inputs each physical node depends on (used to draw the DAGs and
# to check that stakeholder DAGs only start from known nodes).
phys_parents <- list(
  capital_cost           = c("route_km", "path_cost_per_km", "shoulder_cost_per_km",
                             "mitigation_cost_mult", "option_is_path", "option_bundle"),
  public_capital_cost    = c("capital_cost", "grant_share"),
  annual_maint           = c("route_km", "path_maint_per_km_yr", "shoulder_maint_per_km_yr",
                             "option_is_path", "option_bundle"),
  land_ha                = c("route_km", "corridor_width_m", "shoulder_extra_width_m",
                             "path_private_share", "shoulder_private_land_share",
                             "option_is_path", "option_bundle"),
  clear_ha               = c("route_km", "corridor_width_m", "shoulder_extra_width_m",
                             "clearing_fraction", "shoulder_clear_fraction",
                             "option_is_path", "option_bundle"),
  edge_ha                = c("route_km", "edge_depth_m", "clearing_fraction",
                             "shoulder_clear_fraction", "option_is_path", "option_bundle"),
  payment_oneoff         = c("land_ha", "easement_payment_per_ha", "option_bundle"),
  payment_annual         = c("land_ha", "annual_payment_per_ha", "option_bundle"),
  host_share             = c("option_is_path", "option_bundle"),
  donated                = c("option_bundle"),
  capshare_business      = c("mech_capshare_business", "option_bundle"),
  liability_mult         = c("liability_exposed_mult", "option_bundle"),
  share_business         = c("comp_share_business", "option_bundle"),
  extra_bike_trips       = c("baseline_bike_trips_yr", "demand_mult_path", "demand_mult_shoulders",
                             "option_is_path", "option_bundle"),
  road_bike_trips_change = c("baseline_bike_trips_yr", "demand_mult_path", "demand_mult_shoulders",
                             "road_share_path", "option_is_path", "option_bundle"),
  injuries_avoided       = c("baseline_bike_trips_yr", "baseline_injuries_per_10k_trips",
                             "demand_mult_path", "demand_mult_shoulders",
                             "risk_mult_path", "risk_mult_shoulders", "speed_risk_mult",
                             "option_is_path", "option_bundle"),
  extra_walk_trips       = c("baseline_walk_trips_yr", "walk_mult_path", "walk_mult_shoulders",
                             "option_is_path", "option_bundle"),
  car_trips_avoided      = c("extra_bike_trips", "car_replace_share"),
  car_km_avoided         = c("car_trips_avoided", "route_km"),
  speed_delay_min        = c("speed_delay_min_per_car_trip", "option_bundle"),
  trail_km_new           = c("route_km", "option_is_path", "option_bundle"),
  shoulder_km            = c("route_km", "option_is_path", "option_bundle")
)

make_dag <- function(value_parents) {
  edges <- character()
  add <- function(child, parents) {
    edges <<- c(edges, paste0(parents, " -> ", child))
  }
  for (v in names(value_parents)) add(v, value_parents[[v]])
  # expand physical nodes recursively
  todo <- intersect(unlist(value_parents), names(phys_parents))
  done <- character()
  while (length(todo)) {
    n <- todo[1]; todo <- todo[-1]
    if (n %in% done) next
    done <- c(done, n)
    add(n, phys_parents[[n]])
    todo <- c(todo, intersect(phys_parents[[n]], names(phys_parents)))
  }
  paste0("dag {\n  ", paste(unique(edges), collapse = "\n  "), "\n}")
}

new_stakeholder <- function(id, label, ontology, dag_parents, inputs, values, outcomes) {
  structure(list(id = id, label = label, ontology = ontology,
                 dag_parents = dag_parents, dag = make_dag(dag_parents),
                 inputs = inputs, values = values, outcomes = outcomes),
            class = "stakeholder")
}

load_stakeholders <- function(dir = "stakeholders") {
  files <- sort(list.files(dir, pattern = "\\.R$", full.names = TRUE))
  out <- lapply(files, function(f) {
    env <- new.env(parent = globalenv())
    sys.source(f, envir = env)
    env$stakeholder
  })
  setNames(out, vapply(out, `[[`, "", "id"))
}

# Check that each DAG is coherent with its input table and outcome function -----
validate_stakeholder <- function(s, shared_inputs, mid_p) {
  g <- dagitty::dagitty(s$dag)
  nodes <- names(g)
  roots <- dagitty::exogenousVariables(g)
  phys_nodes <- names(physical_delta(mid_p, "carriage_path"))
  allowed_roots <- c(s$inputs$variable, shared_inputs$variable, "option_is_path", "option_bundle")
  problems <- c(
    if (!dagitty::isAcyclic(g)) "DAG has a cycle",
    if (length(bad <- setdiff(roots, allowed_roots))) paste("roots not in any input table:", toString(bad)),
    if (length(m <- setdiff(s$inputs$variable, nodes))) paste("inputs missing from DAG:", toString(m)),
    if (length(m <- setdiff(s$values$value, nodes))) paste("values missing from DAG:", toString(m)),
    if (length(m <- setdiff(intersect(nodes, names(phys_parents)), phys_nodes))) paste("unknown physical nodes:", toString(m))
  )
  # outcome function must return exactly the declared values
  res <- names(s$outcomes(mid_p, physical_delta(mid_p, "carriage_path")))
  if (!setequal(res, s$values$value))
    problems <- c(problems, paste("outcome names differ from values table:", toString(setdiff(union(res, s$values$value), intersect(res, s$values$value)))))
  problems
}

# Layered DAG plot (sources left, outcome values right) ------------------------
# simplify = TRUE hides the shared decision inputs (route length, costs, ...) so the
# group's own inputs, the physical consequences it perceives and its outcome values
# are readable at normal viewing distance. simplify = FALSE draws everything.
# Returns the plot with an attribute "size" = c(width, height) in inches.
plot_dag <- function(s, shared_inputs, simplify = TRUE, label_size = 4.2) {
  g <- dagitty::dagitty(s$dag)
  e <- dagitty::edges(g)
  e <- e[e$e == "->", c("v", "w")]
  shared <- c(shared_inputs$variable, "option_is_path", "option_bundle")
  if (simplify) {
    e <- e[!(e$v %in% shared), ]
  }
  nodes <- union(e$v, e$w)
  depth <- setNames(rep(0, length(nodes)), nodes)
  for (i in seq_along(nodes))                       # longest-path layering
    for (k in seq_len(nrow(e)))
      depth[e$w[k]] <- max(depth[e$w[k]], depth[e$v[k]] + 1)
  # sources sit one layer left of their first child, values in the last layer
  for (n in setdiff(nodes, e$w)) depth[n] <- min(depth[e$w[e$v == n]]) - 1
  depth[s$values$value] <- max(depth)
  depth <- depth - min(depth)
  ord <- order(depth, nodes)
  nd <- data.frame(name = nodes[ord], x = depth[ord], stringsAsFactors = FALSE)
  nd$y <- ave(nd$x, nd$x, FUN = function(z) seq_along(z) - mean(seq_along(z)))
  nd$type <- ifelse(nd$name %in% s$values$value, "outcome value",
             ifelse(nd$name %in% s$inputs$variable, "this group's input",
             ifelse(nd$name %in% shared, "shared decision input",
                    "physical consequence")))
  ed <- merge(merge(e, nd, by.x = "v", by.y = "name"), nd, by.x = "w", by.y = "name",
              suffixes = c("", "_to"))
  # humanize node names a little for reading: underscores to spaces
  nd$text <- gsub("_", " ", nd$name)
  nlayers <- max(nd$x) + 1
  maxn <- max(table(nd$x))
  width <- max(12, 3.6 * nlayers)
  height <- max(6, 0.55 * maxn + 2)
  p <- ggplot2::ggplot() +
    ggplot2::geom_segment(data = ed, ggplot2::aes(x = x, y = y, xend = x_to, yend = y_to),
                          color = "gray60", linewidth = 0.4,
                          arrow = grid::arrow(length = grid::unit(2.5, "mm"), type = "closed")) +
    ggplot2::geom_label(data = nd, ggplot2::aes(x = x, y = y, label = text, fill = type),
                        size = label_size, label.padding = grid::unit(0.25, "lines")) +
    ggplot2::scale_fill_manual(values = c("this group's input" = "#d9ead3",
                                          "shared decision input" = "#eeeeee",
                                          "physical consequence" = "#cfe2f3",
                                          "outcome value" = "#fce5cd"), name = NULL) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(add = 0.9)) +
    ggplot2::labs(title = s$label,
                  subtitle = paste0("Decision: separated carriage-road path, Camden to the Snow Bowl",
                                    if (simplify) " (shared inputs hidden; full version in *_full files)" else "")) +
    ggplot2::theme_void(base_size = 14) +
    ggplot2::theme(legend.position = "bottom", legend.text = ggplot2::element_text(size = 12),
                   plot.title = ggplot2::element_text(face = "bold", size = 18),
                   plot.margin = ggplot2::margin(10, 10, 10, 10))
  attr(p, "size") <- c(width, height)
  p
}
