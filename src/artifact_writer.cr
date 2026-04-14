class ArtifactWriter
  WIP_SUFFIX = ".wip"

  def initialize(@config : Config)
  end

  # Create wip directory and write request files before curl execution
  def prepare(page_num : Int32, url : String, curl_args : Array(String)) : String
    page_key = "%04d" % page_num
    wip_dir = File.join(@config.artifacts_dir, page_key + WIP_SUFFIX)

    Dir.mkdir_p(wip_dir)

    # Write curl command for debugging
    cmd = build_curl_command(url, curl_args)
    File.write(File.join(wip_dir, "cmd"), cmd)

    # Write request header (reconstructed from args)
    req_header = build_request_header(url, curl_args)
    File.write(File.join(wip_dir, "req.header"), req_header)

    # Write request body if present
    if body = extract_request_body(curl_args)
      File.write(File.join(wip_dir, "req.body"), body)
    end

    wip_dir
  end

  # Write response files after curl execution (success or failure)
  def write_response(wip_dir : String, res_header : String, res_body : String) : Nil
    File.write(File.join(wip_dir, "res.header"), res_header)
    File.write(File.join(wip_dir, "res.body"), res_body)
  end

  # Write stripped JSON and complete (rename wip to final)
  def complete(wip_dir : String, stripped_json : String) : Nil
    File.write(File.join(wip_dir, "res.json"), stripped_json)

    # Remove .wip suffix
    final_dir = wip_dir.chomp(WIP_SUFFIX)
    if wip_dir != final_dir
      # Remove existing final dir if any (from previous run)
      FileUtils.rm_rf(final_dir) if Dir.exists?(final_dir)
      File.rename(wip_dir, final_dir)
    end
  end

  private def build_curl_command(url : String, curl_args : Array(String)) : String
    parts = ["curl"]

    # Add user-specified curl args with proper quoting
    curl_args.each do |arg|
      parts << shell_quote(arg)
    end

    # Add URL
    parts << shell_quote(url)

    parts.join(" ")
  end

  private def shell_quote(s : String) : String
    # If string contains special characters, quote it
    if s.matches?(/^[a-zA-Z0-9_.\/:-]+$/)
      s
    else
      "'" + s.gsub("'", "'\\''") + "'"
    end
  end

  private def build_request_header(url : String, curl_args : Array(String)) : String
    # Extract method from args or default to GET
    method = "GET"
    curl_args.each_with_index do |arg, i|
      if arg == "-X" && i + 1 < curl_args.size
        method = curl_args[i + 1]
        break
      end
    end

    lines = [] of String
    lines << "#{method} #{url}"

    # Extract headers from curl args
    curl_args.each_with_index do |arg, i|
      if arg == "-H" && i + 1 < curl_args.size
        lines << curl_args[i + 1]
      end
    end

    lines.join("\n")
  end

  private def extract_request_body(curl_args : Array(String)) : String?
    curl_args.each_with_index do |arg, i|
      if (arg == "-d" || arg == "--data" || arg == "--data-raw") && i + 1 < curl_args.size
        body = curl_args[i + 1]
        return body.starts_with?("@") ? File.read(body[1..]) : body
      end
    end
    nil
  end
end

require "file_utils"
