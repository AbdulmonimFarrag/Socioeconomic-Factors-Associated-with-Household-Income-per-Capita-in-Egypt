-- =============================================================================
-- EGYPT HOUSEHOLD INCOME AND LIVING CONDITIONS PROJECT
-- Complete SQL Data Cleaning, Feature Engineering and Integration Pipeline
-- =============================================================================

USE depi_egypt_raw_import;


-- =============================================================================
-- SECTION 0: STANDARDIZE RAW DATASET REFERENCES
-- =============================================================================
-- These views provide stable source names for the complete SQL workflow.

CREATE OR REPLACE VIEW household_raw AS
SELECT *
FROM stg_household_raw_2021_all;


CREATE OR REPLACE VIEW individual_raw AS
SELECT *
FROM stg_individual_raw_2021;


-- Remove previous analytical outputs to make the script safely rerunnable.

DROP TABLE IF EXISTS merged_survey_final;
DROP TABLE IF EXISTS household_cleaned;
DROP TABLE IF EXISTS individual_cleaned;


-- =============================================================================
-- SECTION 1: CLEAN INDIVIDUAL DATA
-- =============================================================================
-- The preparation stage standardizes identifiers, numeric values and text fields.
-- Survey Year and Country are excluded because they are constant in this dataset.

CREATE TABLE individual_cleaned AS
WITH prepared AS (
    SELECT
        CAST(NULLIF(TRIM(unique_unit_identifier), '') AS UNSIGNED)
            AS household_id,

        CAST(NULLIF(TRIM(person_identifier), '') AS UNSIGNED)
            AS person_id,

        CAST(NULLIF(TRIM(household_weight), '') AS DECIMAL(18,6))
            AS household_weight,

        NULLIF(TRIM(region), '') AS region,
        NULLIF(TRIM(area), '') AS area,
        NULLIF(TRIM(urban_rural_residence), '') AS residence_type,

        CAST(NULLIF(TRIM(age), '') AS UNSIGNED) AS age,
        NULLIF(TRIM(gender), '') AS gender,

        NULLIF(
            NULLIF(TRIM(marital_status_standardized_version), ''),
            'None'
        ) AS marital_status_raw,

        NULLIF(
            NULLIF(TRIM(relationship_to_head_standardized_version), ''),
            'None'
        ) AS relationship_to_head,

        NULLIF(
            NULLIF(TRIM(literacy_status), ''),
            'None'
        ) AS literacy_status_raw,

        CASE
            WHEN LOWER(TRIM(ever_attended_school)) IN ('yes', 'true')
                THEN 'Yes'
            WHEN LOWER(TRIM(ever_attended_school)) IN ('no', 'false')
                THEN 'No'
            ELSE NULL
        END AS ever_attended_school_raw,

        NULLIF(
            NULLIF(TRIM(educational_level_standardized_version), ''),
            'None'
        ) AS education_level_raw,

        CAST(
            NULLIF(TRIM(number_of_effective_years_of_schooling), '')
            AS SIGNED
        ) AS years_of_schooling_raw,

        CASE
            WHEN LOWER(TRIM(school_attendance_status)) IN ('yes', 'true')
                THEN 'Yes'
            WHEN LOWER(TRIM(school_attendance_status)) IN ('no', 'false')
                THEN 'No'
            ELSE NULL
        END AS school_attendance_raw,

        NULLIF(
            NULLIF(TRIM(level_of_schooling_presently_attending), ''),
            'None'
        ) AS current_school_level_raw,

        NULLIF(
            NULLIF(TRIM(type_of_school_attending), ''),
            'None'
        ) AS school_type_raw,

        CASE
            WHEN LOWER(TRIM(disability_status)) IN ('yes', 'true')
                THEN 'Yes'
            WHEN LOWER(TRIM(disability_status)) IN ('no', 'false')
                THEN 'No'
            ELSE NULLIF(TRIM(disability_status), '')
        END AS disability_status,

        NULLIF(
            NULLIF(TRIM(type_of_disability), ''),
            'None'
        ) AS disability_type_raw,

        CASE
            WHEN TRIM(chronic_disease) = 'Yes' THEN 1
            WHEN TRIM(chronic_disease) = 'No' THEN 0
            ELSE NULL
        END AS has_chronic_disease,

        TRIM(health_insurance) AS health_insurance_raw,
        TRIM(kind_of_health_insurance_governmental) AS insurance_government_raw,
        TRIM(kind_of_health_insurance_private) AS insurance_private_raw,
        TRIM(kind_of_health_insurance_other) AS insurance_other_raw,

        CASE
            WHEN TRIM(social_security) = 'Yes' THEN 1
            ELSE 0
        END AS has_social_security,

        NULLIF(
            NULLIF(
                TRIM(labor_force_status_in_the_current_period),
                ''
            ),
            'None'
        ) AS labor_force_status_raw,

        NULLIF(
            NULLIF(
                TRIM(
                    main_activity_status_in_the_current_period_standardized_vers
                ),
                ''
            ),
            'None'
        ) AS main_activity_status_raw,

        NULLIF(
            NULLIF(TRIM(status_of_employment), ''),
            'None'
        ) AS employment_status_raw,

        NULLIF(
            NULLIF(
                TRIM(
                    occupation_classification_for_the_main_job_standardized_vers
                ),
                ''
            ),
            'None'
        ) AS occupation_raw,

        NULLIF(
            NULLIF(
                TRIM(
                    industry_classification_for_the_main_job_standardized_versio
                ),
                ''
            ),
            'None'
        ) AS industry_raw,

        NULLIF(
            NULLIF(
                TRIM(sector_of_employment_standardized_version),
                ''
            ),
            'None'
        ) AS employment_sector_raw,

        NULLIF(TRIM(father_present_at_home), '')
            AS father_present_at_home_raw,

        CAST(NULLIF(TRIM(id_of_the_father), '') AS UNSIGNED)
            AS father_id,

        CAST(NULLIF(TRIM(age_of_the_father), '') AS UNSIGNED)
            AS father_age,

        NULLIF(TRIM(marital_status_of_the_father_standardized_version), '')
            AS father_marital_status_raw,

        NULLIF(TRIM(educational_level_of_the_father_standardized_version), '')
            AS father_education_level,

        NULLIF(TRIM(main_activity_of_the_father_standardized_version), '')
            AS father_main_activity_raw,

        NULLIF(TRIM(employment_status_of_the_father_standardized_version), '')
            AS father_employment_status,

        NULLIF(
            TRIM(
                occupation_classification_for_the_main_job_of_the_father_sta
            ),
            ''
        ) AS father_occupation_raw,

        NULLIF(
            TRIM(
                industry_classification_for_the_main_job_of_the_father_stand
            ),
            ''
        ) AS father_industry_raw,

        NULLIF(
            TRIM(sector_of_employment_of_the_father_standardized_version),
            ''
        ) AS father_employment_sector_raw,

        NULLIF(TRIM(mother_present_at_home), '')
            AS mother_present_at_home_raw,

        CAST(NULLIF(TRIM(id_of_the_mother), '') AS UNSIGNED)
            AS mother_id,

        CAST(NULLIF(TRIM(age_of_the_mother), '') AS UNSIGNED)
            AS mother_age,

        NULLIF(TRIM(marital_status_of_the_mother_standardized_version), '')
            AS mother_marital_status_raw,

        NULLIF(TRIM(educational_level_of_the_mother_standardized_version), '')
            AS mother_education_level_raw,

        NULLIF(TRIM(main_activity_of_the_mother_standardized_version), '')
            AS mother_main_activity_raw,

        NULLIF(TRIM(employment_status_of_the_mother_standardized_version), '')
            AS mother_employment_status_raw,

        NULLIF(
            TRIM(
                occupation_classification_for_the_main_job_of_the_mother_sta
            ),
            ''
        ) AS mother_occupation_raw,

        NULLIF(
            TRIM(
                industry_classification_for_the_main_job_of_the_mother_stand
            ),
            ''
        ) AS mother_industry_raw,

        NULLIF(
            TRIM(sector_of_employment_of_the_mother_standardized_version),
            ''
        ) AS mother_employment_sector_raw

    FROM individual_raw
),

