require 'pathname'
require 'forwardable'

class Basketcase

  VERSION = '1.1.0'

  @usage = <<EOF
usage: basketcase <command> [<options>]

GLOBAL OPTIONS

    -t/--test	test/dry-run/simulate mode
                (ie. don\'t actually do anything)

    -d/--debug  debug cleartool interaction

COMMANDS        (type 'basketcase help <command>' for details)

EOF

  def log_debug(msg)
    return unless @debug_mode
    $stderr.puts(msg)
  end

  def just_testing?
    @test_mode
  end

  module Utils

    def mkpath(path)
      path = path.to_str
      path = path.tr('\\', '/')
      path = path.sub(%r{^\./},'')
      path = path.sub(%r{^([A-Za-z]):\/}, '/cygdrive/\1/')
      Pathname.new(path)
    end

  end

  include Utils

  def ignored?(path)
    path = Pathname(path).expand_path
    require_ignore_patterns_for(path.parent)
    @ignore_patterns.detect do |pattern|
      File.fnmatch(pattern, path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
    end
  end

  private

  def add_ignore_pattern(pattern)
    @ignore_patterns ||= []
    path = File.expand_path(pattern)
    log_debug "ignore #{path}"
    @ignore_patterns << path
  end

  def ignore(pattern)
    pattern = pattern.to_str
    if pattern[-1,1] == '/'                      # a directory
      add_ignore_pattern pattern.chop          # ignore the directory itself
      add_ignore_pattern pattern + '**/*'      # and any files within it
    else
      add_ignore_pattern pattern
    end
  end

  def define_standard_ignore_patterns
    # Standard ignore patterns
    ignore "**/*.hijacked"
    ignore "**/*.keep"
    ignore "**/*.keep.[0-9]"
    ignore "**/#*#"
    ignore "**/*~"
    ignore "**/basketcase-*.tmp"
  end

  def require_ignore_patterns_for(dir)
    @ignore_patterns_loaded ||= {}
    dir = Pathname(dir).expand_path
    return(nil) if @ignore_patterns_loaded[dir]
    require_ignore_patterns_for(dir.parent) unless dir.root?
    bcignore_file = dir + ".bcignore"
    if bcignore_file.exist?
      log_debug "loading #{bcignore_file}"
      bcignore_file.each_line do |line|
        next if line =~ %r{^#}
        ignore(dir + line.strip)
      end
    end
    @ignore_patterns_loaded[dir] = true
  end

  public

  # Represents the status of an element
  class ElementStatus

    def initialize(path, status, base_version = nil)
      @path = path
      @status = status
      @base_version = base_version
    end

    attr_reader :path, :status, :base_version

    def to_s
      s = "#{path} (#{status})"
      s += " [#{base_version}]" if base_version
      return s
    end

  end

  # Object responsible for nice fomatting of output
  DefaultListener = lambda do |element|
    printf("%-7s %-15s %s\n", element.status,
      element.base_version, element.path)
  end

  class TargetList

    include Enumerable
    include Basketcase::Utils

    def initialize(targets)
      @target_paths = targets.map { |t| mkpath(t) }
    end

    def each
      @target_paths.each do |t|
        yield(t)
      end
    end

    def to_s
      @target_paths.map { |f| "'#{f}'" }.join(" ")
    end

    def empty?
      @target_paths.empty?
    end

    def size
      @target_paths.size
    end

    def parents
      TargetList.new(@target_paths.map { |t| t.parent }.uniq)
    end

  end

  class UsageException < Exception
  end

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

  class HelpCommand < Command

    def synopsis
      "[<command>]"
    end

    def help
      "Display usage instructions."
    end

    def execute
      if @targets.empty?
        puts @basketcase.usage
        exit
      end
      @targets.each do |command_name|
        command = make_command(command_name)
        puts
        puts "% basketcase #{command_name} #{command.synopsis}"
        puts
        puts command.help.gsub(/^/, "    ")
      end
    end

  end

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

  class LsCoCommand < Command

    def synopsis
      "[-r] [-d] [<element> ...]"
    end

    def help
      "List checkouts by ALL users"
    end

    def option_directory
      @directory_only = true
    end

    alias :option_d :option_directory

    def execute
      args = ''
      args += ' -recurse' if @recursive
      args += ' -directory' if @directory_only
      cleartool("lsco #{args} #{effective_targets}") do |line|
        case line
        when /^.*\s(\S+)\s+checkout.*version "(\S+)" from (\S+)/
          report($1, mkpath($2), $3)
        when /^Added /
          # ignore
        when /^  /
          # ignore
        else
          cannot_deal_with line
        end
      end
    end

  end

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

  class CheckinCommand < Command

    def synopsis
      "<element> ..."
    end

    def help
      "Check-in elements, prompting for a check-in message."
    end

    def execute
      prompt_for_comment
      comment_file = Pathname.new("basketcase-checkin-comment.tmp")
      comment_file.open("w") do |out|
        out.puts(@comment)
      end
      cleartool_unsafe("checkin -cfile #{comment_file} #{specified_targets}") do |line|
        case line
        when /^Loading /
          # ignore
        when /^Making dir /
          # ignore
        when /^Checked in "(.+)" version "(\S+)"\./
          report(:COMMIT, mkpath($1), $2)
        else
          cannot_deal_with line
        end
      end
      comment_file.unlink
    end

    def prompt_for_comment
      return if @comment
      comment_file = Pathname.new("basketcase-comment.tmp")
      begin
        comment_file.open('w') do |out|
          out.puts <<EOF
# Please enter the commit message for your changes.
# (Comment lines starting with '#' will not be included)
#
# Changes to be committed:
EOF
          specified_targets.each do |target|
            out.puts "#\t#{target}"
          end
        end
        edit(comment_file)
        @comment = comment_file.read.gsub(/^#.*\n/, '')
      ensure
        comment_file.unlink
      end
      raise UsageException, "No check-in comment provided" if @comment.empty?
      @comment
    end

  end

  class CheckoutCommand < Command

    def synopsis
      "<element> ..."
    end

    def help
      ""
    end

    def help
      <<EOF
Check-out elements (unreserved).
By default, any hijacked version is discarded.

-h(ijack)   Retain the hijacked version.
EOF
    end

    def initialize(*args)
      super(*args)
      @keep_or_revert = '-nquery'
    end

    def option_hijack
      @keep_or_revert = '-usehijack'
    end

    alias :option_h :option_hijack

    def execute
      cleartool_unsafe("checkout -unreserved -ncomment #{@keep_or_revert} #{specified_targets}") do |line|
        case line
        when /^Checked out "(.+)" from version "(\S+)"\./
          report(:CO, mkpath($1), $2)
        end
      end
    end

  end

  class UncheckoutCommand < Command

    def synopsis
      "[-r] <element> ..."
    end

    def help
      <<EOF
Undo a checkout, reverting to the checked-in version.

-r(emove)   Don\'t retain the existing version in a '.keep' file.
EOF
    end

    def initialize(*args)
      super(*args)
      @action = '-keep'
    end

    def option_remove
      @action = '-rm'
    end

    alias :option_r :option_remove

    attr_accessor :action

    def execute
      cleartool_unsafe("uncheckout #{@action} #{specified_targets}") do |line|
        case line
        when /^Loading /
          # ignore
        when /^Making dir /
          # ignore
        when /^Checkout cancelled for "(.+)"\./
          report(:UNCO, mkpath($1))
        when /^Private version .* saved in "(.+)"\./
          report(:KEPT, mkpath($1))
        else
          cannot_deal_with line
        end
      end
    end

  end

  class DirectoryModificationCommand < Command

    def find_locked_elements(paths)
      locked_elements = []
      run(LsCommand, '-a', '-d', *paths) do |e|
        locked_elements << e.path if e.status == :OK
      end
      locked_elements
    end

    def checkout(target_list)
      return if target_list.empty?
      run(CheckoutCommand, *target_list)
    end

    def unlock_parent_directories(target_list)
      checkout find_locked_elements(target_list.parents)
    end

  end

  class RemoveCommand < DirectoryModificationCommand

    def synopsis
      "<element> ..."
    end

    def help
      <<EOF
Mark an element as deleted.
(Parent directories are checked-out automatically)
EOF
    end

    def execute
      unlock_parent_directories(specified_targets)
      cleartool_unsafe("rmname -ncomment #{specified_targets}") do |line|
        case line
        when /^Unloaded /
          # ignore
        when /^Removed "(.+)"\./
          report(:REMOVED, mkpath($1))
        else
          cannot_deal_with line
        end
      end
    end

  end

  class AddCommand < DirectoryModificationCommand

    def synopsis
      "<element> ..."
    end

    def help
      <<EOF
Add elements to the repository.
(Parent directories are checked-out automatically)
EOF
    end

    def execute
      unlock_parent_directories(specified_targets)
      cleartool_unsafe("mkelem -ncomment #{specified_targets}") do |line|
        case line
        when /^Created element /
          # ignore
        when /^Checked out "(.+)" from version "(\S+)"\./
          report(:ADDED, mkpath($1), $2)
        else
          cannot_deal_with line
        end
      end
    end

  end

  class MoveCommand < DirectoryModificationCommand

    def synopsis
      "<from> <to>"
    end

    def help
      <<EOF
Move/rename an element.
(Parent directories are checked-out automatically)
EOF
    end

    def execute
      raise UsageException, "expected two arguments" unless (specified_targets.size == 2)
      unlock_parent_directories(specified_targets)
      cleartool_unsafe("move -ncomment #{specified_targets}") do |line|
        case line
        when /^Moved "(.+)" to "(.+)"\./
          report(:REMOVED, mkpath($1))
          report(:ADDED, mkpath($2))
        else
          cannot_deal_with line
        end
      end
    end

  end

  class DiffCommand < Command

    def synopsis
      "[-g] <element>"
    end

    def help
      <<EOF
Compare a file to the latest checked-in version.

-g          Graphical display.
EOF
    end

    def execute
      args = ''
      args += ' -graphical' if @graphical
      specified_targets.each do |target|
        cleartool("diff #{args} -predecessor #{target}") do |line|
          puts line
        end
      end
    end

  end

  class LogCommand < Command

    def synopsis
      "[<element> ...]"
    end

    def help
      <<EOF
List the history of specified elements.
EOF
    end

    def option_directory
      @directory_only = true
    end

    alias :option_d :option_directory

    def execute
      args = ''
      args += ' -recurse' if @recursive
      args += ' -directory' if @directory_only
      args += ' -graphical' if @graphical
      cleartool("lshistory #{args} #{effective_targets}") do |line|
        puts line
      end
    end

  end

  class VersionTreeCommand < Command

    def synopsis
      "<element>"
    end

    def help
      <<EOF
Display a version-tree of specified elements.

-g          Graphical display.
EOF
    end

    def execute
      args = ''
      args += ' -graphical' if @graphical
      cleartool("lsvtree #{args} #{effective_targets}") do |line|
        puts line
      end
    end

  end

  class AutoCommand < Command

    def each_element(&block)
      run(LsCommand, '-r', *effective_targets, &block)
    end

    def find_checkouts
      checkouts = []
      each_element do |e|
        checkouts << e.path if e.status == :CO
      end
      checkouts
    end

  end

  class AutoCheckinCommand < AutoCommand

    def synopsis
      "[<element> ...]"
    end

    def help
      <<EOF
Bulk commit: check-in all checked-out elements.
EOF
    end

    def execute
      checked_out_elements = find_checkouts
      if checked_out_elements.empty?
        puts "Nothing to check-in"
        return
      end
      run(CheckinCommand, '-m', comment, *checked_out_elements)
    end

  end

  class AutoUncheckoutCommand < AutoCommand

    def synopsis
      "[<element> ...]"
    end

    def help
      <<EOF
Bulk revert: revert all checked-out elements.
EOF
    end

    def execute
      checked_out_elements = find_checkouts
      if checked_out_elements.empty?
        puts "Nothing to revert"
        return
      end
      run(UncheckoutCommand, '-r', *checked_out_elements)
    end

  end

  class AutoSyncCommand < AutoCommand

    def initialize(*args)
      super(*args)
      @control_file = Pathname.new("basketcase-autosync.tmp")
      @actions = []
    end

    def synopsis
      "[<element> ...]"
    end

    def help
      <<EOF
Bulk add/remove: offer to add new elements, and remove missing ones.

-n          Don\'t prompt to confirm actions.
EOF
    end

    def option_noprompt
      @noprompt = true
    end

    alias :option_n :option_noprompt

    def collect_actions
      each_element do |e|
        case e.status
        when :LOCAL
          @actions << ['add', e.path]
        when :MISSING
          @actions << ['rm', e.path]
        when :HIJACK
          @actions << ['co -h', e.path]
        end
      end
    end

    def prompt_for_confirmation
      @control_file.open('w') do |control|
        control.puts <<EOF
# basketcase proposes the actions listed below.
# Delete any that you don't wish to occur, then save this file.
#
EOF
        @actions.each do |a|
          control.puts a.join("\t")
        end
      end
      edit(@control_file)
      @actions = []
      @control_file.open('r') do |control|
        control.each_line do |line|
          if line =~ /^(add|rm|co -h)\s+(.*)/
            @actions << [$1, $2]
          end
        end
      end
    end

    def apply_actions
      ['add', 'rm', 'co -h'].each do |command|
        elements = @actions.map { |a| a[1] if a[0] == command }.compact
        unless elements.empty?
          elements.each_slice(2) {|subelements| run(*(command.split(' ') + subelements)) }
        end
      end
    end

    def execute
      collect_actions
      if @actions.empty?
        puts "No changes required"
        return
      end
      prompt_for_confirmation unless @noprompt
      apply_actions
    end

  end

  @registry = {}

  class << self

    def command(command_class, names)
      names.each { |name| @registry[name] = command_class }
      @usage << "    % #{names.join(', ')}\n"
    end

    def command_class(name)
      return name if Class === name
      @registry[name] || raise(UsageException, "Unknown command: #{name}")
    end

    attr_reader :usage

  end

  command LsCommand,              %w(list ls status stat)
  command LsCoCommand,            %w(lsco)
  command DiffCommand,            %w(diff)
  command LogCommand,             %w(log history)
  command VersionTreeCommand,     %w(tree vtree)

  command UpdateCommand,          %w(update up)
  command CheckinCommand,         %w(checkin ci commit)
  command CheckoutCommand,        %w(checkout co edit)
  command UncheckoutCommand,      %w(uncheckout unco revert)
  command AddCommand,             %w(add)
  command RemoveCommand,          %w(remove rm delete del)
  command MoveCommand,            %w(move mv rename)
  command AutoCheckinCommand,     %w(auto-checkin auto-ci auto-commit)
  command AutoUncheckoutCommand,  %w(auto-uncheckout auto-unco auto-revert)
  command AutoSyncCommand,        %w(auto-sync auto-addrm)

  command HelpCommand,            %w(help)

  def usage
    Basketcase.usage
  end

  def make_command(name)
    Basketcase.command_class(name).new(self)
  end

  def run(name, *args, &block)
    command = make_command(name)
    command.accept_args(args) if args
    command.listener = block if block_given?
    command.execute
  end

  def sync_io
    $stdout.sync = true
    $stderr.sync = true
  end

  def handle_global_options
    while /^-/ === @args[0]
      option = @args.shift
      case option
      when '--test', '-t'
        @test_mode = true
      when '--debug', '-d'
        @debug_mode = true
      else
        raise UsageException, "Unrecognised global argument: #{option}"
      end
    end
  end

  def do(*args)
    @args = args
    begin
      sync_io
      handle_global_options
      raise UsageException, "no command specified" if @args.empty?
      define_standard_ignore_patterns
      run(*@args)
    rescue UsageException => usage
      $stderr.puts "ERROR: #{usage.message}"
      $stderr.puts
      $stderr.puts "try 'basketcase help' for usage info"
      exit(1)
    end
  end

end
