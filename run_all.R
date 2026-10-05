# Run the whole pipeline: validate DAGs, write input tables, draw DAGs, then for each
# liability scenario (protected / exposed, see physical_delta) run the Monte Carlo, the
# Pareto views and the agent game, and finally compare the scenarios.
# Usage (from this folder):  Rscript run_all.R [n_runs]

args <- commandArgs(trailingOnly = TRUE)
n_runs <- if (length(args)) as.integer(args[1]) else 5000

suppressPackageStartupMessages({
  library(decisionSupport); library(dagitty); library(ggplot2)
})
for (f in list.files("R", full.names = TRUE)) source(f)

stakeholders <- load_stakeholders("stakeholders")
mid_p <- mid_inputs(build_input_table(stakeholders))

# 1. DAG / inputs / outcomes coherence ------------------------------------------
problems <- lapply(stakeholders, validate_stakeholder, shared_inputs = shared_inputs, mid_p = mid_p)
problems <- Filter(length, problems)
if (length(problems)) {
  for (n in names(problems)) message("[", n, "] ", paste(problems[[n]], collapse = "; "))
  stop("Validation failed")
}
message("Validated ", length(stakeholders), " stakeholder ontologies.")

# 2. Input tables ------------------------------------------------------------------
dir.create("inputs", showWarnings = FALSE)
write.csv(shared_inputs, "inputs/shared_inputs.csv", row.names = FALSE)
for (s in stakeholders) write.csv(s$inputs, file.path("inputs", paste0(s$id, "_inputs.csv")), row.names = FALSE)
write.csv(build_input_table(stakeholders), "inputs/all_inputs.csv", row.names = FALSE)

# 3. DAG pictures -------------------------------------------------------------------
dir.create("outputs/dags", recursive = TRUE, showWarnings = FALSE)
for (s in stakeholders) {
  for (simple in c(TRUE, FALSE)) {
    p <- plot_dag(s, shared_inputs, simplify = simple)
    sz <- attr(p, "size")
    base <- file.path("outputs/dags", paste0(s$id, if (!simple) "_full"))
    ggsave(paste0(base, ".png"), p, width = sz[1], height = sz[2], dpi = 150, bg = "white")
    ggsave(paste0(base, ".pdf"), p, width = sz[1], height = sz[2], bg = "white")  # vector: zoom freely
  }
}

