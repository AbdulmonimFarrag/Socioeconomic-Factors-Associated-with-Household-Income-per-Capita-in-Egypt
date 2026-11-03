-- =============================================================================
-- EGYPT HOUSEHOLD INCOME AND LIVING CONDITIONS PROJECT
-- COMPLETE DASHBOARD AND ANALYTICAL INSIGHTS
-- =============================================================================
-- This script contains the 12 analyses displayed in the final dashboard,
-- followed by the 6 additional analytical insights from the original file.
-- Every insight follows the same structure:
--   1. Title
--   2. Explanation
--   3. Code and application
--   4. Recommendation
--
-- Prerequisite:
--   Run the SQL cleaning and integration pipeline before executing this file.
-- =============================================================================

USE depi_egypt_raw_import;


-- =============================================================================
-- SECTION 0: PREPARE THE ANALYTICAL VIEWS
-- =============================================================================
-- v_analysis enriches the integrated person-level dataset with consistent
-- employment indicators and ordered education classifications used below.

CREATE OR REPLACE VIEW v_analysis AS
SELECT
    m.*,
    CASE
        WHEN m.labor_force_status = 'Active'
         AND m.main_activity_status = 'Employed' THEN 1
        ELSE 0
    END AS is_employed,
    CASE
        WHEN m.labor_force_status = 'Active'
         AND m.main_activity_status = 'Unemployed' THEN 1
        ELSE 0
    END AS is_unemployed,
    m.education_level AS edu_label,
    CASE m.education_level
        WHEN 'None' THEN 0
        WHEN 'Primary/Lower secondary' THEN 1
        WHEN 'Secondary' THEN 2
        WHEN 'Post secondary or equivalent' THEN 3
        WHEN 'University' THEN 4
        WHEN 'Postgraduate' THEN 5
        ELSE NULL
    END AS edu_rank,
    CASE m.mother_education_level
        WHEN 'None' THEN 0
        WHEN 'Primary/Lower secondary' THEN 1
        WHEN 'Secondary' THEN 2
        WHEN 'Post secondary or equivalent' THEN 3
        WHEN 'University' THEN 4
        WHEN 'Postgraduate' THEN 5
        ELSE NULL
    END AS mother_edu_rank
FROM merged_survey_final m;

-- v_workers_class retains employed working-age individuals and assigns each
-- worker to a household-income quintile using income per capita.

CREATE OR REPLACE VIEW v_workers_class AS
SELECT
    a.household_id,
    a.person_id,
    a.occupation,
    a.employment_sector,
    a.household_weight,
    a.income_per_capita AS hh_income_per_capita,
    NTILE(5) OVER (ORDER BY a.income_per_capita) AS income_quintile
FROM v_analysis a
WHERE a.age BETWEEN 15 AND 64
  AND a.is_employed = 1
  AND a.income_per_capita IS NOT NULL;


-- =============================================================================
-- SECTION 1: DASHBOARD OVERVIEW INSIGHTS
-- =============================================================================


-- =============================================================================
-- INSIGHT 1: WHERE HOUSEHOLD MONEY GOES
-- =============================================================================
-- Explanation:
-- This analysis measures the survey-weighted share of total annual household
-- spending allocated to food, housing, health, education, transport, and the
-- remaining categories. It identifies the expenditure component placing the
-- greatest pressure on household resources and savings capacity.
--
-- Code and application:
-- Expenditure categories are converted into a long format, weighted using the
-- household survey weight, and divided by weighted total expenditure.

WITH spending_categories AS (
    SELECT household_weight, total_expenditure,
           'Food' AS spending_category, food_expenditure AS amount, 1 AS sort_order
    FROM household_cleaned
    UNION ALL
    SELECT household_weight, total_expenditure,
           'Housing', housing_expenditure, 2
    FROM household_cleaned
    UNION ALL
    SELECT household_weight, total_expenditure,
           'Health', health_expenditure, 3
    FROM household_cleaned
    UNION ALL
    SELECT household_weight, total_expenditure,
           'Education', education_expenditure, 4
    FROM household_cleaned
    UNION ALL
    SELECT household_weight, total_expenditure,
           'Transport', transport_expenditure, 5
    FROM household_cleaned
    UNION ALL
    SELECT household_weight, total_expenditure,
           'All other',
           GREATEST(
               total_expenditure
               - COALESCE(food_expenditure, 0)
               - COALESCE(housing_expenditure, 0)
               - COALESCE(health_expenditure, 0)
               - COALESCE(education_expenditure, 0)
               - COALESCE(transport_expenditure, 0),
               0
           ), 6
    FROM household_cleaned
)
SELECT
    spending_category,
    ROUND(SUM(amount * household_weight)
          / NULLIF(SUM(household_weight), 0)) AS avg_annual_amount_per_household,
    ROUND(100 * SUM(amount * household_weight)
          / NULLIF(SUM(total_expenditure * household_weight), 0), 1)
        AS share_of_total_spending_pct
FROM spending_categories
WHERE total_expenditure IS NOT NULL
GROUP BY spending_category, sort_order
ORDER BY sort_order;

