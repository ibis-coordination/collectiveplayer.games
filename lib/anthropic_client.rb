# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Simple HTTP client for Anthropic Claude API
class AnthropicClient
  API_URL = 'https://api.anthropic.com/v1/messages'
  DEFAULT_MODEL = 'claude-3-haiku-20240307'

  class Error < StandardError; end
  class ConnectionError < Error; end
  class TimeoutError < Error; end
  class AuthError < Error; end

  def initialize(model: DEFAULT_MODEL, timeout: 30)
    @api_key = ENV['ANTHROPIC_API_KEY']
    @model = model
    @timeout = timeout
  end

  # Generate a response from Claude
  # Returns the generated text
  def generate(prompt)
    raise AuthError, 'ANTHROPIC_API_KEY environment variable not set' unless @api_key

    uri = URI.parse(API_URL)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = @timeout
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @api_key
    request['anthropic-version'] = '2023-06-01'
    request.body = {
      model: @model,
      max_tokens: 20,
      messages: [
        { role: 'user', content: prompt }
      ]
    }.to_json

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      result = JSON.parse(response.body)
      result.dig('content', 0, 'text')&.strip || ''
    when Net::HTTPUnauthorized
      raise AuthError, 'Invalid ANTHROPIC_API_KEY'
    else
      raise Error, "Anthropic API error: #{response.code} - #{response.body}"
    end
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
    raise ConnectionError, "Cannot connect to Anthropic API (#{e.message})"
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    raise TimeoutError, "Anthropic request timed out after #{@timeout}s (#{e.message})"
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON response from Anthropic: #{e.message}"
  end

  # Check if API key is available
  def available?
    return false unless @api_key

    # Do a minimal API call to verify the key works
    uri = URI.parse(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @api_key
    request['anthropic-version'] = '2023-06-01'
    request.body = {
      model: @model,
      max_tokens: 5,
      messages: [{ role: 'user', content: 'Hi' }]
    }.to_json

    response = http.request(request)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  # List available models (static list for Claude)
  def list_models
    %w[
      claude-3-haiku-20240307
      claude-3-5-sonnet-20241022
      claude-3-opus-20240229
    ]
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
