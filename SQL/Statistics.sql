-- =============================================================================
-- EGYPT HOUSEHOLD INCOME AND LIVING CONDITIONS PROJECT
-- SQL STATISTICAL ANALYSIS
-- =============================================================================
-- This script combines all statistical analysis sections in execution order.
-- =============================================================================

-- =============================================================================
-- SECTION 1: DESCRIPTIVE STATISTICS
-- Source: 01_descriptive_statistics.sql
-- =============================================================================
/* =====================================================================
   01 - DESCRIPTIVE STATISTICS  (Egypt HIECS 2021, household level)
   Source : depi_egypt_raw_import.household_cleaned  (1 row per household)
   Notes  : - Read-only. Only session TEMPORARY tables are created;
              no source table is modified.
            - Variance / SD are SAMPLE statistics (VAR_SAMP / STDDEV_SAMP).
            - Q1 / Median / Q3 use linear interpolation
              (same as PERCENTILE_CONT / pandas default):
              position h = 1 + (n - 1) * p
            - NULL values are excluded from each variable's statistics.
   ===================================================================== */

USE depi_egypt_raw_import;

/* ---------------------------------------------------------------------
   1.0  Grain check: household_cleaned must be one row per household.
        merged_survey_final / individual_cleaned are person level and
        are therefore NOT used for household statistics.
   --------------------------------------------------------------------- */
SELECT 'household_cleaned'   AS table_name, COUNT(*) AS row_count,
       COUNT(DISTINCT household_id) AS distinct_households
FROM household_cleaned
UNION ALL
SELECT 'merged_survey_final', COUNT(*), COUNT(DISTINCT household_id)
FROM merged_survey_final;

/* ---------------------------------------------------------------------
   1.1  Long (unpivoted) table: one row per household x variable.
   --------------------------------------------------------------------- */
DROP TEMPORARY TABLE IF EXISTS tmp_num_long;
CREATE TEMPORARY TABLE tmp_num_long (
    variable_group VARCHAR(30),
    variable_name  VARCHAR(60),
    value          DOUBLE
);

INSERT INTO tmp_num_long (variable_group, variable_name, value)
SELECT 'Income', 'disposable_income',                  disposable_income                  FROM household_cleaned UNION ALL
SELECT 'Income', 'income_per_capita',                  income_per_capita                  FROM household_cleaned UNION ALL
SELECT 'Income', 'wage_income',                        wage_income                        FROM household_cleaned UNION ALL
SELECT 'Income', 'self_employment_income',             self_employment_income             FROM household_cleaned UNION ALL
SELECT 'Income', 'rental_income',                      rental_income                      FROM household_cleaned UNION ALL
SELECT 'Income', 'property_income',                    property_income                    FROM household_cleaned UNION ALL
SELECT 'Income', 'transfers_received',                 transfers_received                 FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'total_expenditure',             total_expenditure                  FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'expenditure_per_capita',        expenditure_per_capita             FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'food_expenditure',              food_expenditure                   FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'non_food_expenditure',          non_food_expenditure               FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'durable_expenditure',           durable_expenditure                FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'lumpy_expenditure',             lumpy_expenditure                  FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'taxes_and_levies',              taxes_and_levies                   FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'purchased_food_expenditure',    purchased_food_expenditure         FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'own_produced_food_value',       own_produced_food_value            FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'gifts_and_in_kind_food',        gifts_and_in_kind_food             FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'food_and_non_alcoholic_expenditure', food_and_non_alcoholic_expenditure FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'alcohol_and_tobacco_expenditure', alcohol_and_tobacco_expenditure  FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'clothing_expenditure',          clothing_expenditure               FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'housing_expenditure',           housing_expenditure                FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'furniture_expenditure',         furniture_expenditure              FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'health_expenditure',            health_expenditure                 FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'transport_expenditure',         transport_expenditure              FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'communication_expenditure',     communication_expenditure          FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'recreation_expenditure',        recreation_expenditure             FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'education_expenditure',         education_expenditure              FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'restaurants_expenditure',       restaurants_expenditure            FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'miscellaneous_expenditure',     miscellaneous_expenditure          FROM household_cleaned UNION ALL
SELECT 'Expenditure', 'actual_and_imputed_rentals',    actual_and_imputed_rentals         FROM household_cleaned UNION ALL
SELECT 'Household', 'household_size',                  household_size                     FROM household_cleaned UNION ALL
SELECT 'Household', 'number_of_males',                 number_of_males                    FROM household_cleaned UNION ALL
SELECT 'Household', 'number_of_females',               number_of_females                  FROM household_cleaned UNION ALL
SELECT 'Household', 'members_under_14',                members_under_14                   FROM household_cleaned UNION ALL
SELECT 'Household', 'members_65_or_more',              members_65_or_more                 FROM household_cleaned UNION ALL
SELECT 'Household', 'number_of_earners',               number_of_earners                  FROM household_cleaned UNION ALL
SELECT 'Household', 'head_age',                        head_age                           FROM household_cleaned UNION ALL
SELECT 'Household', 'rooms_count',                     rooms_count                        FROM household_cleaned UNION ALL
SELECT 'Household', 'persons_per_room',                persons_per_room                   FROM household_cleaned UNION ALL
SELECT 'Household', 'asset_count',                     asset_count                        FROM household_cleaned;

-- NULLs are kept in the temp table and filtered in each query
-- (avoids DELETE, which Workbench "safe update" mode would block).

/* ---------------------------------------------------------------------
   1.2  Full descriptive statistics for every numeric variable.
        Count, Mean, Median, Min, Max, Range, Variance, SD, Q1, Q3, IQR.
   --------------------------------------------------------------------- */
