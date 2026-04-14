module Version
  # All values are captured at compile time via Crystal macros

  NAME = "curl-paging"

  # git describe --tags --long --always → "v1.0.0-3-gabcdef0" or "abcdef0"
  GIT_DESCRIBE = {{ `(git describe --tags --long --always 2>/dev/null || echo "unknown")`.stringify.chomp }}

  {% begin %}
    {% parts = `(git describe --tags --long --always 2>/dev/null || echo "")`.chomp.split("-") %}
    {% if parts.size >= 3 %}
      TAG     = {{ parts[0..-3].join("-").gsub(/^v/, "") }}
      AHEAD   = {{ parts[-2] }}
      SHA     = {{ parts[-1].gsub(/^g/, "") }}
    {% else %}
      TAG     = {{ `cat shard.yml`.lines.select(&.starts_with?("version:")).first.split(":").last.strip }}
      AHEAD   = "0"
      SHA     = {{ `(git rev-parse --short HEAD 2>/dev/null || echo "unknown")`.stringify.chomp }}
    {% end %}
  {% end %}

  DATE           = {{ `date "+%Y-%m-%d"`.stringify.chomp }}
  CRYSTAL        = Crystal::VERSION
  TARGET_TRIPLE  = {{ `crystal -v 2>/dev/null | grep -oE '[a-z0-9_]+-[a-z]+-[a-z]+-[a-z]+' || echo "unknown"`.stringify.chomp }}

  def self.to_s : String
    version = if AHEAD == "0"
                "#{TAG} [#{SHA}]"
              else
                "#{TAG}+#{AHEAD} [#{SHA}]"
              end
    "#{NAME} #{version} (#{DATE}) #{TARGET_TRIPLE} crystal-#{CRYSTAL}"
  end
end
