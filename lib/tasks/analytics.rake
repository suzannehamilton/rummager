require "analytics_data"
require "csv"

namespace :analytics do
  ALL_CONTENT_SEARCH_INDICES = %w(mainstream detailed government govuk).freeze

  desc "
  Export all indexed pages to a CSV suitable for importing into Google Analytics.

  The generated file is saved to disk, so you should run this task from the server and
  then use SCP to retrieve the file, which will be around 100 MB.
  "
  task :create_data_import_csv do
    elasticsearch_config = SearchConfig.new.elasticsearch

    analytics_data = AnalyticsData.new(elasticsearch_config["base_uri"], ALL_CONTENT_SEARCH_INDICES)

    path = ENV['EXPORT_PATH'] || 'data'
    FileUtils.mkdir_p(path)
    file_name = "#{path}/analytics_data_import_#{Date.today.strftime('%Y%m%d')}.csv"
    puts "Exporting to: #{file_name}"

    CSV.open(file_name, "wb") do |csv|
      csv << analytics_data.headers

      analytics_data.rows.each do |row|
        csv << row
      end
    end
  end

  desc "Delete old export files (specify the number to keep with EXPORT_FILE_LIMIT)"
  task :delete_old_files do
    path = ENV['EXPORT_PATH'] || 'data'
    export_file_limit = ENV.fetch('EXPORT_FILE_LIMIT').to_i + 1
    files = Dir["#{path}/analytics_data_import_*.csv"]
    files = files.sort
    files[0..-export_file_limit].each do |file|
      puts "Removing file: #{file}"
      File.delete(file)
    end
  end
end
