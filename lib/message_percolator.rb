require_relative "indexer/exceptions"

class MessagePercolator
  def process(message)
    with_logging(message) do
      search_server.index("government").percolate(message.payload)
      message.ack
    end
  rescue Indexer::ProcessingError => e
    log_exception(e)
    Airbrake.notify_or_ignore(e, parameters: message.payload)
    message.discard
  rescue StandardError => e
    # This is rescue of last resort. If anything goes wrong during the payload
    # processing, we don't want to retry the message really quickly because
    # that might overload elasticsearch or other components. This should be
    # replaced by a retry mechanism with exponential back-off.
    log_exception(e)
    Airbrake.notify_or_ignore(e, parameters: message.payload)
    sleep 1
    message.retry
  end

private

  def with_logging(message)
    log_payload = message.payload.slice(*%w[
      content_id
      base_path
      document_type
      schema_name
      title
      update_type
      publishing_app
    ])

    puts "Processing message [#{message.delivery_info.delivery_tag}]: #{log_payload.to_json}"

    yield

    puts "Finished processing message [#{message.delivery_info.delivery_tag}]"
  end

  def log_exception(e)
    Logging.logger.root.error "Uncaught exception in processor: \n\n #{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}"
  end
end
