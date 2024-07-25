module CatConfig

export CatRules, CatLoopConfig

using DocStringExtensions

using PsychometricsBazaarBase.Parameters

using ..Aggregators: AbilityEstimator, AbilityTracker, ConsAbilityTracker,
                     NullAbilityTracker
using ..NextItemRules: NextItemRule
using ..TerminationConditions: TerminationCondition
using ..ConfigBase

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Configuration of the rules for a CAT. This all includes all the basic rules for
the CAT's operation, but not the item bank, nor any of the interactivity hooks
needed to actually run the CAT.

This may be more a more convenient layer to integrate than CatLoopConfig if you
want to write your own CAT loop rather than using hooks.

    $(FUNCTIONNAME)(; next_item=..., termination_condition=..., ability_estimator=..., ability_tracker=...)

Explicit constructor for $(FUNCTIONNAME).

    $(FUNCTIONNAME)(bits...)

Implicit constructor for $(FUNCTIONNAME).
"""
@kw_only struct CatRules{
    NextItemRuleT <: NextItemRule,
    TerminationConditionT <: TerminationCondition,
    AbilityEstimatorT <: AbilityEstimator,
    AbilityTrackerT <: AbilityTracker
} <: CatConfigBase
    """
    The rule to choose the next item in the CAT given the current state.
    """
    next_item::NextItemRuleT
    """
    The rule to choose when to terminate the CAT.
    """
    termination_condition::TerminationConditionT
    """
    The ability estimator, which estimates the testee's current ability.
    """
    ability_estimator::AbilityEstimatorT
    """
    The ability tracker, which tracks the testee's current ability level.
    """
    ability_tracker::AbilityTrackerT = NullAbilityTracker()
end

function item_bank_type(bits...)
    find1_instance(bits...)
end

function _find_ability_estimator_and_tracker(bits...)
    ability_estimator = AbilityEstimator(bits...)
    ability_tracker = AbilityTracker(bits...; ability_estimator = ability_estimator)
    (ability_estimator, ability_tracker)
end

function collect_trackers(_)
    return NullAbilityTracker()
end

function collect_trackers(tracker::AbilityTracker)
    return tracker
end

function collect_trackers(config::CatConfigBase)
    acc = NullAbilityTracker()
    for fieldname in fieldnames(typeof(config))
        tracker = collect_trackers(getfield(config, fieldname))
        if !(tracker isa NullAbilityTracker)
            acc = ConsAbilityTracker(tracker, acc)
        end
    end
    return acc
end

function collect_trackers(next_item_rule::NextItemRule, ability_tracker::AbilityTracker)
    rest = collect_trackers(next_item_rule)
    if !(ability_tracker isa NullAbilityTracker)
        ConsAbilityTracker(ability_tracker, rest)
    else
        rest
    end
end

function CatRules(bits...)
    ability_estimator, ability_tracker = _find_ability_estimator_and_tracker(bits...)
    if ability_estimator === nothing
        error("Could not find an ability estimator in $(bits)")
    end
    if ability_tracker === nothing
        error("Could not find an ability tracker in $(bits)")
    end
    next_item = NextItemRule(bits...,
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    if next_item === nothing
        error("Could not find a next item rule in $(bits)")
    end
    termination_condition = TerminationCondition(bits...)
    if termination_condition === nothing
        error("Could not find a termination condition in $(bits)")
    end
    CatRules(;
        next_item = next_item,
        termination_condition = termination_condition,
        ability_estimator = ability_estimator,
        ability_tracker = collect_trackers(next_item, ability_tracker))
end

"""
Configuration for a simulatable CAT.
"""
@with_kw struct CatLoopConfig{CatEngineT} <: CatConfigBase
    """
    The CAT configuration.
    """
    rules::CatEngineT # e.g. CatRules
    """
    The function (index, label) -> Int8 which obtains the testee's response for
    a given question, e.g. by prompting or simulation from data.
    """
    get_response::Any
    """
    A callback called each time there is a new responses
    """
    new_response_callback = nothing
end

end
