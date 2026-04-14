require "./config"
require "./curl_executor"
require "./page_processor"
require "./artifact_writer"
require "./pager"
require "./version"

HELP_TEXT = <<-HELP
curl-paging - curl wrapper with optional pagination support

Usage: curl-paging [options...] <URL>

By default, curl-paging acts as a simple curl wrapper.
Use --cp to enable pagination mode.

Modes:
  (default)                Simple curl wrapper - passes all args to curl
  --cp                     Enable pagination mode
  --version                Show version information

Output options:
  -o, --output FILE        Write output to FILE (default: stdout)

Pagination options (only effective with --cp):
  --cp-data-key KEY        Item array key in response JSON (default: data)
  --cp-pagination-key KEY  Pagination metadata key (default: pagination)
  --cp-page-key KEY        Current page key in pagination (default: page)
  --cp-total-pages-key KEY Total pages key in pagination (default: total_pages)
  --cp-page-param NAME     Query parameter name for page (default: page)
  --cp-max-pages N         Maximum pages to fetch, truncates with success (default: unlimited)
  --cp-limit-pages N       Safety limit, errors if exceeded (default: 100)
  --cp-artifacts-dir DIR   Directory for page artifacts (default: ./paging)

All other options are passed through to curl.

Examples:
  # Simple curl wrapper
  curl-paging https://api.example.com/items
  curl-paging -H "Authorization: Bearer token" https://api.example.com/items

  # Pagination mode
  curl-paging --cp https://api.example.com/items
  curl-paging --cp --cp-max-pages 50 https://api.example.com/items
HELP

if ARGV.includes?("--version")
  puts Version.to_s
  exit 0
end

if ARGV.empty? || ARGV.includes?("-h") || ARGV.includes?("--help")
  puts HELP_TEXT
  exit 0
end

begin
  config = Config.parse(ARGV.to_a)

  if config.paging_mode
    # Pagination mode
    pager = Pager.new(config)
    exit pager.run
  else
    # Simple curl wrapper mode
    if config.url.empty?
      STDERR.puts "Error: URL is required"
      exit 1
    end

    args = config.curl_args + [config.url]

    if output_file = config.output_file
      # Capture output to file
      stdout = IO::Memory.new
      process = Process.run("curl", args, output: stdout, error: STDERR)
      if process.success?
        File.write(output_file, stdout.to_s)
        exit 0
      else
        exit process.exit_code
      end
    else
      # Direct output to stdout
      process = Process.run("curl", args, output: STDOUT, error: STDERR)
      exit process.exit_code
    end
  end
rescue ex
  STDERR.puts "Error: #{ex.message}"
  exit 1
end