WITH ranked AS (
    SELECT variable_group, variable_name, value,
           ROW_NUMBER() OVER (PARTITION BY variable_name ORDER BY value) AS rn,
           COUNT(*)     OVER (PARTITION BY variable_name)                AS n
    FROM tmp_num_long
    WHERE value IS NOT NULL
),
agg AS (
    SELECT variable_group, variable_name,
           MAX(n)              AS n,
           AVG(value)          AS mean_value,
           MIN(value)          AS min_value,
           MAX(value)          AS max_value,
           VAR_SAMP(value)     AS variance_value,
           STDDEV_SAMP(value)  AS sd_value,
           -- lower / upper order statistics around each percentile position
           MAX(CASE WHEN rn = FLOOR(1 + (n - 1) * 0.25)     THEN value END) AS q1_lo,
           MAX(CASE WHEN rn = FLOOR(1 + (n - 1) * 0.25) + 1 THEN value END) AS q1_hi,
           MAX(1 + (n - 1) * 0.25 - FLOOR(1 + (n - 1) * 0.25))              AS q1_frac,
           MAX(CASE WHEN rn = FLOOR(1 + (n - 1) * 0.50)     THEN value END) AS md_lo,
           MAX(CASE WHEN rn = FLOOR(1 + (n - 1) * 0.50) + 1 THEN value END) AS md_hi,
           MAX(1 + (n - 1) * 0.50 - FLOOR(1 + (n - 1) * 0.50))              AS md_frac,
           MAX(CASE WHEN rn = FLOOR(1 + (n - 1) * 0.75)     THEN value END) AS q3_lo,
           MAX(CASE WHEN rn = FLOOR(1 + (n - 1) * 0.75) + 1 THEN value END) AS q3_hi,
           MAX(1 + (n - 1) * 0.75 - FLOOR(1 + (n - 1) * 0.75))              AS q3_frac
    FROM ranked
    GROUP BY variable_group, variable_name
),
final AS (
    SELECT variable_group, variable_name, n, mean_value, min_value, max_value,
           variance_value, sd_value,
           q1_lo + q1_frac * (COALESCE(q1_hi, q1_lo) - q1_lo) AS q1_value,
           md_lo + md_frac * (COALESCE(md_hi, md_lo) - md_lo) AS median_value,
           q3_lo + q3_frac * (COALESCE(q3_hi, q3_lo) - q3_lo) AS q3_value
    FROM agg
)
SELECT variable_group,
       variable_name,
       n                                AS obs_count,
       ROUND(mean_value, 2)             AS mean,
       ROUND(median_value, 2)           AS median,
       ROUND(min_value, 2)              AS minimum,
       ROUND(max_value, 2)              AS maximum,
       ROUND(max_value - min_value, 2)  AS value_range,
       ROUND(variance_value, 2)         AS variance,
       ROUND(sd_value, 2)               AS std_dev,
       ROUND(q1_value, 2)               AS q1,
       ROUND(q3_value, 2)               AS q3,
       ROUND(q3_value - q1_value, 2)    AS iqr
FROM final
ORDER BY FIELD(variable_group, 'Income', 'Expenditure', 'Household'), variable_name;

/* ---------------------------------------------------------------------
   1.3  Mode - only for discrete household characteristics
        (mode is not meaningful for continuous money amounts).
        Ties for the mode are all shown.
   --------------------------------------------------------------------- */
WITH freq AS (
    SELECT variable_name, value, COUNT(*) AS frequency,
           SUM(COUNT(*)) OVER (PARTITION BY variable_name) AS n
    FROM tmp_num_long
    WHERE variable_name IN ('household_size', 'number_of_males', 'number_of_females',
                            'members_under_14', 'members_65_or_more', 'number_of_earners',
                            'head_age', 'rooms_count', 'asset_count')
      AND value IS NOT NULL
    GROUP BY variable_name, value
),
ranked AS (
    SELECT freq.*, RANK() OVER (PARTITION BY variable_name ORDER BY frequency DESC) AS rnk
    FROM freq
)
SELECT variable_name,
       value                                   AS mode_value,
       frequency                               AS mode_frequency,
       ROUND(100 * frequency / n, 2)           AS mode_pct
FROM ranked
WHERE rnk = 1
ORDER BY variable_name, value;


-- =============================================================================
-- SECTION 2: FREQUENCY DISTRIBUTIONS
-- Source: 02_frequency_distributions.sql
-- =============================================================================
/* =====================================================================
   02 - FREQUENCY DISTRIBUTIONS (unweighted)
   Source : household_cleaned (1 row per household)
   Output : frequency, relative frequency, percentage, cumulative
            frequency and cumulative percentage for each category.
            Categories are ordered from most to least frequent; the
            cumulative columns follow that order (Pareto style), since
            most of these variables are nominal (no natural order).
            Weighted versions are in 07_weighted_statistics.sql.
   ===================================================================== */

USE depi_egypt_raw_import;

/* 2.1  Long table: one row per household x categorical variable. */
DROP TEMPORARY TABLE IF EXISTS tmp_cat_long;
CREATE TEMPORARY TABLE tmp_cat_long (
    variable_name VARCHAR(60),
    category      VARCHAR(255)
);

INSERT INTO tmp_cat_long (variable_name, category)
SELECT 'region',                  region                  FROM household_cleaned UNION ALL
SELECT 'area',                    area                    FROM household_cleaned UNION ALL
SELECT 'residence_type',          residence_type          FROM household_cleaned UNION ALL
SELECT 'household_composition',   household_composition   FROM household_cleaned UNION ALL
SELECT 'main_income_source',      main_income_source      FROM household_cleaned UNION ALL
SELECT 'head_gender',             head_gender             FROM household_cleaned UNION ALL
SELECT 'head_literacy',           head_literacy           FROM household_cleaned UNION ALL
SELECT 'head_education_level',    head_education_level    FROM household_cleaned UNION ALL
SELECT 'head_marital_status',     head_marital_status     FROM household_cleaned UNION ALL
SELECT 'head_partnership_status', head_partnership_status FROM household_cleaned UNION ALL
SELECT 'head_main_activity',      head_main_activity      FROM household_cleaned UNION ALL
SELECT 'head_employment_status',  head_employment_status  FROM household_cleaned UNION ALL
SELECT 'head_occupation',         head_occupation         FROM household_cleaned UNION ALL
SELECT 'head_industry',           head_industry           FROM household_cleaned UNION ALL
SELECT 'head_employment_sector',  head_employment_sector  FROM household_cleaned UNION ALL
SELECT 'dwelling_type',           dwelling_type           FROM household_cleaned UNION ALL
SELECT 'dwelling_tenure',         dwelling_tenure         FROM household_cleaned UNION ALL
SELECT 'water_facility',          water_facility          FROM household_cleaned UNION ALL
SELECT 'sanitation',              sanitation              FROM household_cleaned UNION ALL
SELECT 'garbage_disposal_method', garbage_disposal_method FROM household_cleaned;

/* 2.2  Frequency table for all 20 categorical variables.
        NULL categories are displayed as '(Not recorded)' only for
        readability; they are counted, not removed.                  */
WITH freq AS (
    SELECT variable_name,
           COALESCE(category, '(Not recorded)') AS category,
           COUNT(*) AS frequency
    FROM tmp_cat_long
    GROUP BY variable_name, COALESCE(category, '(Not recorded)')
),
calc AS (
    SELECT variable_name, category, frequency,
           SUM(frequency) OVER (PARTITION BY variable_name) AS total_households,
           SUM(frequency) OVER (PARTITION BY variable_name
                                ORDER BY frequency DESC, category
                                ROWS UNBOUNDED PRECEDING)   AS cumulative_frequency,
           ROW_NUMBER()   OVER (PARTITION BY variable_name
                                ORDER BY frequency DESC, category) AS category_rank
    FROM freq
)
SELECT variable_name,
       category_rank,
       category,
       frequency,
       ROUND(frequency / NULLIF(total_households, 0), 4)              AS relative_frequency,
       ROUND(100 * frequency / NULLIF(total_households, 0), 2)        AS percentage,
       cumulative_frequency,
       ROUND(100 * cumulative_frequency / NULLIF(total_households, 0), 2) AS cumulative_percentage
