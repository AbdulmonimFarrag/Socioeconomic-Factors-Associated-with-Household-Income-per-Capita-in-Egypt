-- =============================================================================
-- EGYPT HOUSEHOLD INCOME AND LIVING CONDITIONS PROJECT
-- FINAL ANALYTICAL GALAXY SCHEMA
-- =============================================================================
-- Source schema : depi_egypt_raw_import
-- Target schema : depi_egypt_analytics
--
-- Prerequisite:
--   household_cleaned and individual_cleaned must already exist and contain
--   the final cleaned records produced by the cleaning pipeline.
--
-- Design grains:
--   fact_household : one row per household
--   fact_person    : one row per person within a household
-- =============================================================================


-- =============================================================================
-- SECTION 0: CREATE THE ANALYTICAL SCHEMA
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS depi_egypt_analytics
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE depi_egypt_analytics;


-- Drop only previously generated analytical tables so the script is rerunnable.
DROP TABLE IF EXISTS household_expenditure_breakdown;
DROP TABLE IF EXISTS household_asset_ownership;
DROP TABLE IF EXISTS fact_person;
DROP TABLE IF EXISTS fact_household;
DROP TABLE IF EXISTS dim_parent_profile;
DROP TABLE IF EXISTS dim_employment;
DROP TABLE IF EXISTS dim_health_protection;
DROP TABLE IF EXISTS dim_education;
DROP TABLE IF EXISTS dim_person_demographics;
DROP TABLE IF EXISTS dim_household_head;
DROP TABLE IF EXISTS dim_housing_characteristics;
DROP TABLE IF EXISTS dim_household_profile;
DROP TABLE IF EXISTS dim_geography;


-- =============================================================================
-- SECTION 1: CREATE AND LOAD HOUSEHOLD DIMENSIONS
-- =============================================================================

-- Stores reusable geographic classifications.
CREATE TABLE dim_geography (
    geography_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    region VARCHAR(120) NOT NULL,
    area VARCHAR(120) NOT NULL,
    residence_type VARCHAR(120) NOT NULL,
    PRIMARY KEY (geography_key)
) ENGINE = InnoDB;

INSERT INTO dim_geography (region, area, residence_type)
SELECT DISTINCT
    COALESCE(region, 'Not stated'),
    COALESCE(area, 'Not stated'),
    COALESCE(residence_type, 'Not stated')
FROM depi_egypt_raw_import.household_cleaned
ORDER BY 1, 2, 3;


-- Stores the household composition and principal income-source categories.
CREATE TABLE dim_household_profile (
    household_profile_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    household_composition VARCHAR(150) NOT NULL,
    main_income_source VARCHAR(150) NOT NULL,
    PRIMARY KEY (household_profile_key)
) ENGINE = InnoDB;

INSERT INTO dim_household_profile (
    household_composition,
    main_income_source
)
SELECT DISTINCT
    COALESCE(household_composition, 'Not stated'),
    COALESCE(main_income_source, 'Not stated')
FROM depi_egypt_raw_import.household_cleaned
ORDER BY 1, 2;


-- Stores categorical housing and service characteristics.
-- rooms_count remains a household fact because it is a numeric measure.
CREATE TABLE dim_housing_characteristics (
    housing_characteristics_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    dwelling_type VARCHAR(150) NOT NULL,
    dwelling_tenure VARCHAR(150) NOT NULL,
    water_facility VARCHAR(150) NOT NULL,
    sanitation VARCHAR(150) NOT NULL,
    garbage_disposal_method VARCHAR(150) NOT NULL,
    PRIMARY KEY (housing_characteristics_key)
) ENGINE = InnoDB;

INSERT INTO dim_housing_characteristics (
    dwelling_type,
    dwelling_tenure,
    water_facility,
    sanitation,
    garbage_disposal_method
)
SELECT DISTINCT
    COALESCE(dwelling_type, 'Not stated'),
    COALESCE(dwelling_tenure, 'Not stated'),
    COALESCE(water_facility, 'Not stated'),
    COALESCE(sanitation, 'Not stated'),
    COALESCE(garbage_disposal_method, 'Not stated')
FROM depi_egypt_raw_import.household_cleaned
ORDER BY 1, 2, 3, 4, 5;


