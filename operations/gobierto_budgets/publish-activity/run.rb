#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require
require "json"
require "net/https"
require "uri"

# Usage:
#
#  - Must be ran as Rails runner of Gobierto
#
# Arguments:
#
#  - 0: Years to import total budget
#  - 1: CKAN dataset url
#  - 2: Absolute path to a file containing the organizations_ids for the import
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/publish-activity/run.rb budgets_updated ids.txt
#

if ARGV.length != 3
  raise "Review arguments"
end

action = ARGV[0]
budgets_updated_dataset_url = ARGV[1]
ORGANIZATIONS_IDS_FILE_PATH = ARGV[2]

puts "[START] publish-activity/run.rb with action=#{action} file=#{ORGANIZATIONS_IDS_FILE_PATH}"

uri = URI.parse(budgets_updated_dataset_url)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

request = Net::HTTP::Get.new(uri.request_uri)

response = http.request(request)
time = Time.parse(JSON.parse(response.body)["result"]["metadata_modified"])

organizations_ids = []

File.open(ORGANIZATIONS_IDS_FILE_PATH, "r") do |f|
  f.each_line do |line|
    organizations_ids << line.strip
  end
end

if organizations_ids.any?
  puts "Received order to update annual for #{organizations_ids.size} organizations"

  organizations_ids.each do |organization_id|
    puts " - Publishing activity #{action} for #{organization_id}"
    Site.where(organization_id: organization_id).find_each do |site|
      site.activities.where(action: "gobierto_budgets.budgets_updated").destroy_all
      a = site.activities.create! action: "gobierto_budgets.budgets_updated", subject: site, subject_ip: "127.0.0.1", admin_activity: false
      a.created_at = time
      a.save!
    end
  end
else
  puts "[SUMMARY] No organizations to update"
end

puts "[END] publish-activity/run.rb"