FROM calc
ORDER BY variable_name, category_rank;


-- =============================================================================
-- SECTION 3: GROUPED DESCRIPTIVE STATISTICS
-- Source: 03_grouped_descriptive_statistics.sql
-- =============================================================================
/* =====================================================================
   03 - GROUPED DESCRIPTIVE STATISTICS
   Source : household_cleaned (1 row per household)
   Output : n, mean, median, min, max, SD (sample) per group.
   Notes  : - household_size grouped as 1..8 and '9+';
              number_of_earners grouped as 0..4 and '5+'
              (very large values have too few households per group).
            - Median uses linear interpolation (same method as file 01).
   ===================================================================== */

USE depi_egypt_raw_import;

/* 3.1  Long table: comparison x group x variable x value. */
DROP TEMPORARY TABLE IF EXISTS tmp_grp_long;
CREATE TEMPORARY TABLE tmp_grp_long (
    comparison    VARCHAR(60),
    group_label   VARCHAR(255),
    group_sort    INT,
    variable_name VARCHAR(60),
    value         DOUBLE
);

-- C1 / C2 / C8 / C9 : region and residence type
INSERT INTO tmp_grp_long
SELECT g.comparison, g.group_label, 0, v.variable_name,
       CASE v.variable_name
            WHEN 'disposable_income'      THEN h.disposable_income
            WHEN 'income_per_capita'      THEN h.income_per_capita
            WHEN 'total_expenditure'      THEN h.total_expenditure
            WHEN 'expenditure_per_capita' THEN h.expenditure_per_capita
            WHEN 'asset_count'            THEN h.asset_count
       END
FROM household_cleaned h
CROSS JOIN LATERAL (
    SELECT '1/8. By region' AS comparison, h.region AS group_label
    UNION ALL
    SELECT '2/9. By residence type', h.residence_type
) g
CROSS JOIN (
    SELECT 'disposable_income' AS variable_name UNION ALL
    SELECT 'income_per_capita'      UNION ALL
    SELECT 'total_expenditure'      UNION ALL
    SELECT 'expenditure_per_capita' UNION ALL
    SELECT 'asset_count'
) v;

-- C3 / C4 / C5 / C6 : income by head education, employment status,
--                     household size and number of earners
INSERT INTO tmp_grp_long
SELECT g.comparison, g.group_label, g.group_sort, v.variable_name,
       CASE v.variable_name
            WHEN 'disposable_income' THEN h.disposable_income
            WHEN 'income_per_capita' THEN h.income_per_capita
       END
FROM household_cleaned h
CROSS JOIN LATERAL (
    SELECT '3. Income by head education level' AS comparison,
           h.head_education_level AS group_label, 0 AS group_sort
    UNION ALL
    SELECT '4. Income by head employment status', h.head_employment_status, 0
    UNION ALL
    SELECT '5. Income by household size',
           IF(h.household_size >= 9, '9+', CAST(h.household_size AS CHAR)),
           LEAST(h.household_size, 9)
    UNION ALL
    SELECT '6. Income by number of earners',
           IF(h.number_of_earners >= 5, '5+', CAST(h.number_of_earners AS CHAR)),
           LEAST(h.number_of_earners, 5)
) g
CROSS JOIN (
    SELECT 'disposable_income' AS variable_name UNION ALL
    SELECT 'income_per_capita'
) v;

-- C7 : expenditure by household size
INSERT INTO tmp_grp_long
SELECT '7. Expenditure by household size',
       IF(h.household_size >= 9, '9+', CAST(h.household_size AS CHAR)),
       LEAST(h.household_size, 9),
       v.variable_name,
       IF(v.variable_name = 'total_expenditure', h.total_expenditure, h.expenditure_per_capita)
FROM household_cleaned h
CROSS JOIN (
    SELECT 'total_expenditure' AS variable_name UNION ALL
    SELECT 'expenditure_per_capita'
) v;

/* 3.2  Grouped statistics for all comparisons.
        Filter on `comparison` / `variable_name` to view one table.     */
WITH ranked AS (
    SELECT comparison, group_label, group_sort, variable_name, value,
           ROW_NUMBER() OVER w_ord AS rn,
           COUNT(*)     OVER w_grp AS n
    FROM tmp_grp_long
    WHERE value IS NOT NULL
    WINDOW w_grp AS (PARTITION BY comparison, group_label, variable_name),
           w_ord AS (PARTITION BY comparison, group_label, variable_name ORDER BY value)
),
agg AS (
    SELECT comparison, group_label, variable_name,
           MAX(group_sort)     AS group_sort,
           MAX(n)              AS n,
           AVG(value)          AS mean_value,
           MIN(value)          AS min_value,
           MAX(value)          AS max_value,
           STDDEV_SAMP(value)  AS sd_value,
           MAX(CASE WHEN rn = FLOOR(1 + (n - 1) * 0.5)     THEN value END) AS md_lo,
           MAX(CASE WHEN rn = FLOOR(1 + (n - 1) * 0.5) + 1 THEN value END) AS md_hi,
           MAX(1 + (n - 1) * 0.5 - FLOOR(1 + (n - 1) * 0.5))              AS md_frac
    FROM ranked
    GROUP BY comparison, group_label, variable_name
)
SELECT comparison,
       variable_name,
       COALESCE(group_label, '(Not recorded)')                    AS group_value,
       n                                                          AS households,
       ROUND(mean_value, 2)                                       AS mean,
       ROUND(md_lo + md_frac * (COALESCE(md_hi, md_lo) - md_lo), 2) AS median,
       ROUND(min_value, 2)                                        AS minimum,
       ROUND(max_value, 2)                                        AS maximum,
       ROUND(sd_value, 2)                                         AS std_dev
FROM agg
ORDER BY comparison, variable_name, group_sort, mean_value DESC;


-- =============================================================================
-- SECTION 4: INCOME AND EXPENDITURE ANALYSIS
-- Source: 04_income_expenditure_analysis.sql
-- =============================================================================
/* =====================================================================
   04 - INCOME AND EXPENDITURE ANALYSIS (unweighted)
   Source : household_cleaned (1 row per household)
   Existing derived columns (definitions verified in
   egypt_project_cleaning_pipeline.sql, "features" CTE):
     income_per_capita      = disposable_income / household_size
     expenditure_per_capita = total_expenditure / household_size
     food_expenditure_share = food_expenditure / total_expenditure
     savings_rate           = (disposable_income - total_expenditure)
                              / disposable_income
   Savings amount is computed here as disposable_income - total_expenditure.
   "Aggregate" ratios = SUM(numerator) / SUM(denominator); they differ from
   the mean of household ratios, which is sensitive to very small incomes.
   ===================================================================== */

