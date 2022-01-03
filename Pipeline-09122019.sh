#!/bin/bash

set -e

# Some variables already defined in .env
source .env

GOBIERTO_ETL_UTILS=$BASE_DIR/gobierto-etl-utils
REUS_ETL=$BASE_DIR/gobierto-etl-reus
GOBIERTO=/var/www/gobierto/current
WORKING_DIR=/tmp/reus
REUS_INE_CODE=43123

# Years variable
YEARS=( 2018 2019 )

# Data files
EXPENSES_PLANNED_URL[2018]=https://opendata.reus.cat/dataset/2405134b-2af3-47b5-9cab-1cfb42b8a894/resource/e5b92612-5f9d-4a94-abbe-e6394909e532/download/8f2155cc-7c25-4781-a3ba-036bd7c25cb7.json
EXPENSES_PLANNED_URL[2019]=https://opendata.reus.cat/dataset/2405134b-2af3-47b5-9cab-1cfb42b8a894/resource/9ca154c3-203b-43f2-8570-12abbf6327ae/download/73bdb636-0390-48f1-8d7f-388508f5d5a2.json

EXPENSES_EXECUTED_URL[2018]=https://opendata.reus.cat/dataset/a7848204-7d13-4283-b7b4-32e02b5d2627/resource/0e743d72-99c7-4122-9a9d-9ab64d1ef308/download/d1280a6a-11be-4d3d-8d55-15393ddccb33.json
EXPENSES_EXECUTED_URL[2019]=https://opendata.reus.cat/dataset/a7848204-7d13-4283-b7b4-32e02b5d2627/resource/5d1425cb-fcc4-4985-b5f7-4dce2ae896f2/download/4af822fb-0d3b-478d-a54a-3eadc7ceb265.json

INCOME_PLANNED_URL[2018]=https://opendata.reus.cat/dataset/1e25767b-49b9-4431-b7ba-6d12cecceac3/resource/3aaa81d6-25ca-465e-9ffc-59d2ba04de23/download/eac43498-91e9-4438-9122-9fe66459b625.json
INCOME_PLANNED_URL[2019]=https://opendata.reus.cat/dataset/1e25767b-49b9-4431-b7ba-6d12cecceac3/resource/0dbd3c4d-ba2c-44a8-a2a1-92890f0ce758/download/ee89210c-4e1e-487f-9c95-f1fcb3fbe5e7.json

INCOME_EXECUTED_URL[2018]=https://opendata.reus.cat/dataset/68a21aa9-0e44-4d8e-ae73-ffdff6bac4fe/resource/ab77dad1-ddc4-4622-8e98-e35eaf6ec3f5/download/c3271b2d-1a4e-4dce-9b9f-d22f40b5fa65.json
INCOME_EXECUTED_URL[2019]=https://opendata.reus.cat/dataset/68a21aa9-0e44-4d8e-ae73-ffdff6bac4fe/resource/2b1d6adc-b15a-4766-a3e2-27db25abd760/download/37b1baba-c07f-4459-b3bc-63f67c0444d2.json

BUDGETS_UPDATED_DATE_DATASET_URL=https://opendata.reus.cat/api/3/action/package_show?id=seguiment-pressupostari-de-despeses-de-l-ajuntament-de-reus
## End data files

rm -rf $WORKING_DIR
mkdir $WORKING_DIR
echo $REUS_INE_CODE > $WORKING_DIR/organization.id.txt

for year in ${YEARS[*]}; do
  echo "- Importing year "$year

  # Extract > Download data sources
  cd $GOBIERTO_ETL_UTILS; ruby operations/download/run.rb ${EXPENSES_PLANNED_URL[$year]}  $WORKING_DIR/expenses-planned.json
  cd $GOBIERTO_ETL_UTILS; ruby operations/download/run.rb ${EXPENSES_EXECUTED_URL[$year]} $WORKING_DIR/expenses-executed.json
  cd $GOBIERTO_ETL_UTILS; ruby operations/download/run.rb ${INCOME_PLANNED_URL[$year]}    $WORKING_DIR/income-planned.json
  cd $GOBIERTO_ETL_UTILS; ruby operations/download/run.rb ${INCOME_EXECUTED_URL[$year]}   $WORKING_DIR/income-executed.json

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
  cd $REUS_ETL; ruby operations/gobierto_budgets/transform-planned/run.rb $WORKING_DIR/expenses-planned.json $WORKING_DIR/expenses-planned-transformed.json E $year
  cd $REUS_ETL; ruby operations/gobierto_budgets/transform-planned/run.rb $WORKING_DIR/income-planned.json $WORKING_DIR/income-planned-transformed.json I $year

  # Transform > Transform planned updated budgets data files
  cd $REUS_ETL; ruby operations/gobierto_budgets/transform-planned-updated/run.rb $WORKING_DIR/expenses-executed.json $WORKING_DIR/expenses-planned-updated-transformed.json E $year
  cd $REUS_ETL; ruby operations/gobierto_budgets/transform-planned-updated/run.rb $WORKING_DIR/income-executed.json $WORKING_DIR/income-planned-updated-transformed.json I $year

  ## # Transform > Transform executed budgets data files
  cd $REUS_ETL; ruby operations/gobierto_budgets/transform-executed/run.rb $WORKING_DIR/expenses-executed.json $WORKING_DIR/expenses-executed-transformed.json E $year
  cd $REUS_ETL; ruby operations/gobierto_budgets/transform-executed/run.rb $WORKING_DIR/income-executed.json $WORKING_DIR/income-executed-transformed.json I $year

  # Load > Import planned budgets
  cd $REUS_ETL; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $WORKING_DIR/expenses-planned-transformed.json $year
  cd $REUS_ETL; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $WORKING_DIR/income-planned-transformed.json $year

  # Load > Import planned updated budgets
  cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb $WORKING_DIR/expenses-planned-updated-transformed.json $year
  cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb $WORKING_DIR/income-planned-updated-transformed.json $year

  # Load > Import executed budgets
  cd $REUS_ETL; ruby operations/gobierto_budgets/import-executed-budgets/run.rb $WORKING_DIR/expenses-executed-transformed.json $year
  cd $REUS_ETL; ruby operations/gobierto_budgets/import-executed-budgets/run.rb $WORKING_DIR/income-executed-transformed.json $year

  # Load > Calculate totals
  cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/update_total_budget/run.rb $year $WORKING_DIR/organization.id.txt

  # Load > Calculate annual data
  cd $GOBIERTO; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto_budgets/annual_data/run.rb $year $WORKING_DIR/organization.id.txt

  echo "- [OK] Imported successfully\n\n\n"
done

# Load > Calculate bubbles
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/bubbles/run.rb $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $GOBIERTO; bin/rails runner $REUS_ETL/operations/gobierto_budgets/publish-activity/run.rb budgets_updated $BUDGETS_UPDATED_DATE_DATASET_URL $WORKING_DIR/organization.id.txt

# Clear cache
cd $GOBIERTO; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/clear-cache/run.rb --site-organization-id "$REUS_INE_CODE" --namespace "GobiertoBudgets"
