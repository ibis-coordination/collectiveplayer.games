# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Simple HTTP client for Ollama API
class OllamaClient
  DEFAULT_HOST = 'http://localhost:11434'
  DEFAULT_MODEL = 'llama3.2'
  DEFAULT_TIMEOUT = 60

  class Error < StandardError; end
  class ConnectionError < Error; end
  class TimeoutError < Error; end

  def initialize(host: DEFAULT_HOST, model: DEFAULT_MODEL, timeout: DEFAULT_TIMEOUT)
    @host = host
    @model = model
    @timeout = timeout
  end

  # Generate a response from Ollama
  # Returns the generated text
  def generate(prompt)
    uri = URI.parse("#{@host}/api/generate")

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = @timeout
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = {
      model: @model,
      prompt: prompt,
      stream: false,
      options: {
        temperature: 0.8,
        num_predict: 20  # Limit response length
      }
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Ollama API error: #{response.code} - #{response.body}"
    end

    result = JSON.parse(response.body)
    result['response']&.strip || ''
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
    raise ConnectionError, "Cannot connect to Ollama at #{@host}. Is Ollama running? (#{e.message})"
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    raise TimeoutError, "Ollama request timed out after #{@timeout}s (#{e.message})"
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON response from Ollama: #{e.message}"
  end

  # Check if Ollama is available and the model exists
  def available?
    uri = URI.parse("#{@host}/api/tags")
    response = Net::HTTP.get_response(uri)
    return false unless response.is_a?(Net::HTTPSuccess)

    tags = JSON.parse(response.body)
    models = tags['models']&.map { |m| m['name']&.split(':')&.first } || []
    models.include?(@model.split(':').first)
  rescue StandardError
    false
  end

  # List available models
  def list_models
    uri = URI.parse("#{@host}/api/tags")
    response = Net::HTTP.get_response(uri)
    return [] unless response.is_a?(Net::HTTPSuccess)

    tags = JSON.parse(response.body)
    tags['models']&.map { |m| m['name'] } || []
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
end
