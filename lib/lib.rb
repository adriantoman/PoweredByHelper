# encoding: UTF-8

base = Pathname(__FILE__).dirname.expand_path
Dir.glob(base + '*.rb').each do |file|
  require file
end

require_relative 'data/etl'
require_relative 'data/maintenance'
require_relative 'data/project'
require_relative 'data/user'