-- Recommendation:
-- Reduce pressure from the largest essential-spending category, particularly
-- food where its share is high, while protecting household savings capacity.


-- =============================================================================
-- INSIGHT 2: ASSET OWNERSHIP BREAKDOWN
-- =============================================================================
-- Explanation:
-- This analysis compares ownership rates for major household assets. The
-- strongest and weakest categories reveal differences between basic durable
-- access, digital inclusion, and ownership of productive or mobility assets.
--
-- Code and application:
-- Each binary asset indicator is converted into a common structure and the
-- weighted ownership percentage is calculated for the full household sample.

WITH asset_flags AS (
    SELECT household_weight, 'Mobile phone' AS asset,
           has_telephone AS owns_asset, 1 AS sort_order
    FROM household_cleaned
    UNION ALL SELECT household_weight, 'TV', has_tv, 2 FROM household_cleaned
    UNION ALL SELECT household_weight, 'Refrigerator', has_refrigerator, 3 FROM household_cleaned
    UNION ALL SELECT household_weight, 'Washing machine', has_washing_machine, 4 FROM household_cleaned
    UNION ALL SELECT household_weight, 'Satellite dish', has_satellite_dish, 5 FROM household_cleaned
    UNION ALL SELECT household_weight, 'Water heater', has_water_heater, 6 FROM household_cleaned
    UNION ALL SELECT household_weight, 'Computer', has_computer, 7 FROM household_cleaned
    UNION ALL SELECT household_weight, 'Internet line', has_internet, 8 FROM household_cleaned
    UNION ALL SELECT household_weight, 'Air conditioner', has_air_conditioner, 9 FROM household_cleaned
    UNION ALL SELECT household_weight, 'Car / vehicle', has_car, 10 FROM household_cleaned
)
SELECT
    asset,
    COUNT(*) AS households_with_valid_status,
    ROUND(100 * SUM(owns_asset * household_weight)
          / NULLIF(SUM(household_weight), 0), 1) AS ownership_pct
FROM asset_flags
WHERE owns_asset IS NOT NULL
GROUP BY asset, sort_order
ORDER BY ownership_pct DESC, sort_order;

-- Recommendation:
-- Direct programmes toward the least-owned high-value assets, especially
-- internet and productive mobility assets, while preserving universal access
-- to basic durables.


-- =============================================================================
-- INSIGHT 3: BEYOND INCOME -- DWELLING TENURE PROFILE
-- =============================================================================
-- Explanation:
-- This analysis shows how households are distributed across dwelling-tenure
-- categories. Housing tenure adds context that income alone cannot provide,
-- because owners, renters, and households in free accommodation face different
-- costs, risks, and service needs.
--
-- Code and application:
-- Survey weights are used to estimate the percentage of households in every
-- tenure category and the categories are ranked from most to least common.

SELECT
    dwelling_tenure,
    COUNT(*) AS sampled_households,
    ROUND(SUM(household_weight), 2) AS weighted_households,
    ROUND(100 * SUM(household_weight)
          / SUM(SUM(household_weight)) OVER (), 1) AS household_share_pct
FROM household_cleaned
WHERE dwelling_tenure IS NOT NULL
GROUP BY dwelling_tenure
ORDER BY household_share_pct DESC;

-- Recommendation:
-- Use the dominant tenure category when designing broad household services,
-- while targeting rent support and housing security measures to the smaller,
-- more vulnerable tenure groups.


-- =============================================================================
-- INSIGHT 4: RURAL VERSUS URBAN OUTCOME GAPS
-- =============================================================================
-- Explanation:
-- This analysis compares rural and urban outcomes for literacy, health
-- insurance, school enrolment, internet access, piped water, labour-force
-- participation, unemployment, and food-spending pressure. It identifies the
-- widest place-based service or labour-market gap.
--
-- Code and application:
-- Household indicators and person indicators are calculated separately using
-- the correct survey denominator and then combined into one comparison table.

