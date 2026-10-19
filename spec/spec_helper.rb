$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

Dir[File.join(__dir__, 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
