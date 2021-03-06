#' @title Tuner using the Hyperband algorithm
#'
#' @name mlr_tuners_hyperband
#'
#' @description
#' `TunerHyperband` class that implements hyperband tuning. Hyperband is a
#' budget oriented-procedure, weeding out suboptimal performing configurations
#' early in a sequential training process, increasing tuning efficiency as a
#' consequence.
#'
#' For this, several brackets are constructed with an associated set of
#' configurations for each bracket. Each bracket as several stages. Different
#' brackets are initialized with different amounts of configurations and
#' different budget sizes. To get an idea of how the bracket layout looks like
#' for a given argument set, please have a look in the `details`.
#'
#' To identify the budget for evaluating hyperband, the user has to specify
#' explicitly which hyperparameter of the learner influences the budget by
#' tagging a single hyperparameter in the [paradox::ParamSet] with `"budget"`.
#' An alternative approach using subsampling and pipelines is described below.
#'
#' Naturally, hyperband terminates once all of its brackets are evaluated, so a
#' [bbotk::Terminator] in the tuning instance acts as an upper bound and should
#' be only set to a low value if one is unsure of how long hyperband will take
#' to finish under the given settings.
#'
#' @section Parameters:
#' \describe{
#' \item{`eta`}{`numeric(1)`\cr
#' Fraction parameter of the successive halving algorithm: With every step the
#' configuration budget is increased by a factor of `eta` and only the best
#' `1/eta` configurations are used for the next stage. Non-integer values are
#' supported, but `eta` is not allowed to be less or equal 1.}
#' \item{`sampler`}{[paradox::Sampler]\cr
#' Object defining how the samples of the parameter space should be drawn during
#' the initialization of each bracket. The default is uniform sampling.}
#' }
#'
#' @section Archive:
#' The [mlr3tuning::ArchiveTuning] holds the following additional columns that
#' are specific to the hyperband tuner:
#'   * `bracket` (`integer(1)`)\cr
#'     The console logs about the bracket index are actually not matching
#'     with the original hyperband algorithm, which counts down the brackets
#'     and stops after evaluating bracket 0. The true bracket indices are
#'     given in this column.
#'   * `bracket_stage` (`integer(1))`\cr
#'     The bracket stage of each bracket. Hyperband starts counting at 0.
#'   * `budget_scaled` (`numeric(1)`)\cr
#'     The intermediate budget in each bracket stage calculated by hyperband.
#'     Because hyperband is originally only considered for budgets starting at 1, some
#'     rescaling is done to allow budgets starting at different values.
#'     For this, budgets are internally divided by the lower budget bound to
#'     get a lower budget of 1. Before the learner
#'     receives its budgets for evaluation, the budget is transformed back to
#'     match the original scale again.
#'   * `budget_real` (`numeric(1)`)\cr
#'     The real budget values the learner uses for evaluation after hyperband
#'     calculated its scaled budget.
#'   * `n_configs` (`integer(1)`)\cr
#'     The amount of evaluated configurations in each stage. These correspond
#'     to the `r_i` in the original paper.
#'
#' @section Hyperband without learner budget:
#' Thanks to \CRANpkg{mlr3pipelines}, it is possible to use hyperband in
#' combination with learners lacking a natural budget parameter. For example,
#' any [mlr3::Learner] can be augmented with a [mlr3pipelines::PipeOp]
#' operator such as [mlr3pipelines::PipeOpSubsample]. With the
#' subsampling rate as budget parameter, the resulting
#' [mlr3pipelines::GraphLearner] is fitted on small proportions of
#' the [mlr3::Task] in the first brackets, and on the complete Task in
#' last brackets. See examples for some code.
#'
#' @section Custom sampler:
#' Hyperband supports custom [paradox::Sampler] object for initial
#' configurations in each bracket.
#' A custom sampler may look like this (the full example is given in the
#' `examples` section):
#' ```
#' # - beta distribution with alpha = 2 and beta = 5
#' # - categorical distribution with custom probabilities
#' sampler = SamplerJointIndep$new(list(
#'   Sampler1DRfun$new(params[[2]], function(n) rbeta(n, 2, 5)),
#'   Sampler1DCateg$new(params[[3]], prob = c(0.2, 0.3, 0.5))
#' ))
#' ```
#'
#' @section Runtime scaling w.r.t. the chosen budget:
#' The calculation of each bracket currently assumes a linear runtime in the
#' chosen budget parameter is always given. Hyperband is designed so each
#' bracket requires approximately the same runtime as the sum of the budget
#' over all configurations in each bracket is roughly the same. This will not
#' hold true once the scaling in the budget parameter is not linear
#' anymore, even though the sum of the budgets in each bracket remains the
#' same. A basic example can be viewed by calling the function
#' `hyperband_brackets` below with the arguments `R = 2` and `eta = 2`. If we
#' run a learner with O(budget^2) time complexity, the runtime of the last
#' bracket will be 33% longer than the first bracket
#' (time of bracket 1 = 2 * 1^2 + 2^2 = 6; time of bracket 2 = 2 * 2^2 = 8).
#' Of course, this won't break anything, but it should be kept in mind when
#' applying hyperband. A possible adaption would be to introduce a trafo,
#' like it is shown in the `examples`.
#'
#' @details
#' This sections explains the calculation of the constants for each bracket.
#' A small overview will be given here, but for more details please check
#' out the original paper (see `references`).
#' To keep things uniform with the notation in the paper (and to safe space in
#' the formulas), `R` is used for the upper budget that last remaining
#' configuration should reach. The formula to calculate the amount of brackets
#' is `floor(log(R, eta)) + 1`. To calculate the starting budget in each
#' bracket, use `R * eta^(-s)`, where `s` is the maximum bracket minus the
#' current bracket index.
#' For the starting configurations in each bracket it is
#' `ceiling((B/R) * ((eta^s)/(s+1)))`, with `B = (bracket amount) * R`.
#' To receive a table with the full brackets layout, load the following function
#' and execute it for the desired `R` and `eta`.
#'
#' ```
#' hyperband_brackets = function(R, eta) {
#'
#'   result = data.frame()
#'   smax = floor(log(R, eta))
#'   B = (smax + 1) * R
#'
#'   # outer loop - iterate over brackets
#'   for (s in smax:0) {
#'
#'     n = ceiling((B/R) * ((eta^s)/(s+1)))
#'     r = R * eta^(-s)
#'
#'     # inner loop - iterate over bracket stages
#'     for (i in 0:s) {
#'
#'       ni = floor(n * eta^(-i))
#'       ri = r * eta^i
#'       result = rbind(result, c(smax - s + 1, i + 1, ri, ni))
#'     }
#'   }
#'
#'   names(result) = c("bracket", "bracket_stage", "budget", "n_configs")
#'   return(result)
#' }
#'
#' hyperband_brackets(R = 81L, eta = 3L)
#' ```
#'
#' @section Logging:
#' When loading the [mlr3hyperband] package, two loggers based on the [lgr]
#' package are made available. One is called `mlr3`, the other `bbotk`. All
#' `mlr3` methods log into the `mlr3` logger. All optimization methods form the
#' packags [bbotk], [mlr3tuning] and [mlr3hyperband] log into the `bbotk`
#' logger. To hide the [mlr3] logging messages run:
#'
#' ```
#' lgr::get_logger("mlr3")$set_threshold("warn")
#' ```
#'
#' @source
#' `r format_bib("li_2018")`
#'
#' @export
#' @examples
#' if(requireNamespace("xgboost")) {
#' library(mlr3)
#' library(mlr3learners)
#' library(paradox)
#' library(mlr3tuning)
#' library(mlr3hyperband)
#'
#' # Define hyperparameter and budget parameter for tuning with hyperband
#' ps = ParamSet$new(list(
#'   ParamInt$new("nrounds", lower = 1, upper = 4, tag = "budget"),
#'   ParamDbl$new("eta", lower = 0, upper = 1),
#'   ParamFct$new("booster", levels = c("gbtree", "gblinear", "dart"))
#' ))
#'
#' # Define termination criterion
#' # Hyperband terminates itself
#' terminator = trm("none")
#'
#' # Create tuning instance
#' inst = TuningInstanceSingleCrit$new(
#'   task = tsk("iris"),
#'   learner = lrn("classif.xgboost"),
#'   resampling = rsmp("holdout"),
#'   measure = msr("classif.ce"),
#'   search_space = ps,
#'   terminator = terminator,
#' )
#'
#' # Load tuner
#' tuner = tnr("hyperband", eta = 2L)
#'
#' \donttest{
#' # Trigger optimization
#' tuner$optimize(inst)
#'
#' # Print all evaluations
#' as.data.table(inst$archive)}
#' }
TunerHyperband = R6Class("TunerHyperband",
  inherit = Tuner,
  public = list(

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function() {
      ps = ParamSet$new(list(
        ParamDbl$new("eta", lower = 1.0001, tags = "required", default = 2),
        ParamUty$new("sampler",
          custom_check = function(x) check_r6(x, "Sampler", null.ok = TRUE))
      ))
      ps$values = list(eta = 2, sampler = NULL)

      super$initialize(
        param_classes = c("ParamLgl", "ParamInt", "ParamDbl", "ParamFct"),
        param_set = ps,
        properties = c("dependencies", "single-crit", "multi-crit"),
        packages = character(0)
      )
    }
  ),

  private = list(
    .optimize = function(inst) {
      eta = self$param_set$values$eta
      sampler = self$param_set$values$sampler
      ps = inst$search_space
      measures = inst$objective$measures
      msr_ids = ids(measures)
      to_minimize = map_lgl(measures, "minimize")

      if (length(msr_ids) > 1) {
        require_namespaces("emoa")
      }

      # name of the hyperparameters with a budget tag
      budget_id = ps$ids(tags = "budget")
      # check if we have EXACTLY 1 budget parameter, or else throw an informative error
      if (length(budget_id) != 1) {
        stopf("Exactly one hyperparameter must be tagged with 'budget'")
      }

      # budget parameter MUST be defined as integer or double in paradox
      assert_choice(ps$class[[budget_id]], c("ParamInt", "ParamDbl"))
      ps_sampler = ps$clone()$subset(setdiff(ps$ids(), budget_id))

      # construct unif sampler if non is given
      if (is.null(sampler)) {
        sampler = SamplerUnif$new(ps_sampler)
      } else {
        assert_set_equal(sampler$param_set$ids(), ps_sampler$ids())
      }

      # use parameter tagged with 'budget' as budget for hyperband
      budget_lower = ps$lower[[budget_id]]
      budget_upper = ps$upper[[budget_id]]

      # we need the budget to start with a SMALL NONNEGATIVE value
      assert_number(budget_lower, lower = 1e-8)

      # rescale config max budget (:= 'R' in the original paper)
      # this represents the maximum budget a single configuration
      # will run for in the last stage of each bracket
      config_max_b = budget_upper / budget_lower

      # cannot use config_max_b due to stability reasons
      bracket_max = floor(log(budget_upper, eta) - log(budget_lower, eta))
      # <=> eta^bracket_max = config_max_b
      lg$info(
        "Amount of brackets to be evaluated = %i, ",
        bracket_max + 1)

      # 'B' is approximately the used budget of an entire bracket.
      # The reference states a single execution of hyperband uses (smax+1) * B
      # amount of budget, and with (smax+1) as the amount of brackets follows
      # the claim. (smax is 'bracket_max' here)
      B = (bracket_max + 1L) * config_max_b

      # outer loop - iterating over brackets
      for (bracket in seq(bracket_max, 0)) {

        # for less confusion of the user we start the print with bracket 1
        lg$info("Start evaluation of bracket %i", bracket_max - bracket + 1)

        # amount of active configs and budget in bracket
        mu_start = mu_current =
          ceiling((B * eta^bracket) / (config_max_b * (bracket + 1)))

        budget_start = budget_current = config_max_b / eta^bracket

        # generate design based on given parameter set and sampler
        active_configs = sampler$sample(mu_current)$data

        # inner loop - iterating over bracket stages
        for (stage in seq(0, bracket)) {

          # amount of configs of the previous stage
          mu_previous = mu_current

          # make configs smaller, increase budget and increment stage counter
          mu_current = floor(mu_start / eta^stage)
          budget_current = budget_start * eta^stage

          # rescale budget back to real world scale
          budget_current_real = budget_current * budget_lower
          # round if the budget is an integer parameter
          if (ps$class[[budget_id]] == "ParamInt") {
            budget_current_real = round(budget_current_real)
          }

          lg$info("Training %i configs with budget of %g for each",
            mu_current, budget_current_real)

          # only rank and pick configurations if we are not in the first stage
          if (stage > 0) {

            # get performance of each active configuration
            configs_perf = inst$archive$data[, msr_ids, with = FALSE]
            n_rows = nrow(configs_perf)
            configs_perf = configs_perf[(n_rows - mu_previous + 1):n_rows]

            # select best mu_current indices
            if (length(msr_ids) < 2) {

              # single crit
              ordered_perf = order(configs_perf[[msr_ids]],
                decreasing = !to_minimize)
              best_indices = ordered_perf[seq_len(mu_current)]

            } else {

              # multi crit
              best_indices = nds_selection(
                points = t(as.matrix(configs_perf[, msr_ids, with = FALSE])),
                n_select = mu_current, minimize = to_minimize)
            }

            # update active configurations
            assert_integer(best_indices, lower = 1,
              upper = nrow(active_configs))
            active_configs = active_configs[best_indices]
          }

          # overwrite active configurations with the current budget
          active_configs[[budget_id]] = budget_current_real

          # extend active_configs with extras
          xdt = cbind(active_configs,
            bracket = bracket, # recycling puts this info in each column, ie for each x value we have the same hyperband info
            bracket_stage = stage,
            budget_scaled = budget_current,
            budget_real = budget_current_real,
            n_configs = mu_current
          )

          inst$eval_batch(xdt)
        }
      }
    }
  )
)
