# Combined Monte Carlo model ----------------------------------------------------
# Output names: <stakeholder>__<value>__<option>

build_input_table <- function(stakeholders) {
  tbl <- rbind(shared_inputs, do.call(rbind, lapply(stakeholders, `[[`, "inputs")),
               xr_inputs(stakeholders))
  stopifnot(!anyDuplicated(tbl$variable))
  tbl
}

make_decision_function <- function(stakeholders, liability = "protected") {
  force(stakeholders); force(liability)
  one_run <- function(p) {
    out <- list()
    for (opt in options_tbl$option) {
      d <- physical_delta(p, opt, liability = liability)
      for (s in stakeholders) {
        v <- s$outcomes(p, d)
        for (nm in names(v)) out[[paste(s$id, nm, opt, sep = "__")]] <- unname(v[[nm]])
      }
    }
    out
  }
  # mcSimulation (data.frameNames syntax) passes the whole sample as a data.frame
  function(x, ...) {
    x <- as.data.frame(x)
    runs <- lapply(seq_len(nrow(x)), function(i) one_run(as.list(x[i, , drop = FALSE])))
    as.data.frame(do.call(rbind, lapply(runs, unlist)))
  }
}

run_mc <- function(stakeholders, n = 5000, seed = 42, liability = "protected") {
  set.seed(seed)
  tbl <- build_input_table(stakeholders)
  decisionSupport::mcSimulation(
    estimate = decisionSupport::as.estimate(tbl),
    model_function = make_decision_function(stakeholders, liability),
    numberOfModelRuns = n
  )
}
