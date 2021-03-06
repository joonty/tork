require 'socket'
require 'json'
require 'shellwords'
require 'set'
require 'tork/bridge'

module Tork
class Server

  def self.address program=$0
    ".#{program}.sock"
  end

  def initialize
    begin
      @welcome = UNIXServer.open(address = Server.address)
      # UNIX domain socket files are not automatically deleted on close
      at_exit { File.delete address if File.socket? address }
    rescue Errno::EADDRINUSE
      # another instance of this program is already running in the same
      # directory so become a remote control for it rather than exiting
      warn "#{$0}: remotely controlling existing instance..."
      exec 'tork-remote', $0, *ARGV
    end

    # only JSON messages are supposed to be emitted on STDOUT
    # so make puts() in the user code write to STDERR instead
    @stdout = STDOUT.dup
    STDOUT.reopen STDERR

    @servers = Set.new.add(@welcome)
    @clients = Set.new; join STDIN # parent process connected on STDIN
  end

  def loop
    catch :quit do
      while @clients.include? STDIN
        IO.select((@servers + @clients).to_a).first.each do |stream|
          if stream == @welcome
            join stream.accept

          elsif (stream.eof? rescue true)
            part stream

          elsif @command = hear(stream, stream.gets) and not @command.empty?
            recv stream, @command
          end
        end
      end
    end
  end

  def quit
    throw :quit
  end

protected

  def join client
    @clients.add client
  end

  def part client
    @clients.delete client
  end

  # Returns nil if the message received was not meant for processing.
  def hear sender, message
    JSON.parse message
  rescue JSON::ParserError => error
    if @clients.include? sender
      # accept non-JSON "command lines" from clients
      Shellwords.split message
    else
      # forward tell() output from servers to clients
      tell @clients, message, false
      nil
    end
  end

  # Sets the @client variable to the client we are currently serving.
  def recv client, command
    @client = client
    __send__(*command)
  rescue => error
    tell client, error
  end

  def send one_or_more_clients, message
    tell one_or_more_clients, JSON.dump(message), false
  end

  def tell one_or_more_clients, message, prefix=true
    if message.kind_of? Exception
      message = [message.inspect, message.backtrace]
    end

    if prefix
      message = Array(message).join("\n").gsub(/^/, "#{$0}: ")
    end

    targets =
      if one_or_more_clients.respond_to? :to_io
        [one_or_more_clients]
      else
        Array(one_or_more_clients)
      end

    targets.each do |target|
      target = @stdout if target == STDIN
      begin
        target.puts message
        target.flush
      rescue Errno::EPIPE
        # the target closed itself asynchronously
        # https://github.com/sunaku/tork/issues/53
        next
      end
    end
  end

  def popen command
    child = Bridge.new(command)
    @servers.add child
    child
  end

  def pclose child
    child.disconnect if @servers.delete? child
  end

end
end