primary_school_reference AS (
    SELECT
        ROUND(AVG(years_of_schooling_raw)) AS primary_school_years

    FROM prepared

    WHERE age >= 10
      AND school_attendance_raw = 'Yes'
      AND LOWER(current_school_level_raw) = 'primary'
      AND years_of_schooling_raw IS NOT NULL
),

education_level_reference AS (
    SELECT
        education_level_raw,
        ROUND(AVG(years_of_schooling_raw)) AS average_schooling_years

    FROM prepared

    WHERE age >= 10
      AND education_level_raw IS NOT NULL
      AND years_of_schooling_raw IS NOT NULL

    GROUP BY education_level_raw
),

cleaned AS (
    SELECT
        p.household_id,
        p.person_id,
        p.household_weight,

        p.region,
        p.area,
        p.residence_type,

        p.age,
        p.gender,

        CASE
            WHEN p.marital_status_raw IS NULL AND p.age < 18
                THEN 'Minor'
            ELSE p.marital_status_raw
        END AS marital_status,

        p.relationship_to_head,

        CASE
            WHEN p.literacy_status_raw IS NULL AND p.age < 10
                THEN 'Not applicable - under 10'
            ELSE p.literacy_status_raw
        END AS literacy_status,

        CASE
            WHEN p.ever_attended_school_raw IS NULL AND p.age < 4
                THEN 'Not applicable'
            ELSE p.ever_attended_school_raw
        END AS ever_attended_school,

        CASE
            WHEN p.education_level_raw IS NULL AND p.age < 10
                THEN 'Not applicable - under 10'
            ELSE p.education_level_raw
        END AS education_level,

        CASE
            WHEN p.years_of_schooling_raw IS NOT NULL
                THEN p.years_of_schooling_raw

            WHEN p.age < 4
                THEN 0

            WHEN p.age BETWEEN 4 AND 9
                 AND (
                     p.school_attendance_raw = 'Yes'
                     OR (
                         p.school_attendance_raw = 'No'
                         AND p.ever_attended_school_raw = 'Yes'
                     )
                 )
                THEN CAST(r.primary_school_years AS SIGNED)

            WHEN p.age BETWEEN 4 AND 9
                 AND p.school_attendance_raw = 'No'
                 AND p.ever_attended_school_raw = 'No'
                THEN 0

            WHEN p.age >= 10
                 AND p.education_level_raw IS NOT NULL
                THEN CAST(e.average_schooling_years AS SIGNED)

            ELSE NULL
        END AS years_of_schooling,

        CASE
            WHEN p.school_attendance_raw IS NULL AND p.age < 4
                THEN 'Too young for school'
            ELSE p.school_attendance_raw
        END AS school_attendance_status,

        CASE
            WHEN p.current_school_level_raw IS NOT NULL
                THEN p.current_school_level_raw

            WHEN p.age < 4
                THEN 'Too young for school'

            WHEN p.school_attendance_raw = 'No'
                THEN 'Not currently attending'

            WHEN p.school_attendance_raw = 'Yes'
                 AND p.years_of_schooling_raw BETWEEN 0 AND 2
                THEN 'Kindergarten'

            WHEN p.school_attendance_raw = 'Yes'
                 AND p.years_of_schooling_raw BETWEEN 3 AND 8
                THEN 'Primary'

            WHEN p.school_attendance_raw = 'Yes'
                 AND p.years_of_schooling_raw BETWEEN 9 AND 11
                THEN 'Preparatory'

            WHEN p.school_attendance_raw = 'Yes'
                 AND p.years_of_schooling_raw BETWEEN 12 AND 14
                THEN 'Secondary'

            WHEN p.school_attendance_raw = 'Yes'
                 AND p.years_of_schooling_raw >= 15
                THEN 'University'

            ELSE 'Not stated'
        END AS current_school_level,

        CASE
            WHEN p.school_type_raw IS NOT NULL
                THEN p.school_type_raw

            WHEN p.school_attendance_raw = 'No'
                THEN 'Not attending school'

            ELSE 'Not stated'
        END AS school_type,

        p.disability_status,

        COALESCE(
            p.disability_type_raw,
            'Not stated'
        ) AS disability_type,

        p.has_chronic_disease,

        CASE
            WHEN p.insurance_other_raw = 'Yes'
                THEN 'Other'
            WHEN p.insurance_private_raw = 'Yes'
                THEN 'Private'
            WHEN p.insurance_government_raw = 'Yes'
                THEN 'Governmental'
            WHEN p.health_insurance_raw = 'Yes'
                THEN 'Unknown insurance type'
            ELSE 'No health insurance'
        END AS insurance_type,

        CASE
            WHEN p.insurance_other_raw = 'Yes'
              OR p.insurance_private_raw = 'Yes'
              OR p.insurance_government_raw = 'Yes'
              OR p.health_insurance_raw = 'Yes'
                THEN 1
            ELSE 0
        END AS has_health_insurance,

        p.has_social_security,

        COALESCE(
            p.labor_force_status_raw,
            'Not applicable - under 6'
        ) AS labor_force_status,

        CASE
            WHEN p.main_activity_status_raw IS NULL AND p.age < 6
                THEN 'Not applicable - under 6'
            ELSE p.main_activity_status_raw
        END AS main_activity_status,

        CASE
            WHEN LOWER(p.employment_status_raw) = 'not stated'
                THEN 'Unemployed'
            WHEN p.employment_status_raw IS NOT NULL
                THEN p.employment_status_raw
            WHEN p.age < 6
                THEN 'Not applicable - under 6'
            WHEN LOWER(p.labor_force_status_raw) = 'inactive'
                THEN 'Not applicable - not in labor force'
            WHEN LOWER(p.main_activity_status_raw) = 'unemployed'
                THEN 'Unemployed'
            ELSE 'Unemployed'
        END AS employment_status,

        CASE
            WHEN LOWER(p.occupation_raw) = 'not stated'
                THEN 'Unemployed'
            WHEN p.occupation_raw IS NOT NULL
                THEN p.occupation_raw
            WHEN p.age < 6
                THEN 'Not applicable - under 6'
            WHEN LOWER(p.labor_force_status_raw) = 'inactive'
                THEN 'Not applicable - not in labor force'
            WHEN LOWER(p.main_activity_status_raw) = 'unemployed'
                THEN 'Unemployed'
            ELSE 'Unemployed'
        END AS occupation,

        COALESCE(
            p.industry_raw,
            'Not applicable - no current job'
        ) AS industry,

        CASE
            WHEN p.employment_sector_raw IN (
                'Not stated',
                'Not applicable - unemployed'
            )
                THEN 'Not applicable - no current employment'

            ELSE COALESCE(
                p.employment_sector_raw,
                'Not applicable - no current employment'
            )
        END AS employment_sector,

        COALESCE(
            p.father_present_at_home_raw,
            'Not stated'
        ) AS father_present_at_home,

        p.father_id,
        p.father_age,

        COALESCE(
            p.father_marital_status_raw,
            'Not stated'
        ) AS father_marital_status,

        p.father_education_level,

        COALESCE(
            p.father_main_activity_raw,
            'Not stated'
        ) AS father_main_activity,

        p.father_employment_status,

        CASE
            WHEN p.father_occupation_raw =
                 'Not applicable - no main job'
                THEN 'Not stated'
            ELSE COALESCE(
                p.father_occupation_raw,
                'Not stated'
            )
        END AS father_occupation,

        COALESCE(
            p.father_industry_raw,
            'Not stated'
        ) AS father_industry,

        COALESCE(
            p.father_employment_sector_raw,
            'Not stated'
        ) AS father_employment_sector,

        COALESCE(
            p.mother_present_at_home_raw,
            'Not stated'
        ) AS mother_present_at_home,

        p.mother_id,
        p.mother_age,

        COALESCE(
            p.mother_marital_status_raw,
            'Not stated'
        ) AS mother_marital_status,

        COALESCE(
            p.mother_education_level_raw,
            'Not stated'
        ) AS mother_education_level,

        COALESCE(
            p.mother_main_activity_raw,
            'Not stated'
        ) AS mother_main_activity,

        COALESCE(
            p.mother_employment_status_raw,
            'Not stated'
        ) AS mother_employment_status,

        COALESCE(
            p.mother_occupation_raw,
            'Not stated'
        ) AS mother_occupation,

        COALESCE(
            p.mother_industry_raw,
            'Not stated'
        ) AS mother_industry,

        COALESCE(
            p.mother_employment_sector_raw,
            'Not stated'
        ) AS mother_employment_sector

    FROM prepared p

    CROSS JOIN primary_school_reference r

    LEFT JOIN education_level_reference e
        ON p.education_level_raw = e.education_level_raw
)

