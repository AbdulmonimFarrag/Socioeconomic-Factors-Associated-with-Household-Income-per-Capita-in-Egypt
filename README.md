# Egypt Household Socioeconomic Analytics Project

A multi-tool analytics project exploring socioeconomic factors associated with household income per capita in Egypt using HIECS 2021 data.

## Live dashboard

**https://egypt-household-income-dashboard.vercel.app**

## Repository structure

| Path | Purpose |
| --- | --- |
| `Python/` | Python data preparation, dashboard builder, dashboard template, dependencies, and generated dashboard copy |
| `SQL/` | Database schema, cleaning pipeline, statistics, analytical insights, and MySQL Workbench ERD |
| `Tableau/` | Tableau work area for the next project phase |
| `PowerBI/` | Power BI work area for the next project phase |
| `index.html` | Production dashboard entry point kept at the repository root for deployment |

## Rebuild the Python dashboard

The raw HIECS workbooks are intentionally excluded from the repository. Place the translated household and individual workbooks locally, then run:

```bash
python -m pip install -r Python/requirements.txt
python Python/build_dashboard.py \
  --household path/to/Egypt21_Household_Translated.xlsx \
  --individual path/to/Egypt21_Individual_Translated.xlsx \
  --template Python/dashboard_template.html \
  --out index.html
```

## SQL workflow

Run the SQL files in this order:

1. `SQL/Cleaning.sql`
2. `SQL/Building Schema.sql`
3. `SQL/Statistics.sql`
4. `SQL/Insights.sql`

The MySQL Workbench model is available at `SQL/ERD Model.mwb`.

## Team

- Abdulmonim Farrag — Team Leader
- Toqa Tamer
- Eyad Wael
- Saifelden Mohamed
- Mohamed Taher

Instructor: **Dr. Amal Mahmoud**

## Data privacy

The repository contains code, models, and aggregated dashboard output only. Raw survey workbooks are excluded from version control.
