#!/usr/bin/env ruby
# Ruby's standard YAML parser reads the checked-in operator policy, never PR code.
require 'json'
require 'yaml'

policy = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false).fetch('merge_policy', {})
labels = policy.fetch('full_ci_labels', [])
raise 'full_ci_labels must be a string array' unless labels.is_a?(Array) && labels.all? { |v| v.is_a?(String) && !v.empty? }
pr = JSON.parse(File.read(ARGV.fetch(1)))
files = JSON.parse(File.read(ARGV.fetch(2)))
paths = files.flat_map { |file| [file.fetch('filename'), file['previous_filename']].compact }
full = pr.fetch('labels').any? do |label|
  label_name = label.fetch('name')
  label_name.casecmp?('ci:full') || labels.any? { |configured| configured.casecmp?(label_name) }
end
puts "full_ci=#{full}"
docs_only = !full && paths.any? && paths.all? { |path| path.start_with?('website/', 'packages/aiur-style/') }
puts "docs_only=#{docs_only}"