SELECT
    cleaned.*,

    CASE
        WHEN age BETWEEN 0 AND 14 THEN '0-14'
        WHEN age BETWEEN 15 AND 29 THEN '15-29'
        WHEN age BETWEEN 30 AND 44 THEN '30-44'
        WHEN age BETWEEN 45 AND 59 THEN '45-59'
        WHEN age >= 60 THEN '60+'
        ELSE NULL
    END AS age_group

FROM cleaned;


ALTER TABLE individual_cleaned
ADD PRIMARY KEY (household_id, person_id);

select * from individual_cleaned;
-- =============================================================================
-- SECTION 2: CLEAN HOUSEHOLD DATA
-- =============================================================================
-- Detailed expenditure components and redundant alternate classifications are
-- excluded. Summary expenditure fields are retained for household analysis.

CREATE TABLE if not exists household_cleaned AS
WITH prepared AS (
    SELECT
        CAST(NULLIF(TRIM(unique_unit_identifier), '') AS UNSIGNED)
            AS household_id,

        CAST(NULLIF(TRIM(household_weight), '') AS DECIMAL(18,6))
            AS household_weight,

        NULLIF(TRIM(region), '') AS region,
        NULLIF(TRIM(area), '') AS area,
        NULLIF(TRIM(urban_rural_residence), '') AS residence_type,

        CAST(NULLIF(TRIM(number_of_males), '') AS UNSIGNED)
            AS number_of_males,

        CAST(NULLIF(TRIM(number_of_females), '') AS UNSIGNED)
            AS number_of_females,

        CAST(NULLIF(TRIM(number_of_persons), '') AS UNSIGNED)
            AS household_size,

        CAST(NULLIF(TRIM(number_of_persons_under_age_14), '') AS UNSIGNED)
            AS members_under_14,

        CAST(NULLIF(TRIM(number_of_persons_aged_65_or_more), '') AS UNSIGNED)
            AS members_65_or_more,

        CAST(NULLIF(TRIM(number_of_earners), '') AS UNSIGNED)
            AS number_of_earners,

        NULLIF(TRIM(household_composition), '')
            AS household_composition,

        NULLIF(TRIM(source_of_income), '')
            AS main_income_source,

        NULLIF(TRIM(type_of_dwelling_standardized_version), '')
            AS dwelling_type,

        NULLIF(TRIM(tenure_of_dwelling_standardized_version), '')
            AS dwelling_tenure,

        CASE TRIM(number_of_rooms)
            WHEN 'غرفة واحدة' THEN 'One room'
            WHEN 'غرفتين' THEN 'Two rooms'
            WHEN 'ثلاث غرف' THEN 'Three rooms'
            WHEN 'اربع غرف' THEN 'Four rooms'
            WHEN 'أربع غرف' THEN 'Four rooms'
            WHEN 'خمس غرف' THEN 'Five rooms'
            WHEN 'ست غرف' THEN 'Six rooms'
            WHEN 'سبع غرف' THEN 'Seven rooms'
            WHEN 'ثمان غرف' THEN 'Eight rooms'
            WHEN 'تسع غرف' THEN 'Nine rooms'
            WHEN 'عشر غرف' THEN 'Ten rooms'
            ELSE NULLIF(TRIM(number_of_rooms), '')
        END AS number_of_rooms,

        CASE TRIM(number_of_rooms)
            WHEN 'غرفة واحدة' THEN 1
            WHEN 'غرفتين' THEN 2
            WHEN 'ثلاث غرف' THEN 3
            WHEN 'اربع غرف' THEN 4
            WHEN 'أربع غرف' THEN 4
            WHEN 'خمس غرف' THEN 5
            WHEN 'ست غرف' THEN 6
            WHEN 'سبع غرف' THEN 7
            WHEN 'ثمان غرف' THEN 8
            WHEN 'تسع غرف' THEN 9
            WHEN 'عشر غرف' THEN 10
            WHEN 'One room' THEN 1
            WHEN 'Two rooms' THEN 2
            WHEN 'Three rooms' THEN 3
            WHEN 'Four rooms' THEN 4
            WHEN 'Five rooms' THEN 5
            WHEN 'Six rooms' THEN 6
            WHEN 'Seven rooms' THEN 7
            WHEN 'Eight rooms' THEN 8
            WHEN 'Nine rooms' THEN 9
            WHEN 'Ten rooms' THEN 10
            ELSE NULL
        END AS rooms_count,

        NULLIF(TRIM(water_facilities), '') AS water_facility,
        NULLIF(TRIM(toilet_facility), '') AS sanitation,
        NULLIF(TRIM(garbage_disposal_method), '') AS garbage_disposal_method,

        CASE TRIM(has_a_car_van_taxi_cart_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_car,

        CASE TRIM(has_bicycle_scooter_motorcycle_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_bicycle_or_motorcycle,

        CASE TRIM(has_a_tv_lcd_led_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_tv,

        CASE TRIM(has_satellite_dish_receiver_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_satellite_dish,

        CASE TRIM(has_dvd_vcr_cd_player_audio_player_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_media_player,

        CASE TRIM(has_photo_or_video_camera)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_camera,

        CASE TRIM(has_telephone_cell_phone_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_telephone,

        CASE TRIM(
            has_computer_or_laptop_connected_or_not_to_an_internet_line
        )
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_computer,

        CASE TRIM(
            has_internet_line_and_related_equipments_router_usb_etc
        )
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_internet,

        CASE TRIM(has_refrigerator_freezer_water_cooler_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_refrigerator,

        CASE TRIM(has_cooker_stove_oven_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_cooker,

        CASE TRIM(has_microwave_grill_fryer_etc)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_microwave,

        CASE TRIM(
            has_food_processor_kitchen_machine_blender_grinder_etc
        )
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_food_processor,

        CASE TRIM(has_washing_machine)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_washing_machine,

        CASE TRIM(has_a_dishwasher)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_dishwasher,

        CASE TRIM(has_an_air_conditioner)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_air_conditioner,

        CASE TRIM(has_an_electric_fan)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_electric_fan,

        CASE TRIM(has_a_heater)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_heater,

        CASE TRIM(has_a_water_heater)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_water_heater,

        CASE TRIM(has_a_sewing_machine)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_sewing_machine,

        CASE TRIM(has_a_vacuum_cleaner)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_vacuum_cleaner,

        CASE TRIM(has_an_iron)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_iron,

        CASE TRIM(watermotor)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_water_motor,

        CASE TRIM(has_other_durables)
            WHEN 'Own one or many' THEN 1
            WHEN 'None' THEN 0
            ELSE NULL
        END AS has_other_durables,

        CAST(
            COALESCE(NULLIF(TRIM(total_purchased_food), ''), '0')
            AS DECIMAL(20,4)
        ) AS purchased_food_expenditure,

        CAST(
            NULLIF(TRIM(total_own_produced_food), '')
            AS DECIMAL(20,4)
        ) AS own_produced_food_value,

        CASE
            WHEN NULLIF(TRIM(total_gifts_and_in_kind_food), '') IS NULL
                 AND ABS(
                     CAST(
                         NULLIF(TRIM(food_and_non_alcoholic_beverages), '')
                         AS DECIMAL(20,4)
                     )
                     -
                     COALESCE(
                         CAST(
                             NULLIF(TRIM(total_purchased_food), '')
                             AS DECIMAL(20,4)
                         ),
                         0
                     )
                 ) <= 0.01
                THEN 0

            ELSE CAST(
                NULLIF(TRIM(total_gifts_and_in_kind_food), '')
                AS DECIMAL(20,4)
            )
        END AS gifts_and_in_kind_food,

        CAST(
            NULLIF(TRIM(food_and_non_alcoholic_beverages), '')
            AS DECIMAL(20,4)
        ) AS food_and_non_alcoholic_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(alcohol_and_tobacco), ''), '0')
            AS DECIMAL(20,4)
        ) AS alcohol_and_tobacco_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(clothing_and_footwear), ''), '0')
            AS DECIMAL(20,4)
        ) AS clothing_expenditure,

        CAST(
            NULLIF(TRIM(housing_and_utilities), '')
            AS DECIMAL(20,4)
        ) AS housing_expenditure,

       CAST(
		NULLIF(TRIM(furniture_and_housing_equipment), '')
        AS DECIMAL(20,4)
	    ) AS furniture_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(health), ''), '0')
            AS DECIMAL(20,4)
        ) AS health_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(transport), ''), '0')
            AS DECIMAL(20,4)
        ) AS transport_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(communication), ''), '0')
            AS DECIMAL(20,4)
        ) AS communication_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(recreation_and_culture), ''), '0')
            AS DECIMAL(20,4)
        ) AS recreation_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(education), ''), '0')
            AS DECIMAL(20,4)
        ) AS education_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(restaurants_and_hotels), ''), '0')
            AS DECIMAL(20,4)
        ) AS restaurants_expenditure,

        CAST(
            COALESCE(
                NULLIF(TRIM(miscellaneous_goods_and_services), ''),
                '0'
            )
            AS DECIMAL(20,4)
        ) AS miscellaneous_expenditure,

        CAST(
            NULLIF(TRIM(total_food_expenditures), '')
            AS DECIMAL(20,4)
        ) AS food_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(total_expenses_on_durables), ''), '0')
            AS DECIMAL(20,4)
        ) AS durable_expenditure,

        CAST(
            NULLIF(TRIM(actual_and_imputed_rentals_for_housing), '')
            AS DECIMAL(20,4)
        ) AS actual_and_imputed_rentals,

        CAST(
            NULLIF(
                TRIM(total_expenditures_on_non_food_and_non_durables),
                ''
            )
            AS DECIMAL(20,4)
        ) AS non_food_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(lumpy_expenses), ''), '0')
            AS DECIMAL(20,4)
        ) AS lumpy_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(expenditures_on_taxes_and_levies), ''), '0')
            AS DECIMAL(20,4)
        ) AS taxes_and_levies,

        CAST(
            NULLIF(TRIM(total_expenditures), '')
            AS DECIMAL(20,4)
        ) AS total_expenditure,

        CAST(
            COALESCE(NULLIF(TRIM(net_wages_and_salaries), ''), '0')
            AS DECIMAL(20,4)
        ) AS wage_income,

        CAST(
            COALESCE(NULLIF(TRIM(self_employment_income), ''), '0')
            AS DECIMAL(20,4)
        ) AS self_employment_income,

        CAST(
            COALESCE(
                NULLIF(TRIM(income_less_expenses_from_rentals), ''),
                '0'
            )
            AS DECIMAL(20,4)
        ) AS rental_income,

        CAST(
            COALESCE(NULLIF(TRIM(property_income), ''), '0')
            AS DECIMAL(20,4)
        ) AS property_income,

        CAST(
            COALESCE(NULLIF(TRIM(current_transfers_received), ''), '0')
            AS DECIMAL(20,4)
        ) AS transfers_received,

        CAST(
            NULLIF(TRIM(total_disposable_income), '')
            AS DECIMAL(20,4)
        ) AS disposable_income,

        CAST(NULLIF(TRIM(age_of_the_head), '') AS UNSIGNED)
            AS head_age,

        NULLIF(TRIM(gender_of_the_head), '')
            AS head_gender,

        NULLIF(TRIM(literacy_status_of_the_head), '')
            AS head_literacy,

        NULLIF(
            TRIM(educational_level_of_the_head_standardized_version),
            ''
        ) AS head_education_level,

        NULLIF(
            TRIM(main_activity_status_of_the_head_standardized_version),
            ''
        ) AS head_main_activity,

        NULLIF(
            TRIM(status_of_employment_of_the_head_standardized_version),
            ''
        ) AS head_employment_status_raw,

        NULLIF(
            TRIM(
                occupation_classification_for_the_main_job_of_the_head_stand
            ),
            ''
        ) AS head_occupation_raw,

        NULLIF(
            TRIM(
                industry_classification_for_the_main_job_of_the_head_standar
            ),
            ''
        ) AS head_industry_raw,

        NULLIF(
            TRIM(sector_of_employment_of_the_head_standardized_version),
            ''
        ) AS head_employment_sector_raw,

        NULLIF(
            TRIM(marital_status_of_the_head_standardized_version),
            ''
        ) AS head_marital_status_raw,

        NULLIF(
            TRIM(partnership_and_parenthood_status_of_the_head),
            ''
        ) AS head_partnership_status

    FROM household_raw
),