-- Stores the categorical socioeconomic characteristics of the household head.
-- head_age remains in fact_household because it is numeric.
CREATE TABLE dim_household_head (
    head_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    head_gender VARCHAR(120) NOT NULL,
    head_literacy VARCHAR(120) NOT NULL,
    head_education_level VARCHAR(150) NOT NULL,
    head_marital_status VARCHAR(150) NOT NULL,
    head_partnership_status VARCHAR(150) NOT NULL,
    head_main_activity VARCHAR(150) NOT NULL,
    head_employment_status VARCHAR(150) NOT NULL,
    head_occupation VARCHAR(200) NOT NULL,
    head_industry VARCHAR(200) NOT NULL,
    head_employment_sector VARCHAR(150) NOT NULL,
    PRIMARY KEY (head_key)
) ENGINE = InnoDB;

INSERT INTO dim_household_head (
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
)
SELECT DISTINCT
    COALESCE(head_gender, 'Not stated'),
    COALESCE(head_literacy, 'Not stated'),
    COALESCE(head_education_level, 'Not stated'),
    COALESCE(head_marital_status, 'Not stated'),
    COALESCE(head_partnership_status, 'Not stated'),
    COALESCE(head_main_activity, 'Not stated'),
    COALESCE(head_employment_status, 'Not stated'),
    COALESCE(head_occupation, 'Not stated'),
    COALESCE(head_industry, 'Not stated'),
    COALESCE(head_employment_sector, 'Not stated')
FROM depi_egypt_raw_import.household_cleaned
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10;