USE depi_egypt_raw_import;

/* 4.0  Composition check of the aggregate columns (to confirm which
        components add up to each total before using them).
        pct_match = % households where the identity holds within 1 EGP. */
SELECT
    ROUND(100 * AVG(ABS(disposable_income
          - (wage_income + self_employment_income + rental_income
             + property_income + transfers_received)) <= 1), 2)
        AS pct_income_equals_sum_of_5_sources,
    ROUND(100 * AVG(ABS(total_expenditure
          - (food_expenditure + non_food_expenditure)) <= 1), 2)
        AS pct_total_exp_equals_food_plus_nonfood,
    ROUND(100 * AVG(ABS(total_expenditure
          - (food_and_non_alcoholic_expenditure + alcohol_and_tobacco_expenditure
             + clothing_expenditure + housing_expenditure + furniture_expenditure
             + health_expenditure + transport_expenditure + communication_expenditure
             + recreation_expenditure + education_expenditure
             + restaurants_expenditure + miscellaneous_expenditure)) <= 1), 2)
        AS pct_total_exp_equals_12_coicop_groups,
    ROUND(100 * AVG(ABS(food_expenditure
          - (purchased_food_expenditure + COALESCE(own_produced_food_value, 0)
             + COALESCE(gifts_and_in_kind_food, 0))) <= 1), 2)
        AS pct_food_equals_purchased_own_gifts
FROM household_cleaned;
-- ADJUST: if a pct_* above is far below 100, the related breakdown share
-- (4.7 / 4.8) should be read as "share of the sum of components" only.

/* 4.1 / 4.2  Income and expenditure distributions by per-capita deciles.
        share_of_total_* shows how concentrated income / spending is.    */
WITH deciles AS (
    SELECT disposable_income, income_per_capita,
           total_expenditure, expenditure_per_capita,
           NTILE(10) OVER (ORDER BY income_per_capita)      AS income_decile,
           NTILE(10) OVER (ORDER BY expenditure_per_capita) AS expenditure_decile
    FROM household_cleaned
    WHERE income_per_capita IS NOT NULL AND expenditure_per_capita IS NOT NULL
)
SELECT 'Income per capita decile' AS distribution, income_decile AS decile,
       COUNT(*)                                   AS households,
       ROUND(MIN(income_per_capita), 2)           AS min_per_capita,
       ROUND(MAX(income_per_capita), 2)           AS max_per_capita,
       ROUND(AVG(income_per_capita), 2)           AS mean_per_capita,
       ROUND(AVG(disposable_income), 2)           AS mean_household_amount,
       ROUND(100 * SUM(disposable_income) / SUM(SUM(disposable_income)) OVER (), 2)
                                                  AS share_of_total_pct
FROM deciles GROUP BY income_decile
UNION ALL
SELECT 'Expenditure per capita decile', expenditure_decile,
       COUNT(*),
       ROUND(MIN(expenditure_per_capita), 2),
       ROUND(MAX(expenditure_per_capita), 2),
       ROUND(AVG(expenditure_per_capita), 2),
       ROUND(AVG(total_expenditure), 2),
       ROUND(100 * SUM(total_expenditure) / SUM(SUM(total_expenditure)) OVER (), 2)
FROM deciles GROUP BY expenditure_decile
ORDER BY distribution DESC, decile;

/* 4.3 / 4.4 / 4.5  Income vs expenditure, savings and food share:
        overall summary (means, medians, aggregate ratios).             */
WITH base AS (
    SELECT disposable_income, total_expenditure, food_expenditure,
           disposable_income - total_expenditure AS savings_amount,
           savings_rate, food_expenditure_share
    FROM household_cleaned
),
long_ratios AS (            -- unpivot for medians
    SELECT m.metric, m.val
    FROM base
    CROSS JOIN LATERAL (
        SELECT 'savings_amount' AS metric, savings_amount AS val UNION ALL
        SELECT 'savings_rate', savings_rate UNION ALL
        SELECT 'food_expenditure_share', food_expenditure_share
    ) m
    WHERE m.val IS NOT NULL
),
ranked AS (
    SELECT metric, val,
           ROW_NUMBER() OVER (PARTITION BY metric ORDER BY val) AS rn,
           COUNT(*)     OVER (PARTITION BY metric)              AS n
    FROM long_ratios
),
medians AS (
    SELECT metric,
           AVG(val) AS median_value          -- average of the 1 or 2 middle rows
    FROM ranked
    WHERE rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
    GROUP BY metric
)
SELECT
    (SELECT COUNT(*) FROM base)                                         AS households,
    (SELECT ROUND(AVG(disposable_income), 2) FROM base)                 AS mean_income,
    (SELECT ROUND(AVG(total_expenditure), 2) FROM base)                 AS mean_expenditure,
    (SELECT ROUND(AVG(savings_amount), 2) FROM base)                    AS mean_savings_amount,
    (SELECT ROUND(median_value, 2) FROM medians WHERE metric = 'savings_amount') AS median_savings_amount,
    (SELECT ROUND(100 * AVG(savings_amount < 0), 2) FROM base)          AS pct_households_spending_more_than_income,
    (SELECT ROUND(100 * SUM(total_expenditure) / NULLIF(SUM(disposable_income), 0), 2) FROM base)
                                                                        AS aggregate_expenditure_to_income_pct,
    (SELECT ROUND(100 * AVG(savings_rate), 2) FROM base)                AS mean_household_savings_rate_pct,
    (SELECT ROUND(100 * median_value, 2) FROM medians WHERE metric = 'savings_rate') AS median_savings_rate_pct,
    (SELECT ROUND(100 * SUM(savings_amount) / NULLIF(SUM(disposable_income), 0), 2) FROM base)
                                                                        AS aggregate_savings_rate_pct,
    (SELECT ROUND(100 * AVG(food_expenditure_share), 2) FROM base)      AS mean_food_share_pct,
    (SELECT ROUND(100 * median_value, 2) FROM medians WHERE metric = 'food_expenditure_share') AS median_food_share_pct,
    (SELECT ROUND(100 * SUM(food_expenditure) / NULLIF(SUM(total_expenditure), 0), 2) FROM base)
                                                                        AS aggregate_food_share_pct;

/* 4.3 / 4.4 / 4.5  The same measures across income-per-capita quintiles
        (1 = poorest 20% of households, 5 = richest 20%).                 */