# 4. One full analysis per liability scenario -----------------------------------------------
run_scenario <- function(liability) {
  out <- file.path("outputs", paste0("liability_", liability))
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  message("== Liability scenario: ", liability)

  # Monte Carlo and Keeney bubble matrix
  mc <- run_mc(stakeholders, n = n_runs, liability = liability)
  summ <- summarize_mc(mc, stakeholders)
  write.csv(summ, file.path(out, "value_summary.csv"), row.names = FALSE)
  saveRDS(mc, file.path(out, "mc_results.rds"))
  ggsave(file.path(out, "keeney_bubble_matrix.png"), bubble_matrix(summ, stakeholders),
         width = 15, height = 15, dpi = 130, bg = "white")

  # Stage 1 welfare / Pareto view, on the unit-free index and on within-group NPV
  idx <- welfare_indices(mc, summ, stakeholders)
  psum <- pareto_summary(idx)
  write.csv(psum, file.path(out, "pareto_summary.csv"), row.names = FALSE)
  ggsave(file.path(out, "welfare_heatmap.png"), welfare_heatmap(idx, stakeholders, psum),
         width = 12, height = 6, dpi = 130, bg = "white")
  ggsave(file.path(out, "pareto_landowners_vs_others.png"), pareto_plot(idx, "landowners", psum),
         width = 8, height = 6, dpi = 130, bg = "white")
  npv <- welfare_npv(mc, stakeholders)
  psum_npv <- pareto_summary(npv)
  write.csv(psum_npv, file.path(out, "pareto_summary_npv.csv"), row.names = FALSE)
  ggsave(file.path(out, "welfare_heatmap_npv.png"), welfare_heatmap(npv, stakeholders, psum_npv, "npv"),
         width = 12, height = 6, dpi = 130, bg = "white")
  ggsave(file.path(out, "pareto_landowners_vs_others_npv.png"), pareto_plot(npv, "landowners", psum_npv, "npv"),
         width = 8, height = 6, dpi = 130, bg = "white")

  # Stage 2: agent game, under each mechanism (voluntary contributions vs binding cost-sharing)
  n_game <- min(n_runs, 1500)                     # the game re-evaluates 22 configurations
  mc_g <- list(x = mc$x[seq_len(n_game), ])
  cfgs <- all_configs()
  cidx <- config_indices(mc_g, summ, stakeholders, cfgs, liability)
  sens_all <- list()
  for (mech in c("voluntary", "binding")) {
    bind <- mech == "binding"
    res <- game_analysis(cidx, w_town = 0.5, binding = bind)
    pre <- paste0("game_", mech, "_")
    write.csv(res$table, file.path(out, paste0(pre, "profiles.csv")), row.names = FALSE)
    write.csv(res$outcomes, file.path(out, paste0(pre, "outcomes.csv")), row.names = FALSE)
    write.csv(res$spe_orders, file.path(out, paste0(pre, "sequential_orders.csv")), row.names = FALSE)
    welf <- do.call(rbind, lapply(res$table$profile, function(pr)
      data.frame(profile = pr, as.list(profile_welfare(cidx, pr, bind)))))
    write.csv(welf, file.path(out, paste0(pre, "profile_welfare_all_groups.csv")), row.names = FALSE)
    sens_all[[mech]] <- do.call(rbind, lapply(c(0, 0.25, 0.5, 1, 2), function(w) {
      r <- game_analysis(cidx, w_town = w, binding = bind)
      o <- r$outcomes
      data.frame(mechanism = mech, w_town_on_residents = w,
                 prob_status_quo_stable = r$status_quo_ne_prob, prob_path_stable = r$path_ne_prob,
                 stable_at_mean = paste(o$label[o$nash_at_mean], collapse = " | "),
                 most_likely_stable = o$label[1], prob_of_that = o$nash_prob[1],
                 sequential_town_first = outcome_label(r$spe_orders$outcome[1]))
    }))
    ggsave(file.path(out, paste0(pre, "nash_probability.png")), plot_nash_probability(res),
           width = 10, height = 6, dpi = 130, bg = "white")
    rep_profile <- function(keys) vapply(keys, function(k) res$table$profile[res$table$outcome == k][1], "")
    show <- unique(c(rep_profile("status_quo"), rep_profile(res$outcomes$outcome[res$outcomes$nash_at_mean]),
                     rep_profile(res$outcomes$outcome[1:3])))
    ggsave(file.path(out, paste0(pre, "equilibrium_welfare.png")),
           plot_equilibrium_welfare(cidx, show, stakeholders, 0.5, bind),
           width = 3 + 1.4 * length(show), height = 6, dpi = 130, bg = "white")
  }
  sens_all <- do.call(rbind, sens_all)
  write.csv(sens_all, file.path(out, "game_mechanism_comparison.csv"), row.names = FALSE)

  # Design of the binding agreement: which terms leave all four players better off?
  grid <- mechanism_grid(mc, summ, stakeholders, liability, n = 400)
  write.csv(grid, file.path(out, "mechanism_design_grid.csv"), row.names = FALSE)
  ggsave(file.path(out, "mechanism_design_grid.png"), plot_mechanism_grid(grid),
         width = 11, height = 5, dpi = 130, bg = "white")

  list(liability = liability, summ = summ, psum = psum, psum_npv = psum_npv, npv = npv,
       sens = sens_all, grid = grid)
}

scenarios <- setNames(lapply(c("protected", "exposed"), run_scenario), c("protected", "exposed"))

# 5. Compare the liability scenarios --------------------------------------------------------
compare_liability(scenarios, stakeholders, "outputs")
message("Done. See outputs/liability_protected, outputs/liability_exposed and outputs/liability_comparison.*")