cleaned AS (
    SELECT
        p.*,

        CASE
            WHEN p.head_marital_status_raw IS NULL
                 AND p.head_age < 18
                 AND p.head_partnership_status =
                     'Single Head, with no children'
                THEN 'Never married'

            ELSE COALESCE(
                p.head_marital_status_raw,
                'Not stated'
            )
        END AS head_marital_status,

        CASE
            WHEN p.head_employment_status_raw IS NULL
                 AND p.head_main_activity IN (
                     'Pensioners/retired/disabled',
                     'Homemaker (Housewife)',
                     'Unemployed',
                     'Student',
                     'Others'
                 )
                THEN 'Not applicable - no current job'

            ELSE COALESCE(
                p.head_employment_status_raw,
                'Not stated'
            )
        END AS head_employment_status,

        CASE
            WHEN p.head_occupation_raw IS NULL
                 AND p.head_main_activity IN (
                     'Pensioners/retired/disabled',
                     'Homemaker (Housewife)',
                     'Unemployed',
                     'Student',
                     'Others'
                 )
                THEN 'Not applicable - no current job'

            ELSE COALESCE(
                p.head_occupation_raw,
                'Not stated'
            )
        END AS head_occupation,

        CASE
            WHEN p.head_industry_raw IS NULL
                 AND p.head_main_activity IN (
                     'Pensioners/retired/disabled',
                     'Homemaker (Housewife)',
                     'Unemployed',
                     'Student',
                     'Others'
                 )
                THEN 'Not applicable - no current job'

            ELSE COALESCE(
                p.head_industry_raw,
                'Not stated'
            )
        END AS head_industry,

        CASE
            WHEN p.head_employment_sector_raw IS NULL
                 AND p.head_main_activity IN (
                     'Pensioners/retired/disabled',
                     'Homemaker (Housewife)',
                     'Unemployed',
                     'Student',
                     'Others'
                 )
                THEN 'Not applicable - no current job'

            ELSE COALESCE(
                p.head_employment_sector_raw,
                'Not stated'
            )
        END AS head_employment_sector

    FROM prepared p
),

