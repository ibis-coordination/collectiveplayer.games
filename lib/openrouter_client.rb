# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Simple HTTP client for the OpenRouter API (OpenAI-compatible chat completions)
class OpenRouterClient
  API_HOST = 'openrouter.ai'
  CHAT_PATH = '/api/v1/chat/completions'
  MODELS_PATH = '/api/v1/models'
  DEFAULT_MODEL = 'anthropic/claude-haiku-4.5'

  class Error < StandardError; end
  class ConnectionError < Error; end
  class TimeoutError < Error; end
  class AuthError < Error; end

  attr_reader :model

  def initialize(model: DEFAULT_MODEL, timeout: 30)
    @api_key = ENV['OPENROUTER_API_KEY']
    @model = model
    @timeout = timeout
  end

  # Generate a response from the model
  # Returns the generated text
  def generate(prompt)
    raise AuthError, 'OPENROUTER_API_KEY environment variable not set' unless @api_key

    response = post_json(CHAT_PATH, {
      model: @model,
      max_tokens: 20,
      temperature: 0.8,
      messages: [
        { role: 'user', content: prompt }
      ]
    })

    case response
    when Net::HTTPSuccess
      result = JSON.parse(response.body)
      result.dig('choices', 0, 'message', 'content')&.strip || ''
    when Net::HTTPUnauthorized
      raise AuthError, 'Invalid OPENROUTER_API_KEY'
    else
      raise Error, "OpenRouter API error: #{response.code} - #{response.body}"
    end
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
    raise ConnectionError, "Cannot connect to OpenRouter API (#{e.message})"
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    raise TimeoutError, "OpenRouter request timed out after #{@timeout}s (#{e.message})"
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON response from OpenRouter: #{e.message}"
  end

  # Check if an API key is set and the model exists on OpenRouter
  def available?
    return false unless @api_key

    models = list_models
    models.any? && models.include?(@model)
  end

  # List available model IDs (the models endpoint is public)
  def list_models
    uri = URI::HTTPS.build(host: API_HOST, path: MODELS_PATH)
    response = Net::HTTP.get_response(uri)
    return [] unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data['data']&.map { |m| m['id'] }&.compact&.sort || []
  rescue StandardError
    []
  end

  # Extract just the first word from a response
  def extract_word(response)
    return 'END' if response.nil? || response.strip.empty?

    # Clean up the response
    cleaned = response.strip
      .gsub(/["""''`]/, '')  # Remove quotes
      .gsub(/[.!?,;:]$/, '') # Remove trailing punctuation
      .strip

    # Get just the first word
    first_word = cleaned.split(/\s+/).first || 'END'

    # Ensure it's a reasonable word
    first_word = first_word.gsub(/[^a-zA-Z0-9'-]/, '')

    first_word.empty? ? 'END' : first_word
  end

  private

  def post_json(path, body)
    http = Net::HTTP.new(API_HOST, 443)
    http.use_ssl = true
    http.read_timeout = @timeout
    http.open_timeout = 10

    request = Net::HTTP::Post.new(path)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"
    request.body = body.to_json

    http.request(request)
  end
end
