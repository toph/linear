require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs = ["lib"]
  t.warning = false
  t.verbose = true
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test
