require 'basketcase/utils'

class Basketcase
  # Base ClearCase command
  class Command
    include Basketcase::Utils

    extend Forwardable
    def_delegators :@basketcase, :log_debug, :just_testing?, :ignored?, :make_command, :run

    def synopsis
      ""
    end

    def help
      "Sorry, no help provided ..."
    end

    def initialize(basketcase)
      @basketcase = basketcase
      @listener = DefaultListener
      @recursive = false
      @graphical = false
    end

    attr_writer :listener
    attr_writer :targets

    def report(status, path, version = nil)
      @listener.call(ElementStatus.new(path, status, version))
    end

    def option_recurse
      @recursive = true
    end

    alias :option_r :option_recurse

    def option_graphical
      @graphical = true
    end

    alias :option_g :option_graphical

    def option_comment(comment)
      @comment = comment
    end

    alias :option_m :option_comment

    attr_accessor :comment

    # Handle command-line arguments:
    # - For option arguments of the form "-X", call the corresponding
    #   option_X() method.
    # - Remaining arguments are stored in @targets
    def accept_args(args)
      while /^-+(.+)/ === args[0]
        option = args.shift
        option_method_name = "option_#{$1}"
        unless respond_to?(option_method_name)
          raise UsageException, "Unrecognised option: #{option}"
        end
        option_method = method(option_method_name)
        parameters = []
        option_method.arity.times { parameters << args.shift }
        option_method.call(*parameters)
      end
      @targets = args
      self
    end

    def effective_targets
      TargetList.new(@targets.empty? ? ['.'] : @targets)
    end

    def specified_targets
      raise UsageException, "No target specified" if @targets.empty?
      TargetList.new(@targets)
    end

    private

    def cleartool(command)
      log_debug "RUNNING: cleartool #{command}"
      IO.popen("cleartool " + command).each_line do |line|
        line.sub!("\r", '')
        log_debug "<<< " + line
        yield(line) if block_given?
      end
    end

    def cleartool_unsafe(command, &block)
      if just_testing?
        puts "WOULD RUN: cleartool #{command}"
        return
      end
      cleartool(command, &block)
    end

    def view_root
      @root ||= catch(:root) do
        cleartool("pwv -root") do |line|
          throw :root, mkpath(line.chomp)
        end
      end
      log_debug "view_root = #{@root}"
      @root
    end

    def cannot_deal_with(line)
      $stderr.puts "unrecognised output: " + line
    end

    def edit(file)
      editor = ENV["EDITOR"] || "notepad"
      system("#{editor} #{file}")
    end
  end
end