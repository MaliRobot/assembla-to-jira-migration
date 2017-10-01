# frozen_string_literal: true

load './lib/common.rb'

# --- Assembla --- #
assembla_statuses_csv = "#{OUTPUT_DIR_ASSEMBLA}/tickets-statuses.csv"
@statuses_assembla = csv_to_array(assembla_statuses_csv)

@board_columns = @statuses_assembla.reject { |status| status['state'].to_i.zero? }.map {|status| { id: status['id'], name: status['name']}}

puts "\nTotal board columns: #{@board_columns.length}"
@board_columns.each do |col|
  puts "* #{col[:name]}"
end
puts

# --- Jira --- #
jira_projects_csv = "#{OUTPUT_DIR_JIRA}/jira-projects.csv"
jira_tickets_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"

@projects_jira = csv_to_array(jira_projects_csv)
@tickets_jira = csv_to_array(jira_tickets_csv)

project = @projects_jira.detect { |p| p['name'] == JIRA_API_PROJECT_NAME }
goodbye("Cannot find project with name='#{JIRA_API_PROJECT_NAME}'") unless project

@board = jira_get_board_by_project_name(JIRA_API_PROJECT_NAME)

goodbye('Cannot find board name') unless @board

@board_columns.each do |col|

end