-- Temporary indexed lookups accelerate surrogate-key resolution without
-- adding technical hash columns to the final analytical dimensions.
DROP TEMPORARY TABLE IF EXISTS map_geography;
CREATE TEMPORARY TABLE map_geography (
    lookup_hash BINARY(32) NOT NULL,
    geography_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_geography
SELECT
    UNHEX(SHA2(CONCAT_WS(CHAR(31), region, area, residence_type), 256)),
    geography_key
FROM dim_geography;


DROP TEMPORARY TABLE IF EXISTS map_household_profile;
CREATE TEMPORARY TABLE map_household_profile (
    lookup_hash BINARY(32) NOT NULL,
    household_profile_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_household_profile
SELECT
    UNHEX(SHA2(CONCAT_WS(
        CHAR(31), household_composition, main_income_source
    ), 256)),
    household_profile_key
FROM dim_household_profile;


DROP TEMPORARY TABLE IF EXISTS map_housing_characteristics;
CREATE TEMPORARY TABLE map_housing_characteristics (
    lookup_hash BINARY(32) NOT NULL,
    housing_characteristics_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_housing_characteristics
SELECT
    UNHEX(SHA2(CONCAT_WS(
        CHAR(31), dwelling_type, dwelling_tenure, water_facility,
        sanitation, garbage_disposal_method
    ), 256)),
    housing_characteristics_key
FROM dim_housing_characteristics;


DROP TEMPORARY TABLE IF EXISTS map_household_head;
CREATE TEMPORARY TABLE map_household_head (
    lookup_hash BINARY(32) NOT NULL,
    head_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_household_head
SELECT
    UNHEX(SHA2(CONCAT_WS(
        CHAR(31), head_gender, head_literacy, head_education_level,
        head_marital_status, head_partnership_status, head_main_activity,
        head_employment_status, head_occupation, head_industry,
        head_employment_sector
    ), 256)),
    head_key
FROM dim_household_head;


-- =============================================================================
-- SECTION 2: CREATE AND LOAD THE HOUSEHOLD FACT TABLE
-- =============================================================================

CREATE TABLE fact_household (
    household_id BIGINT UNSIGNED NOT NULL,
    geography_key INT UNSIGNED NOT NULL,
    household_profile_key INT UNSIGNED NOT NULL,
    housing_characteristics_key INT UNSIGNED NOT NULL,
    head_key INT UNSIGNED NOT NULL,

    household_weight DECIMAL(18,6) NULL,
    number_of_males INT UNSIGNED NULL,
    number_of_females INT UNSIGNED NULL,
    household_size INT UNSIGNED NULL,
    members_under_14 INT UNSIGNED NULL,
    members_65_or_more INT UNSIGNED NULL,
    number_of_earners INT UNSIGNED NULL,
    rooms_count INT UNSIGNED NULL,
    head_age SMALLINT UNSIGNED NULL,
    persons_per_room DECIMAL(18,6) NULL,
    asset_count INT UNSIGNED NULL,

    wage_income DECIMAL(20,4) NULL,
    self_employment_income DECIMAL(20,4) NULL,
    rental_income DECIMAL(20,4) NULL,
    property_income DECIMAL(20,4) NULL,
    transfers_received DECIMAL(20,4) NULL,
    disposable_income DECIMAL(20,4) NULL,
    income_per_capita DECIMAL(24,8) NULL,

    total_expenditure DECIMAL(20,4) NULL,
    expenditure_per_capita DECIMAL(24,8) NULL,
    savings_rate DECIMAL(18,8) NULL,

    PRIMARY KEY (household_id),
    KEY ix_fact_household_geography (geography_key),
    KEY ix_fact_household_profile (household_profile_key),
    KEY ix_fact_household_housing (housing_characteristics_key),
    KEY ix_fact_household_head (head_key),

    CONSTRAINT fk_household_geography
        FOREIGN KEY (geography_key)
        REFERENCES dim_geography (geography_key),

    CONSTRAINT fk_household_profile
        FOREIGN KEY (household_profile_key)
        REFERENCES dim_household_profile (household_profile_key),

    CONSTRAINT fk_household_housing
        FOREIGN KEY (housing_characteristics_key)
        REFERENCES dim_housing_characteristics (housing_characteristics_key),

    CONSTRAINT fk_household_head
        FOREIGN KEY (head_key)
        REFERENCES dim_household_head (head_key)
) ENGINE = InnoDB;


INSERT INTO fact_household (
    household_id,
    geography_key,
    household_profile_key,
    housing_characteristics_key,
    head_key,
    household_weight,
    number_of_males,
    number_of_females,
    household_size,
    members_under_14,
    members_65_or_more,
    number_of_earners,
    rooms_count,
    head_age,
    persons_per_room,
    asset_count,
    wage_income,
    self_employment_income,
    rental_income,
    property_income,
    transfers_received,
    disposable_income,
    income_per_capita,
    total_expenditure,
    expenditure_per_capita,
    savings_rate
)
SELECT
    h.household_id,
    g.geography_key,
    hp.household_profile_key,
    hs.housing_characteristics_key,
    hd.head_key,
    h.household_weight,
    h.number_of_males,
    h.number_of_females,
    h.household_size,
    h.members_under_14,
    h.members_65_or_more,
    h.number_of_earners,
    h.rooms_count,
    h.head_age,
    h.persons_per_room,
    h.asset_count,
    h.wage_income,
    h.self_employment_income,
    h.rental_income,
    h.property_income,
    h.transfers_received,
    h.disposable_income,
    h.income_per_capita,
    h.total_expenditure,
    h.expenditure_per_capita,
    h.savings_rate
FROM depi_egypt_raw_import.household_cleaned h
JOIN map_geography g
  ON g.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(h.region, 'Not stated'),
      COALESCE(h.area, 'Not stated'),
      COALESCE(h.residence_type, 'Not stated')
  ), 256))
JOIN map_household_profile hp
  ON hp.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(h.household_composition, 'Not stated'),
      COALESCE(h.main_income_source, 'Not stated')
  ), 256))
JOIN map_housing_characteristics hs
  ON hs.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(h.dwelling_type, 'Not stated'),
      COALESCE(h.dwelling_tenure, 'Not stated'),
      COALESCE(h.water_facility, 'Not stated'),
      COALESCE(h.sanitation, 'Not stated'),
      COALESCE(h.garbage_disposal_method, 'Not stated')
  ), 256))
JOIN map_household_head hd
  ON hd.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(h.head_gender, 'Not stated'),
      COALESCE(h.head_literacy, 'Not stated'),
      COALESCE(h.head_education_level, 'Not stated'),
      COALESCE(h.head_marital_status, 'Not stated'),
      COALESCE(h.head_partnership_status, 'Not stated'),
      COALESCE(h.head_main_activity, 'Not stated'),
      COALESCE(h.head_employment_status, 'Not stated'),
      COALESCE(h.head_occupation, 'Not stated'),
      COALESCE(h.head_industry, 'Not stated'),
      COALESCE(h.head_employment_sector, 'Not stated')
  ), 256));

DROP TEMPORARY TABLE map_geography;
DROP TEMPORARY TABLE map_household_profile;
DROP TEMPORARY TABLE map_housing_characteristics;
DROP TEMPORARY TABLE map_household_head;


-- =============================================================================
-- SECTION 3: CREATE HOUSEHOLD DETAIL TABLES
-- =============================================================================

