-- Project: Service Operations & Response-Time Analytics
-- Step 2: Check the imported data.
-- These queries only read data; they do not change it.

-- 1. Compare total rows with distinct request IDs.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT unique_key) AS unique_request_ids
FROM public.requests_raw;

-- 2. Check for an accidentally imported CSV header.
SELECT *
FROM public.requests_raw
WHERE unique_key = 'Unique Key';

-- 3. Count missing or blank dates.
SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(created_date), '') IS NULL
    ) AS missing_created_dates,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(closed_date), '') IS NULL
    ) AS missing_closed_dates
FROM public.requests_raw;

-- 4. Check closure-date availability by status.
SELECT
    status,
    COUNT(*) AS total_requests,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(closed_date), '') IS NULL
    ) AS missing_closed_dates
FROM public.requests_raw
GROUP BY status
ORDER BY total_requests DESC;

-- 5. Count closure dates earlier than creation dates.
WITH parsed_dates AS (
    SELECT
        status,
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
SELECT
    status,
    COUNT(*) AS invalid_date_order
FROM parsed_dates
WHERE closed_at < created_at
GROUP BY status
ORDER BY invalid_date_order DESC;