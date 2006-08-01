#! /usr/bin/env ruby

# This is an attempt to wrap up the ClearCase command-line interface
# (cleartool) to enable more CVS-like (or Subversion-like) usage of
# ClearCase.
#
# Warning: this script is EXPERIMENTAL: use AT YOUR OWN RISK
#
# @author Mike Williams

$BASKETCASE = "basketcase"

$USAGE = <<EOF
usage: #{$BASKETCASE} <command> [<options>]

GLOBAL OPTIONS

    -t/--test	test/dry-run/simulate mode
                (ie. don\'t actually do anything)

    -d/--debug  debug cleartool interaction

COMMANDS        (type '$BASKETCASE help <command>' for details)

EOF
# ... command details are added below ...

#---( Imports )---

require 'pathname'

#---( Globals )---

$cwd = Pathname.new('.').expand_path
$test_mode = false
$debug_mode = false

$stdout.sync = true
$stderr.sync = true

#---( Ignorance is bliss )---

$ignore_patterns = []

def ignore(regexp)
  $ignore_patterns << regexp
end

def ignored?(path)
  $ignore_patterns.each { |rexexp| return true if rexexp === path }
  return false
end

ignore %r{(^|/).temp}
ignore %r{(^|/)bin}
ignore %r{(^|/)classes}
ignore %r{/orbtrc}
ignore %r{\.LST$}
ignore %r{\.ant-targets-}
ignore %r{\.class$}
ignore %r{\.contrib$}
ignore %r{\.contrib\.\d+$}
ignore %r{\.keep$}
ignore %r{\.keep\.\d+$}
ignore %r{\.iws$}
ignore %r{\.jar$}
ignore %r{\.jasper$}
ignore %r{\.keep$}
ignore %r{\.log$}
ignore %r{\.lst$}
ignore %r{\.merge$}
ignore %r{\.temp$}
ignore %r{\.tmp$}
ignore %r{\.unloaded$}
ignore %r{junit\d+\.properties$}
ignore %r{null}
ignore %r{~$}

#---( Utilities )---

def mkpath(path)
  Pathname.new(path.to_str.tr('\\', '/').sub(%r{^./},''))
end

def log_debug(msg)
  return unless $debug_mode
  $stderr.puts(msg) 
end

class Symbol
  def to_proc
    proc { |obj, *args| obj.send(self, *args) }
  end
end

#---( Output formatting )---

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
class DefaultListener

  def report(element)
    printf("%-7s %-15s %s\n", element.status, 
                   element.base_version, element.path)
  end
  
end

#---( Target list )---

class TargetList

  include Enumerable

  def initialize(targets)
    @target_paths = targets.map { |t| mkpath(t) }
  end
  
  def each
    @target_paths.each do |t|
      yield(t)
    end
  end
  
  def to_s
    @target_paths.join(" ")
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

#---( Command registry )---

$command_registry = {}

def command(command_class, names)
  names.each { |name| $command_registry[name] = command_class }
  $USAGE << "    % #{names.join(', ')}\n"
end

class UsageException < Exception
end

def make_command(name)
  raise UsageException, "no command specified" if name.nil?
  command_class = $command_registry[name]
  raise UsageException, "Unknown command: " + name unless command_class
  command_class.new
end

#---( Commands )---

# Base ClearCase command
class Command

  def synopsis
    ""
  end

  def help
    "Sorry, no help provided ..."
  end

  attr_writer :listener
  attr_writer :targets

  def initialize()
    @listener = DefaultListener.new
    @recursive = false
    @graphical = false
  end

  def report(status, path, version = nil)
    @listener.report(ElementStatus.new(path, status, version))
  end

  def option_recurse
    @recursive = true
  end

  alias :option_r :option_recurse

  def option_graphical
    @graphical = true
  end

  alias :option_g :option_graphical

  # Handle command-line arguments:
  # - For option arguments of the form "-X", call the corresponding
  #   option_X() method.
  # - Remaining arguments are stored in @targets
  def accept_args(args)
    while /^-+(.+)/ === args[0]
      option = args.shift
      option_method = "option_#{$1}".to_sym
      unless respond_to?(option_method)
        raise UsageException, "Unrecognised option: #{option}"
      end
      send(option_method)
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
      log_debug "<<< " + line
      yield(line) if block_given?
    end
  end
    
  def cleartool_unsafe(command, &block)
    if $test_mode
      log_debug "WOULD RUN: cleartool #{command}"
      return
    end
    cleartool(command, &block)
  end
    
  def view_root
    cleartool("pwv -root") do |line|
      return mkpath(line.chomp)
    end
  end

  def cannot_deal_with(line)
    $stderr.puts "unrecognised output: " + line
  end

  def prompt_for_comment
    comment_file_path = Pathname.new("basketcase-comment.tmp")
    comment_file_path.open('w') do |comment_file|
      puts "Enter message (terminated by '.'):"
      message = ""
      $stdin.each_line do |line|
        break if line.chomp == '.'
        comment_file << line
      end
    end
    return comment_file_path
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
      puts $USAGE
      exit
    end
    @targets.each do |command_name|
      command = make_command(command_name)
      puts
      puts "% #{$BASKETCASE} #{command_name} #{command.synopsis}"
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
      when /^(\S+)@@(\S+) \[hijacked/
        report(:HIJACK, mkpath($1), $2)
      when /^(\S+)@@(\S+) \[loaded but missing\]/
        report(:MISSING, mkpath($1), $2)
      when /^(\S+)@@(\S+) +Rule: /
        next unless @include_all
        report(:OK, mkpath($1), $2)
      when /^(\S+)@@\S+ from (\S+)/
        element_path = mkpath($1)
        status = element_path.exist? ? :CO : :MISSING
        report(status, element_path, $2)
      when /^(\S+)/ 
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
    raise '@root not defined' unless(@root)
    full_path = @root + mkpath(s)
    full_path.relative_path_from($cwd)
  end

  def execute_update 
    @root = view_root
    args = '-log nul -force'
    args += ' -print' if $test_mode
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
    if $test_mode 
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
    puts "Checking-in:"
    specified_targets.each do |path|
      puts "  " + path
    end
    comment_file = prompt_for_comment
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

end

class CheckoutCommand < Command

  def synopsis
    "<element> ..."
  end

  def help
    "Check-out elements (unreserved)."
  end

  def execute
    cleartool_unsafe("checkout -unreserved -ncomment #{specified_targets}") do |line|
      case line
      when /^Checked out "(.+)" from version "(\S+)"\./
        report(:CO, mkpath($1), $2)
      when /^Element "(.+)" is already checked out/
        report(:CO, mkpath($1), 'already')
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

  def initialize
    super
    @action = '-keep'
  end
  
  def option_remove
    @action = '-rm'
  end
  
  alias :option_r :option_remove

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

class CollectingListener

  attr_reader :elements

  def initialize
    @elements = []
  end

  def report(element)
    @elements << element
  end
  
end

class DirectoryModificationCommand < Command

  def find_locked_elements(paths)
    ls = LsCommand.new
    ls.option_a
    ls.option_d
    ls.targets = paths
    collector = CollectingListener.new
    ls.listener = collector
    ls.execute
    collector.elements.find_all { |e| e.status == :OK }.collect(&:path)
  end

  def checkout(target_list)
    return if target_list.empty?
    co = CheckoutCommand.new
    co.targets = target_list
    co.execute
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
    @targets.each do |target|
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

  def list_elements
    ls = LsCommand.new
    ls.option_r
    ls.targets = effective_targets
    collector = CollectingListener.new
    ls.listener = collector
    ls.execute
    collector.elements
  end

  def find_checkouts
    list_elements.find_all { |e| e.status == :CO }.collect(&:path)
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
    ci = CheckinCommand.new
    ci.targets = checked_out_elements
    ci.execute
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
    unco = UncheckoutCommand.new
    unco.targets = checked_out_elements
    unco.execute
  end
  
end

class AutoSyncCommand < AutoCommand
  
  def initialize
    @control_file = Pathname.new("basketcase-autosync.tmp")
  end

  def synopsis
    "[<element> ...]"
  end

  def help
    <<EOF
Bulk add/remove: offer to add new elements, and remove missing ones.
EOF
  end

  def generate_control_file
    element_list = list_elements
    local_elements = element_list.find_all { |e| e.status == :LOCAL }.collect(&:path)
    missing_elements = element_list.find_all { |e| e.status == :MISSING }.collect(&:path)
    @control_file.open('w') do |control|
      local_elements.each do |path|
        control.puts "ADD\t#{path}"
      end
      missing_elements.each do |path|
        control.puts "RM\t#{path}"
      end
    end
  end

  def edit_control_file
    editor = ENV["EDITOR"] || "notepad"
    system("#{editor} #{@control_file}")
  end

  def process_control_file
    elements_to_add = []
    elements_to_remove = []
    @control_file.open do |control|
      control.each_line do |line|
        case line
        when /^ADD\s+(.*)/
          elements_to_add << $1
        when /^RM\s+(.*)/
          elements_to_remove << $1
        end
      end
    end
    add_elements(elements_to_add)
    remove_elements(elements_to_remove)
  end

  def add_elements(targets)
    return if targets.empty?
    add = AddCommand.new
    add.targets = targets
    add.execute
  end

  def remove_elements(targets)
    return if targets.empty?
    remove = RemoveCommand.new
    remove.targets = targets
    remove.execute
  end

  def execute
    generate_control_file
    edit_control_file
    process_control_file
  end

end

#---( Register commands )---

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

#---( Command-line processing )---

class CommandLine

  def handle_global_options
    while /^-/ === @args[0]
      option = @args.shift
      case option
      when '--test', '-t'
        $test_mode = true
      when '--debug', '-d'
        $debug_mode = true
      else
        raise UsageException, "Unrecognised global argument: #{option}"
      end
    end
  end

  def do(*args)
    @args = args
    begin
      handle_global_options
      @command = make_command(@args.shift)
      @command.accept_args(@args)
      @command.execute
    rescue UsageException => usage
      $stderr.puts "ERROR: #{usage.message}"
      $stderr.puts
      $stderr.puts "try '#{$BASKETCASE} help' for usage info"
      exit(1)
    end
  end

end

CommandLine.new.do(*ARGV)

# TODO:
# - automatic uncheckout of files that can't be merged (for Durran)