WITH household_indicators AS (
    SELECT residence_type, 4 AS indicator_order, 'Internet access' AS indicator,
           100 * SUM(has_internet * household_weight)
               / NULLIF(SUM(household_weight), 0) AS indicator_pct
    FROM household_cleaned
    WHERE has_internet IS NOT NULL
    GROUP BY residence_type

    UNION ALL

    SELECT residence_type, 5, 'Piped water',
           100 * SUM((LOWER(water_facility) LIKE '%piped%') * household_weight)
               / NULLIF(SUM(household_weight), 0)
    FROM household_cleaned
    WHERE water_facility IS NOT NULL
    GROUP BY residence_type

    UNION ALL

    SELECT residence_type, 8, 'Food share of spending',
           100 * SUM(food_expenditure * household_weight)
               / NULLIF(SUM(total_expenditure * household_weight), 0)
    FROM household_cleaned
    WHERE total_expenditure > 0
    GROUP BY residence_type
),
person_indicators AS (
    SELECT residence_type, 1 AS indicator_order, 'Literacy (age 10+)' AS indicator,
           100 * SUM((literacy_status = 'Can read AND write') * household_weight)
               / NULLIF(SUM(household_weight), 0) AS indicator_pct
    FROM v_analysis
    WHERE age >= 10 AND literacy_status IS NOT NULL
    GROUP BY residence_type

    UNION ALL

    SELECT residence_type, 2, 'Health insurance',
           100 * SUM(has_health_insurance * household_weight)
               / NULLIF(SUM(household_weight), 0)
    FROM v_analysis
    WHERE has_health_insurance IS NOT NULL
    GROUP BY residence_type

    UNION ALL

    SELECT residence_type, 3, 'School enrolment (age 6-17)',
           100 * SUM((school_attendance_status = 'Yes') * household_weight)
               / NULLIF(SUM(household_weight), 0)
    FROM v_analysis
    WHERE age BETWEEN 6 AND 17
    GROUP BY residence_type

    UNION ALL

    SELECT residence_type, 6, 'Labour-force participation',
           100 * SUM((labor_force_status = 'Active') * household_weight)
               / NULLIF(SUM(household_weight), 0)
    FROM v_analysis
    WHERE age BETWEEN 15 AND 64
    GROUP BY residence_type

    UNION ALL

    SELECT residence_type, 7, 'Unemployment',
           100 * SUM(is_unemployed * household_weight)
               / NULLIF(SUM((is_employed + is_unemployed) * household_weight), 0)
    FROM v_analysis
    WHERE age BETWEEN 15 AND 64
    GROUP BY residence_type
),
combined AS (
    SELECT * FROM household_indicators
    UNION ALL
    SELECT * FROM person_indicators
)
SELECT
    indicator,
    ROUND(MAX(CASE WHEN residence_type = 'Rural' THEN indicator_pct END), 1)
        AS rural_pct,
    ROUND(MAX(CASE WHEN residence_type = 'Urban' THEN indicator_pct END), 1)
        AS urban_pct,
    ROUND(
        MAX(CASE WHEN residence_type = 'Rural' THEN indicator_pct END)
        - MAX(CASE WHEN residence_type = 'Urban' THEN indicator_pct END),
        1
    ) AS rural_minus_urban_pp
FROM combined
GROUP BY indicator, indicator_order
ORDER BY ABS(rural_minus_urban_pp) DESC, indicator_order;

-- Recommendation:
-- Target the widest rural-urban gap first with place-based infrastructure,
-- service-access, or labour-market support rather than a uniform national
-- intervention.


-- =============================================================================
-- INSIGHT 5: INCOME SOURCES BY HOUSEHOLD INCOME QUINTILE
-- =============================================================================
-- Explanation:
-- This analysis compares the composition of household income across income
-- quintiles. It shows whether lower-income households depend mainly on wages
-- while richer households rely more on business, property, rent, or transfers.
--
-- Code and application:
-- Households are divided into five groups using income per capita. Each income
-- component is then expressed as a share of weighted disposable income within
-- the corresponding quintile.

WITH ranked_households AS (
    SELECT
        h.*,
        NTILE(5) OVER (ORDER BY income_per_capita) AS income_quintile
    FROM household_cleaned h
    WHERE income_per_capita IS NOT NULL
      AND disposable_income > 0
),
income_components AS (
    SELECT income_quintile, household_weight, disposable_income,
           'Wages and salaries' AS income_source,
           wage_income AS amount, 1 AS source_order
    FROM ranked_households
    UNION ALL
    SELECT income_quintile, household_weight, disposable_income,
           'Household business', self_employment_income, 2
    FROM ranked_households
    UNION ALL
    SELECT income_quintile, household_weight, disposable_income,
           'Rent and property', rental_income + property_income, 3
    FROM ranked_households
    UNION ALL
    SELECT income_quintile, household_weight, disposable_income,
           'Transfers', transfers_received, 4
    FROM ranked_households
    UNION ALL
    SELECT income_quintile, household_weight, disposable_income,
           'Other income',
           GREATEST(
               disposable_income
               - COALESCE(wage_income, 0)
               - COALESCE(self_employment_income, 0)
               - COALESCE(rental_income, 0)
               - COALESCE(property_income, 0)
               - COALESCE(transfers_received, 0),
               0
           ), 5
    FROM ranked_households
)
SELECT
    CASE income_quintile
        WHEN 1 THEN 'Poorest 20%'
        WHEN 2 THEN 'Lower-middle'
        WHEN 3 THEN 'Middle'
        WHEN 4 THEN 'Upper-middle'
        WHEN 5 THEN 'Richest 20%'
    END AS income_group,
    income_source,
    ROUND(100 * SUM(amount * household_weight)
          / NULLIF(SUM(disposable_income * household_weight), 0), 1)
        AS share_of_group_income_pct
FROM income_components
GROUP BY income_quintile, income_source, source_order
ORDER BY income_quintile, source_order;

-- Recommendation:
-- Protect wage income among the poorest households through better job quality,
-- while widening access to business finance and diversified income sources for
-- lower- and middle-income groups.