-- One record per household containing the complete durable-asset ownership set.
CREATE TABLE household_asset_ownership (
    asset_ownership_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    household_id BIGINT UNSIGNED NOT NULL,
    has_car TINYINT UNSIGNED NULL,
    has_bicycle_or_motorcycle TINYINT UNSIGNED NULL,
    has_tv TINYINT UNSIGNED NULL,
    has_satellite_dish TINYINT UNSIGNED NULL,
    has_media_player TINYINT UNSIGNED NULL,
    has_camera TINYINT UNSIGNED NULL,
    has_telephone TINYINT UNSIGNED NULL,
    has_computer TINYINT UNSIGNED NULL,
    has_internet TINYINT UNSIGNED NULL,
    has_refrigerator TINYINT UNSIGNED NULL,
    has_cooker TINYINT UNSIGNED NULL,
    has_microwave TINYINT UNSIGNED NULL,
    has_food_processor TINYINT UNSIGNED NULL,
    has_washing_machine TINYINT UNSIGNED NULL,
    has_dishwasher TINYINT UNSIGNED NULL,
    has_air_conditioner TINYINT UNSIGNED NULL,
    has_electric_fan TINYINT UNSIGNED NULL,
    has_heater TINYINT UNSIGNED NULL,
    has_water_heater TINYINT UNSIGNED NULL,
    has_sewing_machine TINYINT UNSIGNED NULL,
    has_vacuum_cleaner TINYINT UNSIGNED NULL,
    has_iron TINYINT UNSIGNED NULL,
    has_water_motor TINYINT UNSIGNED NULL,
    has_other_durables TINYINT UNSIGNED NULL,

    PRIMARY KEY (asset_ownership_key),
    UNIQUE KEY uq_assets_household (household_id),
    CONSTRAINT fk_assets_household
        FOREIGN KEY (household_id)
        REFERENCES fact_household (household_id)
        ON DELETE CASCADE
) ENGINE = InnoDB;

INSERT INTO household_asset_ownership (
    household_id,
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
    has_other_durables
)
SELECT
    household_id,
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
    has_other_durables
FROM depi_egypt_raw_import.household_cleaned;


-- One record per household containing detailed expenditure components.
CREATE TABLE household_expenditure_breakdown (
    expenditure_breakdown_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    household_id BIGINT UNSIGNED NOT NULL,
    purchased_food_expenditure DECIMAL(20,4) NULL,
    own_produced_food_value DECIMAL(20,4) NULL,
    gifts_and_in_kind_food DECIMAL(20,4) NULL,
    food_and_non_alcoholic_expenditure DECIMAL(20,4) NULL,
    alcohol_and_tobacco_expenditure DECIMAL(20,4) NULL,
    clothing_expenditure DECIMAL(20,4) NULL,
    housing_expenditure DECIMAL(20,4) NULL,
    furniture_expenditure DECIMAL(20,4) NULL,
    health_expenditure DECIMAL(20,4) NULL,
    transport_expenditure DECIMAL(20,4) NULL,
    communication_expenditure DECIMAL(20,4) NULL,
    recreation_expenditure DECIMAL(20,4) NULL,
    education_expenditure DECIMAL(20,4) NULL,
    restaurants_expenditure DECIMAL(20,4) NULL,
    miscellaneous_expenditure DECIMAL(20,4) NULL,
    food_expenditure DECIMAL(20,4) NULL,
    durable_expenditure DECIMAL(20,4) NULL,
    actual_and_imputed_rentals DECIMAL(20,4) NULL,
    non_food_expenditure DECIMAL(20,4) NULL,
    lumpy_expenditure DECIMAL(20,4) NULL,
    taxes_and_levies DECIMAL(20,4) NULL,
    food_expenditure_share DECIMAL(18,8) NULL,

    PRIMARY KEY (expenditure_breakdown_key),
    UNIQUE KEY uq_expenditure_household (household_id),
    CONSTRAINT fk_expenditure_household
        FOREIGN KEY (household_id)
        REFERENCES fact_household (household_id)
        ON DELETE CASCADE
) ENGINE = InnoDB;

INSERT INTO household_expenditure_breakdown (
    household_id,
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
    food_expenditure_share
)
SELECT
    household_id,
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
    food_expenditure_share
FROM depi_egypt_raw_import.household_cleaned;


-- =============================================================================
-- SECTION 4: CREATE AND LOAD PERSON DIMENSIONS
-- =============================================================================

