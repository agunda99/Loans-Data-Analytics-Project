-- Recorded collection actions and outcomes.
-- This measures operational activity, not causal recovery attribution.
SELECT
    action_date,
    action_type,
    COALESCE(outcome, 'unknown') AS outcome,
    COUNT(*) AS action_count,
    COUNT(DISTINCT loan_id) AS loans_contacted,
    COUNT(DISTINCT agent) AS active_agents,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE outcome IN ('promise_to_pay', 'paid'))
        / NULLIF(COUNT(*), 0),
        2
    ) AS positive_outcome_pct
FROM collections_actions
GROUP BY action_date, action_type, COALESCE(outcome, 'unknown')
ORDER BY action_date, action_type, outcome;

-- Outcome mix by action type for the selected reporting period.
SELECT
    action_type,
    COUNT(*) AS total_actions,
    COUNT(*) FILTER (WHERE outcome = 'paid') AS recorded_paid_outcomes,
    COUNT(*) FILTER (WHERE outcome = 'promise_to_pay') AS promises_to_pay,
    COUNT(*) FILTER (WHERE outcome = 'no_answer') AS no_answers,
    COUNT(*) FILTER (WHERE outcome = 'escalated') AS escalations,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE outcome = 'paid')
        / NULLIF(COUNT(*), 0),
        2
    ) AS recorded_paid_outcome_pct
FROM collections_actions
WHERE action_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY action_type
ORDER BY total_actions DESC;