WITH q AS (
    SELECT h.*, NTILE(5) OVER (ORDER BY income_per_capita) AS income_quintile
    FROM household_cleaned h
    WHERE income_per_capita IS NOT NULL
)
SELECT income_quintile,
       COUNT(*)                                                         AS households,
       ROUND(AVG(disposable_income), 2)                                 AS mean_income,
       ROUND(AVG(total_expenditure), 2)                                 AS mean_expenditure,
       ROUND(AVG(disposable_income - total_expenditure), 2)             AS mean_savings_amount,
       ROUND(100 * AVG(total_expenditure > disposable_income), 2)       AS pct_spending_more_than_income,
       ROUND(100 * SUM(disposable_income - total_expenditure)
                 / NULLIF(SUM(disposable_income), 0), 2)                AS aggregate_savings_rate_pct,
       ROUND(100 * AVG(food_expenditure_share), 2)                      AS mean_food_share_pct,
       ROUND(100 * SUM(food_expenditure) / NULLIF(SUM(total_expenditure), 0), 2)
                                                                        AS aggregate_food_share_pct
FROM q
GROUP BY income_quintile
ORDER BY income_quintile;

/* 4.6  Food versus non-food expenditure. */
SELECT
    ROUND(AVG(food_expenditure), 2)                                    AS mean_food_expenditure,
    ROUND(AVG(non_food_expenditure), 2)                                AS mean_non_food_expenditure,
    ROUND(SUM(food_expenditure), 2)                                    AS total_food_expenditure,
    ROUND(SUM(non_food_expenditure), 2)                                AS total_non_food_expenditure,
    ROUND(100 * SUM(food_expenditure)
              / NULLIF(SUM(food_expenditure) + SUM(non_food_expenditure), 0), 2) AS food_pct_of_food_plus_nonfood,
    ROUND(100 * SUM(non_food_expenditure)
              / NULLIF(SUM(food_expenditure) + SUM(non_food_expenditure), 0), 2) AS nonfood_pct_of_food_plus_nonfood,
    ROUND(100 * AVG(food_expenditure > non_food_expenditure), 2)       AS pct_households_food_exceeds_nonfood
FROM household_cleaned;

/* 4.7  Breakdown of income sources.
        share_of_income_pct = component total / total disposable income. */
WITH src AS (
    SELECT s.income_source, s.amount
    FROM household_cleaned h
    CROSS JOIN LATERAL (
        SELECT 'wage_income' AS income_source, h.wage_income AS amount UNION ALL
        SELECT 'self_employment_income', h.self_employment_income UNION ALL
        SELECT 'rental_income',          h.rental_income          UNION ALL
        SELECT 'property_income',        h.property_income        UNION ALL
        SELECT 'transfers_received',     h.transfers_received
    ) s
)
SELECT income_source,
       ROUND(SUM(amount), 2)                                             AS total_amount,
       ROUND(AVG(amount), 2)                                             AS mean_per_household,
       ROUND(100 * SUM(amount) / NULLIF((SELECT SUM(disposable_income) FROM household_cleaned), 0), 2)
                                                                         AS share_of_income_pct,
       ROUND(100 * AVG(amount > 0), 2)                                   AS pct_households_receiving,
       ROUND(AVG(CASE WHEN amount > 0 THEN amount END), 2)               AS mean_among_receivers
FROM src
GROUP BY income_source
ORDER BY total_amount DESC;

/* 4.8  Breakdown of expenditure by the 12 COICOP groups
        (plus other expenditure aggregates shown separately). */
WITH cat AS (
    SELECT c.category_type, c.expenditure_category, c.amount
    FROM household_cleaned h
    CROSS JOIN LATERAL (
        SELECT 'COICOP' AS category_type, 'food_and_non_alcoholic_expenditure' AS expenditure_category,
               h.food_and_non_alcoholic_expenditure AS amount UNION ALL
        SELECT 'COICOP', 'alcohol_and_tobacco_expenditure', h.alcohol_and_tobacco_expenditure UNION ALL
        SELECT 'COICOP', 'clothing_expenditure',            h.clothing_expenditure            UNION ALL
        SELECT 'COICOP', 'housing_expenditure',             h.housing_expenditure             UNION ALL
        SELECT 'COICOP', 'furniture_expenditure',           h.furniture_expenditure           UNION ALL
        SELECT 'COICOP', 'health_expenditure',              h.health_expenditure              UNION ALL
        SELECT 'COICOP', 'transport_expenditure',           h.transport_expenditure           UNION ALL
        SELECT 'COICOP', 'communication_expenditure',       h.communication_expenditure       UNION ALL
        SELECT 'COICOP', 'recreation_expenditure',          h.recreation_expenditure          UNION ALL
        SELECT 'COICOP', 'education_expenditure',           h.education_expenditure           UNION ALL
        SELECT 'COICOP', 'restaurants_expenditure',         h.restaurants_expenditure         UNION ALL
        SELECT 'COICOP', 'miscellaneous_expenditure',       h.miscellaneous_expenditure       UNION ALL
        SELECT 'Other aggregate', 'actual_and_imputed_rentals', h.actual_and_imputed_rentals  UNION ALL
        SELECT 'Other aggregate', 'durable_expenditure',     h.durable_expenditure            UNION ALL
        SELECT 'Other aggregate', 'lumpy_expenditure',       h.lumpy_expenditure              UNION ALL
        SELECT 'Other aggregate', 'taxes_and_levies',        h.taxes_and_levies
    ) c
)
SELECT category_type,
       expenditure_category,
       ROUND(SUM(amount), 2)                                             AS total_amount,
       ROUND(AVG(amount), 2)                                             AS mean_per_household,
       ROUND(100 * SUM(amount) / NULLIF((SELECT SUM(total_expenditure) FROM household_cleaned), 0), 2)
                                                                         AS share_of_total_expenditure_pct,
       ROUND(100 * AVG(amount > 0), 2)                                   AS pct_households_with_spending
FROM cat
GROUP BY category_type, expenditure_category
ORDER BY category_type, total_amount DESC;

/* 4.9 / 4.10  Income and expenditure comparison by region and by
        residence type (ratios; distribution stats are in file 03). */
SELECT 'Region' AS grouping_variable, region AS group_value,
       COUNT(*)                                                          AS households,
       ROUND(AVG(disposable_income), 2)                                  AS mean_income,
       ROUND(AVG(total_expenditure), 2)                                  AS mean_expenditure,
       ROUND(AVG(income_per_capita), 2)                                  AS mean_income_per_capita,
       ROUND(AVG(expenditure_per_capita), 2)                             AS mean_expenditure_per_capita,
       ROUND(AVG(disposable_income - total_expenditure), 2)              AS mean_savings_amount,
       ROUND(100 * SUM(disposable_income - total_expenditure)
                 / NULLIF(SUM(disposable_income), 0), 2)                 AS aggregate_savings_rate_pct,
       ROUND(100 * SUM(food_expenditure) / NULLIF(SUM(total_expenditure), 0), 2)
                                                                         AS aggregate_food_share_pct
