-- Project: Service Operations & Response-Time Analytics
-- Step 4: Analyze 2025-created DOT service requests.
-- Statuses reflect the downloaded snapshot, not year-end 2025.
-- Closure metrics include only eligible Closed requests.
-- These queries only read data.

-- 1. Headline counts and closure-time metrics.
-- Reconcile status counts with the total before publishing.
SELECT
    COUNT(*) AS total_requests,
    COUNT(*) FILTER (
        WHERE status = 'Closed'
    ) AS closed_requests,
    COUNT(*) FILTER (
        WHERE status IN ('Pending', 'Assigned', 'Open', 'In Progress')
    ) AS unfinished_requests,
    COUNT(*) FILTER (
        WHERE status = 'Unspecified'
    ) AS unspecified_requests,
    COUNT(*) FILTER (
        WHERE valid_for_closure_time
    ) AS eligible_closure_records,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (closed_at - created_at)) / 86400)
            FILTER (WHERE valid_for_closure_time),
        2
    ) AS average_closure_days,
    ROUND(
        (PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (closed_at - created_at)) / 86400
        ) FILTER (WHERE valid_for_closure_time))::numeric,
        2
    ) AS median_closure_days,
    ROUND(
        (PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (closed_at - created_at)) / 86400
        ) FILTER (WHERE valid_for_closure_time))::numeric,
        2
    ) AS p90_closure_days
FROM public.requests_clean;


-- 2. Monthly incoming volume and month-over-month change.
-- January has no prior month in this dataset.
WITH monthly_volume AS (
    SELECT
        DATE_TRUNC('month', created_at)::date AS created_month,
        COUNT(*) AS total_requests
    FROM public.requests_clean
    GROUP BY DATE_TRUNC('month', created_at)::date
),
monthly_comparison AS (
    SELECT
        created_month,
        total_requests,
        LAG(total_requests) OVER (
            ORDER BY created_month
        ) AS previous_month_requests
    FROM monthly_volume
)
SELECT
    created_month,
    total_requests,
    previous_month_requests,
    ROUND(
        100.0 * (total_requests - previous_month_requests)
        / NULLIF(previous_month_requests, 0),
        2
    ) AS monthly_change_pct
FROM monthly_comparison
ORDER BY created_month;


-- 3. Closure times by category.
-- Consider sample sizes and differences in work requirements.
SELECT
    problem,
    COUNT(*) AS eligible_closed_requests,
    ROUND(
        (PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (closed_at - created_at)) / 86400
        ))::numeric,
        2
    ) AS median_closure_days
FROM public.requests_clean
WHERE valid_for_closure_time
GROUP BY problem
ORDER BY median_closure_days DESC;


5


-- 5. Detailed Street Condition categories in Queens.
-- Join by the request ID, verified as unique during quality checks.
SELECT
    COALESCE(NULLIF(TRIM(r.problem_detail), ''), 'Not provided')
        AS problem_detail,
    COUNT(*) AS total_requests,
    COUNT(*) FILTER (
        WHERE c.status IN ('Pending', 'Assigned', 'Open', 'In Progress')
    ) AS unfinished_requests,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE c.status IN ('Pending', 'Assigned', 'Open', 'In Progress')
        ) / COUNT(*),
        2
    ) AS unfinished_pct
FROM public.requests_clean AS c
JOIN public.requests_raw AS r
    ON c.unique_key = r.unique_key
WHERE c.problem = 'Street Condition'
    AND c.borough = 'QUEENS'
GROUP BY COALESCE(NULLIF(TRIM(r.problem_detail), ''), 'Not provided')
ORDER BY unfinished_requests DESC;


-- 6. Compare pothole request statuses across boroughs.
-- Requests do not necessarily represent distinct physical potholes.
-- Differences are descriptive and do not establish their cause.
SELECT
    c.borough,
    COUNT(*) AS total_pothole_requests,
    COUNT(*) FILTER (
        WHERE c.status IN ('Pending', 'Assigned', 'Open', 'In Progress')
    ) AS unfinished_requests,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE c.status IN ('Pending', 'Assigned', 'Open', 'In Progress')
        ) / COUNT(*),
        2
    ) AS unfinished_pct
FROM public.requests_clean AS c
JOIN public.requests_raw AS r
    ON c.unique_key = r.unique_key
WHERE c.problem = 'Street Condition'
    AND TRIM(r.problem_detail) = 'Pothole'
GROUP BY c.borough
ORDER BY unfinished_pct DESC;