-- literacy_status is intentionally retained with demographic attributes.
CREATE TABLE dim_person_demographics (
    demographics_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    gender VARCHAR(120) NOT NULL,
    marital_status VARCHAR(120) NOT NULL,
    relationship_to_head VARCHAR(150) NOT NULL,
    literacy_status VARCHAR(150) NOT NULL,
    age_group VARCHAR(20) NOT NULL,
    PRIMARY KEY (demographics_key)
) ENGINE = InnoDB;

INSERT INTO dim_person_demographics (
    gender,
    marital_status,
    relationship_to_head,
    literacy_status,
    age_group
)
SELECT DISTINCT
    COALESCE(gender, 'Not stated'),
    COALESCE(marital_status, 'Not stated'),
    COALESCE(relationship_to_head, 'Not stated'),
    COALESCE(literacy_status, 'Not stated'),
    COALESCE(age_group, 'Not stated')
FROM depi_egypt_raw_import.individual_cleaned
ORDER BY 1, 2, 3, 4, 5;


CREATE TABLE dim_education (
    education_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    ever_attended_school VARCHAR(120) NOT NULL,
    education_level VARCHAR(150) NOT NULL,
    school_attendance_status VARCHAR(150) NOT NULL,
    current_school_level VARCHAR(150) NOT NULL,
    school_type VARCHAR(150) NOT NULL,
    PRIMARY KEY (education_key)
) ENGINE = InnoDB;

INSERT INTO dim_education (
    ever_attended_school,
    education_level,
    school_attendance_status,
    current_school_level,
    school_type
)
SELECT DISTINCT
    COALESCE(ever_attended_school, 'Not stated'),
    COALESCE(education_level, 'Not stated'),
    COALESCE(school_attendance_status, 'Not stated'),
    COALESCE(current_school_level, 'Not stated'),
    COALESCE(school_type, 'Not stated')
FROM depi_egypt_raw_import.individual_cleaned
ORDER BY 1, 2, 3, 4, 5;


CREATE TABLE dim_health_protection (
    health_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    disability_status VARCHAR(120) NOT NULL,
    disability_type VARCHAR(150) NOT NULL,
    has_chronic_disease TINYINT UNSIGNED NULL,
    has_health_insurance TINYINT UNSIGNED NOT NULL,
    insurance_type VARCHAR(150) NOT NULL,
    has_social_security TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (health_key)
) ENGINE = InnoDB;

INSERT INTO dim_health_protection (
    disability_status,
    disability_type,
    has_chronic_disease,
    has_health_insurance,
    insurance_type,
    has_social_security
)
SELECT DISTINCT
    COALESCE(disability_status, 'Not stated'),
    COALESCE(disability_type, 'Not stated'),
    has_chronic_disease,
    COALESCE(has_health_insurance, 0),
    COALESCE(insurance_type, 'Not stated'),
    COALESCE(has_social_security, 0)
FROM depi_egypt_raw_import.individual_cleaned
ORDER BY 1, 2, 3, 4, 5, 6;


CREATE TABLE dim_employment (
    employment_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    labor_force_status VARCHAR(150) NOT NULL,
    main_activity_status VARCHAR(150) NOT NULL,
    employment_status VARCHAR(150) NOT NULL,
    occupation VARCHAR(200) NOT NULL,
    industry VARCHAR(200) NOT NULL,
    employment_sector VARCHAR(150) NOT NULL,
    PRIMARY KEY (employment_key)
) ENGINE = InnoDB;

INSERT INTO dim_employment (
    labor_force_status,
    main_activity_status,
    employment_status,
    occupation,
    industry,
    employment_sector
)
SELECT DISTINCT
    COALESCE(labor_force_status, 'Not stated'),
    COALESCE(main_activity_status, 'Not stated'),
    COALESCE(employment_status, 'Not stated'),
    COALESCE(occupation, 'Not stated'),
    COALESCE(industry, 'Not stated'),
    COALESCE(employment_sector, 'Not stated')
FROM depi_egypt_raw_import.individual_cleaned
ORDER BY 1, 2, 3, 4, 5, 6;


