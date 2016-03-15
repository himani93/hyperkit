module Hyperkit

  # Custom error class for rescuing from all LXD errors
  class Error < StandardError

    # Returns the appropriate Hyperkit::Error subclass based
    # on status and response message
    #
    # @param [Hash] response HTTP response
    # @return [Hyperkit::Error]
    def self.from_response(response)
      status  = response[:status].to_i
      body    = response[:body].to_s
      headers = response[:response_headers]

      if klass =  case status
                  when 400      then Hyperkit::BadRequest
                  when 401      then Hyperkit::Unauthorized
                  when 403      then Hyperkit::Forbidden
                  when 404      then Hyperkit::NotFound
                  when 405      then Hyperkit::MethodNotAllowed
                  when 406      then Hyperkit::NotAcceptable
                  when 409      then Hyperkit::Conflict
                  when 415      then Hyperkit::UnsupportedMediaType
                  when 422      then Hyperkit::UnprocessableEntity
                  when 400..499 then Hyperkit::ClientError
                  when 500      then Hyperkit::InternalServerError
                  when 501      then Hyperkit::NotImplemented
                  when 502      then Hyperkit::BadGateway
                  when 503      then Hyperkit::ServiceUnavailable
                  when 500..599 then Hyperkit::ServerError
                  end
        klass.new(response)
      end
    end

    def initialize(response=nil)
      @response = response
      super(build_error_message)
    end

    # Documentation URL returned by the API for some errors
    #
    # @return [String]
    def documentation_url
      data[:documentation_url] if data.is_a? Hash
    end

    # Array of validation errors
    # @return [Array<Hash>] Error info
    def errors
      if data && data.is_a?(Hash)
        data[:errors] || []
      else
        []
      end
    end

    private

    def data
      @data ||=
        if (body = @response[:body]) && !body.empty?
          if body.is_a?(String) &&
            @response[:response_headers] &&
            @response[:response_headers][:content_type] =~ /json/

            Sawyer::Agent.serializer.decode(body)
          else
            body
          end
        else
          nil
        end
    end

    def response_message
      case data
      when Hash
        data[:message]
      when String
        data
      end
    end

    def response_error
      "Error: #{data[:error]}" if data.is_a?(Hash) && data[:error]
    end

    def response_error_summary
      return nil unless data.is_a?(Hash) && !Array(data[:errors]).empty?

      summary = "\nError summary:\n"
      summary << data[:errors].map do |hash|
        hash.map { |k,v| "  #{k}: #{v}" }
      end.join("\n")

      summary
    end

    def build_error_message
      return nil if @response.nil?

      message =  "#{@response[:method].to_s.upcase} "
      message << redact_url(@response[:url].to_s) + ": "
      message << "#{@response[:status]} - "
      message << "#{response_message}" unless response_message.nil?
      message << "#{response_error}" unless response_error.nil?
      message << "#{response_error_summary}" unless response_error_summary.nil?
      message << " // See: #{documentation_url}" unless documentation_url.nil?
      message
    end

    def redact_url(url_string)
      %w[secret].each do |token|
        url_string.gsub!(/#{token}=\S+/, "#{token}=(redacted)") if url_string.include? token
      end
      url_string
    end
  end

  # Raised on errors in the 400-499 range
  class ClientError < Error; end

  # Raised when LXD returns a 400 HTTP status code
  class BadRequest < ClientError; end

  # Raised when LXD returns a 401 HTTP status code
  class Unauthorized < ClientError; end

  # Raised when LXD returns a 403 HTTP status code
  class Forbidden < ClientError; end

  # Raised when LXD returns a 403 HTTP status code
  # and body matches 'rate limit exceeded'
  class TooManyRequests < Forbidden; end

  # Raised when LXD returns a 403 HTTP status code
  # and body matches 'login attempts exceeded'
  class TooManyLoginAttempts < Forbidden; end

  # Raised when LXD returns a 403 HTTP status code
  # and body matches 'abuse'
  class AbuseDetected < Forbidden; end

  # Raised when LXD returns a 403 HTTP status code
  # and body matches 'repository access blocked'
  class RepositoryUnavailable < Forbidden; end

  # Raised when LXD returns a 403 HTTP status code
  # and body matches 'email address must be verified'
  class UnverifiedEmail < Forbidden; end

  # Raised when LXD returns a 404 HTTP status code
  class NotFound < ClientError; end

  # Raised when LXD returns a 405 HTTP status code
  class MethodNotAllowed < ClientError; end

  # Raised when LXD returns a 406 HTTP status code
  class NotAcceptable < ClientError; end

  # Raised when LXD returns a 409 HTTP status code
  class Conflict < ClientError; end

  # Raised when LXD returns a 414 HTTP status code
  class UnsupportedMediaType < ClientError; end

  # Raised when LXD returns a 422 HTTP status code
  class UnprocessableEntity < ClientError; end

  # Raised on errors in the 500-599 range
  class ServerError < Error; end

  # Raised when LXD returns a 500 HTTP status code
  class InternalServerError < ServerError; end

  # Raised when LXD returns a 501 HTTP status code
  class NotImplemented < ServerError; end

  # Raised when LXD returns a 502 HTTP status code
  class BadGateway < ServerError; end

  # Raised when LXD returns a 503 HTTP status code
  class ServiceUnavailable < ServerError; end

  # Raised when client fails to provide valid Content-Type
  class MissingContentType < ArgumentError; end

  # Raised when a method requires an application client_id
  # and secret but none is provided
  class ApplicationCredentialsRequired < StandardError; end

  # Raised when a repository is created with an invalid format
  class InvalidRepository < ArgumentError; end

end