-- =============================================================================
-- INSIGHT 6: HOUSEHOLDS MISSING BASIC SERVICES
-- =============================================================================
-- Explanation:
-- This analysis reports how many out of every 100 households lack selected
-- basic services: an internet line, a water heater, and a sewage-connected
-- toilet. Ranking the missing services identifies the most widespread access
-- gap in the selected population.
--
-- Code and application:
-- Each service is converted to a missing-service flag and the survey-weighted
-- share of households without the service is calculated.

WITH missing_services AS (
    SELECT household_weight, 'No internet line' AS missing_service,
           (has_internet = 0) AS is_missing, 1 AS sort_order
    FROM household_cleaned
    WHERE has_internet IS NOT NULL

    UNION ALL

    SELECT household_weight, 'No water heater',
           (has_water_heater = 0), 2
    FROM household_cleaned
    WHERE has_water_heater IS NOT NULL

    UNION ALL

    SELECT household_weight, 'No sewage-connected toilet',
           (sanitation IS NULL OR sanitation <> 'Toilet, sewage-connected'), 3
    FROM household_cleaned
)
SELECT
    missing_service,
    ROUND(100 * SUM(is_missing * household_weight)
          / NULLIF(SUM(household_weight), 0), 1) AS households_missing_pct,
    ROUND(SUM(is_missing * household_weight), 2) AS weighted_households_missing
FROM missing_services
GROUP BY missing_service, sort_order
ORDER BY households_missing_pct DESC, sort_order;

-- Recommendation:
-- Address the most widespread missing basic first; where internet is the
-- largest gap, extend affordable broadband, devices, and data plans, while
-- coordinating sanitation and safe-water improvements in underserved areas.


-- =============================================================================
-- INSIGHT 7: HOUSEHOLD CAPACITY AND RESOURCE PROFILE
-- =============================================================================
-- Explanation:
-- This analysis summarises household size, earners, dependency pressure,
-- housing-spending share, income per person, savings, piped-water access, and
-- receipt of money transfers. The people-per-earner ratio shows resource
-- pressure more clearly than income alone.
--
-- Code and application:
-- Survey-weighted household averages and aggregate ratios are calculated in a
-- single profile for direct use in KPI cards and household comparisons.

SELECT
    ROUND(SUM(household_size * household_weight)
          / NULLIF(SUM(household_weight), 0), 2) AS people_per_household,
    ROUND(SUM(number_of_earners * household_weight)
          / NULLIF(SUM(household_weight), 0), 2) AS earners_per_household,
    ROUND(SUM(household_size * household_weight)
          / NULLIF(SUM(number_of_earners * household_weight), 0), 2)
        AS people_per_earner,
    ROUND(100 * SUM(housing_expenditure * household_weight)
          / NULLIF(SUM(total_expenditure * household_weight), 0), 1)
        AS housing_share_of_spending_pct,
    ROUND(SUM(disposable_income * household_weight)
          / NULLIF(SUM(household_size * household_weight), 0))
        AS annual_income_per_person,
    ROUND(100 * SUM((disposable_income - total_expenditure) * household_weight)
          / NULLIF(SUM(disposable_income * household_weight), 0), 1)
        AS aggregate_savings_rate_pct,
    ROUND(100 * SUM((transfers_received > 0) * household_weight)
          / NULLIF(SUM(household_weight), 0), 1)
        AS households_receiving_transfers_pct,
    ROUND(100 * SUM((LOWER(water_facility) LIKE '%piped%') * household_weight)
          / NULLIF(SUM(household_weight), 0), 1) AS piped_water_pct
FROM household_cleaned
WHERE household_weight > 0;

-- Recommendation:
-- Prioritise households with the highest people-per-earner ratio through job
-- matching, childcare, skills support, and carefully targeted income support.


-- =============================================================================
-- INSIGHT 8: WATER, SOCIAL PROTECTION, AND HOUSEHOLD HEALTH BURDEN
-- =============================================================================
-- Explanation:
-- This analysis tests whether water access, social protection, and household
-- health burden overlap. It identifies households that simultaneously lack
-- piped water or protection and contain a member with a disability or chronic
-- disease, revealing combined vulnerability rather than isolated problems.
--
-- Code and application:
-- Person records are collapsed to one row per household using any-member flags,
-- joined to household water access, and summarised across the eight possible
-- water-protection-health combinations.

WITH person_household_flags AS (
    SELECT
        household_id,
        MAX(has_social_security = 1) AS any_social_protection,
        MAX(
            has_chronic_disease = 1
            OR (disability_status IS NOT NULL AND disability_status <> 'No')
        ) AS any_health_burden
    FROM v_analysis
    GROUP BY household_id
),
household_vulnerability AS (
    SELECT
        h.household_id,
        h.household_weight,
        CASE
            WHEN LOWER(h.water_facility) LIKE '%piped%' THEN 'Piped water'
            ELSE 'Non-piped water'
        END AS water_status,
        CASE
            WHEN p.any_social_protection = 1 THEN 'Protected'
            ELSE 'Not protected'
        END AS protection_status,
        CASE
            WHEN p.any_health_burden = 1 THEN 'Health burden'
            ELSE 'No reported health burden'
        END AS health_status
    FROM household_cleaned h
    JOIN person_household_flags p ON p.household_id = h.household_id
)
SELECT
    water_status,
    protection_status,
    health_status,
    COUNT(*) AS sampled_households,
    ROUND(SUM(household_weight), 2) AS weighted_households,
    ROUND(100 * SUM(household_weight)
          / SUM(SUM(household_weight)) OVER (), 1) AS share_of_all_households_pct