FROM household_cleaned
GROUP BY region
UNION ALL
SELECT 'Residence type', residence_type,
       COUNT(*),
       ROUND(AVG(disposable_income), 2),
       ROUND(AVG(total_expenditure), 2),
       ROUND(AVG(income_per_capita), 2),
       ROUND(AVG(expenditure_per_capita), 2),
       ROUND(AVG(disposable_income - total_expenditure), 2),
       ROUND(100 * SUM(disposable_income - total_expenditure) / NULLIF(SUM(disposable_income), 0), 2),
       ROUND(100 * SUM(food_expenditure) / NULLIF(SUM(total_expenditure), 0), 2)
FROM household_cleaned
GROUP BY residence_type
ORDER BY grouping_variable, mean_income DESC;


-- =============================================================================
-- SECTION 5: CORRELATION ANALYSIS
-- Source: 05_correlation_analysis.sql
-- =============================================================================
/* =====================================================================
   05 - BASIC CORRELATION ANALYSIS
   Source : household_cleaned (1 row per household)
   Method : Pearson r  = SUM(dx*dy) / SQRT(SUM(dx^2) * SUM(dy^2))
            (computed on mean-centred values for numerical stability)
            Spearman rho = Pearson r computed on ranks; tied values get
            their average rank.
            Rows where either variable is NULL are excluded pairwise.
   Note   : Correlation measures association only - NOT causation.
            Income/expenditure are strongly right-skewed, so Spearman
            is the more robust measure of monotonic association.
   ===================================================================== */

USE depi_egypt_raw_import;

/* 5.1  Long table of variable pairs. */
DROP TEMPORARY TABLE IF EXISTS tmp_corr_pairs;
CREATE TEMPORARY TABLE tmp_corr_pairs (
    pair_order INT,
    x_variable VARCHAR(60),
    y_variable VARCHAR(60),
    x DOUBLE,
    y DOUBLE
);

INSERT INTO tmp_corr_pairs
SELECT p.pair_order, p.x_variable, p.y_variable, p.x, p.y
FROM household_cleaned h
CROSS JOIN LATERAL (
    SELECT 1 AS pair_order, 'disposable_income' AS x_variable, 'total_expenditure' AS y_variable,
           h.disposable_income AS x, h.total_expenditure AS y                                UNION ALL
    SELECT 2, 'disposable_income', 'household_size',    h.disposable_income, h.household_size    UNION ALL
    SELECT 3, 'disposable_income', 'number_of_earners', h.disposable_income, h.number_of_earners UNION ALL
    SELECT 4, 'disposable_income', 'head_age',          h.disposable_income, h.head_age          UNION ALL
    SELECT 5, 'disposable_income', 'asset_count',       h.disposable_income, h.asset_count       UNION ALL
    SELECT 6, 'total_expenditure', 'household_size',    h.total_expenditure, h.household_size    UNION ALL
    SELECT 7, 'income_per_capita', 'household_size',    h.income_per_capita, h.household_size
) p
WHERE p.x IS NOT NULL AND p.y IS NOT NULL;

/* 5.2  Pearson and Spearman correlation for each pair. */
WITH ranked AS (
    SELECT pair_order, x_variable, y_variable, x, y,
           RANK() OVER (PARTITION BY pair_order ORDER BY x)
             + (COUNT(*) OVER (PARTITION BY pair_order, x) - 1) / 2 AS rank_x,
           RANK() OVER (PARTITION BY pair_order ORDER BY y)
             + (COUNT(*) OVER (PARTITION BY pair_order, y) - 1) / 2 AS rank_y
    FROM tmp_corr_pairs
),
centred AS (
    SELECT pair_order, x_variable, y_variable,
           x      - AVG(x)      OVER (PARTITION BY pair_order) AS dx,
           y      - AVG(y)      OVER (PARTITION BY pair_order) AS dy,
           rank_x - AVG(rank_x) OVER (PARTITION BY pair_order) AS drx,
           rank_y - AVG(rank_y) OVER (PARTITION BY pair_order) AS dry
    FROM ranked
),
corr AS (
    SELECT pair_order, x_variable, y_variable,
           COUNT(*) AS n,
           SUM(dx * dy)   / NULLIF(SQRT(SUM(dx * dx)   * SUM(dy * dy)),   0) AS pearson_r,
           SUM(drx * dry) / NULLIF(SQRT(SUM(drx * drx) * SUM(dry * dry)), 0) AS spearman_rho
    FROM centred
    GROUP BY pair_order, x_variable, y_variable
)
SELECT x_variable,
       y_variable,
       n                          AS households,
       ROUND(pearson_r, 4)        AS pearson_r,
       ROUND(spearman_rho, 4)     AS spearman_rho,
       -- descriptive label for |r| (rule of thumb only, not a test)
       CASE WHEN ABS(pearson_r) >= 0.7 THEN 'Strong'
            WHEN ABS(pearson_r) >= 0.4 THEN 'Moderate'
            WHEN ABS(pearson_r) >= 0.2 THEN 'Weak'
            ELSE 'Very weak / none' END AS pearson_strength,
       IF(pearson_r >= 0, 'Positive', 'Negative') AS pearson_direction
FROM corr
ORDER BY pair_order;


-- =============================================================================
-- SECTION 6: ASSET OWNERSHIP ANALYSIS
-- Source: 06_asset_ownership_analysis.sql
-- =============================================================================
/* =====================================================================
   06 - ASSET OWNERSHIP ANALYSIS (unweighted)
   Source : household_cleaned (1 row per household)
   Notes  : has_* columns are binary (1 = owns, 0 = does not own).
            Ownership % = owners / households with a recorded value.
            Weighted ownership is in 07_weighted_statistics.sql.
   ===================================================================== */

USE depi_egypt_raw_import;

/* 6.0  Long table: one row per household x asset. */
DROP TEMPORARY TABLE IF EXISTS tmp_asset_long;
CREATE TEMPORARY TABLE tmp_asset_long (
    region         VARCHAR(255),
    residence_type VARCHAR(255),
    asset          VARCHAR(60),
    owned          TINYINT
);

