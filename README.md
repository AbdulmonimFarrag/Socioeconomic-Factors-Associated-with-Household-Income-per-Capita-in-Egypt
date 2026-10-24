# Egypt Household Socioeconomic Dashboard

An interactive dashboard for exploring socioeconomic factors associated with household income per capita in Egypt using HIECS 2021 data.

## Live dashboard

The production dashboard is published with GitHub Pages:

**https://abdulmonimfarrag.github.io/Socioeconomic-Factors-Associated-with-Household-Income-per-Capita-in-Egypt/**

## Repository structure

| File | Purpose |
| --- | --- |
| `index.html` | Production dashboard served by GitHub Pages |
| `dashboard_template.html` | Dashboard UI template with data placeholders |
| `build_dashboard.py` | Python data pipeline that aggregates the survey workbooks and injects the results into the template |
| `requirements.txt` | Python dependencies required to rebuild the dashboard |

## Build locally

The raw HIECS workbooks are intentionally kept outside the repository. Place these files in the project directory:

- `Egypt21_Household_Translated.xlsx`
- `Egypt21_Individual_Translated.xlsx`

Then run:

```bash
python -m pip install -r requirements.txt
python build_dashboard.py
```

The command generates a deployment ready `index.html`.

Custom paths can be supplied when needed:

```bash
python build_dashboard.py \
  --household path/to/Egypt21_Household_Translated.xlsx \
  --individual path/to/Egypt21_Individual_Translated.xlsx \
  --template dashboard_template.html \
  --out index.html
```

## Team

- Abdulmonim Farrag — Team Leader
- Toqa Tamer
- Eyad Wael
- Saifelden Mohamed
- Mohamed Taher

Instructor: **Dr. Amal Mahmoud**

## Data privacy

The repository contains aggregated dashboard data only. Raw survey workbooks are excluded from version control.