features AS (
    SELECT
        c.*,

        disposable_income / NULLIF(household_size, 0)
            AS income_per_capita,

        total_expenditure / NULLIF(household_size, 0)
            AS expenditure_per_capita,

        food_expenditure / NULLIF(total_expenditure, 0)
            AS food_expenditure_share,

        (
            disposable_income - total_expenditure
        ) / NULLIF(disposable_income, 0)
            AS savings_rate,

        household_size / NULLIF(rooms_count, 0)
            AS persons_per_room,

        COALESCE(has_car, 0)
        + COALESCE(has_bicycle_or_motorcycle, 0)
        + COALESCE(has_tv, 0)
        + COALESCE(has_satellite_dish, 0)
        + COALESCE(has_media_player, 0)
        + COALESCE(has_camera, 0)
        + COALESCE(has_telephone, 0)
        + COALESCE(has_computer, 0)
        + COALESCE(has_internet, 0)
        + COALESCE(has_refrigerator, 0)
        + COALESCE(has_cooker, 0)
        + COALESCE(has_microwave, 0)
        + COALESCE(has_food_processor, 0)
        + COALESCE(has_washing_machine, 0)
        + COALESCE(has_dishwasher, 0)
        + COALESCE(has_air_conditioner, 0)
        + COALESCE(has_electric_fan, 0)
        + COALESCE(has_heater, 0)
        + COALESCE(has_water_heater, 0)
        + COALESCE(has_sewing_machine, 0)
        + COALESCE(has_vacuum_cleaner, 0)
        + COALESCE(has_iron, 0)
        + COALESCE(has_water_motor, 0)
        + COALESCE(has_other_durables, 0)
            AS asset_count

    FROM cleaned c
)

