require "sinatra/base"
require "sinatra/param"

class App < Sinatra::Base
  helpers Sinatra::Param

  def initialize(*args, &factory)
    @factory = factory
    super(*args)
  end

  get "/line/:i" do
    # Param checking will return 400 on error. The spec
    # is silent on the matter, but I think that's the
    # best behavior.
    param :i, Integer, required: true, min: 0

    index[params[:i]] || 413
  end

  def index
    Thread.current[:index] ||= @factory.call
  end
end
