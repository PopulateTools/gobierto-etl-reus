#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

require "json"

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Absolute path to a file containing a JSON downloaded from Sant Feliu data source
#  - 1: Absolute path of the output file
#  - 2: Income / Expenses
#  - 3: Year of the data
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/transform-executed/run.rb input.json output.json I 2010
#

if ARGV.length != 4
  raise "At least one argument is required"
end

input_file = ARGV[0]
output_file = ARGV[1]
kind = ARGV[2] == 'I' ? GobiertoData::GobiertoBudgets::INCOME : GobiertoData::GobiertoBudgets::EXPENSE
year = ARGV[3].to_i

puts "[START] transform-executed/run.rb with file=#{input_file} output=#{output_file} year=#{year}"

json_data = JSON.parse(File.read(input_file))

place = INE::Places::Place.find_by_slug('reus')
population = GobiertoData::GobiertoBudgets::Population.get(place.id, year)

base_data = {
  organization_id: place.id,
  ine_code: place.id.to_i,
  province_id: place.province.id.to_i,
  autonomy_id: place.province.autonomous_region.id.to_i,
  year: year,
  population: population
}

def normalize_data(data, kind)
  functional_data = {}
  economic_data = {}

  data.each do |row|
    functional_data, economic_data = process_row(row, functional_data, economic_data, kind)
  end

  return functional_data, economic_data
end

def process_row(row, functional_data, economic_data, kind)
  amount = kind == GobiertoData::GobiertoBudgets::INCOME ? row["PREVISIONS TOTALS"].to_f : row["OBLIGACIONS RECONEGUDES"].to_f
  amount = amount.round(2)
  functional_code = row["PROGRAMA"].try(:strip)
  economic_code   = row["ECONÒMICA"].strip

  if !functional_code.nil? && functional_code.length != economic_code.length
    if functional_code.length == 5 && economic_code.length == 3
      economic_code += "00"
    end
  end

  # Level 3
  economic_code_l3 = economic_code[0..2]
  if kind == GobiertoData::GobiertoBudgets::EXPENSE
    functional_code_l3 = functional_code[0..2]
    functional_data[functional_code_l3] ? functional_data[functional_code_l3] += amount : functional_data[functional_code_l3] = amount
  end
  economic_data[economic_code_l3] ? economic_data[economic_code_l3] += amount : economic_data[economic_code_l3] = amount

  # Level 2
  economic_code_l2 = economic_code[0..1]
  if kind == GobiertoData::GobiertoBudgets::EXPENSE
    functional_code_l2 = functional_code[0..1]
    functional_data[functional_code_l2] ? functional_data[functional_code_l2] += amount : functional_data[functional_code_l2] = amount
  end
  economic_data[economic_code_l2] ? economic_data[economic_code_l2] += amount : economic_data[economic_code_l2] = amount

  # Level 1
  economic_code_l1 = economic_code[0]
  if kind == GobiertoData::GobiertoBudgets::EXPENSE
    functional_code_l1 = functional_code[0]
    functional_data[functional_code_l1] ? functional_data[functional_code_l1] += amount : functional_data[functional_code_l1] = amount
  end
  economic_data[economic_code_l1] ? economic_data[economic_code_l1] += amount : economic_data[economic_code_l1] = amount

  return functional_data, economic_data
end

def hydratate(options)
  area_name = options.fetch(:area_name)
  data      = options.fetch(:data)
  base_data = options.fetch(:base_data)
  kind      = options.fetch(:kind)

  data.map do |code, amount|
    code = code.to_s
    level = code.length == 6 ? 4 : code.length
    parent_code = case level
                    when 1
                      nil
                    when 4
                      code[0..2]
                    else
                      code[0..-2]
                    end

    base_data.merge(amount: amount.round(2), code: code, level: level, kind: kind,
                    amount_per_inhabitant: base_data[:population] ? (amount / base_data[:population]).round(2) : nil,
                    parent_code: parent_code, type: area_name)
  end
end

functional_data, economic_data = normalize_data(json_data, kind)

output_data = hydratate(data: functional_data, area_name: GobiertoData::GobiertoBudgets::FUNCTIONAL_AREA_NAME, base_data: base_data, kind: kind) +
  hydratate(data: economic_data, area_name: GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME, base_data: base_data, kind: kind)

File.write(output_file, output_data.to_json)

puts "[END] transform-executed/run.rb output=#{output_file}"
