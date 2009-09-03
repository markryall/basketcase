require 'basketcase/command'

class Basketcase
  
  class UpdateCommand < Command

    def synopsis
      "[-nomerge] [<element> ...]"
    end

    def help
      <<EOF
Update your (snapshot) view.

-nomerge    Don\'t attempt to merge in changes to checked-out files.
EOF

    end

    def option_nomerge
      @nomerge = true
    end

    def relative_path(s)
      full_path = view_root + mkpath(s)
      full_path.relative_path_from(Pathname.pwd)
    end

    def execute_update
      args = '-log nul -force'
      args += ' -print' if just_testing?
      cleartool("update #{args} #{effective_targets}") do |line|
        case line
        when /^Processing dir "(.*)"/
          # ignore
        when /^\.*$/
          # ignore
        when /^Making dir "(.*)"/
          report(:NEW, relative_path($1))
        when /^Loading "(.*)"/
          report(:UPDATED, relative_path($1))
        when /^Unloaded "(.*)"/
          report(:REMOVED, relative_path($1))
        when /^Keeping hijacked object "(.*)" - base "(.*)"/
          report(:HIJACK, relative_path($1), $2)
        when /^Keeping "(.*)"/
          # ignore
        when /^End dir/
          # ignore
        when /^Done loading/
          # ignore
        else
          cannot_deal_with line
        end
      end
    end

    def execute_merge
      args = '-log nul -flatest '
      if just_testing?
        args += "-print"
      elsif @graphical
        args += "-gmerge"
      else
        args += "-merge -gmerge"
      end
      cleartool("findmerge #{effective_targets} #{args}") do |line|
        case line
        when /^Needs Merge "(.+)" \[to \S+ from (\S+) base (\S+)\]/
          report(:MERGE, mkpath($1), $2)
        end
      end
    end

    def execute
      execute_update
      execute_merge unless @nomerge
    end

  end
end