FROM household_vulnerability
GROUP BY water_status, protection_status, health_status
ORDER BY water_status, protection_status, health_status;

-- Recommendation:
-- Do not target water access alone. Pair remaining water and sanitation upgrades
-- with social-protection enrolment, primary-care outreach, and chronic-disease
-- screening for households facing combined vulnerability.


-- =============================================================================
-- SECTION 3: DASHBOARD PEOPLE INSIGHTS
-- =============================================================================


-- =============================================================================
-- INSIGHT 9: AGE STRUCTURE BY GENDER
-- =============================================================================
-- Explanation:
-- This analysis describes the population distribution across five age groups
-- for males and females. The largest group identifies the dominant life stage
-- around which education, employment, and health services should be planned.
--
-- Code and application:
-- Every person is assigned to a dashboard age band and survey weights are used
-- to calculate each gender-age group's share of the full population.

WITH age_groups AS (
    SELECT
        gender,
        household_weight,
        CASE
            WHEN age BETWEEN 0 AND 14 THEN '0-14'
            WHEN age BETWEEN 15 AND 29 THEN '15-29'
            WHEN age BETWEEN 30 AND 44 THEN '30-44'
            WHEN age BETWEEN 45 AND 59 THEN '45-59'
            WHEN age >= 60 THEN '60+'
        END AS age_group,
        CASE
            WHEN age BETWEEN 0 AND 14 THEN 1
            WHEN age BETWEEN 15 AND 29 THEN 2
            WHEN age BETWEEN 30 AND 44 THEN 3
            WHEN age BETWEEN 45 AND 59 THEN 4
            WHEN age >= 60 THEN 5
        END AS age_order
    FROM v_analysis
    WHERE age IS NOT NULL
)
SELECT
    gender,
    age_group,
    COUNT(*) AS sampled_people,
    ROUND(SUM(household_weight), 2) AS weighted_people,
    ROUND(100 * SUM(household_weight)
          / SUM(SUM(household_weight)) OVER (), 1) AS share_of_population_pct,
    ROUND(100 * SUM(household_weight)
          / SUM(SUM(household_weight)) OVER (PARTITION BY gender), 1)
        AS share_within_gender_pct
FROM age_groups
GROUP BY gender, age_group, age_order
ORDER BY gender, age_order;

-- Recommendation:
-- Align education, employment, and health investment with the largest age
-- group, while ensuring that service capacity anticipates the next life-stage
-- transition of this population cohort.


-- =============================================================================
-- INSIGHT 10: INCOME PER CAPITA BY HOUSEHOLD HEAD EDUCATION
-- =============================================================================
-- Explanation:
-- This analysis measures the education gradient in household income per capita.
-- It compares the mean, median, and middle distribution for each head-education
-- group to show how education is associated with earning opportunity and
-- economic mobility.
--
-- Code and application:
-- Households are ranked within each head-education group to estimate the median,
-- while survey weights are applied to the group mean.

WITH education_income AS (
    SELECT
        head_education_level,
        income_per_capita,
        household_weight,
        CASE head_education_level
            WHEN 'None' THEN 0
            WHEN 'Primary/Lower secondary' THEN 1
            WHEN 'Secondary' THEN 2
            WHEN 'Post secondary or equivalent' THEN 3
            WHEN 'University' THEN 4
            WHEN 'Postgraduate' THEN 5
            ELSE 6
        END AS education_order,
        ROW_NUMBER() OVER (
            PARTITION BY head_education_level ORDER BY income_per_capita
        ) AS rn,
        COUNT(*) OVER (PARTITION BY head_education_level) AS cnt
    FROM household_cleaned
    WHERE head_education_level IS NOT NULL
      AND income_per_capita IS NOT NULL
)
SELECT
    head_education_level,
    COUNT(*) AS sampled_households,
    ROUND(SUM(income_per_capita * household_weight)
          / NULLIF(SUM(household_weight), 0)) AS weighted_mean_income_per_capita,
    ROUND(AVG(
        CASE
            WHEN rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
            THEN income_per_capita
        END
    )) AS median_income_per_capita
FROM education_income
GROUP BY head_education_level, education_order
HAVING COUNT(*) >= 30
ORDER BY education_order;

-- Recommendation:
-- Maintain literacy gains and connect adult learning, technical education, and
-- job-linked skills programmes to better-quality employment and higher earnings.


