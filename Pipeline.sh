#!/bin/bash

# Some variables already defined in .env
source .env

GOBIERTO_ETL_UTILS=$BASE_DIR/gobierto-etl-utils
REUS_ETL=$BASE_DIR/gobierto-etl-reus
GOBIERTO=/var/www/gobierto/current
WORKING_DIR=/tmp/reus
REUS_INE_CODE=43123
YEARS=2018
# Data
EXPENSES_PLANNED_URL=https://opendata.reus.cat/dataset/2405134b-2af3-47b5-9cab-1cfb42b8a894/resource/e5b92612-5f9d-4a94-abbe-e6394909e532/download/8f2155cc-7c25-4781-a3ba-036bd7c25cb7.json
EXPENSES_EXECUTED_URL=https://opendata.reus.cat/dataset/a7848204-7d13-4283-b7b4-32e02b5d2627/resource/0e743d72-99c7-4122-9a9d-9ab64d1ef308/download/d1280a6a-11be-4d3d-8d55-15393ddccb33.json
INCOME_PLANNED_URL=https://opendata.reus.cat/dataset/1e25767b-49b9-4431-b7ba-6d12cecceac3/resource/3aaa81d6-25ca-465e-9ffc-59d2ba04de23/download/eac43498-91e9-4438-9122-9fe66459b625.json
INCOME_EXECUTED_URL=https://opendata.reus.cat/dataset/68a21aa9-0e44-4d8e-ae73-ffdff6bac4fe/resource/ab77dad1-ddc4-4622-8e98-e35eaf6ec3f5/download/c3271b2d-1a4e-4dce-9b9f-d22f40b5fa65.json

rm -rf $WORKING_DIR

# Extract > Download data sources
cd $GOBIERTO_ETL_UTILS; ruby operations/download/run.rb $EXPENSES_PLANNED_URL  $WORKING_DIR/expenses-planned.json
cd $GOBIERTO_ETL_UTILS; ruby operations/download/run.rb $EXPENSES_EXECUTED_URL $WORKING_DIR/expenses-executed.json
cd $GOBIERTO_ETL_UTILS; ruby operations/download/run.rb $INCOME_PLANNED_URL    $WORKING_DIR/income-planned.json
cd $GOBIERTO_ETL_UTILS; ruby operations/download/run.rb $INCOME_EXECUTED_URL   $WORKING_DIR/income-executed.json

# Extract > Check valid JSON
cd $GOBIERTO_ETL_UTILS; ruby operations/check-json/run.rb $WORKING_DIR/expenses-planned.json
cd $GOBIERTO_ETL_UTILS; ruby operations/check-json/run.rb $WORKING_DIR/expenses-executed.json
cd $GOBIERTO_ETL_UTILS; ruby operations/check-json/run.rb $WORKING_DIR/income-planned.json
cd $GOBIERTO_ETL_UTILS; ruby operations/check-json/run.rb $WORKING_DIR/income-executed.json

# Extract > Check data source columns
cd $REUS_ETL; ruby operations/gobierto_budgets/check-json-columns/run.rb $WORKING_DIR/expenses-planned.json
cd $REUS_ETL; ruby operations/gobierto_budgets/check-json-columns/run.rb $WORKING_DIR/expenses-executed.json
cd $REUS_ETL; ruby operations/gobierto_budgets/check-json-columns/run.rb $WORKING_DIR/income-planned.json
cd $REUS_ETL; ruby operations/gobierto_budgets/check-json-columns/run.rb $WORKING_DIR/income-executed.json

# Transform > Transform planned budgets data files
cd $REUS_ETL; ruby operations/gobierto_budgets/transform-planned/run.rb $WORKING_DIR/expenses-planned.json $WORKING_DIR/expenses-planned-transformed.json E $YEARS
cd $REUS_ETL; ruby operations/gobierto_budgets/transform-planned/run.rb $WORKING_DIR/income-planned.json $WORKING_DIR/income-planned-transformed.json I $YEARS

## # Transform > Transform executed budgets data files
cd $REUS_ETL; ruby operations/gobierto_budgets/transform-executed/run.rb $WORKING_DIR/expenses-executed.json $WORKING_DIR/expenses-executed-transformed.json E $YEARS
cd $REUS_ETL; ruby operations/gobierto_budgets/transform-executed/run.rb $WORKING_DIR/income-executed.json $WORKING_DIR/income-executed-transformed.json I $YEARS

# Load > Import planned budgets
cd $REUS_ETL; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $WORKING_DIR/expenses-planned-transformed.json $YEARS
cd $REUS_ETL; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $WORKING_DIR/income-planned-transformed.json $YEARS

# Load > Import executed budgets
cd $REUS_ETL; ruby operations/gobierto_budgets/import-executed-budgets/run.rb $WORKING_DIR/expenses-executed-transformed.json $YEARS
cd $REUS_ETL; ruby operations/gobierto_budgets/import-executed-budgets/run.rb $WORKING_DIR/income-executed-transformed.json $YEARS

# Load > Calculate totals
echo $REUS_INE_CODE > $WORKING_DIR/organization.id.txt
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/update_total_budget/run.rb $YEARS $WORKING_DIR/organization.id.txt

# Load > Calculate bubbles
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/bubbles/run.rb $WORKING_DIR/organization.id.txt

# Load > Calculate annual data
cd $GOBIERTO; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto_budgets/annual_data/run.rb  $YEARS $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $GOBIERTO; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/publish-activity/run.rb budgets_updated $WORKING_DIR/organization.id.txt

# Clear cache
cd $GOBIERTO; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/clear-cache/run.rb