SELECT
    household_id,
    household_weight,

    region,
    area,
    residence_type,

    number_of_males,
    number_of_females,
    household_size,
    members_under_14,
    members_65_or_more,
    number_of_earners,
    household_composition,
    main_income_source,

    dwelling_type,
    dwelling_tenure,
    number_of_rooms,
    rooms_count,
    persons_per_room,
    water_facility,
    sanitation,
    garbage_disposal_method,

    has_car,
    has_bicycle_or_motorcycle,
    has_tv,
    has_satellite_dish,
    has_media_player,
    has_camera,
    has_telephone,
    has_computer,
    has_internet,
    has_refrigerator,
    has_cooker,
    has_microwave,
    has_food_processor,
    has_washing_machine,
    has_dishwasher,
    has_air_conditioner,
    has_electric_fan,
    has_heater,
    has_water_heater,
    has_sewing_machine,
    has_vacuum_cleaner,
    has_iron,
    has_water_motor,
    has_other_durables,
    asset_count,

    purchased_food_expenditure,
    own_produced_food_value,
    gifts_and_in_kind_food,
    food_and_non_alcoholic_expenditure,
    alcohol_and_tobacco_expenditure,
    clothing_expenditure,
    housing_expenditure,
    furniture_expenditure,
    health_expenditure,
    transport_expenditure,
    communication_expenditure,
    recreation_expenditure,
    education_expenditure,
    restaurants_expenditure,
    miscellaneous_expenditure,
    food_expenditure,
    durable_expenditure,
    actual_and_imputed_rentals,
    non_food_expenditure,
    lumpy_expenditure,
    taxes_and_levies,
    total_expenditure,

    wage_income,
    self_employment_income,
    rental_income,
    property_income,
    transfers_received,
    disposable_income,

    income_per_capita,
    expenditure_per_capita,
    food_expenditure_share,
    savings_rate,

    head_age,
    head_gender,
    head_literacy,
    head_education_level,
    head_marital_status,
    head_partnership_status,
    head_main_activity,
    head_employment_status,
    head_occupation,
    head_industry,
    head_employment_sector

