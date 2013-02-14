require "bundler/gem_tasks"

root = File.dirname(__FILE__)
tasks_dir = File.join(root, "tasks")
$:.unshift(tasks_dir)
$:.unshift(File.join(root, "lib"))

Dir[File.join(tasks_dir, "**", "*.rake")].each do |task_file|
  load task_file
end

task :default => :spec
