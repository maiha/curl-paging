class Config
  property data_key : String = "data"
  property pagination_key : String = "pagination"
  property page_key : String = "page"
  property total_pages_key : String = "total_pages"
  property page_param : String = "page"
  property max_pages : Int32 = Int32::MAX  # unlimited by default
  property limit_pages : Int32 = 100
  property artifacts_dir : String = "./paging"
  property curl_args : Array(String) = [] of String
  property url : String = ""
  property output_file : String? = nil
  property header_file : String? = nil
  property paging_mode : Bool = false

  # --cp-XXX options that take a value
  CP_VALUE_OPTIONS = %w[--cp-data-key --cp-pagination-key --cp-page-key --cp-total-pages-key --cp-page-param --cp-max-pages --cp-limit-pages --cp-artifacts-dir]

  # curl options that take a URL as value (don't mistake their value for target URL)
  CURL_URL_VALUE_OPTIONS = %w[-e --referer --proxy --preproxy --doh-url]

  def self.parse(args : Array(String)) : Config
    config = Config.new
    curl_args = [] of String
    i = 0

    # First pass: check if --cp is present
    config.paging_mode = args.includes?("--cp")

    while i < args.size
      arg = args[i]

      if arg == "--cp"
        # Enable paging mode (already set above, just skip)
        # Don't pass to curl
      elsif arg.starts_with?("--cp-")
        if config.paging_mode
          # Process --cp-XXX options only in paging mode
          case arg
          when "--cp-data-key"
            i += 1
            raise "Missing value for --cp-data-key" if i >= args.size
            config.data_key = args[i]
          when "--cp-pagination-key"
            i += 1
            raise "Missing value for --cp-pagination-key" if i >= args.size
            config.pagination_key = args[i]
          when "--cp-page-key"
            i += 1
            raise "Missing value for --cp-page-key" if i >= args.size
            config.page_key = args[i]
          when "--cp-total-pages-key"
            i += 1
            raise "Missing value for --cp-total-pages-key" if i >= args.size
            config.total_pages_key = args[i]
          when "--cp-page-param"
            i += 1
            raise "Missing value for --cp-page-param" if i >= args.size
            config.page_param = args[i]
          when "--cp-max-pages"
            i += 1
            raise "Missing value for --cp-max-pages" if i >= args.size
            config.max_pages = args[i].to_i
          when "--cp-limit-pages"
            i += 1
            raise "Missing value for --cp-limit-pages" if i >= args.size
            config.limit_pages = args[i].to_i
          when "--cp-artifacts-dir"
            i += 1
            raise "Missing value for --cp-artifacts-dir" if i >= args.size
            config.artifacts_dir = args[i]
          else
            # Unknown --cp-XXX in paging mode is an error
            raise "Unknown option: #{arg}"
          end
        else
          # Not in paging mode: skip --cp-XXX and their values
          if CP_VALUE_OPTIONS.includes?(arg)
            i += 1  # Skip the value too
          end
        end
      elsif arg == "-o" || arg == "--output"
        # Special handling: use for final aggregated output, not passed to curl
        i += 1
        raise "Missing value for #{arg}" if i >= args.size
        config.output_file = args[i]
      elsif arg == "-D" || arg == "--dump-header"
        if config.paging_mode
          # In paging mode: intercept and write final header to this file
          i += 1
          raise "Missing value for #{arg}" if i >= args.size
          config.header_file = args[i]
        else
          # In wrapper mode: pass through to curl
          curl_args << arg
          i += 1
          if i < args.size
            curl_args << args[i]
          end
        end
      elsif CURL_URL_VALUE_OPTIONS.includes?(arg)
        # Options that take a URL as value - pass both to curl, don't treat value as target URL
        curl_args << arg
        i += 1
        if i < args.size
          curl_args << args[i]
        end
      elsif arg =~ /^https?:/
        # URL detected by http:// or https:// prefix
        config.url = arg
      else
        # Everything else passes through to curl
        curl_args << arg
      end

      i += 1
    end

    config.curl_args = curl_args
    config
  end
end
