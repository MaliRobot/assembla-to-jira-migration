# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla users
assembla_users_csv = "#{dirname_assembla}/report-users.csv"
@users_assembla = csv_to_array(assembla_users_csv)

# TODO: Move to common.rb
@user_id_to_login = {}
@list_of_logins = {}
@users_assembla.each do |user|
  login = user['login'].sub(/@.*$/,'')
  @user_id_to_login[user['id']] = login
  @list_of_logins[login] = true
end

# Assembla comments
comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"
@comments_assembla = csv_to_array(comments_assembla_csv)
total_comments = @comments_assembla.length

# Ignore empty comments
@comments_assembla_empty = @comments_assembla.select { |comment| comment['comment'].nil? || comment['comment'].strip.empty? }
@comments_assembla.select! { |comment| ! (comment['comment'].nil? || comment['comment'].strip.empty?) }

puts "Total comments: #{total_comments}"
puts "Empty comments: #{@comments_assembla_empty.length}"
puts "Remaining comments: #{@comments_assembla.length}"

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

# Convert assembla_ticket_id to jira_ticket_id and assembla_ticket_number to jira_ticket_key
@assembla_id_to_jira_id = {}
@assembla_number_to_jira_key = {}
@tickets_jira.each do |ticket|
  @assembla_id_to_jira_id[ticket['assembla_ticket_id']] = ticket['jira_ticket_id']
  @assembla_number_to_jira_key[ticket['assembla_ticket_number']] = ticket['jira_ticket_key']
end

# Jira attachments (images)
attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
@attachments_jira = csv_to_array(attachments_jira_csv)

@list_of_images = {}
@attachments_jira.each do |attachment|
  @list_of_images[attachment['assembla_attachment_id']] = attachment['filename']
end

puts "Attachments: #{@attachments_jira.length}"
puts

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "Filter newer than: #{tickets_created_on}"
  comments_initial = @comments_assembla.length
  # Only want comments which belong to remaining tickets
  @comments_assembla.select! { |item| @assembla_id_to_jira_id[item['ticket_id']] }
  puts "Comments: #{comments_initial} => #{@comments_assembla.length} ∆#{comments_initial - @comments_assembla.length}"
end
puts "Tickets: #{@tickets_jira.length}"

@comments_total = @comments_assembla.length

# POST /rest/api/2/issue/{issueIdOrKey}/comment
def jira_create_comment(issue_id, user_id, comment, counter)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}/comment"
  user_login = @user_id_to_login[user_id]
  headers = headers_user_login(user_login)
  body = "Assembla | Created on #{date_time(comment['created_on'])}\n\n#{reformat_markdown(comment['comment'], logins: @list_of_logins, images: @list_of_images, content_type: 'comments', strikethru: true)}"
  payload = {
    body: body
  }.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    result = JSON.parse(response.body)
    percentage = ((counter * 100) / @comments_total).round.to_s.rjust(3)
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} => OK"
  rescue RestClient::ExceptionWithResponse => e
    # TODO: use following helper method for all RestClient calls in other files.
    rest_client_exception(e, 'POST', url)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@comments_total}] POST #{url} => NOK (#{e.message})"
  end
  result
end

# IMPORTANT: Make sure that the comments are ordered chronologically from first (oldest) to last (newest)
@comments_assembla.sort! { |x, y| x['created_on'] <=> y['created_on'] }

@jira_comments = []

@comments_assembla.each_with_index do |comment, index|
  id = comment['id']
  ticket_id = comment['ticket_id']
  user_id = comment['user_id']
  issue_id = @assembla_id_to_jira_id[ticket_id]
  user_login = @user_id_to_login[user_id],
  comment['comment'] = reformat_markdown(comment['comment'], logins: @list_of_logins, images: @list_of_images,  tickets: @assembla_number_to_jira_key, content_type: 'comments', strikethru: true)
  result = jira_create_comment(issue_id, user_id, comment, index + 1)
  next unless result
  comment_id = result['id']
  @jira_comments << {
    jira_comment_id: comment_id,
    jira_ticket_id: issue_id,
    assembla_comment_id: id,
    assembla_ticket_id: ticket_id,
    user_login: user_login,
    body: comment['comment']
  }
end

puts "Total all: #{@comments_total}"
comments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments.csv"
write_csv_file(comments_jira_csv, @jira_comments)
