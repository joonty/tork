rspec_version = begin
  require 'rspec/core/version'
  RSpec::Core::Version::STRING
rescue LoadError, NameError
  # ignore
end

if $tork_test_file.start_with? 'spec/' and $tork_line_numbers.any?
  if rspec_version and rspec_version >= '3.0'
    ARGV.push [$tork_test_file, *$tork_line_numbers].join(':')
  else
    $tork_line_numbers.each do |line|
      ARGV.push '--line_number', line.to_s
    end
  end
end
