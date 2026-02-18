#!/usr/bin/env ruby
require 'bundler/setup'
require 'aws-sdk-sqs'
require 'json'

queue_url = "https://sqs.ap-east-1.amazonaws.com/115154022797/taipower-sns-sqs-github"
sqs = Aws::SQS::Client.new(region: 'ap-east-1')
paths = []
receipt_handles = []

loop do
  receive_message_result = sqs.receive_message({
    queue_url: queue_url,
    max_number_of_messages: 10
  })
  receive_message_result.messages.each do |message|
    receipt_handles << message.receipt_handle
    body = message.body
    json = JSON.parse(body)

    dir, file = json[''].split(/ /)
    Dir.mkdir(dir) unless Dir.exist?(dir)
    path = "#{dir}/#{file}.json"
    File.write(path, message.body)
    puts path

    paths << path
  rescue JSON::ParserError
    puts $!
  end
  break if receive_message_result.messages.length <10
end

raise 'no files' if paths.empty?

system "git", "add", "-v", *paths
system "git", "commit", "-m", "Updated data from AWS SQS"
system "git", "push", exception: true

i=0
receipt_handles.each_slice(10) do |batch|
  sqs.delete_message_batch({
    queue_url: queue_url,
    entries: batch.map do |receipt_handle|
      {
        id: (i += 1).to_s,
        receipt_handle:
      }
    end
  })
  puts "delete"
end