FROM features;


ALTER TABLE household_cleaned
ADD PRIMARY KEY (household_id);

select * from household_cleaned;

-- =============================================================================
-- SECTION 3: VALIDATE THE INDIVIDUAL-HOUSEHOLD RELATIONSHIP
-- =============================================================================

-- Every individual record should match a household record.

SELECT
    COUNT(*) AS unmatched_individuals

FROM individual_cleaned i

LEFT JOIN household_cleaned h
    ON i.household_id = h.household_id

WHERE h.household_id IS NULL;


-- Identify households that do not contain individual records.

SELECT
    COUNT(*) AS households_without_individuals

FROM household_cleaned h

LEFT JOIN individual_cleaned i
    ON h.household_id = i.household_id

WHERE i.household_id IS NULL;


-- Compare reported household size with the number of individual records.

SELECT
    h.household_id,
    h.household_size AS reported_household_size,
    COUNT(i.person_id) AS counted_household_members,
    h.household_size - COUNT(i.person_id) AS size_difference

FROM household_cleaned h

LEFT JOIN individual_cleaned i
    ON h.household_id = i.household_id

GROUP BY
    h.household_id,
    h.household_size

HAVING h.household_size <> COUNT(i.person_id);


-- =============================================================================
-- SECTION 4: MERGE THE CLEANED DATASETS
-- =============================================================================
-- Each row in the final table represents one individual.
-- Household characteristics are repeated for members of the same household.

