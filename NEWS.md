# mlr3hyperband 0.6.0

* compatibility; Work with new bbotk 1.0.0 and mlr3tuning 1.0.0

# mlr3hyperband 0.5.0

* compatibility: Work with new paradox version 1.0.0

# mlr3hyperband 0.4.5

* fix: Unloading `mlr3hyperband` removes optimizers and tuners from the dictionaries.
* docs: Update resources and descriptions.
* tests: Remove deprecated `method` argument of `mlr3tuning::tune()`.

# mlr3hyperband 0.4.4

* fix: Remove `emoa` from required packages of `OptimizerBatchSuccessiveHalving`.

# mlr3hyperband 0.4.3

* docs: Examples use `branin_wu()` function now.

# mlr3hyperband 0.4.2

* docs: Re-generate rd files with valid html.

# mlr3hyperband 0.4.1

* feat: `Optimizer` and `Tuner` objects have the field `$id` now.
* feat: `Optimizer` and `Tuner` objects have the optional field `$label` now.
* feat: New `$help()` method which opens the manual page of `Optimizer` and `Tuner` objects.

# mlr3hyperband 0.4.0

* feat: New `adjust_minimum_budget` flag in  `OptimizerBatchSuccessiveHalving`. The
  minimum budget is adjusted in the base stage to use the maximum budget in last
  stage.
* feat: New `repetitions` parameter to specify the exact number of repetitions.
  Replaced the `repeats` parameter.

# mlr3hyperband 0.3.0

* feat: `TunerBatchHyperband` evaluates configurations of same budget across
  brackets in parallel now.
* feat: New `repeats` parameter to repeat runs of successive halving and
  hyperband until termination.
* fix: Bug where maximization measures were minimized.

# mlr3hyperband 0.2.0

* feat: New `OptimizerBatchHyperband` and `OptimizerBatchSuccessiveHalving` optimizers.

# mlr3hyperband 0.1.2

* refactor: Make XGBoost conditionally in examples.

# mlr3hyperband 0.1.1

* fix: Dependency on `emoa`.

# mlr3hyperband 0.1.0

* Initial CRAN release.