-- =============================================================================
-- INSIGHT 11: HEALTH INSURANCE AND CHRONIC ILLNESS BY AGE GROUP
-- =============================================================================
-- Explanation:
-- This analysis compares health-insurance coverage with chronic-disease burden
-- in each age group. A positive burden-minus-coverage gap identifies the age
-- group where health need is furthest ahead of financial protection.
--
-- Code and application:
-- Individuals are assigned to the five dashboard age groups and both indicators
-- are calculated using survey weights and a common age-group denominator.

WITH age_health AS (
    SELECT
        household_weight,
        has_health_insurance,
        has_chronic_disease,
        CASE
            WHEN age BETWEEN 0 AND 14 THEN '0-14'
            WHEN age BETWEEN 15 AND 29 THEN '15-29'
            WHEN age BETWEEN 30 AND 44 THEN '30-44'
            WHEN age BETWEEN 45 AND 59 THEN '45-59'
            WHEN age >= 60 THEN '60+'
        END AS age_group,
        CASE
            WHEN age BETWEEN 0 AND 14 THEN 1
            WHEN age BETWEEN 15 AND 29 THEN 2
            WHEN age BETWEEN 30 AND 44 THEN 3
            WHEN age BETWEEN 45 AND 59 THEN 4
            WHEN age >= 60 THEN 5
        END AS age_order
    FROM v_analysis
    WHERE age IS NOT NULL
)
SELECT
    age_group,
    COUNT(*) AS sampled_people,
    ROUND(100 * SUM(has_health_insurance * household_weight)
          / NULLIF(SUM(household_weight), 0), 1) AS insurance_coverage_pct,
    ROUND(100 * SUM(has_chronic_disease * household_weight)
          / NULLIF(SUM(household_weight), 0), 1) AS chronic_disease_pct,
    ROUND(100 * SUM((has_chronic_disease - has_health_insurance) * household_weight)
          / NULLIF(SUM(household_weight), 0), 1) AS burden_minus_coverage_pp
FROM age_health
GROUP BY age_group, age_order
ORDER BY age_order;

-- Recommendation:
-- Expand age-targeted screening and insurance enrolment in the age group where
-- chronic-disease burden exceeds coverage by the widest margin.


-- =============================================================================
-- INSIGHT 12: GENDER PROFILE ON KEY OUTCOMES
-- =============================================================================
-- Explanation:
-- This analysis compares male and female literacy, school enrolment, labour-
-- force participation, unemployment, health insurance, and social security.
-- It highlights the largest visible gender gap, especially the economic cost
-- of unequal participation in paid work.
--
-- Code and application:
-- Each indicator uses its appropriate age and labour-force denominator, with
-- survey weights applied separately for males and females.

SELECT
    gender,
    ROUND(100 * SUM(CASE WHEN age >= 10
                         THEN (literacy_status = 'Can read AND write') * household_weight END)
          / NULLIF(SUM(CASE WHEN age >= 10 THEN household_weight END), 0), 1)
        AS literacy_age10plus_pct,
    ROUND(100 * SUM(CASE WHEN age BETWEEN 6 AND 17
                         THEN (school_attendance_status = 'Yes') * household_weight END)
          / NULLIF(SUM(CASE WHEN age BETWEEN 6 AND 17 THEN household_weight END), 0), 1)
        AS school_enrolment_age6_17_pct,
    ROUND(100 * SUM(CASE WHEN age BETWEEN 15 AND 64
                         THEN (labor_force_status = 'Active') * household_weight END)
          / NULLIF(SUM(CASE WHEN age BETWEEN 15 AND 64 THEN household_weight END), 0), 1)
        AS labour_force_participation_pct,
    ROUND(100 * SUM(CASE WHEN age BETWEEN 15 AND 64
                         THEN is_unemployed * household_weight END)
          / NULLIF(SUM(CASE WHEN age BETWEEN 15 AND 64
                            THEN (is_employed + is_unemployed) * household_weight END), 0), 1)
        AS unemployment_rate_pct,
    ROUND(100 * SUM(has_health_insurance * household_weight)
          / NULLIF(SUM(household_weight), 0), 1) AS health_insurance_pct,
    ROUND(100 * SUM(has_social_security * household_weight)
          / NULLIF(SUM(household_weight), 0), 1) AS social_security_pct
FROM v_analysis
WHERE gender IS NOT NULL
GROUP BY gender
ORDER BY gender;

-- Recommendation:
-- Reduce the gender participation gap through affordable childcare, safe
-- transport, flexible work arrangements, anti-discrimination measures, and
-- skills financing linked to real job opportunities.


-- =============================================================================
-- SECTION 4: ADDITIONAL ANALYTICAL INSIGHTS FROM THE ORIGINAL FILE
-- =============================================================================


-- =============================================================================
-- INSIGHT 13: FEMALE-HEADED HOUSEHOLDS -- TOTAL INCOME VS INCOME PER CAPITA
-- =============================================================================
-- Explanation:
-- This analysis tests whether higher per-capita income among female-headed
-- households is mainly associated with smaller household size rather than
-- higher total disposable income. It compares median income, household size,
-- single-person households, earners, and the age of the household head.
--
-- Code and application:
-- Separate row-number rankings calculate median total income and median income
-- per person for male- and female-headed households.

