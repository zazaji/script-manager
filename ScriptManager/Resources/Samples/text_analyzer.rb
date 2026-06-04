# ScriptManager/Resources/Samples/text_analyzer.rb
#!/usr/bin/env ruby
# @Name: Text Analyzer
# @Desc: Analyzes text to count words, characters, and find the most frequent words.
# @Author: ScriptManager
# @Version: 1.0.0
# @Param: text | string | true | Hello world! This is a test. | Text to analyze
# @Param: top_words | string | false | 3 | Number of top frequent words to display

puts "📝 Starting Text Analyzer..."

if ARGV.empty?
  puts "❌ Error: Text parameter is required."
  exit 1
end

text = ARGV[0]
top_n = (ARGV[1] || 3).to_i

puts "Analyzing text: \"#{text}\""
puts "----------------------------------------"

# Character count
char_count = text.length
puts "🔤 Total Characters: #{char_count}"

# Word count
words = text.downcase.scan(/\w+/)
word_count = words.length
puts "📖 Total Words: #{word_count}"

# Word frequency
frequencies = Hash.new(0)
words.each { |word| frequencies[word] += 1 }

sorted_frequencies = frequencies.sort_by { |word, count| -count }

puts "🏆 Top #{top_n} Frequent Words:"
sorted_frequencies.first(top_n).each_with_index do |(word, count), index|
  puts "  #{index + 1}. '#{word}' - #{count} times"
end

puts "----------------------------------------"
puts "✅ Analysis completed."