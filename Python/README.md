# Python Analysis and Dashboard

This folder contains the Python analysis notebook and the source files used to generate the interactive dashboard.

## Files

| File | Purpose |
| --- | --- |
| `Socioeconomic Factors Associated with Household Income per Capita in Egypt.ipynb` | Main Python analysis notebook. |
| `build_dashboard.py` | Loads the source workbooks, calculates the aggregated indicators, and generates the production dashboard. |
| `dashboard_template.html` | Source template containing the dashboard layout, styles, charts, and data placeholders. It is not a second published dashboard. |
| `requirements.txt` | Python dependencies required to rebuild the dashboard. |
| `../index.html` | Generated production dashboard kept at the repository root for GitHub Pages. |

## Live Dashboard
- [Vercel](https://egypt-household-income-dashboard.vercel.app)

## Rebuild the Dashboard

The raw HIECS workbooks are excluded from the public repository. Keep them locally, install the dependencies, and run:

```bash
python -m pip install -r Python/requirements.txt
python Python/build_dashboard.py \
  --household path/to/Egypt21_Household_Translated.xlsx \
  --individual path/to/Egypt21_Individual_Translated.xlsx \
  --template Python/dashboard_template.html \
  --out index.html
```

The command regenerates the root `index.html` used for deployment.

## Data Privacy

Only code and aggregated dashboard output are published. Raw household and individual survey workbooks must not be committed.