-- One role-playing dimension is used by both father and mother foreign keys.
CREATE TABLE dim_parent_profile (
    parent_profile_key INT UNSIGNED NOT NULL AUTO_INCREMENT,
    present_at_home VARCHAR(120) NOT NULL,
    marital_status VARCHAR(150) NOT NULL,
    education_level VARCHAR(150) NOT NULL,
    main_activity VARCHAR(150) NOT NULL,
    employment_status VARCHAR(150) NOT NULL,
    occupation VARCHAR(200) NOT NULL,
    industry VARCHAR(200) NOT NULL,
    employment_sector VARCHAR(150) NOT NULL,
    PRIMARY KEY (parent_profile_key)
) ENGINE = InnoDB;

INSERT INTO dim_parent_profile (
    present_at_home,
    marital_status,
    education_level,
    main_activity,
    employment_status,
    occupation,
    industry,
    employment_sector
)
SELECT DISTINCT
    parent_profiles.present_at_home,
    parent_profiles.marital_status,
    parent_profiles.education_level,
    parent_profiles.main_activity,
    parent_profiles.employment_status,
    parent_profiles.occupation,
    parent_profiles.industry,
    parent_profiles.employment_sector
FROM (
    SELECT
        COALESCE(father_present_at_home, 'Not stated') AS present_at_home,
        COALESCE(father_marital_status, 'Not stated') AS marital_status,
        COALESCE(father_education_level, 'Not stated') AS education_level,
        COALESCE(father_main_activity, 'Not stated') AS main_activity,
        COALESCE(father_employment_status, 'Not stated') AS employment_status,
        COALESCE(father_occupation, 'Not stated') AS occupation,
        COALESCE(father_industry, 'Not stated') AS industry,
        COALESCE(father_employment_sector, 'Not stated') AS employment_sector
    FROM depi_egypt_raw_import.individual_cleaned

    UNION

    SELECT
        COALESCE(mother_present_at_home, 'Not stated'),
        COALESCE(mother_marital_status, 'Not stated'),
        COALESCE(mother_education_level, 'Not stated'),
        COALESCE(mother_main_activity, 'Not stated'),
        COALESCE(mother_employment_status, 'Not stated'),
        COALESCE(mother_occupation, 'Not stated'),
        COALESCE(mother_industry, 'Not stated'),
        COALESCE(mother_employment_sector, 'Not stated')
    FROM depi_egypt_raw_import.individual_cleaned
) AS parent_profiles
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8;


