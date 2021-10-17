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
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/check-json-columns/run.rb input.json
#

if ARGV.length != 1
  raise "At least one argument is required"
end

input_file = ARGV[0]

puts "[START] check-json-columns/run.rb with file=#{input_file}"

json_data = JSON.parse(File.read(input_file))

if json_data.length < 1
  puts "[ERROR] 0 rows of information"
  exit(-1)
end

unless json_data.is_a?(Hash)
  puts "[ERROR] data is not a Hash"
  exit(-1)
end

columns = json_data["fields"].map{ |h| h["id"] }.sort

if columns != ["ANY", "CRÈDITS INICIALS", "DESCRIPCIÓ PARTIDA", "ECONÒMICA", "ORGÀNICA", "PROGRAMA", "_id"] &&
   columns != ["ANY", "CRÈDITS INICIALS", "CRÈDITS TOTALS CONSIGNATS", "DESCRIPCIÓ PARTIDA", "DISPOSICIONS O COMPROMISOS", "ECONÒMICA", "MODIFICACIONS CRÈDIT", "OBLIGACIONS RECONEGUDES", "ORGÀNICA", "PAGAMENTS REALITZATS", "PROGRAMA", "_id"]  &&
   columns != ["ANY", "DESCRIPCIÓ PARTIDA", "DRETS RECONEGUTS NETS", "ECONÒMICA", "ORGÀNICA", "PREVISIONS INICIALS", "PREVISIONS TOTALS", "RECAPTACIÓ LÍQUIDA", "TOTAL MODIFICACIONS", "_id"] &&
   columns != ["ANY", "DESCRIPCIÓ PARTIDA", "ECONÒMICA", "ORGÀNICA", "PREVISIONS INGRESSOS INICIALS", "_id"]

  puts "[ERROR] row columns are not the expected"
  exit(-1)
end

puts "[END] check-json-columns/run.rb"
