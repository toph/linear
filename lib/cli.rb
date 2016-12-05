require "app"
require "index"
require "puma"

module CLI
  # Prepare will either be called by prepare_and_serve
  # in which dir will have been generated or it is
  # required to have been manually specified.
  def self.generate(filename, index_filename)
    print "Preparing... "
    Index.generate(filename, index_filename).tap do
      puts "done."
    end
  end

  def self.serve(filename, index_filename, threads = 400, port = 4567)
    threads = Integer(threads)
    port = Integer(port)

    app = App.new { Index.new(filename, index_filename) }

    print "Starting... "
    server = Puma::Server.new(app)
    server.add_tcp_listener "0.0.0.0", port
    server.min_threads = threads
    server.max_threads = threads
    puts "ready (on :4567)."
    server.run.join
  end
end
