module VagrantPlugins
  module FTPPush
    class Adapter
      attr_reader :host
      attr_reader :port
      attr_reader :username
      attr_reader :password
      attr_reader :options
      attr_reader :server

      def initialize(host, username, password, options = {})
        @host, @port = parse_host(host)
        @username = username
        @password = password
        @options  = options
        @server   = nil
      end

      # Parse the host into it's url and port parts.
      # @return [Array]
      def parse_host(host)
        if host.include?(":")
          split = host.split(":", 2)
          [split[0], split[1].to_i]
        else
          [host, default_port]
        end
      end

      def default_port
        raise NotImplementedError
      end

      def connect(&block)
        raise NotImplementedError
      end

      def upload(local, remote)
        raise NotImplementedError
      end
    end

    #
    # The FTP Adapter
    #
    class FTPAdapter < Adapter
      def initialize(*)
        require "net/ftp"
        super
      end

      def default_port
        20
      end

      def connect(&block)
        @server = Net::FTP.new
        @server.passive = options.fetch(:passive, true)
        @server.connect(host, port)
        @server.login(username, password)

        begin
          yield self
        ensure
          @server.close
        end
      end

      def upload(local, remote)
        parent = File.dirname(remote)

        # Create the parent directory if it does not exist
        if !@server.list("/").any? { |f| f.start_with?(parent) }
          @server.mkdir(parent)
        end

        # Upload the file
        @server.putbinaryfile(local, remote)
      end
    end

    #
    # The SFTP Adapter
    #
    class SFTPAdapter < Adapter
      def initialize(*)
        require "net/sftp"
        super
      end

      def default_port
        22
      end

      def connect(&block)
        Net::SFTP.start(@host, @username, password: @password, port: @port) do |server|
          @server = server
          yield self
        end
      end

      def upload(local, remote)
        @server.upload!(local, remote, mkdir: true)
      end
    end
  end
end
