require_relative "mini_graphite/version"
require_relative "mini_graphite/logger"
require_relative "mini_graphite/routes_reporter"
require "benchmark"

require "socket"

module Dalia
  module MiniGraphite
    DEFAULTS = {
      :graphite_host => "graphite.host.com",
      :graphite_port => 2003,
      :statsd_host => "statsd.host.com",
      :statsd_port => 8125,
      :mock_mode => false,
      :debug_mode => false
    }

    def self.config(opts = {})
      @opts = DEFAULTS.merge(opts)
      @logger = Dalia::MiniGraphite::Logger.new(opts[:debug_mode])
      logger.debug("Initalized with opts")
      logger.debug(opts.inspect)
    end

    def self.datapoint(key, value = 1, timestamp = Time.now)
      signal = "#{key} #{value} #{timestamp.to_i}"
      logger.debug("Sending datapoint: '#{signal}'")

      send_tcp(signal) if !opts[:mock_mode]
    end

    def self.counter(key, value = nil)
      value ||= 1
      signal = "#{key}:#{value}|c"
      logger.debug("Sending counter: '#{signal}'")

      send_udp(signal) if !opts[:mock_mode]
    end

    def self.time(key, value = 0)
      signal = "#{key}:#{value}|ms"
      logger.debug("Sending time: '#{signal}'")

      send_udp(signal) if !opts[:mock_mode]
    end

    def self.benchmark_wrapper(key, result_send_method = nil)
      counter("#{key}.ini")

      result = nil

      time =
        Benchmark.realtime do
          result = yield
        end

      counter("#{key}.time", time * 1000)
      counter("#{key}.result", result.send(result_send_method)) if result_send_method
      counter("#{key}.end")

      result
    end

    def self.send_tcp(message)
      hosts = [opts[:graphite_host]].flatten

      hosts.each do |host|
        send_tcp_on_host(host, opts[:graphite_port], message)
      end
    end

    def self.send_udp(message)
      hosts = [opts[:statsd_host]].flatten

      hosts.each do |host|
        send_udp_on_host(host, opts[:statsd_port], message)
      end
    end

    def self.send_tcp_on_host(host, port, message)
      socket = TCPSocket.new(host, port)
      socket.print("#{message}\n")
      socket.close
    end

    def self.send_udp_on_host(host, port, message)
      socket = UDPSocket.new
      socket.send(message, 0, host, port)
      socket.close
    end

  private

    def self.opts
      @opts
    end

    def self.logger
      @logger
    end
  end
end
