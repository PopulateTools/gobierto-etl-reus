# Gobierto ETL for Reus

ETL scripts for Gobierto Reus site

## Setup

Edit `.env.example` and copy it to `.env` or `.rbenv-vars` with the expected values.

This repository relies heavily in [gobierto_budgets_data](https://github.com/PopulateTools/gobierto_budgets_data)

## Available operations

- check-json-columns
- transform-planned
- transform-executed
- import-planned-budgets
- import-executed-budgets

## How to add new data

Follow these changes in `Pipeline.sh` file:

1. Edit `YEARS` variable and add a new year
2. Edit `EXPENSES_PLANNED_URL`, `EXPENSES_EXECUTED_URL`, `INCOME_PLANNED_URL` and `INCOME_EXECUTED_URL` variables with the urls of the JSON files of the new year.