INSERT INTO tmp_asset_long
SELECT h.region, h.residence_type, a.asset, a.owned
FROM household_cleaned h
CROSS JOIN LATERAL (
    SELECT 'has_car' AS asset, h.has_car AS owned             UNION ALL
    SELECT 'has_bicycle_or_motorcycle', h.has_bicycle_or_motorcycle UNION ALL
    SELECT 'has_tv',               h.has_tv               UNION ALL
    SELECT 'has_satellite_dish',   h.has_satellite_dish   UNION ALL
    SELECT 'has_media_player',     h.has_media_player     UNION ALL
    SELECT 'has_camera',           h.has_camera           UNION ALL
    SELECT 'has_telephone',        h.has_telephone        UNION ALL
    SELECT 'has_computer',         h.has_computer         UNION ALL
    SELECT 'has_internet',         h.has_internet         UNION ALL
    SELECT 'has_refrigerator',     h.has_refrigerator     UNION ALL
    SELECT 'has_cooker',           h.has_cooker           UNION ALL
    SELECT 'has_microwave',        h.has_microwave        UNION ALL
    SELECT 'has_food_processor',   h.has_food_processor   UNION ALL
    SELECT 'has_washing_machine',  h.has_washing_machine  UNION ALL
    SELECT 'has_dishwasher',       h.has_dishwasher       UNION ALL
    SELECT 'has_air_conditioner',  h.has_air_conditioner  UNION ALL
    SELECT 'has_electric_fan',     h.has_electric_fan     UNION ALL
    SELECT 'has_heater',           h.has_heater           UNION ALL
    SELECT 'has_water_heater',     h.has_water_heater     UNION ALL
    SELECT 'has_sewing_machine',   h.has_sewing_machine   UNION ALL
    SELECT 'has_vacuum_cleaner',   h.has_vacuum_cleaner   UNION ALL
    SELECT 'has_iron',             h.has_iron             UNION ALL
    SELECT 'has_water_motor',      h.has_water_motor      UNION ALL
    SELECT 'has_other_durables',   h.has_other_durables
) a;

/* 6.1 / 6.2 / 6.3  Owners, ownership % and rank for every asset.
        rank_most_common = 1 -> most common; rank_least_common = 1 -> least. */
WITH own AS (
    SELECT asset,
           COUNT(owned)                       AS households_recorded,
           SUM(owned = 1)                     AS households_owning
    FROM tmp_asset_long
    GROUP BY asset
)
SELECT asset,
       households_owning,
       households_recorded,
       ROUND(100 * households_owning / NULLIF(households_recorded, 0), 2) AS ownership_pct,
       RANK() OVER (ORDER BY households_owning / NULLIF(households_recorded, 0) DESC) AS rank_most_common,
       RANK() OVER (ORDER BY households_owning / NULLIF(households_recorded, 0) ASC)  AS rank_least_common
FROM own
ORDER BY ownership_pct DESC;

/* 6.4  Distribution of asset_count (number of the 24 assets owned).
        Cumulative columns follow the natural numeric order.           */
SELECT asset_count,
       COUNT(*)                                                       AS households,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)               AS percentage,
       SUM(COUNT(*)) OVER (ORDER BY asset_count)                      AS cumulative_households,
       ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY asset_count)
                 / SUM(COUNT(*)) OVER (), 2)                          AS cumulative_percentage
FROM household_cleaned
GROUP BY asset_count
ORDER BY asset_count;

/* 6.5  Asset ownership % by region (long format: region x asset).
        rank_in_region = 1 -> most common asset in that region.       */
SELECT COALESCE(region, '(Not recorded)')                              AS region,
       asset,
       COUNT(owned)                                                    AS households_recorded,
       SUM(owned = 1)                                                  AS households_owning,
       ROUND(100 * SUM(owned = 1) / NULLIF(COUNT(owned), 0), 2)        AS ownership_pct,
       RANK() OVER (PARTITION BY region
                    ORDER BY SUM(owned = 1) / NULLIF(COUNT(owned), 0) DESC) AS rank_in_region
FROM tmp_asset_long
GROUP BY region, asset
ORDER BY region, rank_in_region, asset;

/* 6.6  Asset ownership % by residence type, side by side.
        Run separately from 6.5 (MySQL cannot reopen a TEMPORARY table
        twice in one statement, so each query reads it only once).     */
SELECT asset,
       COALESCE(residence_type, '(Not recorded)')                      AS residence_type,
       COUNT(owned)                                                    AS households_recorded,
       SUM(owned = 1)                                                  AS households_owning,
       ROUND(100 * SUM(owned = 1) / NULLIF(COUNT(owned), 0), 2)        AS ownership_pct
FROM tmp_asset_long
GROUP BY asset, residence_type
ORDER BY asset, residence_type;


-- =============================================================================
-- SECTION 7: WEIGHTED STATISTICS
-- Source: 07_weighted_statistics.sql
-- =============================================================================
/* =====================================================================
   07 - WEIGHTED DESCRIPTIVE STATISTICS
   Source : household_cleaned (1 row per household), weight = household_weight
   Formula: weighted mean = SUM(w * x) / SUM(w)
            weighted %    = SUM(w in category) / SUM(w) * 100
   Notes  : - All results in this file are WEIGHTED; unweighted results
              are in files 01-06. Do not mix the two.
            - Applying household weights corrects point estimates for
              unequal selection probabilities only. It does NOT account
              for the full complex survey design (stratification,
              clustering); standard errors would need design-based methods.
            - Households with NULL weight are excluded.
   ===================================================================== */

USE depi_egypt_raw_import;

/* 7.1  Weighted means of income and expenditure.
        Household-weighted per-capita mean  = average over households.
        Person-weighted per-capita mean     = SUM(w*income)/SUM(w*size),
        i.e. average income per person in the population.              */
SELECT
    COUNT(*)                                                               AS sample_households,
    ROUND(SUM(household_weight), 2)                                        AS sum_of_weights,
    ROUND(SUM(household_weight * disposable_income)
          / NULLIF(SUM(CASE WHEN disposable_income IS NOT NULL THEN household_weight END), 0), 2)
                                                                           AS weighted_mean_disposable_income,
    ROUND(SUM(household_weight * total_expenditure)
          / NULLIF(SUM(CASE WHEN total_expenditure IS NOT NULL THEN household_weight END), 0), 2)
                                                                           AS weighted_mean_total_expenditure,
    ROUND(SUM(household_weight * income_per_capita)
          / NULLIF(SUM(CASE WHEN income_per_capita IS NOT NULL THEN household_weight END), 0), 2)
                                                                           AS weighted_mean_income_per_capita_hh,
    ROUND(SUM(household_weight * disposable_income)
          / NULLIF(SUM(CASE WHEN disposable_income IS NOT NULL THEN household_weight * household_size END), 0), 2)
                                                                           AS weighted_mean_income_per_person,
    ROUND(SUM(household_weight * expenditure_per_capita)
          / NULLIF(SUM(CASE WHEN expenditure_per_capita IS NOT NULL THEN household_weight END), 0), 2)
                                                                           AS weighted_mean_expenditure_per_capita_hh
FROM household_cleaned
WHERE household_weight IS NOT NULL;

/* 7.2  Weighted means by region and by residence type. */
SELECT 'Region' AS grouping_variable, region AS group_value,
       COUNT(*)                                                                    AS sample_households,
       ROUND(SUM(household_weight), 2)                                             AS sum_of_weights,
       ROUND(SUM(household_weight * disposable_income) / NULLIF(SUM(household_weight), 0), 2) AS weighted_mean_income,
       ROUND(SUM(household_weight * total_expenditure) / NULLIF(SUM(household_weight), 0), 2) AS weighted_mean_expenditure,
       ROUND(SUM(household_weight * income_per_capita) / NULLIF(SUM(household_weight), 0), 2) AS weighted_mean_income_per_capita
