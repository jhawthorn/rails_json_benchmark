require "rails/all"
require "rapidjson"
require "benchmark/ips"

source_twitter_data = ::JSON.parse(File.read("twitter.json"))

# We're making a fake twitter reimplementation, based on the popular
# twitter.json benchmark.
# It's far from perfect. I'm sure the real Rails serializer which probably once
# powered this had more models, but this gives us non-zero so we're actually
# exercising the .as_json path

class User
  def initialize(data)
    @data = data
    @data[:created_at] = Time.parse(@data[:created_at])
    @data.keys.each { self.class.attr_reader _1 unless respond_to? _1 }
  end

  def as_json(*) = @data
end

class Status
  def initialize(data)
    @data = data
    @data[:user] = User.new(@data[:user])
    @data[:created_at] = Time.parse(@data[:created_at])
    @data[:retweeted_status] = Status.new(@data[:retweeted_status]) if @data[:retweeted_status]
  end

  def as_json(*) = @data
end

data = source_twitter_data.deep_symbolize_keys.deep_dup
data[:statuses].map! { Status.new(_1) }

TestEncoder = MyEncoder.new do |obj, is_key|
  if !is_key
    obj.as_json
  else
    obj.to_s
  end
end


#p data.to_json
result = TestEncoder.dump(data)

File.write("test.json", result)
File.write("compare.json", data.to_json)

p result.size
p data.to_json.size
p source_twitter_data.to_json.size

Benchmark.ips do |x|
  x.report "data.to_json" do
    data.to_json
  end

  x.report "source_twitter_data.to_json" do
    source_twitter_data.to_json
  end

  x.report "JSON.generate(source_data)" do
    JSON.generate(source_twitter_data)
  end

  x.report "RapidJSON.generate(source_data)" do
    RapidJSON.encode(source_twitter_data)
  end

  x.report "TestEncoder" do
    TestEncoder.dump(data)
  end
end

