require "json"

class PageProcessor
  def initialize(@config : Config)
  end

  def extract_pagination(json_str : String) : {page: Int32, total_pages: Int32}
    json = parse_json(json_str)

    pagination = json[@config.pagination_key]?
    raise "Missing pagination key '#{@config.pagination_key}' in response" unless pagination

    page = pagination[@config.page_key]?.try(&.as_i)
    raise "Missing page key '#{@config.page_key}' in pagination" unless page

    total_pages = pagination[@config.total_pages_key]?.try(&.as_i)
    raise "Missing total_pages key '#{@config.total_pages_key}' in pagination" unless total_pages

    {page: page, total_pages: total_pages}
  end

  def strip_pagination(json_str : String) : String
    json = parse_json(json_str)

    if json.as_h?
      obj = json.as_h
      obj.delete(@config.pagination_key)
      obj.to_json
    else
      json_str
    end
  end

  def extract_data(json_str : String) : JSON::Any
    json = parse_json(json_str)
    json[@config.data_key]? || JSON::Any.new([] of JSON::Any)
  end

  def aggregate(page_data : Array(JSON::Any)) : String
    all_items = [] of JSON::Any

    page_data.each do |data|
      if arr = data.as_a?
        all_items.concat(arr)
      else
        all_items << data
      end
    end

    result = {
      @config.data_key => all_items,
    }
    result.to_json
  end

  private def parse_json(json_str : String) : JSON::Any
    JSON.parse(json_str)
  rescue ex : JSON::ParseException
    preview = json_str.strip
    preview = preview[0, 100] + "..." if preview.size > 100
    raise "Response is not valid JSON. Body preview: #{preview.inspect}"
  end
end
