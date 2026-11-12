-- Project: Service Operations & Response-Time Analytics
-- Step 3: Prepare a reusable view for analysis.
-- Preserve all requests and leave the raw table unchanged.
-- Dates represent local NYC clock time without a timezone.

CREATE OR REPLACE VIEW public.requests_clean AS
WITH parsed AS (
    SELECT
        unique_key,
        problem,
        status,
        borough,
        TO_TIMESTAMP(
            NULLIF(TRIM(created_date), ''),
            'MM/DD/YYYY HH12:MI:SS AM'
        )::timestamp AS created_at,
        TO_TIMESTAMP(
            NULLIF(TRIM(closed_date), ''),
            'MM/DD/YYYY HH12:MI:SS AM'
        )::timestamp AS closed_at
    FROM public.requests_raw
)
SELECT *,
    CASE
        WHEN status = 'Closed'
            AND created_at IS NOT NULL
            AND closed_at IS NOT NULL
            AND closed_at >= created_at
        THEN TRUE
        ELSE FALSE
    END AS valid_for_closure_time
FROM parsed;