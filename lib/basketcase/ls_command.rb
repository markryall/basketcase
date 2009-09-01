require 'basketcase/command'

class Basketcase
    class LsCommand < Command
      def synopsis
        "[<element> ...]"
      end

      def help
        <<EOF
List element status.

-a(ll)      Show all files.
            (by default, up-to-date files are not reported)

-r(ecurse)  Recursively list sub-directories.
            (by default, just lists current directory)
EOF
      end

      def option_all
        @include_all = true
      end

      alias :option_a :option_all

      def option_directory
        @directory_only = true
      end

      alias :option_d :option_directory

      def execute
        args = ''
        args += ' -recurse' if @recursive
        args += ' -directory' if @directory_only
        cleartool("ls #{args} #{effective_targets}") do |line|
          case line
          when /^(.+)@@(\S+) \[hijacked/
            report(:HIJACK, mkpath($1), $2)
          when /^(.+)@@(\S+) \[loaded but missing\]/
            report(:MISSING, mkpath($1), $2)
          when /^(.+)@@\S+\\CHECKEDOUT(?: from (\S+))?/
            element_path = mkpath($1)
            status = element_path.exist? ? :CO : :MISSING
            report(status, element_path, $2 || 'new')
          when /^(.+)@@(\S+) +Rule: /
            next unless @include_all
            report(:OK, mkpath($1), $2)
          when /^(.+)/
            path = mkpath($1)
            if ignored?(path)
              log_debug "ignoring #{path}"
              next
            end
            report(:LOCAL, path)
          else
            cannot_deal_with line
          end
        end
      end
    end
end