require "json"
require "uri"

class CurlExecutor
  struct Result
    property status : Int32
    property res_header : String
    property res_body : String

    def initialize(@status, @res_header, @res_body)
    end

    def success? : Bool
      (200..299).includes?(status)
    end
  end

  def initialize(@config : Config)
  end

  def execute(url : String, page : Int32? = nil) : Result
    actual_url = page ? add_page_param(url, page) : url

    # Create temp file for response headers
    res_header_file = File.tempfile("res_header")

    begin
      args = build_curl_args(actual_url, res_header_file.path)

      stdout = IO::Memory.new
      stderr = IO::Memory.new

      Process.run(
        "curl",
        args,
        output: stdout,
        error: stderr
      )

      res_body = stdout.to_s
      res_header = File.exists?(res_header_file.path) ? File.read(res_header_file.path) : ""

      # Extract status code from response header
      status = extract_status_code(res_header)

      Result.new(
        status: status,
        res_header: res_header,
        res_body: res_body
      )
    ensure
      res_header_file.delete
    end
  end

  def build_url(url : String, page : Int32? = nil) : String
    page ? add_page_param(url, page) : url
  end

  private def add_page_param(url : String, page : Int32) : String
    uri = URI.parse(url)
    params = uri.query_params
    params[@config.page_param] = page.to_s
    uri.query = params.to_s
    uri.to_s
  end

  private def build_curl_args(url : String, res_header_file : String) : Array(String)
    args = ["-s", "-S"]  # silent but show errors
    args << "-D" << res_header_file
    args.concat(@config.curl_args)
    args << url
    args
  end

  private def extract_status_code(res_header : String) : Int32
    if match = res_header.match(/HTTP\/[\d.]+ (\d+)/)
      match[1].to_i
    else
      0
    end
  end
end