-- Indexed temporary lookups keep the person-fact load fast while preserving
-- the clean physical structure of the final dimensions.
DROP TEMPORARY TABLE IF EXISTS map_person_demographics;
CREATE TEMPORARY TABLE map_person_demographics (
    lookup_hash BINARY(32) NOT NULL,
    demographics_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_person_demographics
SELECT
    UNHEX(SHA2(CONCAT_WS(
        CHAR(31), gender, marital_status, relationship_to_head,
        literacy_status, age_group
    ), 256)),
    demographics_key
FROM dim_person_demographics;


DROP TEMPORARY TABLE IF EXISTS map_education;
CREATE TEMPORARY TABLE map_education (
    lookup_hash BINARY(32) NOT NULL,
    education_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_education
SELECT
    UNHEX(SHA2(CONCAT_WS(
        CHAR(31), ever_attended_school, education_level,
        school_attendance_status, current_school_level, school_type
    ), 256)),
    education_key
FROM dim_education;


DROP TEMPORARY TABLE IF EXISTS map_health_protection;
CREATE TEMPORARY TABLE map_health_protection (
    lookup_hash BINARY(32) NOT NULL,
    health_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_health_protection
SELECT
    UNHEX(SHA2(CONCAT_WS(
        CHAR(31), disability_status, disability_type,
        COALESCE(CAST(has_chronic_disease AS CHAR), 'NULL'),
        CAST(has_health_insurance AS CHAR), insurance_type,
        CAST(has_social_security AS CHAR)
    ), 256)),
    health_key
FROM dim_health_protection;


DROP TEMPORARY TABLE IF EXISTS map_employment;
CREATE TEMPORARY TABLE map_employment (
    lookup_hash BINARY(32) NOT NULL,
    employment_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_employment
SELECT
    UNHEX(SHA2(CONCAT_WS(
        CHAR(31), labor_force_status, main_activity_status,
        employment_status, occupation, industry, employment_sector
    ), 256)),
    employment_key
FROM dim_employment;


DROP TEMPORARY TABLE IF EXISTS map_father_profile;
CREATE TEMPORARY TABLE map_father_profile (
    lookup_hash BINARY(32) NOT NULL,
    parent_profile_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_father_profile
SELECT
    UNHEX(SHA2(CONCAT_WS(
        CHAR(31), present_at_home, marital_status, education_level,
        main_activity, employment_status, occupation, industry,
        employment_sector
    ), 256)),
    parent_profile_key
FROM dim_parent_profile;


-- MySQL cannot reference one temporary table twice in the same statement,
-- so the mother role receives an independent lookup with identical contents.
DROP TEMPORARY TABLE IF EXISTS map_mother_profile;
CREATE TEMPORARY TABLE map_mother_profile (
    lookup_hash BINARY(32) NOT NULL,
    parent_profile_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (lookup_hash)
) ENGINE = InnoDB;

INSERT INTO map_mother_profile
SELECT
    lookup_hash,
    parent_profile_key
FROM map_father_profile;


-- =============================================================================
-- SECTION 5: CREATE AND LOAD THE PERSON FACT TABLE
-- =============================================================================

CREATE TABLE fact_person (
    household_id BIGINT UNSIGNED NOT NULL,
    person_id INT UNSIGNED NOT NULL,
    demographics_key INT UNSIGNED NOT NULL,
    education_key INT UNSIGNED NOT NULL,
    health_key INT UNSIGNED NOT NULL,
    employment_key INT UNSIGNED NOT NULL,
    father_profile_key INT UNSIGNED NOT NULL,
    mother_profile_key INT UNSIGNED NOT NULL,

    person_weight DECIMAL(18,6) NULL,
    age SMALLINT UNSIGNED NULL,
    years_of_schooling INT NULL,
    father_id INT UNSIGNED NULL,
    father_age SMALLINT UNSIGNED NULL,
    mother_id INT UNSIGNED NULL,
    mother_age SMALLINT UNSIGNED NULL,

    PRIMARY KEY (household_id, person_id),
    KEY ix_person_demographics (demographics_key),
    KEY ix_person_education (education_key),
    KEY ix_person_health (health_key),
    KEY ix_person_employment (employment_key),
    KEY ix_person_father (father_profile_key),
    KEY ix_person_mother (mother_profile_key),

    CONSTRAINT fk_person_household
        FOREIGN KEY (household_id)
        REFERENCES fact_household (household_id),

    CONSTRAINT fk_person_demographics
        FOREIGN KEY (demographics_key)
        REFERENCES dim_person_demographics (demographics_key),

    CONSTRAINT fk_person_education
        FOREIGN KEY (education_key)
        REFERENCES dim_education (education_key),

    CONSTRAINT fk_person_health
        FOREIGN KEY (health_key)
        REFERENCES dim_health_protection (health_key),

    CONSTRAINT fk_person_employment
        FOREIGN KEY (employment_key)
        REFERENCES dim_employment (employment_key),

    CONSTRAINT fk_person_father
        FOREIGN KEY (father_profile_key)
        REFERENCES dim_parent_profile (parent_profile_key),

    CONSTRAINT fk_person_mother
        FOREIGN KEY (mother_profile_key)
        REFERENCES dim_parent_profile (parent_profile_key)
) ENGINE = InnoDB;


INSERT INTO fact_person (
    household_id,
    person_id,
    demographics_key,
    education_key,
    health_key,
    employment_key,
    father_profile_key,
    mother_profile_key,
    person_weight,
    age,
    years_of_schooling,
    father_id,
    father_age,
    mother_id,
    mother_age
)
SELECT
    i.household_id,
    i.person_id,
    d.demographics_key,
    e.education_key,
    h.health_key,
    em.employment_key,
    fp.parent_profile_key,
    mp.parent_profile_key,
    i.household_weight AS person_weight,
    i.age,
    i.years_of_schooling,
    i.father_id,
    i.father_age,
    i.mother_id,
    i.mother_age
FROM depi_egypt_raw_import.individual_cleaned i
JOIN fact_household fh
  ON fh.household_id = i.household_id
JOIN map_person_demographics d
  ON d.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(i.gender, 'Not stated'),
      COALESCE(i.marital_status, 'Not stated'),
      COALESCE(i.relationship_to_head, 'Not stated'),
      COALESCE(i.literacy_status, 'Not stated'),
      COALESCE(i.age_group, 'Not stated')
  ), 256))
JOIN map_education e
  ON e.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(i.ever_attended_school, 'Not stated'),
      COALESCE(i.education_level, 'Not stated'),
      COALESCE(i.school_attendance_status, 'Not stated'),
      COALESCE(i.current_school_level, 'Not stated'),
      COALESCE(i.school_type, 'Not stated')
  ), 256))
