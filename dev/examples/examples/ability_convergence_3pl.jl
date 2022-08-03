using Makie
import Pkg
import Random
using Distributions: Normal, cdf
using AlgebraOfGraphics
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic
using ComputerAdaptiveTesting.Sim: auto_responder
using ComputerAdaptiveTesting.NextItemRules: AbilityVarianceStateCriterion
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator, MeanAbilityEstimator, LikelihoodAbilityEstimator
using ComputerAdaptiveTesting.ItemBanks
using ComputerAdaptiveTesting.Integrators
import ComputerAdaptiveTesting.IntegralCoeffs
using CATPlots

@automakie()

using ComputerAdaptiveTesting.DummyData: dummy_3pl, std_normal
Random.seed!(42)
(item_bank, question_labels, abilities, responses) = dummy_3pl(;num_questions=100, num_testees=3)

max_questions = 99
integrator = FixedGKIntegrator(-6, 6, 80)
dist_ability_est = PriorAbilityEstimator(std_normal)
ability_estimator = MeanAbilityEstimator(dist_ability_est, integrator)
rules = CatRules(
    ability_estimator,
    AbilityVarianceStateCriterion(dist_ability_est, integrator),
    FixedItemsTerminationCondition(max_questions)
)

points = 500
xs = range(-2.5, 2.5, length=points)
raw_estimator = LikelihoodAbilityEstimator()
recorder = CatRecorder(xs, responses, integrator, raw_estimator, ability_estimator)
for testee_idx in axes(responses, 2)
    tracked_responses, θ = run_cat(
        CatLoopConfig(
            rules=rules,
            get_response=auto_responder(@view responses[:, testee_idx]),
            new_response_callback=(tracked_responses, terminating) -> recorder(tracked_responses, testee_idx, terminating),
        ),
        item_bank
    )
    true_θ = abilities[testee_idx]
    abs_err = abs(θ - true_θ)
end

conv_lines_fig = ability_evolution_lines(recorder; abilities=abilities)
conv_lines_fig

conv_dist_fig = lh_evolution_interactive(recorder; abilities=abilities)
conv_dist_fig

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
