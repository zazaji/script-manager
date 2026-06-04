# ScriptManager/Resources/Templates/template.rb
#!/usr/bin/env ruby
# @Name: New Ruby Script
# @Desc: A sample script to demonstrate auto UI generation.
# @Author: You
# @Version: 1.0.0
# @Param: name | string | true | World | Who to greet
# @Param: verbose | bool | false | false | Enable verbose output

name = "World"
verbose = false

ARGV.each do |arg|
  if arg == "--verbose"
    verbose = true
  else
    name = arg
  end
end

puts "Verbose mode enabled." if verbose
puts "Hello, #{name}!"