CREATE TABLE merged_survey_final AS
SELECT
    i.*,

    h.number_of_males,
    h.number_of_females,
    h.household_size,
    h.members_under_14,
    h.members_65_or_more,
    h.number_of_earners,
    h.household_composition,
    h.main_income_source,

    h.dwelling_type,
    h.dwelling_tenure,
    h.number_of_rooms,
    h.rooms_count,
    h.persons_per_room,
    h.water_facility,
    h.sanitation,
    h.garbage_disposal_method,

    h.has_car,
    h.has_bicycle_or_motorcycle,
    h.has_tv,
    h.has_satellite_dish,
    h.has_media_player,
    h.has_camera,
    h.has_telephone,
    h.has_computer,
    h.has_internet,
    h.has_refrigerator,
    h.has_cooker,
    h.has_microwave,
    h.has_food_processor,
    h.has_washing_machine,
    h.has_dishwasher,
    h.has_air_conditioner,
    h.has_electric_fan,
    h.has_heater,
    h.has_water_heater,
    h.has_sewing_machine,
    h.has_vacuum_cleaner,
    h.has_iron,
    h.has_water_motor,
    h.has_other_durables,
    h.asset_count,

    h.purchased_food_expenditure,
    h.own_produced_food_value,
    h.gifts_and_in_kind_food,
    h.food_and_non_alcoholic_expenditure,
    h.alcohol_and_tobacco_expenditure,
    h.clothing_expenditure,
    h.housing_expenditure,
    h.furniture_expenditure,
    h.health_expenditure,
    h.transport_expenditure,
    h.communication_expenditure,
    h.recreation_expenditure,
    h.education_expenditure,
    h.restaurants_expenditure,
    h.miscellaneous_expenditure,
    h.food_expenditure,
    h.durable_expenditure,
    h.actual_and_imputed_rentals,
    h.non_food_expenditure,
    h.lumpy_expenditure,
    h.taxes_and_levies,
    h.total_expenditure,

    h.wage_income,
    h.self_employment_income,
    h.rental_income,
    h.property_income,
    h.transfers_received,
    h.disposable_income,

    h.income_per_capita,
    h.expenditure_per_capita,
    h.food_expenditure_share,
    h.savings_rate,

    h.head_age,
    h.head_gender,
    h.head_literacy,
    h.head_education_level,
    h.head_marital_status,
    h.head_partnership_status,
    h.head_main_activity,
    h.head_employment_status,
    h.head_occupation,
    h.head_industry,
    h.head_employment_sector

FROM individual_cleaned i

LEFT JOIN household_cleaned h
    ON i.household_id = h.household_id;


ALTER TABLE merged_survey_final
ADD PRIMARY KEY (household_id, person_id);

select * from merged_survey_final;
-- =============================================================================
-- SECTION 5: FINAL DATA QUALITY CHECKS
-- =============================================================================

-- Confirm that cleaning and merging did not remove individual records.

SELECT
    (SELECT COUNT(*) FROM individual_raw)
        AS raw_individual_rows,

    (SELECT COUNT(*) FROM individual_cleaned)
        AS cleaned_individual_rows,

    (SELECT COUNT(*) FROM merged_survey_final)
        AS merged_rows;


-- Confirm that cleaning did not remove household records.

SELECT
    (SELECT COUNT(*) FROM household_raw)
        AS raw_household_rows,

    (SELECT COUNT(*) FROM household_cleaned)
        AS cleaned_household_rows;


-- Validate identifiers, weights, age and household structure.

SELECT
    SUM(household_id IS NULL OR person_id IS NULL)
        AS missing_individual_keys,

    SUM(household_weight IS NULL OR household_weight <= 0)
        AS invalid_individual_weights,

    SUM(age IS NULL OR age > 120)
        AS invalid_ages,

    COUNT(*) - COUNT(
        DISTINCT CONCAT(household_id, '-', person_id)
    ) AS duplicate_individual_keys

FROM individual_cleaned;


SELECT
    SUM(household_id IS NULL)
        AS missing_household_keys,

    SUM(household_weight IS NULL OR household_weight <= 0)
        AS invalid_household_weights,

    SUM(household_size IS NULL OR household_size <= 0)
        AS invalid_household_sizes,

    SUM(number_of_males + number_of_females <> household_size)
        AS household_size_mismatches,

    SUM(number_of_earners > household_size)
        AS invalid_earner_counts,

    SUM(rooms_count IS NOT NULL AND rooms_count <= 0)
        AS invalid_room_counts,

    SUM(total_expenditure < 0)
        AS negative_expenditure_values,

    SUM(disposable_income < 0)
        AS negative_income_values,

    COUNT(*) - COUNT(DISTINCT household_id)
        AS duplicate_household_keys

FROM household_cleaned;


-- Review remaining missing values in key analytical fields.

SELECT
    SUM(marital_status IS NULL) AS missing_marital_status,
    SUM(literacy_status IS NULL) AS missing_literacy_status,
    SUM(education_level IS NULL) AS missing_education_level,
    SUM(years_of_schooling IS NULL) AS missing_years_of_schooling,
    SUM(school_attendance_status IS NULL) AS missing_school_attendance,
    SUM(disability_status IS NULL) AS missing_disability_status,
    SUM(main_activity_status IS NULL) AS missing_main_activity

FROM individual_cleaned;


SELECT
    SUM(disposable_income IS NULL) AS missing_disposable_income,
    SUM(total_expenditure IS NULL) AS missing_total_expenditure,
    SUM(food_expenditure IS NULL) AS missing_food_expenditure,
    SUM(rooms_count IS NULL) AS missing_room_count,
    SUM(head_marital_status IS NULL) AS missing_head_marital_status,
    SUM(head_employment_status IS NULL) AS missing_head_employment_status

FROM household_cleaned;


-- Review the final analytical table structure.

SELECT
    column_name,
    data_type,
    is_nullable

FROM information_schema.columns

WHERE table_schema = 'depi_egypt_raw_import'
  AND table_name = 'merged_survey_final'

ORDER BY ordinal_position;


-- Display a sample of the final integrated dataset.

SELECT *
FROM merged_survey_final
ORDER BY household_id, person_id
LIMIT 10;