$: << File.expand_path('../lib', __FILE__)

require 'three_balance_scraper'

run lambda { |env|
  result = ThreeBalanceScraper.new.run ENV['THREE_PHONE_NUMBER'], ENV['THREE_PASSWORD']
  [200, {'Content-Type' => 'text/plain'}, StringIO.new(result.join("\n"))]
}