FROM household_cleaned
WHERE household_weight IS NOT NULL
GROUP BY region
UNION ALL
SELECT 'Residence type', residence_type,
       COUNT(*),
       ROUND(SUM(household_weight), 2),
       ROUND(SUM(household_weight * disposable_income) / NULLIF(SUM(household_weight), 0), 2),
       ROUND(SUM(household_weight * total_expenditure) / NULLIF(SUM(household_weight), 0), 2),
       ROUND(SUM(household_weight * income_per_capita) / NULLIF(SUM(household_weight), 0), 2)
FROM household_cleaned
WHERE household_weight IS NOT NULL
GROUP BY residence_type
ORDER BY grouping_variable, weighted_mean_income DESC;
-- ADJUST: if 4.0 / file 01 show NULLs in income or expenditure, the
-- denominators above should use CASE WHEN x IS NOT NULL as in 7.1.

/* 7.3  Weighted frequency distributions for the categorical variables. */
DROP TEMPORARY TABLE IF EXISTS tmp_cat_long_w;
CREATE TEMPORARY TABLE tmp_cat_long_w (
    variable_name VARCHAR(60),
    category      VARCHAR(255),
    w             DOUBLE
);

INSERT INTO tmp_cat_long_w
SELECT c.variable_name, c.category, h.household_weight
FROM household_cleaned h
CROSS JOIN LATERAL (
    SELECT 'region' AS variable_name, h.region AS category          UNION ALL
    SELECT 'area',                    h.area                    UNION ALL
    SELECT 'residence_type',          h.residence_type          UNION ALL
    SELECT 'household_composition',   h.household_composition   UNION ALL
    SELECT 'main_income_source',      h.main_income_source      UNION ALL
    SELECT 'head_gender',             h.head_gender             UNION ALL
    SELECT 'head_literacy',           h.head_literacy           UNION ALL
    SELECT 'head_education_level',    h.head_education_level    UNION ALL
    SELECT 'head_marital_status',     h.head_marital_status     UNION ALL
    SELECT 'head_partnership_status', h.head_partnership_status UNION ALL
    SELECT 'head_main_activity',      h.head_main_activity      UNION ALL
    SELECT 'head_employment_status',  h.head_employment_status  UNION ALL
    SELECT 'head_occupation',         h.head_occupation         UNION ALL
    SELECT 'head_industry',           h.head_industry           UNION ALL
    SELECT 'head_employment_sector',  h.head_employment_sector  UNION ALL
    SELECT 'dwelling_type',           h.dwelling_type           UNION ALL
    SELECT 'dwelling_tenure',         h.dwelling_tenure         UNION ALL
    SELECT 'water_facility',          h.water_facility          UNION ALL
    SELECT 'sanitation',              h.sanitation              UNION ALL
    SELECT 'garbage_disposal_method', h.garbage_disposal_method
) c
WHERE h.household_weight IS NOT NULL;

WITH freq AS (
    SELECT variable_name,
           COALESCE(category, '(Not recorded)') AS category,
           COUNT(*) AS sample_households,
           SUM(w)   AS weighted_frequency
    FROM tmp_cat_long_w
    GROUP BY variable_name, COALESCE(category, '(Not recorded)')
),
calc AS (
    SELECT freq.*,
           SUM(weighted_frequency) OVER (PARTITION BY variable_name) AS total_weight,
           SUM(weighted_frequency) OVER (PARTITION BY variable_name
                                         ORDER BY weighted_frequency DESC, category
                                         ROWS UNBOUNDED PRECEDING)  AS cumulative_weight
    FROM freq
)
SELECT variable_name,
       category,
       sample_households,
       ROUND(weighted_frequency, 2)                                        AS weighted_frequency,
       ROUND(weighted_frequency / NULLIF(total_weight, 0), 4)              AS weighted_relative_frequency,
       ROUND(100 * weighted_frequency / NULLIF(total_weight, 0), 2)        AS weighted_pct,
       ROUND(100 * cumulative_weight / NULLIF(total_weight, 0), 2)         AS weighted_cumulative_pct
FROM calc
ORDER BY variable_name, weighted_frequency DESC;

/* 7.4  Weighted asset ownership percentages (binary categorical). */
SELECT a.asset,
       ROUND(100 * SUM(h.household_weight * (a.owned = 1))
                 / NULLIF(SUM(CASE WHEN a.owned IS NOT NULL THEN h.household_weight END), 0), 2)
                                                                           AS weighted_ownership_pct
FROM household_cleaned h
CROSS JOIN LATERAL (
    SELECT 'has_car' AS asset, h.has_car AS owned             UNION ALL
    SELECT 'has_bicycle_or_motorcycle', h.has_bicycle_or_motorcycle UNION ALL
    SELECT 'has_tv',               h.has_tv               UNION ALL
    SELECT 'has_satellite_dish',   h.has_satellite_dish   UNION ALL
    SELECT 'has_media_player',     h.has_media_player     UNION ALL
    SELECT 'has_camera',           h.has_camera           UNION ALL
    SELECT 'has_telephone',        h.has_telephone        UNION ALL
    SELECT 'has_computer',         h.has_computer         UNION ALL
    SELECT 'has_internet',         h.has_internet         UNION ALL
    SELECT 'has_refrigerator',     h.has_refrigerator     UNION ALL
    SELECT 'has_cooker',           h.has_cooker           UNION ALL
    SELECT 'has_microwave',        h.has_microwave        UNION ALL
    SELECT 'has_food_processor',   h.has_food_processor   UNION ALL
    SELECT 'has_washing_machine',  h.has_washing_machine  UNION ALL
    SELECT 'has_dishwasher',       h.has_dishwasher       UNION ALL
    SELECT 'has_air_conditioner',  h.has_air_conditioner  UNION ALL
    SELECT 'has_electric_fan',     h.has_electric_fan     UNION ALL
    SELECT 'has_heater',           h.has_heater           UNION ALL
    SELECT 'has_water_heater',     h.has_water_heater     UNION ALL
    SELECT 'has_sewing_machine',   h.has_sewing_machine   UNION ALL
    SELECT 'has_vacuum_cleaner',   h.has_vacuum_cleaner   UNION ALL
    SELECT 'has_iron',             h.has_iron             UNION ALL
    SELECT 'has_water_motor',      h.has_water_motor      UNION ALL
    SELECT 'has_other_durables',   h.has_other_durables
) a
WHERE h.household_weight IS NOT NULL
GROUP BY a.asset
ORDER BY weighted_ownership_pct DESC;


