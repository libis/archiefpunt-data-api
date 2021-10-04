$LOAD_PATH << '.'
require 'rack/cors'
require 'app/controllers/main_controller'

use Rack::Cors do
  allow do
    origins '*'
    resource '*', methods: [:get], headers: :any
  end
end


map '/' do
  run MainController
end
