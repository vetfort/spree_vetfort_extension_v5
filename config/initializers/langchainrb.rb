Langchain.logger =
  if defined? RailsSemanticLogger
    SemanticLogger[Langchain].tap do |logger|
      logger.level = Logger::ERROR
    end
  else
    Rails.logger
  end
