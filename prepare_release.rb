after = ARGV.first
if after.nil?
  $stderr.puts "Example: ruby #{__FILE__} v0.6.0"
  exit 1
end

path = 'lib/aws/xray/version.rb'
version_str = after.gsub('v', '')
File.write(path, File.read(path).gsub(/VERSION = '.+'$/, "VERSION = '#{version_str}'"))
system('git', 'add', path)
system('git', 'commit', '-m', after)
