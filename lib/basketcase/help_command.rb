require 'basketcase/command'

class Basketcase
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
end