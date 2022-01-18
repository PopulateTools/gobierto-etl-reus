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
YEARS=( 2018 2019 2020 2021 2022)

# Data files
EXPENSES_PLANNED_URL[2018]=https://opendata.reus.cat/datastore/dump/8f2155cc-7c25-4781-a3ba-036bd7c25cb7?format=json
EXPENSES_PLANNED_URL[2019]=https://opendata.reus.cat/datastore/dump/73bdb636-0390-48f1-8d7f-388508f5d5a2?format=json
EXPENSES_PLANNED_URL[2020]=https://opendata.reus.cat/datastore/dump/e04c6544-a5e6-4b9e-8d7b-be99b400c76b?format=json
EXPENSES_PLANNED_URL[2021]=https://opendata.reus.cat/datastore/dump/c6e335bd-3da6-4f59-ac99-316f40d41b84?format=json
EXPENSES_PLANNED_URL[2022]=https://opendata.reus.cat/datastore/dump/789027e1-bf33-4f34-8a38-cd4db12e3c2b?format=json

EXPENSES_EXECUTED_URL[2018]=https://opendata.reus.cat/datastore/dump/d1280a6a-11be-4d3d-8d55-15393ddccb33?format=json
EXPENSES_EXECUTED_URL[2019]=https://opendata.reus.cat/datastore/dump/4af822fb-0d3b-478d-a54a-3eadc7ceb265?format=json
EXPENSES_EXECUTED_URL[2020]=https://opendata.reus.cat/datastore/dump/70720657-657c-4708-af81-040ffe7530b4?format=json
EXPENSES_EXECUTED_URL[2021]=https://opendata.reus.cat/datastore/dump/7bcecd44-d4bd-44a6-8c7d-27ea1977d029?format=json
EXPENSES_EXECUTED_URL[2022]=https://opendata.reus.cat/datastore/dump/2bb6dd47-b259-484c-97a8-e6a1355b3f7f?format=json

INCOME_PLANNED_URL[2018]=https://opendata.reus.cat/datastore/dump/eac43498-91e9-4438-9122-9fe66459b625?format=json
INCOME_PLANNED_URL[2019]=https://opendata.reus.cat/datastore/dump/ee89210c-4e1e-487f-9c95-f1fcb3fbe5e7?format=json
INCOME_PLANNED_URL[2020]=https://opendata.reus.cat/datastore/dump/25347a34-5813-4cde-9cd8-41f87c5cfce9?format=json
INCOME_PLANNED_URL[2021]=https://opendata.reus.cat/datastore/dump/fa2a2b23-33f3-4b9f-865b-56fb8f983d08?format=json
INCOME_PLANNED_URL[2022]=https://opendata.reus.cat/datastore/dump/ae610172-4597-4bac-80c5-3ce50220f7a9?format=json

INCOME_EXECUTED_URL[2018]=https://opendata.reus.cat/datastore/dump/c3271b2d-1a4e-4dce-9b9f-d22f40b5fa65?format=json
INCOME_EXECUTED_URL[2019]=https://opendata.reus.cat/datastore/dump/37b1baba-c07f-4459-b3bc-63f67c0444d2?format=json
INCOME_EXECUTED_URL[2020]=https://opendata.reus.cat/datastore/dump/6ff99726-9564-4c1e-9c6d-6ddf4cd5c802?format=json
INCOME_EXECUTED_URL[2021]=https://opendata.reus.cat/datastore/dump/7e5e556c-6ef0-4815-a53a-9b16c451d3c6?format=json
INCOME_EXECUTED_URL[2022]=https://opendata.reus.cat/datastore/dump/431d4cd8-b2e8-4dd1-842d-f13fe46c12b9?format=json

BUDGETS_UPDATED_DATE_DATASET_URL=https://opendata.reus.cat/api/3/action/package_show?id=seguiment-pressupostari-de-despeses-de-l-ajuntament-de-reus
## End data files

rm -rf $WORKING_DIR
mkdir $WORKING_DIR
echo $REUS_INE_CODE > $WORKING_DIR/organization.id.txt

for year in ${YEARS[*]}; do
  #Clear existing budgets
  cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/clear-budgets/run.rb $WORKING_DIR/organization.id.txt $year

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
  #if [ $year -ne 2020 ]; then
	  cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb $WORKING_DIR/expenses-planned-updated-transformed.json $year
	  cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb $WORKING_DIR/income-planned-updated-transformed.json $year
  #fi

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
