require "kemal"
require "json"
require "option_parser"

# Configuration
port = 8080
host = "127.0.0.1"

OptionParser.parse do |parser|
  parser.banner = "Usage: mock-server [options]"
  parser.on("-p PORT", "--port=PORT", "Port to listen on (default: 8080)") { |p| port = p.to_i }
  parser.on("-h HOST", "--host=HOST", "Host to bind (default: 127.0.0.1)") { |h| host = h }
  parser.on("--help", "Show this help") do
    puts parser
    exit 0
  end
end

# Helper to build paginated items
def build_items(page : Int32, page_size : Int32) : Array(Hash(String, Int32 | String))
  items = [] of Hash(String, Int32 | String)
  page_size.times do |i|
    items << {
      "id"    => "item-#{page}-#{i + 1}",
      "page"  => page,
      "index" => i,
    }
  end
  items
end

# GET /api/items - Paginated items
get "/api/items" do |env|
  env.response.content_type = "application/json"

  page_param = env.params.query["page_param"]? || "page"
  page = (env.params.query[page_param]? || "1").to_i
  total_pages = (env.params.query["total_pages"]? || "3").to_i
  page_size = (env.params.query["page_size"]? || "2").to_i

  items = build_items(page, page_size)

  {
    "data"       => items,
    "pagination" => {
      "page"        => page,
      "total_pages" => total_pages,
    },
  }.to_json
end

# GET/POST /api/echo - Echo request
get "/api/echo" do |env|
  env.response.content_type = "application/json"
  echo_request(env)
end

post "/api/echo" do |env|
  env.response.content_type = "application/json"
  echo_request(env)
end

put "/api/echo" do |env|
  env.response.content_type = "application/json"
  echo_request(env)
end

delete "/api/echo" do |env|
  env.response.content_type = "application/json"
  echo_request(env)
end

def echo_request(env) : String
  headers = {} of String => String
  env.request.headers.each do |key, values|
    headers[key] = values.join(", ")
  end

  query = {} of String => String
  env.params.query.each do |key, value|
    query[key] = value
  end

  body = env.request.body.try(&.gets_to_end) || ""

  {
    "method"  => env.request.method,
    "path"    => env.request.path,
    "query"   => query,
    "headers" => headers,
    "body"    => body,
  }.to_json
end

# GET /api/fault - Fault injection
get "/api/fault" do |env|
  mode = env.params.query["mode"]? || "http_500"
  page = (env.params.query["page"]? || "1").to_i
  total_pages = (env.params.query["total_pages"]? || "3").to_i
  delay = (env.params.query["delay"]? || "1").to_i

  case mode
  when "http_500"
    env.response.status_code = 500
    env.response.content_type = "application/json"
    {"error" => "Internal Server Error"}.to_json

  when "invalid_json"
    env.response.content_type = "application/json"
    "{\"data\": [{\"id\": 1}, {\"id\": 2"  # Truncated JSON

  when "missing_pagination"
    env.response.content_type = "application/json"
    {"data" => build_items(page, 2)}.to_json

  when "missing_data"
    env.response.content_type = "application/json"
    {"pagination" => {"page" => page, "total_pages" => total_pages}}.to_json

  when "wrong_types"
    env.response.content_type = "application/json"
    {
      "data"       => build_items(page, 2),
      "pagination" => {
        "page"        => "not_a_number",  # Wrong type
        "total_pages" => total_pages,
      },
    }.to_json

  when "inconsistent_total"
    # total_pages changes based on current page
    env.response.content_type = "application/json"
    {
      "data"       => build_items(page, 2),
      "pagination" => {
        "page"        => page,
        "total_pages" => total_pages + page,  # Changes each page
      },
    }.to_json

  when "loop_trap"
    # Always returns page 1, causing infinite loop
    env.response.content_type = "application/json"
    {
      "data"       => build_items(1, 2),
      "pagination" => {
        "page"        => 1,  # Always 1
        "total_pages" => total_pages,
      },
    }.to_json

  when "empty_data"
    env.response.content_type = "application/json"
    {
      "data"       => [] of Hash(String, Int32 | String),
      "pagination" => {
        "page"        => page,
        "total_pages" => total_pages,
      },
    }.to_json

  when "slow"
    sleep delay.seconds
    env.response.content_type = "application/json"
    {
      "data"       => build_items(page, 2),
      "pagination" => {
        "page"        => page,
        "total_pages" => total_pages,
      },
    }.to_json

  else
    env.response.status_code = 400
    env.response.content_type = "application/json"
    {"error" => "Unknown mode: #{mode}"}.to_json
  end
end

# Startup message
Kemal.config.port = port
Kemal.config.host_binding = host

before_all do |env|
  STDERR.puts "[#{Time.local}] #{env.request.method} #{env.request.resource}"
end

puts "Mock Server for curl-paging integration tests"
puts "=============================================="
puts "Listening on http://#{host}:#{port}"
puts ""
puts "Endpoints:"
puts "  GET /api/items?page=N&total_pages=N&page_size=N"
puts "  GET/POST /api/echo"
puts "  GET /api/fault?mode=MODE"
puts ""
puts "Fault modes:"
puts "  http_500, invalid_json, missing_pagination, missing_data,"
puts "  wrong_types, inconsistent_total, loop_trap, empty_data, slow"
puts ""
puts "Example curl commands:"
puts "  curl http://#{host}:#{port}/api/items"
puts "  curl http://#{host}:#{port}/api/items?page=2&total_pages=5"
puts "  curl http://#{host}:#{port}/api/echo -X POST -d 'hello'"
puts "  curl http://#{host}:#{port}/api/fault?mode=http_500"
puts ""

Kemal.run
