# Socioeconomic Factors Associated with Household Income per Capita in Egypt

> 📎 Project Name :  
> Socioeconomic Factors Associated with Household Income per Capita in Egypt

> 📌 Project Overview:  
> An end-to-end data analytics project that explores the socioeconomic factors associated with household income per capita in Egypt. The project uses the Egypt HIECS 2021 survey data to transform raw household and individual records into a clean analytical model, weighted indicators, statistical insights, and an interactive web dashboard. Users can compare governorates, urban and rural areas, gender groups, age groups, education, employment, expenditure patterns, living conditions, and household assets.

> 👥 Team Members:
>
> - Abdulmonim Farrag — Team Leader
> - Toqa Tamer
> - Eyad Wael
> - Saifelden Mohamed
> - Mohamed Taher

> 📎🎓 Instructor  
> Dr. Amal Mahmoud

> 🎯 Project Objectives:
>
> - Clean, translate, validate, and integrate the household and individual survey datasets.
> - Design a reliable analytical data model for household socioeconomic analysis.
> - Calculate survey-weighted indicators for income, expenditure, education, employment, health, housing, and asset ownership.
> - Identify the factors and regional differences associated with household income per capita.
> - Present the findings through clear, interactive, and decision-oriented dashboards.
> - Deliver a reproducible workflow that can rebuild the dashboard from the source workbooks.

> 📦 Project Scope :
>
> - Data cleaning, translation, validation, and integration.
> - Exploratory data analysis and descriptive statistics.
> - SQL data modeling and analytical queries.
> - Python-based data aggregation and dashboard generation.
> - Interactive analysis by governorate, area, gender, age, and education.
> - Visualization of income, expenditure, living conditions, employment, and household assets.
> - Documentation, quality assurance, and public deployment with GitHub Pages.
> - Raw HIECS workbooks are not published; the public dashboard contains aggregated results only.

> 📅 Project Plan (5 Weeks)
>
> | Week | Phase | Main Deliverables |
> | --- | --- | --- |
> | 1 | Project definition and data understanding | Requirements, research questions, data dictionary, and source assessment |
> | 2 | Data preparation | Cleaning, translation, missing-value treatment, validation, and dataset integration |
> | 3 | Data modeling and analysis | SQL model, analytical queries, weighted statistics, and initial findings |
> | 4 | Dashboard development | Python dashboard, Tableau views, filters, KPIs, and visual refinements |
> | 5 | Testing and delivery | QA, insight validation, documentation, GitHub publishing, and final presentation |

## Live Dashboard

Open the dashboard:

- **[GitHub Pages](https://abdulmonimfarrag.github.io/Socioeconomic-Factors-Associated-with-Household-Income-per-Capita-in-Egypt/)**
- **[Vercel](https://egypt-household-income-dashboard.vercel.app)**

## Repository Files

| File | Purpose |
| --- | --- |
| `index.html` | The finished dashboard and public website entry point at the repository root. Keep this filename so GitHub Pages can open it automatically. |
| `Python/dashboard_template.html` | The dashboard source template. It contains layout, styles, charts, and data placeholders; it is not a second published dashboard. |
| `Python/build_dashboard.py` | The Python pipeline that aggregates the source workbooks and regenerates the root `index.html`. |
| `Python/requirements.txt` | Python packages needed to rebuild the dashboard. |
| `Python/*.ipynb` | Python analysis notebook. |
| `SQL/` | Database schema, cleaning pipeline, statistics, insights, and ERD model. |
| `Tableau/` | Tableau dashboard files. |
| `PowerBI/` | Power BI dashboard files. |

## Run the Dashboard

No Python installation is required to view the ready version. Download the repository and open `index.html` in a browser.

## Rebuild with Python

The raw HIECS workbooks are intentionally excluded from the public repository. To rebuild the dashboard, keep the source workbooks locally and run:

- `Egypt21_Household_Translated.xlsx`
- `Egypt21_Individual_Translated.xlsx`

Then run:

```bash
python -m pip install -r Python/requirements.txt
python Python/build_dashboard.py \
  --household path/to/Egypt21_Household_Translated.xlsx \
  --individual path/to/Egypt21_Individual_Translated.xlsx \
  --template Python/dashboard_template.html \
  --out index.html
```

The command updates the root `index.html` used by GitHub Pages.

## SQL Workflow

Run the SQL files in this order:

1. `SQL/Cleaning.sql`
2. `SQL/Building Schema.sql`
3. `SQL/Statistics.sql`
4. `SQL/Insights.sql`

## Data Privacy

The repository publishes aggregated dashboard results only. Raw survey workbooks are excluded from version control through `.gitignore`.