WITH r AS (
    SELECT
        head_gender,
        household_size,
        number_of_earners,
        head_age,
        disposable_income,
        income_per_capita,
        ROW_NUMBER() OVER (
            PARTITION BY head_gender ORDER BY disposable_income
        ) AS rn_total,
        ROW_NUMBER() OVER (
            PARTITION BY head_gender ORDER BY income_per_capita
        ) AS rn_pc,
        COUNT(*) OVER (PARTITION BY head_gender) AS cnt
    FROM household_cleaned
    WHERE disposable_income IS NOT NULL
      AND household_size > 0
)
SELECT
    head_gender,
    COUNT(*) AS households,
    ROUND(AVG(household_size), 2) AS avg_household_size,
    ROUND(100 * AVG(household_size = 1), 1) AS pct_single_person_households,
    ROUND(AVG(CASE
        WHEN rn_total IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
        THEN disposable_income
    END)) AS median_total_income,
    ROUND(AVG(CASE
        WHEN rn_pc IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
        THEN income_per_capita
    END)) AS median_income_per_person,
    ROUND(AVG(number_of_earners), 2) AS avg_earners,
    ROUND(AVG(head_age), 1) AS avg_head_age
FROM r
GROUP BY head_gender;

-- Recommendation:
-- Do not interpret higher income per capita as greater household security
-- without considering family size, the number of earners, head age, income
-- source, and the household's ability to absorb financial shocks.


-- =============================================================================
-- INSIGHT 14: OCCUPATION AND SECTOR PROFILES OF HIGH-INCOME WORKERS
-- =============================================================================
-- Explanation:
-- This analysis identifies occupation-sector combinations most strongly
-- represented in the richest household-income quintile. Groups with fewer than
-- 30 worker records are excluded to reduce small-sample instability.
--
-- Code and application:
-- Employed people aged 15-64 are compared using their household income per
-- capita, with weighted shares reported for the richest 20% and poorest 40%.

SELECT
    occupation,
    CASE
        WHEN employment_sector IN ('Government', 'Public sector')
            THEN 'Government/Public'
        ELSE 'Private/Other'
    END AS sector_group,
    COUNT(*) AS workers,
    ROUND(AVG(hh_income_per_capita)) AS avg_income_pc,
    ROUND(100 * SUM(CASE WHEN income_quintile = 5 THEN household_weight END)
          / NULLIF(SUM(household_weight), 0), 1) AS pct_in_richest,
    ROUND(100 * SUM(CASE WHEN income_quintile <= 2 THEN household_weight END)
          / NULLIF(SUM(household_weight), 0), 1) AS pct_in_poorest40
FROM v_workers_class
GROUP BY occupation, sector_group
HAVING COUNT(*) >= 30
ORDER BY pct_in_richest DESC;

-- Recommendation:
-- Expand access to high-return occupations through job-linked training and
-- career pathways, while improving pay, productivity, and formal protection in
-- occupations concentrated in the poorest 40%.


-- =============================================================================
-- INSIGHT 15: EMPLOYMENT AND UNEMPLOYMENT RATES BY GOVERNORATE
-- =============================================================================
-- Explanation:
-- This analysis compares labour-market outcomes across governorates for people
-- aged 15-64. Employment uses the full working-age population as its denominator,
-- while unemployment uses only the active labour force.
--
-- Code and application:
-- Survey weights produce representative employment and unemployment rates for
-- every governorate or region in the integrated person-level dataset.

SELECT
    region,
    COUNT(*) AS n,
    ROUND(100 * SUM(is_employed * household_weight)
          / NULLIF(SUM(household_weight), 0), 2) AS employment_rate,
    ROUND(100 * SUM(is_unemployed * household_weight)
          / NULLIF(SUM((is_employed + is_unemployed) * household_weight), 0), 2)
        AS unemployment_rate
FROM v_analysis
WHERE age BETWEEN 15 AND 64
GROUP BY region
ORDER BY employment_rate DESC;

-- Recommendation:
-- Use governorate-specific job creation, training, transport, and enterprise
-- support, and investigate whether low employment reflects unemployment or low
-- labour-force participation before selecting the intervention.


-- =============================================================================
-- INSIGHT 16: HEALTH INSURANCE AND SOCIAL SECURITY BY INCOME GROUP
-- =============================================================================
-- Explanation:
-- This analysis compares protection coverage across household-income quintiles.
-- Adult indicators are shown separately because a high share of children in
-- poorer households can make all-age insurance coverage appear stronger than
-- the protection available to working adults.
--
-- Code and application:
-- Household income quintiles are joined to person records and weighted coverage
-- rates are calculated for all ages and for adults aged 18 or older.

