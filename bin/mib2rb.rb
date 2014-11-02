$: << '../lib'
require 'net-snmp'
require 'optparse'
require 'erb'
require 'logger'

Net::SNMP.init

default_template = '
<% nodes = [root] + root.descendants.to_a -%>
<% nodes.each do |node| -%>
<%= root.module.nil? ? "" : "#{root.module.name}::" %><%= root.label %>
  - oid:       <%= node.oid %>
  - type:      <%= node.type %>
  - file:      <%= node.module.file unless node.module.nil? %>
  - descr:     <%= node.description %>
  - enums:     <%= node.enums.map { |e| "#{e[:label]}(#{e[:value]})" }.join(", ") %>
  - parent:    <%= node.parent.oid unless node.parent.nil? %>
  - peers:     <%= node.peers.map { |n| "#{n.label}(#{n.subid})"}.join(", ") %>
  - next:      <%= node.next.oid unless node.next.nil? %>
  - next_peer: <%= node.next_peer.oid unless node.next_peer.nil? %>
  - children:  <%= node.children.map { |n| "#{n.label}(#{n.subid})"}.join(", ") %>
<% end -%>
'.sub!("\n", "") # Remove leading newline

usage = <<USAGE
Usage: mib2rb [OPTION]... ROOT_NODE [ERB_FILE]

Description
  Prints a mib subtree according to the ERB_FILE.

Options
  -h,          Prints this usage information.

               Aliases:   --help

  -l LEVEL     Set the log level.
               Logs are piped to STDERR, so you can redirect
               STDOUT to a file without worrying about logs
               getting into the output.

               Values:   debug, info, warn, error, fatal, none
               Default:  none
               Alieases: --log-level


Arguments
  ROOT_NODE    [Required] The root node of the mib tree to translate.
               May be specified as numeric oid or mib name.

  ERB_FILE     [Optional] The template file to use for output.
               Within the erb file, the `node` variable is the root
               node specified by ROOT_NODE as a Net::SNMP::Node object.
               This can be used to traverse the mib subtree using
               `node.children` recursively.

               Default:  Builtin template specifying human readable output.
                         (See below)

Example ERB_FILE Contents:

#{default_template.each_line.map { |l| "  #{l}" }.join}

USAGE

optparse = OptionParser.new do|opts|
  opts.on( '-h', '--help') do
    puts usage
    exit
  end

  opts.on('-l', '--log-level LEVEL') do |level|
    break if level =~ /none/i

    Net::SNMP::Debug.logger = Logger.new(STDERR)
    Net::SNMP::Debug.logger.level = case level
      when /debug/i
        Logger::DEBUG
      when /info/i
        Logger::INFO
      when /warn/i
        Logger::WARN
      when /error/i
        Logger::ERROR
      when /fatal/i
        Logger::FATAL
      else
        puts "Invalid log level: #{level}"
        puts
        puts usage
        exit(1)
    end
  end
end
optparse.parse!

root_node = nil
erb_template = nil

case ARGV.length
when 1
  root_node = Net::SNMP::MIB.get_node(ARGV[0])
  erb_template = default_template
when 2
  root_node = et::SNMP::MIB.get_node(ARGV[0])
  erb_template = File.read(ARGV[1])
else
  puts "Invalid arguments..."
  puts
  puts usage
  exit(1)
end

def render(node, erb_template)
  root = node
  erb = ERB.new(erb_template, nil, '-')
  puts erb.result binding
end

render(root_node, erb_template)
