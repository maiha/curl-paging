require "file_utils"

class Pager
  def initialize(@config : Config)
    @executor = CurlExecutor.new(@config)
    @processor = PageProcessor.new(@config)
    @writer = ArtifactWriter.new(@config)
    @url_history = Set(String).new
    @response_page_history = Set(Int32).new
  end

  def run : Int32
    if @config.url.empty?
      STDERR.puts "Error: URL is required"
      return 1
    end

    # Rule 3: Clear paging directory before starting
    clear_artifacts_dir

    page_data = [] of JSON::Any
    last_header = ""

    # Fetch first page
    STDERR.puts "Fetching page 1..."
    result = fetch_page(1)
    return 1 unless result

    begin
      pagination = @processor.extract_pagination(result[:body])
      response_page = pagination[:page]
      total_pages = pagination[:total_pages]

      # Check for duplicate response page_id
      if check_duplicate_response_page(response_page)
        return 1
      end

      # Safety valve: limit_pages is a hard error limit
      if total_pages > @config.limit_pages
        STDERR.puts "Error: total_pages (#{total_pages}) exceeds limit_pages (#{@config.limit_pages})"
        return 1
      end

      # Limit to max_pages (soft limit, normal truncation)
      pages_to_fetch = Math.min(total_pages, @config.max_pages)
      if total_pages > @config.max_pages
        STDERR.puts "Note: Limiting to #{@config.max_pages} pages (total: #{total_pages})"
      end

      # Process first page
      stripped = @processor.strip_pagination(result[:body])
      @writer.complete(result[:wip_dir], stripped)
      page_data << @processor.extract_data(stripped)
      last_header = result[:header]

      # Fetch remaining pages (up to max_pages)
      (2..pages_to_fetch).each do |page|
        STDERR.puts "Fetching page #{page}/#{pages_to_fetch}..."
        result = fetch_page(page)
        return 1 unless result

        # Check response page_id for duplicates
        pagination = @processor.extract_pagination(result[:body])
        response_page = pagination[:page]
        if check_duplicate_response_page(response_page)
          return 1
        end

        stripped = @processor.strip_pagination(result[:body])
        @writer.complete(result[:wip_dir], stripped)
        page_data << @processor.extract_data(stripped)
        last_header = result[:header]
      end

      # Output aggregated result
      aggregated = @processor.aggregate(page_data)
      if output_file = @config.output_file
        File.write(output_file, aggregated)
      else
        puts aggregated
      end

      # Write header file if requested (-D option)
      if header_file = @config.header_file
        File.write(header_file, last_header)
      end

      0
    rescue ex
      STDERR.puts "Error: #{ex.message}"
      1
    end
  end

  # Clear artifacts directory before starting (Rule 3)
  private def clear_artifacts_dir
    dir = @config.artifacts_dir
    if Dir.exists?(dir)
      FileUtils.rm_rf(dir)
    end
  end

  # Check if page_id directory already exists (Rule 1)
  private def check_duplicate_page_id(page_num : Int32) : Bool
    page_key = "%04d" % page_num
    dir = @config.artifacts_dir

    # Check both .wip and non-.wip versions
    wip_path = File.join(dir, "#{page_key}.wip")
    final_path = File.join(dir, page_key)

    if Dir.exists?(wip_path) || Dir.exists?(final_path)
      STDERR.puts "Error: Duplicate page_id detected: #{page_key}"
      return true
    end
    false
  end

  # Check if URL was already fetched (Rule 2)
  private def check_duplicate_url(url : String) : Bool
    if @url_history.includes?(url)
      STDERR.puts "Error: Duplicate URL detected (infinite loop prevention): #{url}"
      return true
    end
    @url_history.add(url)
    false
  end

  # Check if response page_id was already seen (additional safety)
  private def check_duplicate_response_page(page : Int32) : Bool
    if @response_page_history.includes?(page)
      STDERR.puts "Error: Duplicate response page detected (infinite loop prevention): page #{page}"
      return true
    end
    @response_page_history.add(page)
    false
  end

  # Fetch a page with artifact preparation
  # Returns nil on failure, leaves .wip directory for debugging
  private def fetch_page(page_num : Int32) : NamedTuple(body: String, header: String, wip_dir: String)?
    # Rule 1: Check duplicate page_id
    if check_duplicate_page_id(page_num)
      return nil
    end

    url = @executor.build_url(@config.url, page_num == 1 ? nil : page_num)

    # Rule 2: Check duplicate URL
    if check_duplicate_url(url)
      return nil
    end

    # Prepare artifacts directory and write request files
    wip_dir = @writer.prepare(page_num, url, @config.curl_args)

    # Execute curl
    result = @executor.execute(@config.url, page_num == 1 ? nil : page_num)

    # Write response files (always, even on failure)
    @writer.write_response(wip_dir, result.res_header, result.res_body)

    unless result.success?
      STDERR.puts "Error: HTTP #{result.status}"
      # Leave .wip directory for debugging
      nil
    else
      {body: result.res_body, header: result.res_header, wip_dir: wip_dir}
    end
  end
end
