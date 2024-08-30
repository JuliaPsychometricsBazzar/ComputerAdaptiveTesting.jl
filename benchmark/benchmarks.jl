using BenchmarkTools
using AirspeedVelocity
using ComputerAdaptiveTesting
using Random: Xoshiro
using StatsBase: sample
using FittedItemBanks
using FittedItemBanks.DummyData: dummy_full, SimpleItemBankSpec, StdModel4PL
using ComputerAdaptiveTesting.Aggregators
using PsychometricsBazaarBase.Optimizers
using PsychometricsBazaarBase.Integrators: even_grid
using ComputerAdaptiveTesting.NextItemRules: mirtcat_quadpts
using ComputerAdaptiveTesting.NextItemRules: DistributionExpectationBasedItemCriterion,
                                             PointExpectationBasedItemCriterion
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.Responses

const SUITE = BenchmarkGroup()

SUITE["next_item_rules"] = BenchmarkGroup()

#prepare_0(ability_estimator)
function prepare_4pls(group)
    rng = Xoshiro(42)
    (; item_bank, abilities, responses) = dummy_full(
        rng,
        SimpleItemBankSpec(StdModel4PL(), OneDimContinuousDomain(), BooleanResponse());
        num_questions = 20,
        num_testees = 1
    )
    integrator = even_grid(-6.0, 6.0, mirtcat_quadpts(1))
    optimizer = AbilityOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead()))

    dist_ability_estimator = PriorAbilityEstimator()
    ability_estimators = [
        ("mean", MeanAbilityEstimator(dist_ability_estimator, integrator)),
        ("mode", ModeAbilityEstimator(dist_ability_estimator, optimizer))
    ]
    response_idxs = sample(rng, 1:20, 10)

    for (est_nick, ability_estimator) in ability_estimators
        next_item_rule = ItemStrategyNextItemRule(
            ExhaustiveSearch1Ply(),
            PointExpectationBasedItemCriterion(ability_estimator,
                AbilityVarianceStateCriterion(
                    integrator, distribution_estimator(ability_estimator)))
        )
        next_item_rule = preallocate(next_item_rule)
        tracked_responses = TrackedResponses(BareResponses(ResponseType(item_bank)),
            item_bank,
            NullAbilityTracker())
        group["$(est_nick)_point_mepv_bare"] = @benchmarkable ($next_item_rule)(
            $tracked_responses, $item_bank)
        bare_responses = BareResponses(
            ResponseType(item_bank),
            response_idxs,
            # XXX: Not sure why this is needed (seems to not be needed else)
            collect(responses[response_idxs, 1])
        )
        tracked_responses = TrackedResponses(
            bare_responses,
            item_bank,
            NullAbilityTracker())
        group["$(est_nick)_point_mepv_10"] = @benchmarkable ($next_item_rule)(
            $tracked_responses, $item_bank)
    end
    return group
end

SUITE["next_item_rules"]["4pl"] = prepare_4pls(BenchmarkGroup())