WITH hq AS (
    SELECT
        household_id,
        NTILE(5) OVER (ORDER BY income_per_capita) AS income_quintile
    FROM household_cleaned
    WHERE income_per_capita IS NOT NULL
)
SELECT
    CASE hq.income_quintile
        WHEN 1 THEN 'Poorest 20%'
        WHEN 2 THEN 'Lower-middle'
        WHEN 3 THEN 'Middle'
        WHEN 4 THEN 'Upper-middle'
        WHEN 5 THEN 'Richest 20%'
    END AS income_group,
    COUNT(*) AS n_all,
    ROUND(100 * SUM(CASE WHEN a.age < 15 THEN a.household_weight END)
          / NULLIF(SUM(a.household_weight), 0), 1) AS pct_children,
    ROUND(100 * SUM(a.has_health_insurance * a.household_weight)
          / NULLIF(SUM(a.household_weight), 0), 1) AS insured_all_ages_pct,
    ROUND(100 * SUM(CASE WHEN a.age >= 18
                         THEN a.has_health_insurance * a.household_weight END)
          / NULLIF(SUM(CASE WHEN a.age >= 18 THEN a.household_weight END), 0), 1)
        AS insured_adults_pct,
    ROUND(100 * SUM(CASE WHEN a.age >= 18
                         THEN a.has_social_security * a.household_weight END)
          / NULLIF(SUM(CASE WHEN a.age >= 18 THEN a.household_weight END), 0), 1)
        AS social_security_adults_pct
FROM v_analysis a
JOIN hq ON hq.household_id = a.household_id
GROUP BY hq.income_quintile
ORDER BY hq.income_quintile;

-- Recommendation:
-- Prioritise low-income adults and informal workers for simplified insurance
-- enrolment, subsidised contributions, and portable social-security coverage.


-- =============================================================================
-- INSIGHT 17: REGIONAL INSURANCE GAPS AND MOST-AFFECTED OCCUPATIONS
-- =============================================================================
-- Explanation:
-- This analysis measures health-insurance coverage by region and identifies the
-- occupation contributing the largest weighted number of uninsured employed
-- people aged 15-64. It distinguishes the biggest contributor from the group
-- with the lowest coverage rate.
--
-- Code and application:
-- Occupations are ranked within each region by their weighted uninsured worker
-- count, and the leading occupation is combined with regional coverage.

WITH region_cov AS (
    SELECT
        region,
        ROUND(100 * SUM(has_health_insurance * household_weight)
              / NULLIF(SUM(household_weight), 0), 1) AS insured_pct
    FROM v_analysis
    GROUP BY region
),
occ AS (
    SELECT
        region,
        occupation,
        SUM(household_weight) AS w_total,
        COALESCE(
            SUM(CASE WHEN has_health_insurance = 0 THEN household_weight END),
            0
        ) AS w_uninsured
    FROM v_analysis
    WHERE age BETWEEN 15 AND 64
      AND is_employed = 1
    GROUP BY region, occupation
),
ranked AS (
    SELECT
        occ.*,
        SUM(w_uninsured) OVER (PARTITION BY region) AS region_uninsured,
        ROW_NUMBER() OVER (
            PARTITION BY region ORDER BY w_uninsured DESC
        ) AS rn
    FROM occ
)
SELECT
    c.region,
    c.insured_pct,
    r.occupation AS main_occupation_without_insurance,
    ROUND(100 * (1 - r.w_uninsured / NULLIF(r.w_total, 0)), 1)
        AS occupation_insured_pct,
    ROUND(100 * r.w_uninsured / NULLIF(r.region_uninsured, 0), 1)
        AS share_of_uninsured_workers_pct
FROM region_cov c
JOIN ranked r ON r.region = c.region AND r.rn = 1
ORDER BY c.insured_pct;

-- Recommendation:
-- In each region, begin enrolment and formalisation campaigns with the occupation
-- contributing the largest number of uninsured workers, then address smaller
-- occupations with exceptionally low coverage.


-- =============================================================================
-- INSIGHT 18: INTERGENERATIONAL EDUCATION BY MOTHER'S EDUCATION LEVEL
-- =============================================================================
-- Explanation:
-- This analysis examines adult children's educational attainment within each
-- maternal-education group. It highlights the relationship between a mother's
-- education and the educational outcomes of the next generation.
--
-- Code and application:
-- Survey weights calculate the child-education distribution within each mother-
-- education level for adults aged 25-64 whose education is largely complete.

SELECT
    mother_education_level,
    edu_label AS child_education,
    COUNT(*) AS n,
    ROUND(100 * SUM(household_weight)
          / SUM(SUM(household_weight)) OVER (
                PARTITION BY mother_education_level
            ), 2) AS pct_within_mother_level
FROM v_analysis
WHERE age BETWEEN 25 AND 64
  AND edu_rank IS NOT NULL
  AND mother_edu_rank IS NOT NULL
GROUP BY mother_education_level, mother_edu_rank, edu_label, edu_rank
ORDER BY mother_edu_rank, edu_rank;

-- Recommendation:
-- Invest in girls' education, adult literacy for mothers, school retention, and
-- targeted support for children whose parents have low educational attainment
-- to strengthen upward educational mobility across generations.