JOIN map_health_protection h
  ON h.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(i.disability_status, 'Not stated'),
      COALESCE(i.disability_type, 'Not stated'),
      COALESCE(CAST(i.has_chronic_disease AS CHAR), 'NULL'),
      CAST(COALESCE(i.has_health_insurance, 0) AS CHAR),
      COALESCE(i.insurance_type, 'Not stated'),
      CAST(COALESCE(i.has_social_security, 0) AS CHAR)
  ), 256))
JOIN map_employment em
  ON em.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(i.labor_force_status, 'Not stated'),
      COALESCE(i.main_activity_status, 'Not stated'),
      COALESCE(i.employment_status, 'Not stated'),
      COALESCE(i.occupation, 'Not stated'),
      COALESCE(i.industry, 'Not stated'),
      COALESCE(i.employment_sector, 'Not stated')
  ), 256))
JOIN map_father_profile fp
  ON fp.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(i.father_present_at_home, 'Not stated'),
      COALESCE(i.father_marital_status, 'Not stated'),
      COALESCE(i.father_education_level, 'Not stated'),
      COALESCE(i.father_main_activity, 'Not stated'),
      COALESCE(i.father_employment_status, 'Not stated'),
      COALESCE(i.father_occupation, 'Not stated'),
      COALESCE(i.father_industry, 'Not stated'),
      COALESCE(i.father_employment_sector, 'Not stated')
  ), 256))
JOIN map_mother_profile mp
  ON mp.lookup_hash = UNHEX(SHA2(CONCAT_WS(
      CHAR(31),
      COALESCE(i.mother_present_at_home, 'Not stated'),
      COALESCE(i.mother_marital_status, 'Not stated'),
      COALESCE(i.mother_education_level, 'Not stated'),
      COALESCE(i.mother_main_activity, 'Not stated'),
      COALESCE(i.mother_employment_status, 'Not stated'),
      COALESCE(i.mother_occupation, 'Not stated'),
      COALESCE(i.mother_industry, 'Not stated'),
      COALESCE(i.mother_employment_sector, 'Not stated')
  ), 256));

DROP TEMPORARY TABLE map_person_demographics;
DROP TEMPORARY TABLE map_education;
DROP TEMPORARY TABLE map_health_protection;
DROP TEMPORARY TABLE map_employment;
DROP TEMPORARY TABLE map_father_profile;
DROP TEMPORARY TABLE map_mother_profile;


-- =============================================================================
-- SECTION 6: VALIDATE THE FINAL MODEL
-- =============================================================================

-- Row counts must match the cleaned source grains.
SELECT
    (SELECT COUNT(*)
       FROM depi_egypt_raw_import.household_cleaned) AS source_households,
    (SELECT COUNT(*)
       FROM fact_household) AS fact_households,
    (SELECT COUNT(*)
       FROM household_asset_ownership) AS asset_rows,
    (SELECT COUNT(*)
       FROM household_expenditure_breakdown) AS expenditure_rows;

SELECT
    (SELECT COUNT(*)
       FROM depi_egypt_raw_import.individual_cleaned) AS source_people,
    (SELECT COUNT(*)
       FROM fact_person) AS fact_people;


-- Both results should be zero.
SELECT COUNT(*) AS households_without_people
FROM fact_household h
LEFT JOIN fact_person p
  ON p.household_id = h.household_id
WHERE p.household_id IS NULL;

SELECT COUNT(*) AS people_without_household
FROM fact_person p
LEFT JOIN fact_household h
  ON h.household_id = p.household_id
WHERE h.household_id IS NULL;


-- Confirm that every one-to-one household detail relationship is complete.
SELECT
    SUM(a.household_id IS NULL) AS households_without_asset_record,
    SUM(x.household_id IS NULL) AS households_without_expenditure_record
FROM fact_household h
LEFT JOIN household_asset_ownership a
  ON a.household_id = h.household_id
LEFT JOIN household_expenditure_breakdown x
  ON x.household_id = h.household_id;


-- Display the physical relationships created in the target schema.
SELECT
    table_name,
    column_name,
    referenced_table_name,
    referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'depi_egypt_analytics'
  AND referenced_table_name IS NOT NULL
ORDER BY table_name, column_name;

