require 'rake'

module FFI
    module Compiler
        class MultiFileTask < Rake::MultiTask
            def needed?
                begin
                    @application.options.build_all || out_of_date?(File.mtime(name))
                rescue Errno::ENOENT
                    true
                end
            end

            def timestamp
                begin
                    File.mtime(name)
                rescue Errno::ENOENT
                    Rake::LATE
                end
            end

            def invoke_with_call_chain(task_args, invocation_chain)
              return unless needed?
              super
            end

            private

            def out_of_date?(timestamp)
                all_prerequisite_tasks.any? do |prereq|
                    prereq_task = application[prereq, @scope]
                    if prereq_task.instance_of?(Rake::FileTask)
                        File.exist?(prereq_task.name) && prereq_task.timestamp > timestamp
                    else
                        prereq_task.needed?
                    end
                end
            end

            class << self
                # Apply the scope to the task name according to the rules for this kind
                # of task.  File based tasks ignore the scope when creating the name.
                def scope_name(scope, task_name)
                  Rake.from_pathname(task_name)
                end
            end
        end
    end
end
